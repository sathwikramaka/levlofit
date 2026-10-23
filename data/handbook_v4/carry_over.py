"""Carry evidence-review decisions from the v3 register into the Handbook v4 draft register, then record the review of
the new v4 text that this session could check. Run after extract_claims.py --sync for v4 (see README.md here).

Rules (nothing is marked resolved without a basis):
  - A v4 claim whose text is identical (same text hash) to a reviewed v3 claim inherits that review, with a note naming
    the v3 claim. Changed text stays unreviewed.
  - Up next items and part openers are navigation and structure text: labelled editorial, wording review only.
  - Key points restate their chapter: left unreviewed, with a note asking the reviewer to match them to the chapter.
  - New claims are checked only against source text already downloaded in the evidence audit; each quoted passage must
    occur in that text (after whitespace normalisation) or the script stops.
  - New medical warning signs and after-birth guidance are flagged for clinical review and need a source.
Usage: python -I data/handbook_v4/carry_over.py <folder with who2020.txt and helms2014.xml>
"""
import csv
import importlib.util
import html
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V3 = HERE.parent / "evidence" / "claims_register.csv"
V4 = HERE / "claims_register.csv"
REVIEW = ["evidence_status", "passage_source", "supporting_passage", "passage_locator", "reviewed_by", "reviewed_on", "review_needs", "notes"]
TODAY = "2026-10-14"
WHO = "Claude (session 2026-10-14); passage matched in the downloaded source text"


def norm(s):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", s))).replace(" ", " ")


def main(src_dir: Path):
    who = re.sub(r"\s+", " ", (src_dir / "who2020.txt").read_text(encoding="utf-8"))   # plain text: no tag stripping ("<6 METs")
    hx = (src_dir / "helms2014.xml").read_text(encoding="utf-8")
    helms = norm(hx[hx.find("<body"):hx.rfind("</body>")])

    def quote(text, *passages):
        for p in passages:
            assert p in text, f"passage not found in source text: {p[:60]}"
        return " [...] ".join(passages)

    v3 = list(csv.DictReader(V3.open(encoding="utf-8", newline="")))
    rows = list(csv.DictReader(V4.open(encoding="utf-8", newline="")))
    cols = list(rows[0].keys())
    by_sha = {}
    for r in v3:
        # Unreviewed v3 claims are included too: their gates (source_access, clinical, content_decision) must carry over.
        if r["evidence_status"] != "auto_label" and (r["evidence_status"] != "unreviewed" or r["review_needs"] or r["notes"]):
            by_sha.setdefault(r["text_sha"], []).append(r)

    def wording(t):  # v4 wording edits that do not change a claim's meaning
        return t.lower().replace("workout", "session")
    changed = {(r["chapter"], wording(r["text"])): r for r in v3 if r["evidence_status"] != "auto_label"}
    spec = importlib.util.spec_from_file_location("v4", HERE / "build_handbook_v4.py")
    v4m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(v4m)

    def v3_of(r):
        """The v3 claim a v4 claim came from when v4 only reworded it (recorded in REWORDS) or swapped workout/session."""
        h = changed.get((r["chapter"], wording(r["text"])))
        if h:
            return h
        text = r["text"]
        for slug, old, new in v4m.REWORDS:   # undo every recorded reword in this chapter, then look up the v3 text
            if slug == r["chapter"] and new in text:
                text = text.replace(new, old)
        return changed.get((r["chapter"], wording(text)))
    carried = nav = keyp = gated = 0
    for r in rows:
        if r["evidence_status"] == "stale" and not v3_of(r) and not by_sha.get(r["text_sha"]):
            # A claim id reused by different text after blocks moved (for example a block inserted above it): the old
            # review belonged to other text, so nothing of it is kept; the steps below label the new text afresh.
            for k in REVIEW:
                r[k] = ""
            r["evidence_status"] = "unreviewed"
        if r["evidence_status"] not in ("unreviewed", "auto_label", "stale"):
            continue
        hits = by_sha.get(r["text_sha"], [])
        same = [h for h in hits if h["chapter"] == r["chapter"]] or hits
        if same:
            if not r["notes"].startswith("Carried from v3"):
                h = same[0]
                for k in (REVIEW if h["evidence_status"] != "unreviewed" else ["review_needs", "notes"]):
                    r[k] = h[k]
                r["notes"] = f"Carried from v3 claim {h['claim_id']} (identical text). " + h["notes"]
                carried += 1
        elif r["evidence_status"] in ("unreviewed", "stale") and v3_of(r):
            # Same claim with v4 wording edits ("workout" -> "session", or a recorded reword such as Decision 2's
            # cautious wording): the review is NOT carried, the gates are.
            h = v3_of(r)
            if r["evidence_status"] == "stale":
                for k in ("passage_source", "supporting_passage", "passage_locator", "reviewed_by", "reviewed_on"):
                    r[k] = ""
                r["evidence_status"] = "unreviewed"
            if h["review_needs"] and not r["review_needs"]:
                r["review_needs"] = h["review_needs"]
            if not r["notes"].startswith("Text changed in v4"):
                r["notes"] = f"Text changed in v4 from v3 claim {h['claim_id']} (wording only); review reset, gates carried. " + h["notes"]
            gated += 1
        elif r["block_type"] in ("next", "part"):
            r.update(evidence_status="editorial", reviewed_by="Claude (session 2026-10-14); structure text",
                     reviewed_on=TODAY, review_needs="",
                     notes="Navigation or part-opener text written for the v4 book draft; no factual claim. Wording review only.")
            nav += 1
        elif r["block_type"] == "keypoints" and r["evidence_status"] == "unreviewed":
            r["review_needs"] = "summary_check"
            r["notes"] = "Key point restating this chapter; reviewer to confirm it matches the chapter's reviewed claims and their status."
            keyp += 1

    by = {r["claim_id"]: r for r in rows}

    def find(chapter, needle):
        m = [r for r in rows if r["chapter"] == chapter and needle in r["text"]]
        assert len(m) == 1, (chapter, needle, len(m))
        return m[0]

    def record(r, status, src, passage, locator, note, needs=""):
        r.update(evidence_status=status, passage_source=src, supporting_passage=passage, passage_locator=locator,
                 reviewed_by=WHO, reviewed_on=TODAY, review_needs=needs, notes=note)

    WHO_LOC = "PMC7719906 (article body)"
    LPA = "light-intensity physical activity is usually a 2–4 on a rating scale of perceived exertion scale of 0–10"
    MPA = "MPA is usually a 5 or 6 on a rating scale of perceived exertion scale of 0–10"
    VPA = "VPA is usually a 7 or 8 on a rating scale of perceived exertion scale of 0–10"
    ADULT = "All adults should undertake 150–300 min of moderate-intensity, or 75–150 min of vigorous-intensity physical activity"
    record(find("cardio-intensity", "WHO rates light activity"), "verified", "who2020", quote(who, LPA, MPA, VPA), WHO_LOC, "New v4 text.")
    record(find("cardio-intensity", "2 to 4 · Light"), "verified", "who2020", quote(who, LPA, "Examples include slow walking"), WHO_LOC, "New v4 text.")
    record(find("cardio-intensity", "5 to 6 · Moderate"), "verified", "who2020", quote(who, MPA, ADULT), WHO_LOC, "New v4 text.")
    record(find("cardio-intensity", "7 to 8 · Vigorous"), "verified", "who2020", quote(who, VPA, ADULT), WHO_LOC, "New v4 text.")
    for needle in ("All moderate", "All vigorous", "Mixed: 90 moderate", "Add up"):
        record(find("cardio-intensity", needle), "partly_supported", "who2020", quote(who, ADULT), WHO_LOC,
               "New v4 text. The 2-to-1 equivalence is read from WHO's matching ranges (150-300 moderate vs 75-150 vigorous); WHO says 'some equivalent combination' without giving the ratio here.")
    CHILD = "Children and adolescents (aged 5–17 years)"
    record(find("welcome", "WHO gives separate physical activity"), "verified", "who2020", quote(who, CHILD), WHO_LOC, "New v4 text.")
    PREG = ("all pregnant and postpartum women without contraindication should: undertake regular physical activity throughout pregnancy and post partum; "
            "do at least 150 min of moderate-intensity aerobic physical activity throughout the week for substantial health benefits; "
            "incorporate a variety of aerobic and muscle-strengthening activities")
    CONT = "Women who, before pregnancy, habitually engaged in vigorous-intensity aerobic activity or who were physically active can continue these activities during pregnancy and the postpartum period."
    record(find("women", "WHO advises pregnant and postpartum"), "needs_clinical_review", "who2020", quote(who, PREG, CONT), WHO_LOC,
           "New v4 text; source-checked. Pregnancy guidance stays a clinical review item.", needs="clinical")
    LEA = "low-levels of sustained energy availability are also the proposed cause of the hormonal disturbance “athletic amenorrhea” in women"
    TEST = "these testosterone changes in men appear mostly related to energy availability"
    record(find("under-eating", "In lean athletes, low energy availability"), "needs_clinical_review", "helms2014", quote(helms, TEST, LEA),
           "PMC4033492 (article body)", "New v4 text; source-checked. Part of the eating-too-little chapter, a clinical review item.", needs="clinical")

    ax = (src_dir / "acsm2026.xml").read_text(encoding="utf-8")
    acsm = norm(ax[ax.find("<body"):ax.rfind("</body>")])
    VOL = "higher volume (≥10 sets/muscle group/wk)"
    FREQ = "RT did not influence hypertrophy performed with low (1 d/wk) versus high (>5 d/wk) frequency when total volume was equated"
    r = find("build-muscle", "Reaching your weekly sets")
    if r["evidence_status"] in ("unreviewed", "stale"):  # stale: the v3-reviewed text was reworded
        record(r, "verified", "acsm2026", quote(acsm, VOL, FREQ), "PMC12965823 (article body)",
               "Reworded in v4 (was 'Training each muscle twice a week', verified only against ACSM's general twice-weekly "
               "advice). Resolves the conflict with Sets, reps and progress using ACSM 2026; reviewer to confirm the wording.",
               needs="reviewer_confirm")

    # Decision 4 caution (PROVISIONAL, pending source and clinical review). Passages from ISSN 2017 (caffeine), already read;
    # recorded as source-checked parts only, never approved. No numeric daily limit is given (no source read).
    cx = (src_dir / "issncaffeine.xml").read_text(encoding="utf-8")
    caf = norm(cx[cx.find("<body"):cx.rfind("</body>")])
    PREG = "The rate of caffeine metabolism may be inhibited or decreased with pregnancy or use of hormonal contraceptives"
    BP1 = "individuals with the AC or CC genotype (slow metabolizers) have an elevated risk of myocardial infarction"
    BP2 = "hypertension and elevated blood pressure"
    SLEEP = "caffeine ingestion before an evening Super Rugby game resulted in a delay in time at sleep onset and a reduction in sleep duration"
    DEC4 = "Decision 4 caution (PROVISIONAL, pending source and clinical review). "
    caution = {
        "Count your whole day": (None, None, "No source read on daily caffeine totals; no number is given until one is checked."),
        "Pregnant or on hormonal contraception?": (quote(caf, PREG), "partly_supported",
            "Supports slower clearance in pregnancy and with hormonal contraceptives; the advice to ask a doctor is Levlofit's referral wording."),
        "High blood pressure or a heart condition?": (quote(caf, BP1, BP2), "partly_supported",
            "Supports a link in slow metabolisers (a genetic type) between more caffeinated coffee and higher blood pressure; the doctor referral is Levlofit's wording."),
        "Sleep": (quote(caf, SLEEP), "partly_supported", "One study of evening caffeine in rugby players; 'hours before bed' is Levlofit's wording."),
    }
    for r in rows:
        if r["chapter"] != "supplements" or r["evidence_status"] != "unreviewed":
            continue
        for title, (passage, status, note) in caution.items():
            if r["text"].startswith(title + " · "):
                if passage:
                    record(r, status, "issncaffeine", passage, "PMC7777221 (article body)", DEC4 + note, needs="clinical; content_decision")
                else:
                    r["review_needs"] = "source_needed; clinical; content_decision"
                    r["notes"] = DEC4 + note
    for r in rows:   # the reworded 9 mg/kg warning and the caution's heading belong to the same decision
        if r["chapter"] == "supplements" and ("higher-dose example" in r["text"]) and "content_decision" not in r["review_needs"]:
            r["review_needs"] = (r["review_needs"] + "; content_decision").lstrip("; ")
            r["notes"] = DEC4 + r["notes"]

    # Decision 5 (option B, wording pending review): add review flags, never remove the carried ones; nothing verified here.
    DEC5 = "Decision 5 (option B, owner 2026-10-14; wording pending review). "
    ACSM5 = ("ACSM 2026 passage for the reviewer to match: 'Strength was not affected by ... short (<1 min) versus long (>1 min) "
             "between-set rest intervals'; hypertrophy: 'insufficient data'. Grgic 2018 and Grgic 2017 remain unread. ")
    adds = [
        ("rest-between-sets", "Muscle building (evidence under review)", "source_needed",
         "The matching review is Grgic 2017 (ACSM ref 143, unread), not grgic2018; stays flagged until it is read. "),
        ("rest-between-sets", "Big lifts (Levlofit rule)", "reviewer_confirm", "Levlofit rule matching the app timer (120 s for compound lifts); not a proven optimum. "),
        ("rest-between-sets", "Other exercises (Levlofit rule)", "reviewer_confirm", "Levlofit rule matching the app timer (90 s); not a proven optimum. "),
        ("rest-between-sets", "Similar · strength outcomes", "reviewer_confirm", ACSM5),
        ("rest-between-sets", "Similar strength outcomes were reported", "reviewer_confirm; grade_confirm",
         ACSM5 + "Grade 'moderate' kept only pending reviewer confirmation: ACSM's 63% evidence-quality rating is not Levlofit's grade. "),
        ("get-stronger", "About 2 · min rest", "reviewer_confirm", "Levlofit rule; " + ACSM5),
    ]
    for chapter, needle, flag, note in adds:
        hit = [r for r in rows if r["chapter"] == chapter and r["text"].startswith(needle) and r["evidence_status"] != "auto_label" and r["block_type"] != "keypoints"]
        assert len(hit) == 1, (chapter, needle, len(hit))
        r = hit[0]
        for f in flag.split("; "):
            if f not in r["review_needs"]:
                r["review_needs"] = (r["review_needs"] + "; " + f).lstrip("; ")
        if DEC5 not in r["notes"]:
            r["notes"] = DEC5 + note + r["notes"]

    # Worked examples: arithmetic of Levlofit's own method, checked here.
    assert 10 * 70 + 6.25 * 175 - 5 * 30 + 5 == 1648.75 and round(1648.75 * 1.375) == 2267 and round(2267 * 0.85) == 1927
    assert 60 * 1.4 == 84 and 60 * 2.0 == 120 and 84 / 4 == 21 and 120 / 4 == 30
    for chapter, title in (("calories", "Worked example"), ("food-basics", "Worked example: protein")):
        for r in rows:
            if r["chapter"] == chapter and r["block_type"] == "steps" and r["evidence_status"] == "unreviewed" and \
                    any(x in r["text"] for x in ("30-year-old", "BMR · 10 x", "Activity · Light activity", "Goal · Fat loss",
                                                 "Daily target · 1.4", "Spread it · Four", "On the plate · For example", title)):
                r.update(evidence_status="editorial", reviewed_by="Claude (session 2026-10-14); arithmetic checked",
                         reviewed_on=TODAY, review_needs="",
                         notes="Worked example of the method in this chapter; arithmetic checked (1648.75, 2267, 1927 kcal; 84 to 120 g, 21 to 30 g per meal).")

    # New medical warning content: explicit clinical gates, no source yet.
    gates = [("under-eating", None), ("water", "Dizziness, nausea"), ("water", "Confusion, or skin"), ("water", "Get medical help"),
             ("water", "Stop, get into shade"), ("women", "After giving birth"), ("over-40", "Levlofit builds plans for ages 18 to 80")]
    flagged = 0
    for chapter, needle in gates:
        for r in rows:
            if r["chapter"] == chapter and (needle is None or needle in r["text"]) and r["evidence_status"] == "unreviewed":
                r["review_needs"] = "source_needed; clinical" if chapter != "over-40" else "clinical"
                prefix = "New v4 safety or medical guidance: needs a qualified reviewer and, where it states a fact, a source. "
                r["notes"] = r["notes"] if r["notes"].startswith(prefix) else prefix + r["notes"]
                flagged += 1

    # Correction (2026-10-14): ACSM 2026 reports insufficient data on concurrent training, not "no effect".
    wrong = ("Possible conflict: ACSM 2026 (article body) lists concurrent training among variables that did not affect strength; "
             "the cited Wilson 2012 meta-analysis could not be read.")
    right = ("No read source decides this: ACSM 2026 (article body) reports insufficient data to determine whether aerobic and "
             "resistance training in the same session affects strength, muscle growth or power (it does not report 'no effect'); "
             "the cited Wilson 2012 meta-analysis could not be read. Decision 2 provisional option C (cautious wording), pending evidence review.")
    for r in rows:
        if wrong in r["notes"]:
            r["notes"] = r["notes"].replace(wrong, right)

    # The BMI cut-off decision also governs the eating-too-little rules that depend on "below the healthy range".
    for r in rows:
        if r["chapter"] == "under-eating" and "BMI" in r["text"] and "content_decision" not in r["review_needs"]:
            r["review_needs"] = (r["review_needs"] + "; content_decision").lstrip("; ")
            r["notes"] = "Depends on the open BMI cut-off decision (Misra 2009 vs ICMR 2024). " + r["notes"]

    # A key point summarising a chapter that has clinical items is itself a clinical review item (conservative).
    clinical_chapters = {r["chapter"] for r in rows if "clinical" in r["review_needs"]}
    for r in rows:
        if r["block_type"] == "keypoints" and r["evidence_status"] == "unreviewed" and r["chapter"] in clinical_chapters \
                and "clinical" not in r["review_needs"]:
            r["review_needs"] = "summary_check; clinical"
    # Likewise for the open content decisions (BMI cut-offs, running vs strength, vegetarian muscle-building, caffeine):
    # a key point in such a chapter must not settle the decision by summarising it.
    decision_chapters = {r["chapter"] for r in rows if "content_decision" in r["review_needs"] and r["block_type"] != "keypoints"}
    for r in rows:
        if r["block_type"] == "keypoints" and r["evidence_status"] == "unreviewed" and r["chapter"] in decision_chapters \
                and "content_decision" not in r["review_needs"]:
            r["review_needs"] = (r["review_needs"] + "; content_decision").lstrip("; ")

    w = csv.DictWriter(V4.open("w", encoding="utf-8", newline=""), fieldnames=cols, lineterminator="\n")
    w.writeheader()
    w.writerows(rows)
    print(f"carried {carried} reviews from v3; {gated} changed claims kept their gates; {nav} navigation units editorial; {keyp} key points to confirm; {flagged} new clinical gates")


if __name__ == "__main__":
    main(Path(sys.argv[1]))

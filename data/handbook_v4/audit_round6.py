"""Evidence audit round 6 (2026-10-16): the claims with no source and the claims read only in abstracts, checked against
open-access full texts where they exist (Europe PMC), one accepted manuscript (green open access) and, where no open
full text exists, the PubMed abstract. Texts are downloaded by fetch_round6.py; every quoted passage must occur in the
downloaded text or the script stops. Nothing here is a qualified reviewer's sign-off.

Access levels (recorded in passage_locator):
  full        open-access published article, full text read
  manuscript  accepted manuscript in the author's university repository (green open access), full text read
  abstract    PubMed abstract only: never treated as full-text verified; the source_access gate stays open
Gates: a verified record removes source_needed and summary_check; only a full-text or manuscript read also removes
source_access, and never on reworded v4 text (its v3 gate is carried, as in round 5). partly_supported removes only
source_needed (a source is attached; the status keeps the item open). Clinical claims stop at needs_clinical_review.
The same text in the v3 register gets the same record (by text hash), as in round 5.

Usage: python -I data/handbook_v4/audit_round6.py <folder written by fetch_round6.py>
"""
import csv
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V3 = HERE.parent / "evidence" / "claims_register.csv"
V4 = HERE / "claims_register.csv"
SOURCES = HERE / "sources_register.csv"
TODAY = "2026-10-16"
WHO = "Claude (session 2026-10-16, AI, not a qualified reviewer); passage matched in the downloaded text"

ACCESS = {
    "refalo2025": ("full", "PMC11869894, CC BY"), "manore2017": ("full", "PMC5579698, CC BY"),
    "wilson2025": ("full", "PMC12357318, CC BY-NC-ND"), "cunha2023": ("full", "PMC10354314, CC BY"),
    "zhang2020": ("full", "PMC7056053, CC BY-NC-ND"), "konrad2024": ("full", "PMC10980866, CC BY-NC-ND"),
    "coetsee2015": ("full", "PMC4748325, CC BY"), "singer2024": ("full", "PMC11349676, CC BY"),
    "zourdos2016": ("manuscript", "accepted manuscript, hdl.handle.net/10292/12176 (AUT repository)"),
    "mifflin1990": ("abstract", "PMID 2305711"), "lake2012": ("abstract", "PMID 22580981"),
    "seiler2010": ("abstract", "PMID 20861519"), "behm2016": ("abstract", "PMID 26642915"),
}
URL = {
    "refalo2025": "https://doi.org/10.7717/peerj.19042", "manore2017": "https://doi.org/10.3390/nu9080905",
    "wilson2025": "https://doi.org/10.1016/j.jshs.2025.101024", "cunha2023": "https://doi.org/10.1186/s40798-023-00599-z",
    "zhang2020": "https://doi.org/10.14309/ctg.0000000000000122", "konrad2024": "https://doi.org/10.1016/j.jshs.2023.06.002",
    "coetsee2015": "https://doi.org/10.1186/s11556-015-0153-8",
}

RIR_SCALE = "9 1 repetition remaining 8.5 1-2 repetitions remaining 8 2 repetitions remaining 7.5 2-3 repetitions remaining 7 3 repetitions remaining"
KONRAD = "neither volume, intensity, nor frequency of stretching were found to play a significant role in ROM yields"
CUNHA = "Sleep extension and naps were the most representative and most effective strategies to improve sleep and performance"
ZHANG = "The prevalence of bloating at baseline and at the end of the carbohydrate-rich, protein-rich, and unsaturated fat-rich diet period was 18%, 24%, 33%, and 30%, respectively"
REFALO = "relative increases in muscle size were similar between sexes"
LAKE = "6 weeks of biweekly KB training provides a stimulus that is sufficient to increase both maximum and explosive strength"
BEHM = "greater performance deficits with ≥60 s (-4.6%) than with <60 s (-1.1%) SS per muscle group"

# (claim_id, status, source, passage or None, note). Status None = note only (still unresolved after the search).
DECISIONS = [
    ("warm-up:b00:text", "partly_supported", "wilson2025",
     "It has hence been well established that increased muscle contractile capacity occurs when muscle temperature increases within physiologically normal levels",
     "Supports the temperature part (introduction of a 2025 meta-analysis). Moving the joints you will use and a light first set are practice guidance, not tested here."),
    # Decision 5 (owner, 2026-10-14) keeps this row flagged until Grgic 2017 is read, so it is not marked verified here.
    ("rest-between-sets:b01:items[1]", "partly_supported", "singer2024",
     "suggests a small benefit to employing longer vs. shorter inter-set rest intervals for muscle hypertrophy",
     "Full text supports it: a small benefit of longer rests, and the discussion names rest periods greater than 60 s. Kept flagged under Decision 5 (owner) until Grgic 2017 is read or the owner accepts Singer 2024 instead."),
    ("sleep-recovery:b00:text", "partly_supported", "cunha2023", CUNHA,
     "Systematic review in athletes: sleep extension and naps improved performance. 'You improve while you rest' is a framing, not tested; reworded in the v4 draft."),
    ("carbs-fibre-fats:b05:text", "partly_supported", "zhang2020", ZHANG,
     "One trial (OmniHeart): bloating became more common on high-fibre diets. Adding fibre gradually and drinking water were not tested (kept as a Levlofit tip in the v4 rewording)."),
    ("calories:b00:text", "verified", "manore2017",
     "Increases in energy intake that match or exceed the energy cost of an exercise bout (or increased PA) negate body weight loss and can even result in weight gain",
     "Full text. The review stresses that energy balance is dynamic (expenditure changes as weight changes); the second sentence describes the app, not a claim of the source."),
    ("calories:b01:items[0]", "verified", "mifflin1990", "REE (males) = 10 x weight (kg) + 6.25 x height (cm) - 5 x age (y) + 5",
     "Abstract only: the equation uses weight, height, age and sex for resting energy expenditure measured by indirect calorimetry."),
    ("mobility:b02:do.items[1]", "partly_supported", "konrad2024", KONRAD,
     "Meta-analysis of 77 studies: static stretching increased range of motion, but hold time, volume and frequency did not significantly change the gains, so '30 to 60 s, most days' is not shown to matter. Reworded in the v4 draft."),
    ("mobility:b02:dont.items[0]", "needs_better_source", "konrad2024", KONRAD,
     "Contradicted: frequency did not significantly change range-of-motion gains, so 'only once a week' is not shown to be worse. Replaced in the v4 draft."),
    ("kettlebells:b00:text", "partly_supported", "lake2012", LAKE,
     "Abstract only: swings improved maximal and explosive strength; 'conditioning' is not in the abstract. Reworded in the v4 draft."),
    ("running:b00:text", "partly_supported", "seiler2010", "about 80% of training sessions are performed at low intensity",
     "Abstract only, and for nationally or internationally competitive athletes; 'faster by running more, gradually' is not stated there."),
    ("busy-weeks:b00:text", "verified", "coetsee2015", "this value was still significantly higher than their BL values",
     "Full text, older adults (55 to 75): after 16 weeks of training and then 16 weeks without it, strength fell but stayed above baseline. The second sentence matches Bickel 2011 (abstract: a one-third dose kept muscle size in young adults)."),
    ("women:b00:text", "partly_supported", "refalo2025", REFALO,
     "Meta-analysis: relative muscle growth similar between sexes (absolute growth slightly higher in men). 'Not bulk' is not tested. Reworded in the v4 draft."),
    *[(f"effort-and-rir:b01:items[{i}]", "partly_supported", "zourdos2016", RIR_SCALE,
       "Accepted manuscript, Figure 1: the reps-left numbers match the scale. Its words are 'Maximum effort' for 10 and reps remaining for 9 to 7; 'Very hard', 'Hard', 'Challenging' and 'Moderate' are Levlofit labels.") for i in range(5)],
    ("effort-and-rir:b04:text", "partly_supported", "zourdos2016", "precision of an athlete’s ability to assess RPE is enhanced with experience",
     "Accepted manuscript, introduction: a background statement citing another study (their ref 30); this study did not measure accuracy."),
    # Searched (Europe PMC open access, OpenAlex) and not resolved:
    ("how-training-works:b02:items[2]", None, None, None, "No open-access source found that states adaptation happens between sessions; reword as a Levlofit principle or provide a source."),
    ("tracking-progress:b03:dont.items[0]", None, None, None, "No open-access source found for salt causing a heavier next day."),
    ("habits:b02:items[3]", None, None, None, "Lally 2010 is free to read on the publisher's site (OpenAlex: bronze), but the PDF is served only after a browser check, which was not bypassed; the owner can download it for the reviewer."),
    ("water:b04:do.items[1]", None, None, None, "ACSM 2007 fluid position stand: no open copy (OpenAlex: closed)."),
    ("calories:b05:items[1]", None, None, None, "No open-access source found for a 0.5 to 1 kg rise after salt and carbs; label as a Levlofit estimate or provide a source."),
    ("fat-loss:b04:items[0]", None, None, None, "Decision-tree guidance; no source found; label as a Levlofit rule or provide one."),
    ("women:b01:dont.items[0]", None, None, None, "Refalo 2025 covers muscle growth by sex, not 'heavy lifting builds shape'; still needs a source or rewording."),
]

# The v4 rewordings ("evidence round 6" in build_handbook_v4.py), applied to the reworded (stale) claims only.
REVISED = [
    ("sleep-recovery:b00:text", "verified", "cunha2023", CUNHA, "Reworded to what the review found (sleep extension and naps improved athletes' performance)."),
    ("carbs-fibre-fats:b05:text", "verified", "zhang2020", ZHANG, "Reworded: bloating rose on high-fibre diets (OmniHeart); gradual increase and water are labelled a Levlofit tip."),
    ("mobility:b02:do.items[1]", "verified", "konrad2024", KONRAD, "Reworded to the meta-analysis: regular static stretching; hold time and frequency mattered little."),
    ("mobility:b02:dont.items[0]", "verified", "behm2016", BEHM, "Replaced: long holds (60 s or more) right before heavy lifting cut performance more (abstract only)."),
    ("kettlebells:b00:text", "verified", "lake2012", LAKE, "Reworded: strength and power only (abstract); 'conditioning' removed."),
    ("women:b00:text", "verified", "refalo2025", REFALO, "Reworded to the meta-analysis: similar percentage muscle growth; 'not bulk' removed."),
]


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


def locator(src):
    level, where = ACCESS[src]
    return {"full": f"full text, {where} (Europe PMC)", "manuscript": where, "abstract": f"abstract, {where} (Europe PMC)"}[level]


# Rows whose flags an owner decision fixes: the passage is recorded, the gates are left exactly as they are.
OWNER_FLAGGED = {"rest-between-sets:b01:items[1]"}  # Decision 5: flagged until Grgic 2017 is read


def record(r, status, src, passage, note, reworded=False):
    """[reworded]: v4 text that replaced a v3 claim; its v3 source_access gate is carried (as in round 5)."""
    gates = [g.strip() for g in r["review_needs"].split(";") if g.strip()]
    if r["claim_id"] in OWNER_FLAGGED:
        return dict(evidence_status=status, passage_source=src, supporting_passage=passage, passage_locator=locator(src),
                    reviewed_by=WHO, reviewed_on=TODAY, notes=(r["notes"] + " " if r["notes"] else "") + f"Round 6: {note}")
    note = f"Round 6: {note}"
    if status is None:  # note only
        return dict(notes=(r["notes"] + " " if r["notes"] else "") + note)
    if status == "verified" and ("clinical" in gates or "clinical_review" in r["flags"].split()):
        status, note = "needs_clinical_review", note + " Evidence found; clinical sign-off still needed."
    if status == "verified":
        drop = {"source_needed", "summary_check"} | ({"source_access"} if ACCESS[src][0] != "abstract" and not reworded else set())
        gates = [g for g in gates if g not in drop]
    elif status == "partly_supported":
        gates = [g for g in gates if g != "source_needed"]  # a source is attached now; the status keeps the item open
    elif status == "needs_source" and "source_needed" not in gates:
        gates.append("source_needed")
    return dict(evidence_status=status, passage_source=src, supporting_passage=passage, passage_locator=locator(src),
                reviewed_by=WHO, reviewed_on=TODAY, review_needs="; ".join(gates),
                notes=(r["notes"] + " " if r["notes"] else "") + note)


def main(folder):
    texts = {k: norm((Path(folder) / f"{k}.txt").read_text(encoding="utf-8")) for k in ACCESS}
    v4 = list(csv.DictReader(V4.open(encoding="utf-8")))
    v3 = list(csv.DictReader(V3.open(encoding="utf-8")))
    by_id = {r["claim_id"]: r for r in v4}
    todo = [d for d in DECISIONS if "Round 6:" not in by_id[d[0]]["notes"] and by_id[d[0]]["evidence_status"] != "stale"]
    todo += [d for d in REVISED if by_id[d[0]]["evidence_status"] == "stale"]
    for cid, status, src, passage, note in todo:
        r = by_id[cid]  # KeyError = a claim id that does not exist: stop
        if passage is not None and norm(passage) not in texts[src]:
            sys.exit(f"passage not in the {src} text: {passage!r}")
        reworded = r["evidence_status"] == "stale"
        if reworded:
            r.update(evidence_status="unreviewed", passage_source="", supporting_passage="", passage_locator="", reviewed_by="")
        rec = record(r, status, src, passage, note, reworded)
        r.update(rec)
        for o in v3:
            if o["text_sha"] == r["text_sha"] and o["evidence_status"] != "auto_label":
                o.update(rec)
    for path, rows in ((V4, v4), (V3, v3)):
        with path.open("w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()), lineterminator="\n")
            w.writeheader()
            w.writerows(rows)
    srcs = list(csv.DictReader(SOURCES.open(encoding="utf-8")))
    for s in srcs:
        if s["key"] in ACCESS and ACCESS[s["key"]][0] != "abstract" and "Round 6" not in s["verification_status"]:
            level, where = ACCESS[s["key"]]
            s["verification_status"] = (f"Round 6, {TODAY}: {'open-access full text' if level == 'full' else 'accepted manuscript'} read ({where}); "
                                        f"passages recorded. {s['verification_status']}").strip()
            if s["key"] in URL and not s["url_or_doi"]:
                s["url_or_doi"] = URL[s["key"]]
            if not s.get("licence"):
                s["licence"] = where.split(", ", 1)[1] if level == "full" else "author manuscript (repository terms)"
    with SOURCES.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(srcs[0].keys()), lineterminator="\n")
        w.writeheader()
        w.writerows(srcs)
    print(f"{len(todo)} decisions applied")


if __name__ == "__main__":
    main(sys.argv[1])

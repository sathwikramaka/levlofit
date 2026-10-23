"""Builds the Handbook v4 reviewer package from the v4 claims register (read-only on the register and the draft).

Writes:
  docs/HANDBOOK_V4_REVIEW.md                    overview, how to review, policy decisions with options, counts
  docs/handbook_v4_review/1_clinical_safety.md  per-claim records, grouped by chapter
  docs/handbook_v4_review/2_evidence_gaps.md
  docs/handbook_v4_review/3_policy_decisions.md
  docs/handbook_v4_review/4_editorial.md
  docs/handbook_v4_review/review_items.csv      the same items as a worksheet with blank reviewer columns

Every open claim appears exactly once, in its primary section (policy decision > clinical safety > evidence gap >
editorial); all its flags are listed with it. Nothing is approved or verified here.
Usage: python -I data/handbook_v4/review_package.py
"""
import csv
import importlib.util
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "docs" / "handbook_v4_review"
_s = importlib.util.spec_from_file_location("v4", HERE / "build_handbook_v4.py")
v4 = importlib.util.module_from_spec(_s)
_s.loader.exec_module(v4)
CH = {c["slug"]: (i, c) for i, c in enumerate(v4.CHAPTERS, 1)}
SRC = v4.SRC
ALL = list(csv.DictReader((HERE / "claims_register.csv").open(encoding="utf-8")))
CLAIMS = [r for r in ALL if r["evidence_status"] != "auto_label"]

RESOLVED = {"verified", "editorial", "non_claim"}


def is_open(r):
    return r["evidence_status"] not in RESOLVED or bool(r["review_needs"].strip())


def flags(r):
    f = [x.strip() for x in r["review_needs"].split(";") if x.strip()]
    if r["evidence_status"] == "needs_clinical_review" and "clinical" not in f:
        f.append("clinical")
    if r["evidence_status"] == "needs_source" and "source_needed" not in f:
        f.append("source_needed")
    return f


FREQ_ID = next(r["claim_id"] for r in CLAIMS if "Reaching your weekly sets" in r["text"])


def decision_of(r):
    """Which open policy decision governs a content_decision claim (or the frequency rewording)."""
    if r["claim_id"] == FREQ_ID:
        return "Muscle-training frequency wording"
    if r["chapter"] == "body-measures" or (r["chapter"] == "under-eating" and "BMI" in r["text"]) or "BMI cut-off" in r["notes"]:
        return "BMI cut-offs for Indian adults"
    if r["chapter"] in ("one-step-at-a-time", "hyrox"):
        return "Running versus strength (interference)"
    if r["chapter"] == "veg-protein":
        return "Vegetarian and vegan muscle-building"
    if r["chapter"] == "supplements" and ("630" in r["text"] or "caffeine" in r["text"].lower() or "Decision 4" in r["notes"]):
        return "Caffeine 630 mg example"
    return "Other recorded content decision"


def primary(r):
    f = flags(r)
    if "content_decision" in f or r["claim_id"] == FREQ_ID:
        return "policy"
    if "clinical" in f:
        return "clinical"
    if any(x in f for x in ("source_access", "source_needed", "official_table_spot_check")) or \
            r["evidence_status"] in ("needs_source", "partly_supported", "needs_better_source", "stale", "unsupported", "contradicted"):
        return "evidence"
    return "editorial"


def section_of(r):
    i, c = CH[r["chapter"]]
    b = c["blocks"][int(r["block"])]
    title = b.get("title") or (b.get("do") or {}).get("title") or ""
    kind = {"next": "Up next", "keypoints": "Key points", "part": "Part opener", "lead": "Opening line", "evidence": "Evidence note",
            "rule": "Rule"}.get(b["t"], b["t"])
    return f"{kind}" + (f": {title}" if title and b["t"] not in ("keypoints", "next") else "")


def question(r, sec):
    f, s = flags(r), r["evidence_status"]
    src = r["passage_source"] or r["direct_sources"] or r["chapter_sources"]
    if r["claim_id"] == FREQ_ID:
        return "Confirm the reworded frequency claim (old: 'Training each muscle twice a week'); approve, amend or reject."
    if sec == "policy":
        d = decision_of(r)
        if d == "Other recorded content decision":
            return "Content decision recorded in the evidence audit (see note): keep this wording, amend it, or remove it?"
        return f"Governed by the decision '{d}' (options in docs/HANDBOOK_V4_REVIEW.md): after choosing, approve, amend or remove this wording."
    if sec == "clinical":
        if s == "needs_clinical_review":
            return "Source passage is recorded. Is the claim clinically safe and appropriate for general adult users as worded? Approve, amend or remove."
        if r["block_type"] == "keypoints":
            return "Does this summary match the chapter and is it clinically safe as worded? Approve or amend."
        if "source_needed" in f:
            return "Is this medically correct and suitably cautious? Name a source, or approve it as referral guidance, amend or remove."
        if "source_access" in f:
            return f"Read the cited source ({src}). Does it support this? Is it clinically safe as worded?"
        return "Is this clinically safe and appropriate as worded? Approve, amend or remove."
    if sec == "evidence":
        if "source_access" in f:
            return f"Source not yet readable ({src}). Obtain it; does it support the claim? Record the exact passage."
        if "official_table_spot_check" in f:
            return "Spot-check these numbers against the official table (IFCT 2017)."
        if s == "partly_supported":
            return "The passage supports only part of this (see note). Is the rest acceptable, or should it be reworded?"
        if s == "needs_better_source":
            return "The current source is weak or indirect (see note). Suggest a stronger source or reword."
        return "No source yet. Provide a source, approve rewording as a labelled Levlofit rule, or remove."
    if r["block_type"] == "keypoints":
        return "Does this key point accurately summarise its chapter without adding claims?"
    if "summary_check" in f:
        return "Does this summary match its chapter?"
    return "Is this accurate and clear? If it states a fact, does it need a source?"


def record(r):
    i, c = CH[r["chapter"]]
    sec = primary(r)
    srckey = r["passage_source"] or r["direct_sources"]
    return {
        "claim_id": r["claim_id"], "chapter_no": i, "chapter": c["title"], "slug": r["chapter"], "section": section_of(r),
        "wording": r["text"], "status": r["evidence_status"], "flags": "; ".join(flags(r)),
        "source": srckey, "citation": "; ".join(SRC.get(k, k) for k in srckey.split()) if srckey else "",
        "passage": r["supporting_passage"], "locator": r["passage_locator"], "note": r["notes"],
        "question": question(r, sec), "primary": sec, "decision": decision_of(r) if sec == "policy" else "",
    }


ITEMS = sorted((record(r) for r in CLAIMS if is_open(r)), key=lambda x: (x["chapter_no"], x["claim_id"]))
SECTIONS = [("clinical", "1_clinical_safety.md", "Clinical safety"), ("evidence", "2_evidence_gaps.md", "Evidence and source gaps"),
            ("policy", "3_policy_decisions.md", "Policy decisions"), ("editorial", "4_editorial.md", "Editorial review")]

DECISIONS = [
    ("BMI cut-offs for Indian adults", "body-measures, under-eating, calories/fat-loss rules; app: plan-engine.ts (underweight below 18.0, bands), tools.dart bmiBandIndia. PROVISIONAL choice recorded: option B, pending clinical review (docs/handbook_v4_review/DECISIONS.md); nothing applied yet",
     [("A. Keep Misra 2009 consensus: underweight <18, normal 18-22.9, overweight 23-24.9, obese >=25",
       "No code change. The cited paper has not been read (source_access), so the bands stay unverified. People with BMI 18.0-18.4 are treated as normal and can be offered a fat-loss phase."),
      ("B. Adopt ICMR Dietary Guidelines for Indians 2024: normal 18.5-23, overweight 23-27.5, obese >27.5 (passage recorded, PDF pp. 81-82)",
       "Handbook bands, plan-engine.ts thresholds, tools.dart and their tests change together. Fewer people are labelled obese; BMI 18.0-18.4 becomes underweight, so no fat-loss phase. Consistent with a current Indian national source."),
      ("C. Show both with an explanation, and choose one for app decisions",
       "Most transparent; longer chapter; the app still needs one threshold, so A or B is still required for the engine.")],
     "Which cut-offs should the handbook and the app use, and is a clinician comfortable with the underweight threshold that blocks dieting?"),
    ("Running versus strength (interference)", "one-step-at-a-time (why one goal first), hyrox, key points; the app's goal gating does not use this claim directly. PROVISIONAL choice recorded: option C, pending evidence review (docs/handbook_v4_review/DECISIONS.md); the draft now uses its cautious wording and an 'unverified' evidence grade",
     [("A. Keep: frequent, long endurance work costs some strength, size and especially power (cites Wilson 2012, not read)",
       "Current wording stays; unverified until Wilson 2012 is read."),
      ("B. Remove or substantially soften the interference claims. ACSM 2026 (read) reports insufficient data to determine whether aerobic and resistance training in the same session affects strength, muscle growth or power; it does not report 'no effect'",
       "Removes the stronger claim; 'One goal at a time' then rests on learning and recovery rather than interference; the HYROX scheduling advice needs another reason or none."),
      ("C. Keep but label as uncertain: 'may reduce power and size gains, especially with long or frequent endurance sessions; evidence is mixed'",
       "Cautious middle ground; still needs a reviewer to accept the wording.")],
     "Which wording best reflects the evidence, and does the One goal at a time rationale still hold?"),
    ("Vegetarian and vegan muscle-building", "veg-protein (opening line, vegan staples), key points",
     [("A. Keep: 'You can build muscle on a vegetarian or vegan diet. It takes planning.' (partly supported: ICMR 2024 on complete amino acids from combined plant foods)",
       "Encouraging for a mostly vegetarian audience; the muscle-building part is not directly shown by a read source."),
      ("B. Soften: 'Vegetarian and vegan diets can support muscle gain when protein is planned; direct evidence in vegans is limited.'",
       "More cautious; acknowledges ISSN 2017's cited trial in older men where fat-free mass rose on a meat diet and fell on a lacto-ovo-vegetarian one."),
      ("C. Find and cite a direct source first (for example a trial or review of plant versus animal protein and muscle gain), then decide",
       "Needs a new source review before release.")],
     "Which wording should the handbook use, and is further evidence required first?"),
    ("Caffeine 630 mg example", "supplements (caffeine bar chart: 3, 6 and 9 mg per kg for a 70 kg person)",
     [("A. Keep the 9 mg/kg = 630 mg bar labelled 'more side effects'", "Shows the upper end honestly as a warning; a single dose above commonly cited daily limits may still read as a target to some users."),
      ("B. Remove the 630 mg bar; show only 3 and 6 mg/kg", "Simpler and safer to read; loses the side-effect comparison."),
      ("C. Keep or remove the bar, and add a caution: daily caffeine limits, pregnancy, high blood pressure, sleep",
       "Safest wording, but the limits need a source (for example EFSA 2015 on caffeine, not yet read) and clinical review.")],
     "Should the 630 mg example stay, and what caution (with which source) should accompany caffeine advice?"),
]


def item_md(x):
    lines = [f"#### `{x['claim_id']}`",
             f"- **Chapter:** {x['chapter_no']}. {x['chapter']} ({x['slug']}), {x['section']}",
             f"- **Proposed wording:** {x['wording']}",
             f"- **Status:** {x['status']}" + (f"; **flags:** {x['flags']}" if x["flags"] else ""),
             f"- **Source:** {x['source'] + ' — ' + x['citation'] if x['source'] else 'none recorded'}"]
    if x["passage"]:
        label = "Recorded passage (for a decision item it may conflict with the wording; see note)" if x["decision"] else "Quoted passage"
        lines.append(f"- **{label}** ({x['locator']}): \"{x['passage']}\"")
    if x["note"]:
        lines.append(f"- **Note:** {x['note']}")
    if x["decision"]:
        lines.append(f"- **Policy decision:** {x['decision']}")
    lines.append(f"- **Reviewer question:** {x['question']}")
    lines.append("- **Decision:** [ ] approve  [ ] amend  [ ] remove   Reviewer / date: ________")
    return "\n".join(lines)


def write_section(key, fname, title, intro):
    xs = [x for x in ITEMS if x["primary"] == key]
    by = defaultdict(list)
    order = [d[0] for d in DECISIONS] + ["Muscle-training frequency wording", "Other recorded content decision"]
    for x in xs:
        # Policy items are grouped by decision (in the order of the overview); the rest by chapter.
        by[(order.index(x["decision"]) + 1, x["decision"]) if key == "policy" else (x["chapter_no"], x["chapter"])].append(x)
    md = [f"# {title} ({len(xs)} claims)", "", intro, ""]
    md += ["## Contents", ""] + [f"- {n}. {t} ({len(v)})" for (n, t), v in sorted(by.items())] + [""]
    for (n, t), v in sorted(by.items()):
        md += [f"## {n}. {t}", ""] + [item_md(x) + "\n" for x in v]
    (OUT / fname).write_text("\n".join(md), encoding="utf-8", newline="\n")
    return len(xs)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    intros = {
        "clinical": "Safety-relevant wording: symptoms and warning signs, pain and return to training, pregnancy and after birth, eating too little, heat illness, mental health, medical referrals, and key points summarising those chapters. Needs a qualified clinician (and a dietitian for nutrition items). Items that also lack a source say so in their flags.",
        "evidence": "Claims whose source could not be read (source_access), have no source (source_needed), are only partly supported, or need an official-table spot check. Inaccessible and missing sources are unresolved; none is marked verified.",
        "policy": "Claims governed by an open policy decision. Choose an option in docs/HANDBOOK_V4_REVIEW.md first, then review these items against it. Includes the muscle-training frequency rewording.",
        "editorial": "Key points (summaries of their chapter), new v4 text without safety or evidence flags, and reworded text. Needs an editor or subject expert, not a clinician.",
    }
    counts = {k: write_section(k, f, t, intros[k]) for k, f, t in SECTIONS}

    cols = ["claim_id", "primary", "decision", "chapter_no", "chapter", "slug", "section", "wording", "status", "flags", "source", "citation",
            "passage", "locator", "note", "question", "reviewer_decision", "reviewer_wording", "reviewer_source", "reviewer", "review_date"]
    with (OUT / "review_items.csv").open("w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore", lineterminator="\n")
        w.writeheader()
        for x in ITEMS:
            w.writerow({**x, "reviewer_decision": "", "reviewer_wording": "", "reviewer_source": "", "reviewer": "", "review_date": ""})

    # Counts straight from the register, for the cross-check in the overview and in tests.
    open_ = [r for r in CLAIMS if is_open(r)]
    flag_counts = Counter(f for r in open_ for f in flags(r))
    status_all = Counter(r["evidence_status"] for r in CLAIMS)
    freq = next(x for x in ITEMS if x["claim_id"] == FREQ_ID)
    old_passage = "Our primary recommendation is that healthy adults perform RT with high effort ... at least twice weekly, with all major muscle groups being engaged"

    md = [f"""# Handbook v4: reviewer package

Status: local draft for review. Production handbook (v3 migration, builder, evidence register, passages file) is unchanged.
Nothing in this package is clinically approved; "verified" in a status means only that a quoted passage from the cited
source was matched. Generated by `data/handbook_v4/review_package.py` from `data/handbook_v4/claims_register.csv`.

## How to review
1. Decide the policy questions below (section "Policy decisions"); each lists options and consequences. Provisional choices, if any, are in handbook_v4_review/DECISIONS.md and approve nothing.
2. Work through the four item files. Every open claim appears once, in its primary section, with all its flags:
   - [1_clinical_safety.md](handbook_v4_review/1_clinical_safety.md): {counts['clinical']} claims, for a qualified clinician (and dietitian for nutrition).
   - [2_evidence_gaps.md](handbook_v4_review/2_evidence_gaps.md): {counts['evidence']} claims, for an evidence reviewer with library access.
   - [3_policy_decisions.md](handbook_v4_review/3_policy_decisions.md): {counts['policy']} claims governed by a decision below.
   - [4_editorial.md](handbook_v4_review/4_editorial.md): {counts['editorial']} claims, for an editor or subject expert.
3. Or use the worksheet [review_items.csv](handbook_v4_review/review_items.csv) (same {len(ITEMS)} items; blank columns for
   decision, new wording, source, reviewer and date). Return it; decisions are then applied to the draft and register.
Primary section order: policy decision, then clinical safety, then evidence gap, then editorial.

## Counts (from the register; checked by tests)
- Claims in the v4 draft: {len(CLAIMS)} (plus {len(ALL) - len(CLAIMS)} headings and labels). Open for review: {len(ITEMS)}.
- By primary section: clinical {counts['clinical']}, evidence {counts['evidence']}, policy {counts['policy']}, editorial {counts['editorial']}.
- Flags on open claims (a claim can carry several): {", ".join(f"{k} {v}" for k, v in sorted(flag_counts.items()))}.
- Status of all claims: {", ".join(f"{k} {v}" for k, v in status_all.most_common())}.

## Policy decisions (options; provisional choices are recorded in handbook_v4_review/DECISIONS.md and approve nothing)
"""]
    for name, where, options, q in DECISIONS:
        md.append(f"### {name}\nWhere it applies: {where}.\n")
        for o, c in options:
            md.append(f"- **{o}**  \n  Consequence: {c}")
        md.append(f"\nQuestion for the decision-maker: {q}\n")
    md.append(f"""### Muscle-training frequency wording (change made in the draft; needs confirmation)
- Old wording (v3, build-muscle "Grows muscle" list): "Training each muscle twice a week". It was marked verified against
  ACSM 2026's general recommendation: "{old_passage}".
- Conflict: Sets, reps and progress says frequency is "Any, once weekly sets are reached" for muscle size.
- New draft wording (`{freq['claim_id']}`): "{freq['wording']}".
- Evidence (ACSM 2026, {freq['locator']}): "{freq['passage']}".
- Twice-weekly training stays in How training works and Sets, reps and progress as ACSM's general advice.
- Question: approve the new wording, amend it, or restore the old one with a different source?
""")
    (ROOT / "docs" / "HANDBOOK_V4_REVIEW.md").write_text("\n".join(md), encoding="utf-8", newline="\n")
    print(f"open items {len(ITEMS)}: " + ", ".join(f"{k} {v}" for k, v in counts.items()) + f"; flags {dict(sorted(flag_counts.items()))}")


if __name__ == "__main__":
    main()

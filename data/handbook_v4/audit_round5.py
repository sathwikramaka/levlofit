"""Evidence audit round 5 (2026-10-16): claims citing sources that had never been read, checked against their PubMed
abstracts (Europe PMC, resultType=core). None of these articles is open access, so only the abstract was read; a claim
is marked verified only when the abstract itself states it, and the locator says "abstract". Population or
strength-of-finding differences are recorded as partly_supported with the reason; claims the abstract does not cover
keep their gate (needs_source or source_access). Nothing here is a qualified reviewer's sign-off.

The same text in the v3 register (data/evidence/claims_register.csv) gets the same record, matched by text hash, so
the two registers never disagree about identical text.

Usage: python -I data/handbook_v4/audit_round5.py <folder with <source>.txt abstracts>
Each <source>.txt is "title\\nabstract" as downloaded; every quoted passage must occur in it or the script stops.
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
WHO = "Claude (session 2026-10-16, AI, not a qualified reviewer); passage matched in the PubMed abstract"

PMID = {
    "zourdos2016": "26049792", "seiler2010": "20861519", "nielsen2014": "25155475", "bickel2011": "21131862",
    "behm2016": "26642915", "soy2021": "33383165", "mifflin1990": "2305711", "kotarsky2018": "29466268",
    "lauersen2014": "24100287", "zheng2015": "25521523", "acsmfluid": "17277604", "lake2012": "22580981",
    "riebe2015": "26473759",
}

# (claim_id, status, source, passage or None, note)
DECISIONS = [
    # Zourdos 2016: the RIR scale itself; descriptive labels and Levlofit's prescriptions are not in the abstract.
    *[(f"effort-and-rir:b01:items[{i}]", "partly_supported", "zourdos2016", "RPE-10 = 0-RIR, RPE-9 = 1-RIR, and so forth",
       "The reps-left numbers follow the RIR scale in the abstract; the words (Failure, Very hard, Hard, Challenging, Moderate) "
       "are Levlofit labels and need the full-text table or an editorial decision.") for i in range(5)],
    ("effort-and-rir:b04:text", "needs_source", "zourdos2016", None,
     "The abstract reports higher RPE at 1RM in experienced squatters, not that beginners judge reps in reserve less "
     "accurately or improve with practice. Needs the full text or another source."),
    *[(f"get-stronger:b03:items[{i}]", "needs_source", "zourdos2016", None,
       "The abstract supports RIR as a way to regulate load, not these bands. Label as a Levlofit rule or cite a source "
       "for the bands (ACSM 2026 states 1 to 3 reps in reserve for most sets).") for i in range(3)],
    # Seiler 2010: 80/20 in highly trained endurance athletes.
    ("running:b01:items[0]", "partly_supported", "seiler2010",
     "about 80% of training sessions are performed at low intensity",
     "Observed in nationally or internationally competitive athletes training 10 to 13 times a week; applying it to "
     "recreational runners is an extrapolation. The talk-test wording is not in the abstract."),
    ("running:b01:items[1]", "partly_supported", "seiler2010", "with about 20% dominated by periods of high-intensity work",
     "Same population limit as the 80% row."),
    *[(f"running:b04:items[{i}]", "needs_source", "seiler2010", None,
       "The talk-test zones are not in the abstract; needs a source for the talk test.") for i in range(3)],
    # Nielsen 2014: exploratory, not statistically significant.
    *[(f"running:b02:ranges[{i}]", "partly_supported", "nielsen2014",
       "were categorized into 1 of the following exposure groups, based on the progression of their weekly running distance",
       "The study used under 10%, 10 to 30% and over 30%; overall injury rates did not differ significantly, and the higher "
       "rate of distance-related injuries above 30% was not significant (P = .07). The 50% upper bound and the risk labels "
       "are Levlofit wording; reword as a cautious guide.") for i in range(3)],
    ("running:b05:text", "partly_supported", "nielsen2014",
     "Novice runners who progressed their running distance by more than 30% over a 2-week period seem to be more vulnerable to distance-related injuries",
     "The finding is for distance-related injuries specifically, is exploratory and not statistically significant; the text "
     "states it more firmly. Rewording proposed in HANDBOOK_V4_REVIEW round 5."),
    # Bickel 2011.
    ("busy-weeks:b01:items[0]", "verified", "bickel2011", "Both maintenance prescriptions preserved phase 1 muscle hypertrophy in the young",
     "The one-third and one-ninth doses were the two maintenance prescriptions over the 32-week phase 2."),
    ("busy-weeks:b05:text", "verified", "bickel2011",
     "older adults require a higher dose of weekly loading than the young to maintain myofiber hypertrophy", ""),
    ("over-40:b01:items[1]", "verified", "bickel2011",
     "older adults require a higher dose of weekly loading than the young to maintain myofiber hypertrophy", ""),
    # Behm 2016.
    ("warm-up:b03:items[0]", "verified", "behm2016", "greater performance deficits with ≥60 s (-4.6%) than with <60 s (-1.1%) SS per muscle group", ""),
    ("mobility:b04:text", "verified", "behm2016", "greater performance deficits with ≥60 s (-4.6%) than with <60 s (-1.1%) SS per muscle group",
     "The abstract reports performance in general (strength and power tests), measured within minutes of stretching."),
    # Reed 2021 (soy).
    ("food-basics:b07:text", "verified", "soy2021",
     "neither soy protein nor isoflavone exposure affects TT, FT, E 2 or E 1 levels in men",
     "The second sentence (50 g dry soya chunks a day) is a labelled Levlofit rule, not a claim of this source."),
    ("veg-protein:b04:text", "verified", "soy2021", "neither soy protein nor isoflavone exposure affects TT, FT, E 2 or E 1 levels in men", ""),
    # Mifflin 1990.
    ("calories:b02:rows[0]", "verified", "mifflin1990", "REE (males) = 10 x weight (kg) + 6.25 x height (cm) - 5 x age (y) + 5", ""),
    ("calories:b02:rows[1]", "verified", "mifflin1990", "REE (females) = 10 x weight (kg) + 6.25 x height (cm) - 5 x age (y) - 161", ""),
    # Kotarsky 2018: 1RM rose in both groups; muscle thickness did not change significantly in either group.
    ("calisthenics:b03:items[0]", "partly_supported", "kotarsky2018",
     "No significant differences were found within groups for MT and MBP (p > 0.05)",
     "Small trial (23 moderately trained men, 4 weeks). 1RM rose in both groups (p < 0.001), but muscle thickness did not "
     "change in either group, so 'muscle gains' is contradicted by the abstract, not just unverified."),
    ("calisthenics:b04:text", "partly_supported", "kotarsky2018",
     "No significant differences were found within groups for MT and MBP (p > 0.05)",
     "As above: strength gain supported; muscle thickness did not change in either group."),
    # Lauersen 2014.
    ("soreness-pain-injury:b04:items[0]", "verified", "lauersen2014", "Strength training reduced sports injuries to less than 1/3", ""),
    ("soreness-pain-injury:b06:text", "verified", "lauersen2014",
     "consistently favourable estimates were obtained for all injury prevention measures except for stretching",
     "25 trials; strength training RR 0.315; stretching RR 0.963 (no beneficial effect)."),
    # Zheng 2015.
    ("tracking-progress:b04:text", "verified", "zheng2015",
     "regular self-weighing was associated with more weight loss and not with adverse psychological outcomes (e.g., depression, anxiety)",
     "17 studies; association, not causation."),
    # ACSM fluid 2007.
    ("water:b02:items[0]", "verified", "acsmfluid",
     "prevent excessive (>2% body weight loss from water deficit) dehydration and excessive changes in electrolyte balance to avert compromised performance", ""),
    # Lake 2012.
    ("kettlebells:b03:items[0]", "verified", "lake2012",
     "6 weeks of biweekly KB training provides a stimulus that is sufficient to increase both maximum and explosive strength", ""),
    # Riebe 2015: the three screening factors are in the abstract; the activity threshold and advice are in the full text.
    ("safety-first:b01:note", "verified", "riebe2015",
     "1) the individual's current level of physical activity, 2) presence of signs or symptoms and/or known cardiovascular, metabolic, or renal disease, and 3) desired exercise intensity", ""),
    ("safety-first:b01:items[2]", "unreviewed", "riebe2015", None,
     "Abstract read (PMID 26473759): it names the three screening factors but not the activity threshold or the advice; "
     "these are in the full-text algorithm, still not read."),
]

# Rewordings made in build_handbook_v4.py ("evidence round 5") so the text says what the abstract says. Applied to the
# reworded (stale) claims only.
REVISED = [
    ("running:b05:text", "verified", "nielsen2014",
     "Novice runners who progressed their running distance by more than 30% over a 2-week period seem to be more vulnerable to distance-related injuries",
     "Reworded to the abstract's scope: distance-related injuries only, exploratory, not statistically significant (P = .07); "
     "it now also says overall injury rates did not differ ('no statistically significant differences in injury rates were "
     "found across the 3 exposure groups')."),
    ("running:b02:ranges[0]", "partly_supported", "nielsen2014",
     "were categorized into 1 of the following exposure groups, based on the progression of their weekly running distance",
     "Label 'Safer' replaced by 'Gradual': the study did not show the under-10% group was safer overall."),
    ("running:b02:ranges[2]", "partly_supported", "nielsen2014",
     "were categorized into 1 of the following exposure groups, based on the progression of their weekly running distance",
     "Label hedged ('Possibly'); the 50% upper bound is display range only (the study's top group was 'more than 30%')."),
    ("calisthenics:b04:text", "verified", "kotarsky2018",
     "calisthenics, using different progressive variations to maintain strength training programming variables, can improve upper-body muscle strength",
     "Reworded to what the abstract states (3 days a week for 4 weeks, randomly assigned); no equivalence claim."),
    ("calisthenics:b03:items[0]", "verified", "kotarsky2018",
     "calisthenics, using different progressive variations to maintain strength training programming variables, can improve upper-body muscle strength",
     "Reworded: no longer claims muscle-thickness equivalence with the bench press."),
]


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


def main(folder):
    texts = {k: norm((Path(folder) / f"{k}.txt").read_text(encoding="utf-8")) for k in PMID}
    v4 = list(csv.DictReader(V4.open(encoding="utf-8")))
    v3 = list(csv.DictReader(V3.open(encoding="utf-8")))
    by_id = {r["claim_id"]: r for r in v4}
    todo = [d for d in DECISIONS if "Round 5:" not in by_id[d[0]]["notes"] and by_id[d[0]]["evidence_status"] != "stale"]
    todo += [d for d in REVISED if by_id[d[0]]["evidence_status"] == "stale"]  # reworded text: record afresh
    for cid, status, src, passage, note in todo:
        r = by_id[cid]  # KeyError = a claim id that does not exist: stop
        if r["evidence_status"] == "stale":
            r.update(evidence_status="unreviewed", passage_source="", supporting_passage="", passage_locator="", reviewed_by="")
        if passage is not None and norm(passage) not in texts[src]:
            sys.exit(f"passage not in the {src} abstract: {passage!r}")
        if status == "verified" and passage is None:
            sys.exit(f"verified without a passage: {cid}")
        gates = [g.strip() for g in r["review_needs"].split(";") if g.strip()]
        if status == "verified" and ("clinical" in gates or "clinical_review" in r["flags"].split()):
            # Evidence found, but a clinical claim is only verified after a clinician's sign-off (clinical_done).
            status, note = "needs_clinical_review", f"{note} Evidence passage found; clinical sign-off still needed.".strip()
        if status == "verified":
            # source_access stays: only the abstract was read, the full text still is not.
            gates = [g for g in gates if g not in ("source_needed", "summary_check")]
        elif status == "needs_source" and "source_needed" not in gates:
            gates.append("source_needed")
        record = dict(
            evidence_status=status,
            passage_source=src if passage else r["passage_source"],
            supporting_passage=passage or r["supporting_passage"],
            passage_locator=f"abstract, PMID {PMID[src]} (Europe PMC)" if passage else r["passage_locator"],
            reviewed_by=WHO if passage else r["reviewed_by"],
            reviewed_on=TODAY,
            review_needs="; ".join(gates),
            notes=(r["notes"] + " " if r["notes"] else "") + f"Round 5: {note}".strip(),
        )
        if status == "unreviewed":  # only the note changes
            record = dict(notes=record["notes"], reviewed_on=r["reviewed_on"])
        r.update(record)
        for o in v3:
            if o["text_sha"] == r["text_sha"] and o["evidence_status"] != "auto_label":
                o.update(record)
    for path, rows in ((V4, v4), (V3, v3)):
        with path.open("w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()), lineterminator="\n")
            w.writeheader()
            w.writerows(rows)
    srcs = list(csv.DictReader(SOURCES.open(encoding="utf-8")))
    for s in srcs:
        if s["key"] in PMID and s["verification_status"] == "unchecked":
            s["verification_status"] = (f"citation matches the PubMed record (title, journal, year); abstract read via Europe PMC "
                                        f"PMID {PMID[s['key']]} on {TODAY}; full text not read (not open access)")
    with SOURCES.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(srcs[0].keys()), lineterminator="\n")
        w.writeheader()
        w.writerows(srcs)
    print(f"{len(todo)} decisions applied")


if __name__ == "__main__":
    main(sys.argv[1])

"""Evidence audit round 8 (2026-10-18): the owner's priority topics. Rest between sets against the open full text of
ACSM 2026 (Europe PMC PMC12965823), and the waist-to-height bands against the 2025 revised definition of obesity in
Asian Indians (Misra et al., full article PDF). Same rules as audit_round6.py (whose record() it uses): an AI reading
is not a clinical review, clinical gates stay, and a band the source does not state is left open.

Usage: python -I data/handbook_v4/audit_round8.py <folder with acsm2026.txt and misra2025.txt>
"""
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_round6 as r6  # noqa: E402

r6.TODAY = "2026-10-18"
r6.WHO = "Claude (session 2026-10-18, AI, not a qualified reviewer); passage matched in the downloaded text"
r6.ACCESS.update({
    "acsm2026": ("full", "PMC12965823, CC BY-NC-ND"),
    "misra2025": ("manuscript", "full article PDF (Diabetes Metab Syndr 2025;19:102989), read 2026-10-18"),
})
r6.URL["misra2025"] = "https://doi.org/10.1016/j.dsx.2024.102989"
r6.ACCESS["nhs_dehydration"] = ("manuscript", "NHS web page, last reviewed 01 May 2026, read 2026-10-22")
r6.URL["nhs_dehydration"] = "https://www.nhs.uk/conditions/dehydration/"

ACSM_REST = "short (<1 min) versus long (>1 min) between-set rest intervals"
WHTR_CUT = "W-HtR cutoff level: >0.5"
WHTR_J = "with the lowest all-cause mortality risk at 0.5 and a sharp linear increase after that"

DECISIONS = [
    # Decision 5 (owner, 2026-10-18): rest stays unresolved until its full-text evidence is read, so these get a note
    # with the matched passage and keep their status and gates.
    ("rest-between-sets:b02:items[0]", None, "acsm2026", ACSM_REST,
     "ACSM 2026 full text (PMC12965823) matches: strength 'was not affected by' short (<1 min) versus long (>1 min) between-set rests; no finding for hypertrophy. Left unresolved under Decision 5."),
    ("rest-between-sets:b04:text", None, "acsm2026", ACSM_REST, "As rest-between-sets:b02:items[0]."),
    ("body-measures:b02:ranges[0]", "partly_supported", "misra2025", WHTR_CUT,
     "Revised Indian definition (2025) uses a waist-to-height cut-off of >0.5 for abdominal obesity, so under 0.5 matches its non-elevated range; the 0.3 lower edge is a display range, not from the source. NICE 2022 still not readable (403)."),
    ("body-measures:b02:ranges[1]", "partly_supported", "misra2025", WHTR_CUT,
     "0.5 is the cut-off in the 2025 Indian definition; the source gives no 0.6 boundary, so the 0.5 to 0.6 band edge is not supported by it."),
    ("body-measures:b02:ranges[2]", "partly_supported", "misra2025", WHTR_J,
     "The source reports risk rising linearly above 0.5 but states no 0.6 'high risk' threshold; the 0.6 band needs NICE 2022 (unreadable) or another source, or rewording."),
    # Added 2026-10-22: NHS dehydration page (exact text checked in the downloaded page). Clinical gates stay: record()
    # turns 'verified' into needs_clinical_review for clinical rows.
    ("water:b04:dont.items[0]", "verified", "nhs_dehydration", "dark yellow, strong-smelling pee",
     "NHS adult dehydration symptoms list dark yellow, strong-smelling pee and peeing less often than usual (the latter covers 'very little of it')."),
    ("water:b04:dont.items[1]", "partly_supported", "nhs_dehydration", "headache and feeling light-headed",
     "NHS lists headache and dizziness among dehydration symptoms; the source does not tie them to training."),
]


def main(folder):
    texts = {k: r6.norm((Path(folder) / f"{k}.txt").read_text(encoding="utf-8")) for k in {d[2] for d in DECISIONS}}
    v4 = list(csv.DictReader(r6.V4.open(encoding="utf-8")))
    v3 = list(csv.DictReader(r6.V3.open(encoding="utf-8")))
    by_id = {r["claim_id"]: r for r in v4}
    todo = [d for d in DECISIONS if "Round 8:" not in by_id[d[0]]["notes"]]
    for cid, status, src, passage, note in todo:
        r = by_id[cid]
        day = "2026-10-22" if src == "nhs_dehydration" else "2026-10-18"
        r6.TODAY, r6.WHO = day, f"Claude (session {day}, AI, not a qualified reviewer); passage matched in the downloaded text"
        if r6.norm(passage) not in texts[src]:
            sys.exit(f"passage not in the {src} text: {passage!r}")
        rec = r6.record(r, status, src, passage, note) if status else dict(notes=(r["notes"] + " " if r["notes"] else "") + f"Round 8: {note}")
        rec["notes"] = rec["notes"].replace("Round 6:", "Round 8:")
        r.update(rec)
        for o in v3:
            if o["text_sha"] == r["text_sha"] and o["evidence_status"] != "auto_label":
                o.update(rec)
    for path, rows in ((r6.V4, v4), (r6.V3, v3)):
        with path.open("w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()), lineterminator="\n")
            w.writeheader()
            w.writerows(rows)
    for sources in (r6.SOURCES, r6.V3.parent / "sources_register.csv"):
        srcs = list(csv.DictReader(sources.open(encoding="utf-8")))
        for s in srcs:
            if s["key"] in {d[2] for d in DECISIONS} and "Round 8" not in s["verification_status"]:
                level, where = r6.ACCESS[s["key"]]
                s["verification_status"] = f"Round 8, 2026-10-18: {level} read ({where}); passages recorded. {s['verification_status']}".strip()
                if s["key"] in r6.URL and not s["url_or_doi"]:
                    s["url_or_doi"] = r6.URL[s["key"]]
        with sources.open("w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(srcs[0].keys()), lineterminator="\n")
            w.writeheader()
            w.writerows(srcs)
    print(f"{len(todo)} decisions applied")


if __name__ == "__main__":
    main(sys.argv[1])

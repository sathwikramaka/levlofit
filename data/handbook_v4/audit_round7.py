"""Evidence audit round 7 (2026-10-17): claims whose sources were "not yet readable" and turned out to have a readable
abstract after all (publisher abstracts via OpenAlex for Lally 2010 and EFSA 2010; Europe PMC for ACSM 2007), plus a
2024 open-access meta-analysis for the habit-timing claims. Same rules as audit_round6.py (whose record() it uses):
abstract-only records keep source_access open; texts come from fetch_round6.py.

Usage: python -I data/handbook_v4/audit_round7.py <folder written by fetch_round6.py>
"""
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_round6 as r6  # noqa: E402

r6.ACCESS.update({
    "singh2024": ("full", "PMC11641623, CC BY"),
    "acsmfluid": ("abstract", "PMID 17277604"),
    "lally2010": ("abstract", "publisher abstract in the OpenAlex record, DOI 10.1002/ejsp.674"),
    "efsa2010": ("abstract", "publisher abstract in the OpenAlex record, DOI 10.2903/j.efsa.2010.1459"),
})
r6.URL["singh2024"] = "https://doi.org/10.3390/healthcare12232488"

LALLY_MISS = "Missing one opportunity to perform the behaviour did not materially affect the habit formation process"
SINGH = "Four studies reported the median or mean times to reach habit formation, ranging from 59–66 days (median) and 106–154 days (means)"
EFSA = "Available data for adults permit the definition of AIs as 2.0 L/day (P 95 3.1 L) for females and 2.5 L/day (P95 4.0 L) for males"

DECISIONS = [
    ("habits:b01:items[1]", "verified", "lally2010", "ranged from 18 to 254 days",
     "Abstract: time to reach 95% of the automaticity asymptote, 82 analysed participants."),
    ("habits:b03:text", "verified", "lally2010", LALLY_MISS, "Abstract."),
    ("habits:b02:items[3]", "verified", "lally2010", LALLY_MISS, "Abstract; 'not twice' is advice built on it."),
    ("habits:b01:items[0]", "partly_supported", "singh2024", SINGH,
     "Meta-analysis full text: medians of 59 to 66 days across four studies, with wide individual variation (4 to 335 days); 66 days is Lally 2010's median, whose full text is not read."),
    ("mind-motivation:b02:items[1]", "partly_supported", "singh2024", SINGH, "As habits:b01:items[0]."),
    ("water:b01:items[0]", "verified", "efsa2010", EFSA, "Abstract: adequate total water intake from drinks and food, as the block title says, at moderate temperature and activity."),
    ("water:b01:items[1]", "verified", "efsa2010", EFSA, "Abstract, as above."),
    ("water:b00:text", "verified", "acsmfluid",
     "prevent excessive (>2% body weight loss from water deficit) dehydration and excessive changes in electrolyte balance to avert compromised performance",
     "Abstract (position stand)."),
]


def main(folder):
    texts = {k: r6.norm((Path(folder) / f"{k}.txt").read_text(encoding="utf-8")) for k in {d[2] for d in DECISIONS}}
    v4 = list(csv.DictReader(r6.V4.open(encoding="utf-8")))
    v3 = list(csv.DictReader(r6.V3.open(encoding="utf-8")))
    by_id = {r["claim_id"]: r for r in v4}
    todo = [d for d in DECISIONS if "Round 7:" not in by_id[d[0]]["notes"]]
    for cid, status, src, passage, note in todo:
        r = by_id[cid]
        if r6.norm(passage) not in texts[src]:
            sys.exit(f"passage not in the {src} text: {passage!r}")
        rec = r6.record(r, status, src, passage, note)
        rec["notes"] = rec["notes"].replace("Round 6:", "Round 7:")
        r.update(rec)
        for o in v3:
            if o["text_sha"] == r["text_sha"] and o["evidence_status"] != "auto_label":
                o.update(rec)
    for path, rows in ((r6.V4, v4), (r6.V3, v3)):
        with path.open("w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()), lineterminator="\n")
            w.writeheader()
            w.writerows(rows)
    srcs = list(csv.DictReader(r6.SOURCES.open(encoding="utf-8")))
    for s in srcs:
        if s["key"] in {d[2] for d in DECISIONS} and "Round 7" not in s["verification_status"]:
            level, where = r6.ACCESS[s["key"]]
            s["verification_status"] = f"Round 7, 2026-10-17: {level} read ({where}); passages recorded. {s['verification_status']}".strip()
            if s["key"] in r6.URL and not s["url_or_doi"]:
                s["url_or_doi"] = r6.URL[s["key"]]
    with r6.SOURCES.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(srcs[0].keys()), lineterminator="\n")
        w.writeheader()
        w.writerows(srcs)
    print(f"{len(todo)} decisions applied")


if __name__ == "__main__":
    main(sys.argv[1])

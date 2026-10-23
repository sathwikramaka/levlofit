# Step 1 evidence review check (read-only). Usage: python -I check_step1.py <downloaded-sources dir>
# Every quoted passage in step1_candidate_passages.csv must occur verbatim (whitespace-normalised) in
# <dir>/<source_file>.txt, and every claim must still exist in the v4 register with unchanged text.
import csv, re, sys
from pathlib import Path

HERE = Path(__file__).parent
norm = lambda s: re.sub(r"\s+", " ", s).strip()
reg = {r["claim_id"]: r["text_sha"] for r in csv.DictReader(open(HERE / "claims_register.csv", encoding="utf-8"))}
rows = list(csv.DictReader(open(HERE / "step1_candidate_passages.csv", encoding="utf-8")))
src_dir, texts, bad = Path(sys.argv[1]), {}, []
for i, r in enumerate(rows, 2):
    if reg.get(r["claim_id"]) != r["text_sha"]:
        bad.append(f"line {i}: {r['claim_id']} missing from register or wording changed")
    if r["match"] not in ("supports", "partly", "not_found"):
        bad.append(f"line {i}: bad match value {r['match']!r}")
    if (r["match"] == "not_found") != (not r["passage"]):
        bad.append(f"line {i}: not_found rows must have no passage, others must have one")
    if r["passage"]:
        f = src_dir / f"{r['source_file']}.txt"
        if f not in texts:
            texts[f] = norm(f.read_text(encoding="utf-8")) if f.exists() else None
        if texts[f] is None:
            bad.append(f"line {i}: source text {f.name} not found")
        elif norm(r["passage"]) not in texts[f]:
            bad.append(f"line {i}: passage not found in {f.name}: {r['passage'][:60]}")
print(f"{len(rows)} rows, {sum(1 for r in rows if r['passage'])} passages checked")
if bad:
    sys.exit("\n".join(bad))
print("OK: every passage occurs in its source text; every claim id and wording matches the register")

"""Downloads the PubMed abstracts that audit_round5.py checks passages against, so the audit can be re-run from the
repository alone. Abstracts come from Europe PMC (resultType=core); nothing is stored in the repository.

Only real HTML tags are removed (a "<" followed by a letter or "/"), so "p < 0.05" survives; entities are decoded.
Usage: python -I data/handbook_v4/fetch_abstracts.py <empty folder>
"""
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_round5 import PMID  # noqa: E402

TAG = re.compile(r"</?[A-Za-z][A-Za-z0-9]*(\s[^<>]*)?/?>")


def clean(s):
    return re.sub(r"\s+", " ", html.unescape(TAG.sub(" ", s))).strip()


def main(folder):
    out = Path(folder)
    out.mkdir(parents=True, exist_ok=True)
    for key, pmid in PMID.items():
        q = urllib.parse.urlencode({"query": f"EXT_ID:{pmid} AND SRC:MED", "format": "json", "resultType": "core"})
        with urllib.request.urlopen(f"https://www.ebi.ac.uk/europepmc/webservices/rest/search?{q}", timeout=60) as r:
            rec = json.load(r)["resultList"]["result"][0]
        (out / f"{key}.txt").write_text(clean(rec.get("title", "")) + "\n" + clean(rec.get("abstractText", "")), encoding="utf-8")
        print(key, pmid, rec.get("pubYear"))
        time.sleep(0.5)


if __name__ == "__main__":
    main(sys.argv[1])

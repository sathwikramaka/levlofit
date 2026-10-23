"""Downloads the texts that audit_round6.py checks passages against, into an empty folder (nothing is stored in the
repository). Full texts are open-access articles from Europe PMC (fullTextXML; the reference list is dropped so a
passage can never come from another paper's title); one accepted manuscript comes from the author's university
repository; abstracts come from Europe PMC as in fetch_abstracts.py. Only real tags are stripped ("p < 0.05" stays).

Usage: python data/handbook_v4/fetch_round6.py <empty folder>      (pypdf is needed for the one PDF)
"""
import html
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

TAG = re.compile(r"</?[A-Za-z][A-Za-z0-9:-]*(\s[^<>]*)?/?>")
UA = {"User-Agent": "Levlofit evidence audit (python urllib)"}

# key -> (kind, id). Kinds: pmc (open full text), pmid (abstract), pdf (accepted manuscript URL).
SOURCES = {
    "refalo2025": ("pmc", "PMC11869894"),
    "manore2017": ("pmc", "PMC5579698"),
    "wilson2025": ("pmc", "PMC12357318"),
    "cunha2023": ("pmc", "PMC10354314"),
    "zhang2020": ("pmc", "PMC7056053"),
    "konrad2024": ("pmc", "PMC10980866"),
    "coetsee2015": ("pmc", "PMC4748325"),
    "singer2024": ("pmc", "PMC11349676"),
    "mifflin1990": ("pmid", "2305711"),
    "lake2012": ("pmid", "22580981"),
    "seiler2010": ("pmid", "20861519"),
    "behm2016": ("pmid", "26642915"),
    # Accepted manuscript (green open access), Auckland University of Technology repository, hdl.handle.net/10292/12176.
    "zourdos2016": ("pdf", "https://openrepository.aut.ac.nz/bitstreams/16ad9fb9-5da8-446b-9cd9-aae75afb0b92/download"),
    # Round 7 (audit_round7.py).
    "singh2024": ("pmc", "PMC11641623"),
    "acsmfluid": ("pmid", "17277604"),
    # Abstracts not in Europe PMC: the publisher's abstract as published in the OpenAlex record (inverted index).
    "lally2010": ("openalex", "10.1002/ejsp.674"),
    "efsa2010": ("openalex", "10.2903/j.efsa.2010.1459"),
}


def clean(s):
    return re.sub(r"\s+", " ", html.unescape(TAG.sub(" ", s))).strip()


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
        return r.read()


def main(folder):
    out = Path(folder)
    out.mkdir(parents=True, exist_ok=True)
    for key, (kind, ident) in SOURCES.items():
        if kind == "pmc":
            xml = get(f"https://www.ebi.ac.uk/europepmc/webservices/rest/{ident}/fullTextXML").decode("utf-8")
            text = clean(re.sub(r"<ref-list.*?</ref-list>", "", xml, flags=re.S))
        elif kind == "pmid":
            q = urllib.parse.urlencode({"query": f"EXT_ID:{ident} AND SRC:MED", "format": "json", "resultType": "core"})
            rec = json.loads(get(f"https://www.ebi.ac.uk/europepmc/webservices/rest/search?{q}"))["resultList"]["result"][0]
            text = clean(rec.get("title", "")) + "\n" + clean(rec.get("abstractText", ""))
        elif kind == "openalex":
            rec = json.loads(get(f"https://api.openalex.org/works/doi:{ident}"))
            words = sorted((p, w) for w, ps in (rec.get("abstract_inverted_index") or {}).items() for p in ps)
            text = clean(rec.get("title", "")) + "\n" + clean(" ".join(w for _, w in words))
        else:
            from pypdf import PdfReader
            # If Python cannot reach the repository (some networks time out on IPv6), download the PDF first, for
            # example with `curl -4 -L -o <folder>/<key>.pdf <url>`; a PDF already in the folder is used as is.
            local = out / f"{key}.pdf"
            data = local.read_bytes() if local.is_file() else get(ident)
            text = re.sub(r"\s+", " ", " ".join(p.extract_text() or "" for p in PdfReader(io.BytesIO(data)).pages))
        (out / f"{key}.txt").write_text(text, encoding="utf-8")
        print(key, kind, ident, len(text))
        time.sleep(0.5)


if __name__ == "__main__":
    main(sys.argv[1])

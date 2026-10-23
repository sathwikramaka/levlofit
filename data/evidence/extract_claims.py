"""Handbook claims register: extract every statement from the Handbook and check the evidence register covers it.

The Handbook content lives in data/build_handbook.py (CHAPTERS, SRC). This script reads it without running the
builder, splits every block into claim units, and keeps two CSV registers next to this file:

  claims_register.csv   one row per claim unit: where it is, what it says, the numbers in it, the sources the
                        block cites, automatic flags, and the human review columns (status, supporting passage,
                        where the passage is, who checked it and when, what review is still needed).
  sources_register.csv  one row per source key: the citation, which chapters use it, and human columns for the
                        URL or DOI, licence and verification status.

Usage (from the repo root):
  python data/evidence/extract_claims.py --sync    rebuild both registers from the Handbook, keeping review work
  python data/evidence/extract_claims.py --check   fail (exit 1) if the registers are out of date or a review row
                                                   breaks the rules; print coverage per chapter
  python data/evidence/extract_claims.py --check --strict   also fail while any claim is still unreviewed

Rules the check enforces (so coverage means something):
  - Every claim unit in the Handbook has exactly one row, and its text matches what was reviewed. Text that changed
    after review must be marked "stale" until it is checked again.
  - "verified" or "partly_supported" needs the supporting passage quoted, where it is (page or section), the source
    key it comes from (one listed in SRC), and the review date. A cited source title alone is never proof.
  - A claim flagged for clinical review cannot be "verified" until review_needs records "clinical_done".
  - Automatic flags are hints for reviewers, never verdicts.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
BUILDER = HERE.parent / "build_handbook.py"
CLAIMS_CSV = HERE / "claims_register.csv"
SOURCES_CSV = HERE / "sources_register.csv"

# Block fields that carry layout or references, not statements.
META = {"t", "source", "kind", "tone", "grade", "ref"}  # ref: a chapter link in Handbook v4 "Up next" blocks

CLAIM_COLUMNS = [
    "claim_id", "chapter", "part", "block", "block_type", "field", "auto_kind", "text", "text_sha", "numbers",
    "direct_sources", "chapter_sources", "flags",
    # human review columns, kept across --sync
    "evidence_status", "passage_source", "supporting_passage", "passage_locator", "reviewed_by", "reviewed_on",
    "review_needs", "notes",
]
CLAIM_HUMAN = CLAIM_COLUMNS[CLAIM_COLUMNS.index("evidence_status"):]
SOURCE_COLUMNS = ["key", "citation", "chapters", "claims_citing", "url_or_doi", "licence", "verification_status", "notes"]
SOURCE_HUMAN = ["url_or_doi", "licence", "verification_status", "notes"]

STATUSES = {
    "unreviewed",  # nobody has checked it yet
    "auto_label",  # a heading or label with no claim in it, set by the extractor
    "non_claim",  # a reviewer confirmed it states nothing that needs evidence
    "verified",  # the quoted passage supports the claim as written
    "partly_supported",  # the passage supports part of it; notes say which part
    "unsupported",  # the cited source does not support it
    "contradicted",  # a source says otherwise
    "needs_better_source",  # plausible, but the cited source is too weak or indirect
    "needs_clinical_review",  # a qualified clinician or dietitian must decide
    "stale",  # the text changed after it was reviewed
    "editorial",  # Levlofit's own guidance (a decision step, a priority list, app advice); it claims no evidence
    "needs_source",  # a factual health or fitness claim with no citation; needs a source, or rewording as guidance
}
SUPPORTED = {"verified", "partly_supported"}
REVIEWED = STATUSES - {"unreviewed", "stale"}

NUMBER = re.compile(r"\d+(?:[.,]\d+)?")
CLINICAL = re.compile(
    r"\b(pregnan\w*|postpartum|heart|cardiac|chest pain|faint\w*|dizz\w*|blood pressure|hypertension|diabet\w*|kidney|"
    r"medication|medicine|doctor|surgery|injur\w*|pain|eating disorder|self-harm|suicid\w*|depress\w*|bmi|waist|"
    r"caffeine|creatine|supplement\w*|protein powder|whey|deficit|weight loss|fasting|hydrat\w*|sodium|salt|alcohol)\b",
    re.I,
)


def load_builder(path: Path = BUILDER):
    """Imports the builder module for its CHAPTERS and SRC; its main() is not run, so nothing is written."""
    spec = importlib.util.spec_from_file_location("handbook_builder", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _render(value) -> str:
    """One item as a line of text, in field order, leaving out references and layout fields."""
    if isinstance(value, dict):
        return " · ".join(_render(v) for k, v in value.items() if k not in META and v not in (None, "", [], {}))
    if isinstance(value, list):
        return " | ".join(_render(v) for v in value)
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def _is_leaf(value, path: str = "") -> bool:
    """An item to treat as one claim: text, a table row or header, or a dict with no lists inside. Other lists of
    text (compare and cycle items) are split, one unit per entry."""
    if isinstance(value, (str, int, float)):
        return True
    if isinstance(value, list):
        row = re.fullmatch(r"rows\[\d+\]|head", path) is not None
        return row and all(isinstance(v, (str, int, float)) or v is None for v in value)
    if isinstance(value, dict):
        return not any(isinstance(v, (list, dict)) for k, v in value.items() if k not in META)
    return False


def _units(block: dict):
    """Yields (field path, item) for every claim unit in a block."""

    def walk(value, path):
        if isinstance(value, dict) and not _is_leaf(value, path):
            for k, v in value.items():
                if k not in META and v is not None:
                    yield from walk(v, f"{path}.{k}" if path else k)
        elif isinstance(value, list) and not _is_leaf(value, path):
            for i, v in enumerate(value):
                yield from walk(v, f"{path}[{i}]")
        elif _is_leaf(value, path) and _render(value).strip():
            yield path, value

    for k, v in block.items():
        if k in META or v is None:
            continue
        yield from walk(v, k)


def _auto_kind(text: str, block_type: str, field: str) -> str:
    if NUMBER.search(text):
        return "numeric"
    if block_type == "week" or field.endswith(("title", "head")) or len(text.split()) <= 3:
        return "label"
    return "statement"


def extract(module) -> list[dict]:
    """Every claim unit in the Handbook, in chapter and block order, with automatic flags."""
    src = module.SRC
    rows = []
    for c in module.CHAPTERS:
        listed = list(c["sources"])
        for bi, block in enumerate(c["blocks"]):
            unit_suffix = f" [{block['unit']}]" if block.get("unit") else ""
            for field, item in _units(block):
                if field == "unit":
                    continue  # the unit is folded into each item of that block
                text = _render(item)
                if block["t"] == "table" and field.startswith("rows[") and isinstance(item, list) and block.get("head"):
                    # A table row reads on its own only with its column names.
                    text = "; ".join(f"{_render(h)}: {_render(v)}" for h, v in zip(block["head"], item))
                numeric_item = isinstance(item, dict) and any(isinstance(v, (int, float)) for v in item.values())
                if unit_suffix and numeric_item:
                    text += unit_suffix
                direct = item.get("source") if isinstance(item, dict) else None
                direct = direct or block.get("source")
                direct_list = [direct] if direct else []
                kind = _auto_kind(text, block["t"], field)
                flags = []
                if kind == "numeric" and not direct_list:
                    flags.append("uncited_number")
                if kind == "statement" and not direct_list:
                    flags.append("no_direct_source")
                if any(k not in src for k in direct_list):
                    flags.append("source_key_unknown")
                elif any(k not in listed for k in direct_list):
                    flags.append("source_not_listed_by_chapter")
                if CLINICAL.search(text):
                    flags.append("clinical_review")
                rows.append({
                    "claim_id": f"{c['slug']}:b{bi:02d}:{field}",
                    "chapter": c["slug"],
                    "part": c["part"],
                    "block": str(bi),
                    "block_type": block["t"],
                    "field": field,
                    "auto_kind": kind,
                    "text": text,
                    "text_sha": hashlib.sha256(text.encode("utf-8")).hexdigest()[:16],
                    "numbers": " ".join(NUMBER.findall(text)),
                    "direct_sources": " ".join(direct_list),
                    "chapter_sources": " ".join(listed),
                    "flags": " ".join(flags),
                })
    return rows


def _read(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def _write(path: Path, columns: list[str], rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=columns, lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in columns})


def merge_claims(extracted: list[dict], existing: list[dict]) -> tuple[list[dict], dict]:
    """New register rows: extracted facts plus kept review columns. Changed text after review becomes 'stale'."""
    old = {r["claim_id"]: r for r in existing}
    out, changes = [], {"added": [], "removed": [], "stale": []}
    for r in extracted:
        prev = old.get(r["claim_id"])
        row = dict(r)
        if prev is None:
            row.update({k: "" for k in CLAIM_HUMAN})
            row["evidence_status"] = "auto_label" if r["auto_kind"] == "label" else "unreviewed"
            changes["added"].append(r["claim_id"])
        else:
            row.update({k: prev.get(k, "") for k in CLAIM_HUMAN})
            if prev.get("text_sha") != r["text_sha"] and row["evidence_status"] not in ("unreviewed", "auto_label", "stale"):
                row["notes"] = (f"text changed after review (was: {prev.get('text', '')}); " + row["notes"]).strip("; ")
                row["evidence_status"] = "stale"
                changes["stale"].append(r["claim_id"])
            elif prev.get("text_sha") != r["text_sha"] and row["evidence_status"] == "auto_label" and r["auto_kind"] != "label":
                row["evidence_status"] = "unreviewed"
        out.append(row)
    ids = {r["claim_id"] for r in extracted}
    changes["removed"] = [i for i in old if i not in ids]
    return out, changes


def merge_sources(module, claims: list[dict], existing: list[dict]) -> list[dict]:
    old = {r["key"]: r for r in existing}
    chapters, citing = defaultdict(list), Counter()
    for c in module.CHAPTERS:
        for k in c["sources"]:
            chapters[k].append(c["slug"])
    for r in claims:
        for k in r["direct_sources"].split():
            citing[k] += 1
    rows = []
    for key, citation in module.SRC.items():
        prev = old.get(key, {})
        row = {"key": key, "citation": citation, "chapters": " ".join(chapters[key]), "claims_citing": str(citing[key])}
        row.update({k: prev.get(k, "") for k in SOURCE_HUMAN})
        row["licence"] = row["licence"] or "unknown"
        row["verification_status"] = row["verification_status"] or "unchecked"
        rows.append(row)
    return rows


def check(module, claims: list[dict], sources: list[dict], strict: bool = False) -> tuple[list[str], dict]:
    """Integrity errors (always fatal) and a coverage summary."""
    errors = []
    extracted = {r["claim_id"]: r for r in extract(module)}
    have = {}
    for r in claims:
        if r["claim_id"] in have:
            errors.append(f"{r['claim_id']}: duplicate row")
        have[r["claim_id"]] = r
    for cid in extracted.keys() - have.keys():
        errors.append(f"{cid}: in the Handbook but not in the register (run --sync)")
    for cid in have.keys() - extracted.keys():
        errors.append(f"{cid}: in the register but no longer in the Handbook (run --sync)")
    src = module.SRC
    for cid, r in have.items():
        status = r.get("evidence_status", "")
        if status not in STATUSES:
            errors.append(f"{cid}: unknown evidence_status '{status}'")
            continue
        e = extracted.get(cid)
        if e and e["text_sha"] != r.get("text_sha") and status not in ("stale", "unreviewed", "auto_label"):
            errors.append(f"{cid}: text changed since review; mark it stale (run --sync)")
        if status == "auto_label" and e and e["auto_kind"] != "label":
            errors.append(f"{cid}: auto_label on a {e['auto_kind']} unit")
        if status in SUPPORTED:
            for col in ("supporting_passage", "passage_locator", "passage_source", "reviewed_on"):
                if not r.get(col, "").strip():
                    errors.append(f"{cid}: {status} without {col}")
        elif r.get("supporting_passage", "").strip():
            # Any quoted passage, whatever the status, must say where it is from and when it was checked.
            for col in ("passage_locator", "passage_source", "reviewed_on"):
                if not r.get(col, "").strip():
                    errors.append(f"{cid}: quoted passage without {col}")
        if r.get("passage_source") and r["passage_source"] not in src:
                errors.append(f"{cid}: passage_source '{r['passage_source']}' is not a listed source")
        if status == "verified" and "clinical_review" in r.get("flags", "").split() and "clinical_done" not in r.get("review_needs", ""):
            errors.append(f"{cid}: clinical claim marked verified without review_needs 'clinical_done'")
    keys = {s["key"] for s in sources}
    for k in src.keys() - keys:
        errors.append(f"source {k}: missing from sources_register.csv (run --sync)")
    for k in keys - src.keys():
        errors.append(f"source {k}: in sources_register.csv but not in SRC (run --sync)")

    per = defaultdict(Counter)
    for cid, r in have.items():
        e = extracted.get(cid)
        if not e:
            continue
        ch = per[e["chapter"]]
        ch["units"] += 1
        if e["auto_kind"] != "label":
            ch["claims"] += 1
            ch["reviewed"] += r["evidence_status"] in REVIEWED
            ch["supported"] += r["evidence_status"] in SUPPORTED
        for f in e["flags"].split():
            ch[f] += 1
    total = sum(per.values(), Counter())
    if strict:
        pending = [cid for cid, r in have.items() if r["evidence_status"] in ("unreviewed", "stale")]
        if pending:
            errors.append(f"{len(pending)} claims still unreviewed or stale (--strict)")
    return errors, {"per_chapter": per, "total": total}


PASSAGES_JSON = HERE.parent.parent / "supabase" / "functions" / "_shared" / "handbook-passages.json"


NAV_BLOCKS = {"next", "part"}


def build_passages(module, claims: list[dict]) -> dict:
    """Retrieval passages for Levlofit AI: one per Handbook block, id '<chapter>:bNN' (the claim ids' prefix), with
    the sources that block cites and an evidence summary taken from the register. 'checked' needs every claim in the
    block verified with a quoted passage; nothing here is a clinical sign-off."""
    reviewed = {r["claim_id"]: r for r in claims}
    blocks: dict[str, list[dict]] = defaultdict(list)
    for u in extract(module):
        blocks[u["claim_id"].rsplit(":", 1)[0]].append(u)
    titles = {c["slug"]: c["title"] for c in module.CHAPTERS}
    passages, used = [], set()
    for pid, units in blocks.items():
        if units[0]["block_type"] in NAV_BLOCKS:
            continue  # navigation (Handbook v4 "Up next", part openers) is not knowledge to retrieve
        chapter = units[0]["chapter"]
        claims_ = [u for u in units if u["auto_kind"] != "label"]
        statuses = [reviewed.get(u["claim_id"], {}).get("evidence_status", "unreviewed") for u in claims_]
        # A claim whose source passage was checked but which still awaits clinical sign-off counts as partly
        # checked, never as checked.
        source_checked = [
            s in SUPPORTED or (s == "needs_clinical_review" and reviewed.get(u["claim_id"], {}).get("supporting_passage", "").strip())
            for u, s in zip(claims_, statuses)
        ]
        if not claims_:
            evidence = "no_claims"
        elif any(s in ("unsupported", "contradicted") for s in statuses):
            evidence = "disputed"
        elif all(s == "verified" for s in statuses):
            evidence = "checked"
        elif any(source_checked):
            evidence = "partly_checked"
        elif any(s in ("unreviewed", "stale") for s in statuses):
            evidence = "unreviewed"
        elif any(s in ("needs_source", "needs_better_source") for s in statuses):
            evidence = "unsourced"
        elif all(s in ("editorial", "non_claim", "auto_label") for s in statuses):
            evidence = "editorial"
        else:
            evidence = "unreviewed"
        clinical = any(
            "clinical_review" in u["flags"].split() and "clinical_done" not in reviewed.get(u["claim_id"], {}).get("review_needs", "")
            for u in units
        )
        cited = {k for u in units for k in u["direct_sources"].split()}
        sources = sorted(k for k in cited if k in module.SRC)  # a key with no listed citation is never presented as one
        used.update(sources)
        passages.append({
            "id": pid,
            "chapter": chapter,
            "chapterTitle": titles[chapter],
            "blockType": units[0]["block_type"],
            "text": ". ".join(dict.fromkeys(u["text"] for u in units)),
            "sources": sources,
            "unknownSources": sorted(cited - set(sources)),
            "chapterSources": units[0]["chapter_sources"].split(),
            "evidence": evidence,
            "clinicalReview": clinical,
            "claimIds": [u["claim_id"] for u in units],
        })
    return {
        "generatedBy": "data/evidence/extract_claims.py --sync (from data/build_handbook.py and claims_register.csv); do not edit",
        "sources": {k: module.SRC[k] for k in sorted(used)},
        "passages": passages,
    }


def _passages_json(module, claims: list[dict]) -> str:
    return json.dumps(build_passages(module, claims), ensure_ascii=False, indent=1) + "\n"


def check_passages(module, claims: list[dict], path: Path) -> list[str]:
    """The passages file must match the Handbook and the register exactly."""
    if not path.exists():
        return [f"{path.name}: missing (run --sync)"]
    if path.read_text(encoding="utf-8") != _passages_json(module, claims):
        return [f"{path.name}: out of date with the Handbook or the register (run --sync)"]
    return []


def _print_coverage(summary: dict) -> None:
    cols = ["units", "claims", "reviewed", "supported", "uncited_number", "no_direct_source", "clinical_review"]
    print(f"{'chapter':<24}" + "".join(f"{c[:12]:>13}" for c in cols))
    for ch, n in summary["per_chapter"].items():
        print(f"{ch:<24}" + "".join(f"{n[c]:>13}" for c in cols))
    t = summary["total"]
    print(f"{'TOTAL':<24}" + "".join(f"{t[c]:>13}" for c in cols))
    pct = 100 * t["reviewed"] / t["claims"] if t["claims"] else 0
    print(f"reviewed {t['reviewed']} of {t['claims']} claims ({pct:.1f}%); {t['supported']} supported by a quoted passage")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--sync", action="store_true", help="rebuild the registers from the Handbook, keeping review columns")
    p.add_argument("--check", action="store_true", help="validate the registers and print coverage")
    p.add_argument("--strict", action="store_true", help="with --check, also fail while claims are unreviewed")
    p.add_argument("--builder", type=Path, default=BUILDER)
    p.add_argument("--claims", type=Path, default=CLAIMS_CSV)
    p.add_argument("--sources", type=Path, default=SOURCES_CSV)
    p.add_argument("--passages", type=Path, default=PASSAGES_JSON, help="retrieval passages for Levlofit AI (written by --sync)")
    a = p.parse_args(argv)
    module = load_builder(a.builder)
    if a.sync:
        claims, changes = merge_claims(extract(module), _read(a.claims))
        _write(a.claims, CLAIM_COLUMNS, claims)
        _write(a.sources, SOURCE_COLUMNS, merge_sources(module, claims, _read(a.sources)))
        a.passages.write_text(_passages_json(module, claims), encoding="utf-8", newline="\n")
        print(f"synced {len(claims)} claim units: {len(changes['added'])} new, {len(changes['removed'])} removed, {len(changes['stale'])} now stale")
        for cid in changes["removed"]:
            print(f"  removed: {cid}")
    if a.check or not a.sync:
        errors, summary = check(module, _read(a.claims), _read(a.sources), strict=a.strict)
        errors += check_passages(module, _read(a.claims), a.passages)
        _print_coverage(summary)
        for e in errors:
            print(f"ERROR {e}")
        return 1 if errors else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())

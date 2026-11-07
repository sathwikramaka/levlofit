"""Handbook book: turns data/handbook_book/NN-slug.md into website/src/lib/handbook_book.json and checks it.

Run from the repo root: python -I data/handbook_book/build.py

Chapter file format:
  First lines: `slug: ...`, `title: ...`, `summary: ...`, then a blank line.
  `# Volume name` starts a new volume in the book order (put it before `slug:` in that volume's first chapter).
  `## Heading`, `### Subheading`, plain paragraph, `- list item`, `| table | row |` (first row is the header).
  `> evidence: Title` or `> warn: Title` or `> tip: Title`, followed by `> paragraph` lines, makes a note.
  `{key}` cites a source from sources.json. `[[slug|Title]]` links to a chapter; the link becomes plain text until
  that chapter exists.
"""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "website" / "src" / "lib" / "handbook_book.json"
MIGRATION = HERE.parents[1] / "supabase" / "migrations" / "20261107300000_handbook_book.sql"
ROMAN = ["I", "II", "III", "IV", "V", "VI"]
BANNED = re.compile(r"\bAPS\b|Chapter \d|—|earlier editions", re.I)


def parse(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    meta, blocks, volume, i = {}, [], None, 0
    while lines[i].strip():
        if lines[i].startswith("# "):
            volume = lines[i][2:].strip()
        else:
            k, v = lines[i].split(": ", 1)
            meta[k] = v.strip()
        i += 1
    for line in lines[i:]:
        line = line.strip()
        last = blocks[-1] if blocks else {}
        if not line:
            continue
        if line.startswith("### "):
            blocks.append({"t": "h3", "text": line[4:]})
        elif line.startswith("## "):
            blocks.append({"t": "h2", "text": line[3:]})
        elif line.startswith("- "):
            if last.get("t") == "list":
                last["items"].append(line[2:])
            else:
                blocks.append({"t": "list", "items": [line[2:]]})
        elif line.startswith("|"):
            cells = [c.strip() for c in re.split(r"\|(?![^\[]*\]\])", line.strip("|"))]  # not the | inside [[slug|Title]]
            if last.get("t") == "rows":
                last["rows"].append(cells)
            else:
                blocks.append({"t": "rows", "head": cells, "rows": []})
        elif line.startswith("> "):
            m = re.match(r"> (evidence|warn|tip): (.+)", line)
            if m:
                blocks.append({"t": "note", "kind": m[1], "title": m[2], "paras": []})
            else:
                last["paras"].append(line[2:])
        else:
            blocks.append({"t": "p", "text": line})
    return meta, volume, blocks


def texts(block):
    for k in ("text", "title"):
        if k in block:
            yield block[k]
    yield from block.get("items", [])
    yield from block.get("paras", [])
    yield from block.get("head", [])
    for row in block.get("rows", []):
        yield from row


def build():
    sources = json.loads((HERE / "sources.json").read_text(encoding="utf-8"))
    chapters, volume, volumes = [], None, 0
    for path in sorted(HERE.glob("[0-9][0-9]-*.md")):
        meta, new_volume, blocks = parse(path)
        if new_volume:
            volume, volumes = new_volume, volumes + 1
        assert volume, f"{path.name}: no volume yet"
        assert meta["slug"] == path.stem[3:], f"{path.name}: slug does not match the file name"
        keys = []
        for b in blocks:
            for s in texts(b):
                assert not BANNED.search(s), f"{path.name}: banned wording: {s[:70]}"
                for key in re.findall(r"\{([a-z0-9-]+)\}", s):
                    assert key in sources, f"{path.name}: unknown source {key}"
                    if key not in keys:
                        keys.append(key)
            if b["t"] == "rows":
                assert all(len(r) == len(b["head"]) for r in b["rows"]), f"{path.name}: uneven table: {b['head']}"
        assert sum(b["t"] == "h2" for b in blocks) >= 2, f"{path.name}: too few sections"
        words = sum(len(s.split()) for b in blocks for s in texts(b))
        chapters.append({
            "slug": meta["slug"],
            "number": len(chapters) + 1,
            "part": ROMAN[volumes - 1],
            "partTitle": volume,
            "volume": f"Volume {ROMAN[volumes - 1]} · {volume}",
            "title": meta["title"],
            "summary": meta["summary"],
            "minutes": max(1, round(words / 200)),
            "sources": {k: sources[k] for k in keys},
            "blocks": blocks,
        })
    slugs = {c["slug"] for c in chapters}
    link = re.compile(r"\[\[([a-z0-9-]+)\|([^\]]+)\]\]")
    def resolve(s):
        return link.sub(lambda m: m[0] if m[1] in slugs else m[2], s) if isinstance(s, str) else s
    for c in chapters:
        for b in c["blocks"]:
            for k, v in b.items():
                if isinstance(v, list):
                    b[k] = [[resolve(x) for x in row] if isinstance(row, list) else resolve(row) for row in v]
                else:
                    b[k] = resolve(v)
    return chapters


# Read by data/evidence/extract_claims.py --builder, which keeps this book's evidence register.
SRC = json.loads((HERE / "sources.json").read_text(encoding="utf-8"))
CHAPTERS = build()
GENERATED_BY = "data/evidence/extract_claims.py --sync --builder data/handbook_book/build.py (with this folder's claims_register.csv); do not edit"

def q(s):
    return "'" + s.replace("'", "''") + "'"


def plain(c):
    """A chapter's text for the search column, without markup."""
    s = " ".join(t for b in c["blocks"] for t in texts(b))
    return re.sub(r"\[\[[a-z0-9-]+\|([^\]]+)\]\]", r"\1", re.sub(r"\s*\{[a-z0-9-]+\}", "", s)).replace("**", "")


def migration():
    rows = []
    for c in CHAPTERS:
        cited = "array[" + ", ".join(q(v) for v in c["sources"].values()) + "]::text[]"
        blocks = json.dumps({"sources": c["sources"], "blocks": c["blocks"]}, ensure_ascii=False)
        rows.append(f"({c['number']}, {q(c['slug'])}, {q(c['part'])}, {q(c['partTitle'])}, {q(c['title'])}, {q(c['summary'])}, "
                    f"{c['minutes']}, {q(plain(c))}, {cited}, {q(blocks)}::jsonb)")
    return f"""-- Handbook book: {len(rows)} chapters in six volumes, ids in reading order. Generated by data/handbook_book/build.py; edit
-- that folder, not this file. Not clinician-reviewed. The evidence register is data/handbook_book/claims_register.csv.
-- Order at release: the app that reads these blocks first (older apps show them blank), then this file, then coach-chat.
do $$
begin
  -- ids are renumbered: stop rather than point a goal at the wrong chapter
  if exists (select 1 from public.goal_catalog where handbook_chapter is not null) then
    raise exception 'goal_catalog.handbook_chapter is set; map goals to book chapter ids first';
  end if;
end $$;
delete from public.handbook_chapters;
insert into public.handbook_chapters (id, slug, part, part_title, title, summary, minutes, body_md, sources, blocks) values
{",\n".join(rows)};
"""


if __name__ == "__main__":
    OUT.write_text(json.dumps(CHAPTERS, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    MIGRATION.write_text(migration(), encoding="utf-8", newline="\n")
    print(len(CHAPTERS), "chapters,", sum(c["minutes"] for c in CHAPTERS), "minutes:", ", ".join(c["slug"] for c in CHAPTERS))

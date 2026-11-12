"""Handbook book: turns data/handbook_book/NN-slug.md into website/src/lib/handbook_book.json and checks it.

Run from the repo root: python -I data/handbook_book/build.py

Chapter file format:
  First lines: `slug: ...`, `title: ...`, `summary: ...`, then a blank line.
  `# Volume name` starts a new volume in the book order (put it before `slug:` in that volume's first chapter).
  `## Heading`, `### Subheading`, plain paragraph, `- list item`, `| table | row |` (first row is the header).
  `> evidence: Title` or `> warn: Title` or `> tip: Title`, followed by `> paragraph` lines, makes a note.
  `{key}` cites a source from sources.json. `[[slug|Title]]` links to a chapter; the link becomes plain text until
  that chapter exists.
  Visual blocks (2026-11-12, drawn by the app's and the website's figure renderers): a line `:: kind header` opens one,
  each following line is a row of cells split by ` | `, and a line `::` closes it. A `{key}` cell or header part is the
  figure's source. Kinds and their rows:
    stats                               value | unit | label | {key}
    steps Title                         step | text
    compare Do title | Avoid title      do item | avoid item   (- for an empty side)
    bars Title | unit | {key}           label | number | note
    plate Title | {key}                 label | share 0 to 1 | note
    flow Title | {key}                  question | if yes | if no
    band Title | unit | {key}           from | to | label | good, ok or bad
    scale Title | {key}                 mark | label | text
"""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "website" / "src" / "lib" / "handbook_book.json"
# Each content release writes a new migration; earlier ones are applied and never rewritten.
MIGRATION = HERE.parents[1] / "supabase" / "migrations" / "20261112100000_handbook_book_update.sql"
REDIRECTS = HERE.parents[1] / "website" / "public" / "_redirects"
ROMAN = ["I", "II", "III", "IV", "V", "VI"]
# Old chapter addresses people may have saved, and the book chapter that replaces each.
MOVED = {
    "how-training-works": "exercise-science", "effort-and-rir": "exercise-science", "warm-up": "warmup-mobility",
    "sets-reps-progress": "progressive-overload", "rest-between-sets": "exercise-science", "sleep-recovery": "sleep-guide",
    "one-step-at-a-time": "combining-training", "tracking-progress": "why-track", "plateaus-deloads": "plateaus",
    "habits": "sustainable-habits", "food-basics": "nutrition-fundamentals", "water": "hydration",
    "carbs-fibre-fats": "nutrition-fundamentals", "meal-timing": "nutrient-timing", "body-measures": "body-measurements",
    "calories": "calories-body-composition", "fat-loss": "body-fat-lean", "supplements": "supplements-guide",
    "build-muscle": "aesthetic-physique", "physique": "aesthetic-physique", "calisthenics": "calisthenics-ladders",
    "mobility": "mobility-flexibility", "running": "running-guide", "hyrox": "hyrox-guide",
    "soreness-pain-injury": "injury-prevention", "busy-weeks": "staying-consistent", "home-training": "home-training-guide",
    "mind-motivation": "motivation", "putting-it-together": "building-a-week",
}
BANNED = re.compile(r"\bAPS\b|Chapter \d|—|earlier editions", re.I)


SRC_CELL = re.compile(r"^\{([a-z0-9-]+)\}$")


def visual(kind, head, rows, where):
    """One figure block from a `:: kind head` header and its rows (see the module docstring)."""
    parts = [x.strip() for x in head.split(" | ")] if head else []
    src = next((SRC_CELL.match(x)[1] for x in parts if SRC_CELL.match(x)), None)
    parts = [x for x in parts if not SRC_CELL.match(x)]
    def need(n):
        for r in rows:
            assert len(r) == n, f"{where}: a {kind} row needs {n} cells: {r}"
    def num(x):
        return float(x) if "." in x else int(x)
    if kind == "stats":
        need(4)
        return {"t": "stats", "items": [{"value": a, "unit": b, "label": c, "source": SRC_CELL.match(d)[1] if SRC_CELL.match(d) else None} for a, b, c, d in rows]}
    if kind == "steps":
        need(2)
        return {"t": "steps", "title": parts[0], "items": [{"title": a, "text": b} for a, b in rows]}
    if kind == "compare":
        need(2)
        return {"t": "compare", "do": {"title": parts[0], "items": [a for a, _ in rows if a != "-"]},
                "dont": {"title": parts[1], "items": [b for _, b in rows if b != "-"]}}
    if kind == "bars":
        need(3)
        return {"t": "bars", "title": parts[0], "unit": parts[1], "items": [{"label": a, "value": num(b), "note": c} for a, b, c in rows], "source": src}
    if kind == "plate":
        need(3)
        items = [{"label": a, "share": num(b), "note": c} for a, b, c in rows]
        assert abs(sum(x["share"] for x in items) - 1) < 0.01, f"{where}: plate shares must add to 1"
        return {"t": "plate", "title": parts[0], "items": items, "source": src}
    if kind == "flow":
        need(3)
        return {"t": "flow", "title": parts[0], "items": [{"q": a, "yes": b, "no": c} for a, b, c in rows], "note": None, "source": src}
    if kind == "band":
        need(4)
        for r in rows:
            assert r[3] in ("good", "ok", "bad"), f"{where}: band tone must be good, ok or bad: {r}"
        return {"t": "band", "title": parts[0], "unit": parts[1], "ranges": [{"from": num(a), "to": num(b), "label": c, "tone": d} for a, b, c, d in rows], "source": src}
    if kind == "scale":
        need(3)
        return {"t": "scale", "title": parts[0], "items": [{"mark": a, "label": b, "text": c} for a, b, c in rows], "source": src}
    raise AssertionError(f"{where}: unknown visual block {kind}")


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
    fig = None  # an open visual block: (kind, head, rows)
    for line in lines[i:]:
        line = line.strip()
        last = blocks[-1] if blocks else {}
        if fig is not None:
            if line == "::":
                blocks.append(visual(*fig, path.name))
                fig = None
            elif line:
                fig[2].append([c.strip() for c in line.split(" | ")])
            continue
        if line.startswith(":: "):
            kind, _, head = line[3:].partition(" ")
            fig = (kind, head.strip(), [])
            continue
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
    assert fig is None, f"{path.name}: a visual block is not closed with ::"
    return meta, volume, blocks


def texts(block):
    for k in ("text", "title"):
        if k in block:
            yield block[k]
    yield from (x for x in block.get("items", []) if isinstance(x, str))
    yield from block.get("paras", [])
    yield from block.get("head", [])
    for row in block.get("rows", []):
        yield from row
    # Visual blocks: every text in their items, and their sources as {key} so they are counted and listed.
    for item in block.get("items", []) if isinstance(block.get("items"), list) else []:
        if isinstance(item, dict):
            for k, v in item.items():
                if k == "source" and v:
                    yield "{" + v + "}"
                elif isinstance(v, str):
                    yield v
    for side in ("do", "dont"):
        yield from block.get(side, {}).get("items", [])
    for r in block.get("ranges", []):
        yield r["label"]
    if block.get("source"):
        yield "{" + block["source"] + "}"


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


def redirects():
    slugs = {c["slug"] for c in CHAPTERS}
    assert not (MOVED.keys() & slugs), "a moved address is still a chapter"
    assert set(MOVED.values()) <= slugs, "a redirect points at a missing chapter"
    return "".join(f"/handbook/{a} /handbook/{b} 301\n" for a, b in MOVED.items())


if __name__ == "__main__":
    REDIRECTS.write_text(redirects(), encoding="utf-8", newline="\n")
    OUT.write_text(json.dumps(CHAPTERS, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    MIGRATION.write_text(migration(), encoding="utf-8", newline="\n")
    print(len(CHAPTERS), "chapters,", sum(c["minutes"] for c in CHAPTERS), "minutes:", ", ".join(c["slug"] for c in CHAPTERS))

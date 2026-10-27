"""Build the USDA FoodData Central food rows (CC0 1.0) for Levlofit's meal planner.

Run (after the owner-approved download of an FDC CSV release, unzipped OUTSIDE the repository):
    python -I data/build_foods_fdc.py <unzipped FDC csv folder> [<more folders>]
Writes supabase/migrations/20261025200000_foods_usda_fdc.sql. Nothing is downloaded here.

Rules:
- Only rows of data/fdc/planner_map.csv with match "exact" or "close" are built; "none" rows are reported, never
  filled. Every mapped description must exist exactly once in the given releases (when SR Legacy and Foundation both
  have it, the SR Legacy record), or the build stops: no guessing.
- "close" rows carry their disclosure into the food's name note (shown with the food), so a nutritionally different
  food is never presented as the Indian one.
- carb_g means available carbohydrate, as in the IFCT rows (CHOAVLDF): FDC carbohydrate by difference (1005) minus
  total dietary fibre (1079). Without a fibre value it stays null rather than counting fibre as carbohydrate.
- An existing row with the same FDC record (soya chunks X001, FDC 174275, added before this builder with 1005 as its
  carbohydrate) is corrected to the same values.
- Values are per 100 g as published. A missing nutrient stays null, never 0. Energy: FDC nutrient 1008 (kcal), else
  the Atwater values 2047 / 2048 that Foundation Foods publish; if none, an Atwater estimate (4/9/4) flagged
  kcal_estimated, as for IFCT.
- Provenance: source 'usda_fdc', source_ref = fdc_id, code 'FDC<fdc_id>'.
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAP = ROOT / "data/fdc/planner_map.csv"
OUT = ROOT / "supabase/migrations/20261025200000_foods_usda_fdc.sql"

MACROS = {"protein_g": 1003, "fat_g": 1004, "carb_g": 1005, "fiber_g": 1079}
MICROS = {"calcium_mg": 1087, "iron_mg": 1089, "zinc_mg": 1095, "sodium_mg": 1093, "potassium_mg": 1092,
          "magnesium_mg": 1090, "vitamin_c_mg": 1162, "folate_ug": 1177}
ENERGY = (1008, 2047, 2048)


def read_map(path=MAP):
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        if r["match"] not in ("exact", "close", "none"):
            raise SystemExit(f"{r['planner_code']}: unknown match {r['match']!r}")
        if r["match"] == "close" and not r["disclosure"].strip():
            raise SystemExit(f"{r['planner_code']}: a close match needs a disclosure")
        if r["match"] != "none" and not r["fdc_description"].strip():
            raise SystemExit(f"{r['planner_code']}: no FDC description")
    return rows


def read_release(folders):
    """fdc_id -> (description, data type), and fdc_id -> {nutrient_id: amount}, over SR Legacy / Foundation folders."""
    foods, values = {}, {}
    for folder in folders:
        folder = Path(folder)
        with open(folder / "food.csv", encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                if r["data_type"] in ("sr_legacy_food", "foundation_food"):
                    foods[r["fdc_id"]] = (r["description"], r["data_type"])
        with open(folder / "food_nutrient.csv", encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                if r["fdc_id"] in foods and r["amount"] not in ("", None):
                    values.setdefault(r["fdc_id"], {})[int(r["nutrient_id"])] = float(r["amount"])
    return foods, values


def build(mapping, foods, values):
    by_desc = {}
    for fid, (desc, kind) in foods.items():
        by_desc.setdefault(desc, []).append((fid, kind))
    rows, missing = [], []
    for m in mapping:
        if m["match"] == "none":
            missing.append(m["planner_code"])
            continue
        hits = by_desc.get(m["fdc_description"], [])
        # The same name in both releases: take the SR Legacy record, so every value comes from one dataset.
        if len(hits) > 1:
            hits = [h for h in hits if h[1] == "sr_legacy_food"]
        if len(hits) != 1:
            raise SystemExit(f"{m['planner_code']}: {len(hits)} FDC records named {m['fdc_description']!r} (need exactly 1)")
        fid = hits[0][0]
        v = values.get(fid, {})
        row = {k: v.get(n) for k, n in MACROS.items()}
        row.update({k: v.get(n) for k, n in MICROS.items()})
        by_difference = row["carb_g"]
        row["carb_g"] = None if by_difference is None or row["fiber_g"] is None else max(0.0, by_difference - row["fiber_g"])
        kcal = next((v[n] for n in ENERGY if n in v), None)
        estimated = False
        if kcal is None and None not in (row["protein_g"], row["fat_g"], by_difference):
            kcal, estimated = 4 * row["protein_g"] + 9 * row["fat_g"] + 4 * by_difference, True
        for k, x in row.items():
            if x is not None and x < 0:
                raise SystemExit(f"{m['planner_code']}: negative {k}")
        row.update(code=f"FDC{fid}", fdc_id=fid, planner_code=m["planner_code"], name=m["levlofit_name"],
                   note=m["disclosure"].strip() or None, tags=[t for t in m["tags"].split(";") if t],
                   kcal=None if kcal is None else round(kcal), kcal_estimated=estimated)
        rows.append(row)
    return rows, missing


def sql_value(x):
    if x is None:
        return "null"
    if isinstance(x, bool):
        return "true" if x else "false"
    if isinstance(x, (int, float)):
        return repr(round(x, 2))
    return "'" + str(x).replace("'", "''") + "'"


def to_sql(rows, missing):
    cols = ["code", "name", "food_group", "tags", "kcal", "protein_g", "fat_g", "carb_g", "fiber_g", "suggestible",
            "kcal_estimated", "source", "source_ref", *MICROS]
    lines = [
        "-- Generated by data/build_foods_fdc.py from USDA FoodData Central (CC0 1.0). Do not edit.",
        "-- Source: U.S. Department of Agriculture, Agricultural Research Service. FoodData Central. fdc.nal.usda.gov",
        f"-- Planner foods without a licensed record (left out, never filled): {', '.join(missing) or 'none'}",
        "alter table public.foods add column if not exists source_note text;",
        f"insert into public.foods ({', '.join(cols)}, source_note) values",
    ]
    vals = []
    for r in rows:
        tags = "array[" + ",".join(sql_value(t) for t in r["tags"]) + "]::text[]"
        vals.append("(" + ", ".join([sql_value(r["code"]), sql_value(r["name"]), "'USDA FoodData Central'", tags,
                                      sql_value(r["kcal"]), *(sql_value(r[k]) for k in MACROS), "true",
                                      sql_value(r["kcal_estimated"]), "'usda_fdc'", sql_value(r["fdc_id"]),
                                      *(sql_value(r[k]) for k in MICROS), sql_value(r["note"])]) + ")")
    fix = [
        "-- Earlier FDC-sourced rows (source usda_fdc, same FDC id) take the same values, so a food never has two answers.",
        "update public.foods f set kcal = n.kcal, protein_g = n.protein_g, fat_g = n.fat_g, carb_g = n.carb_g, fiber_g = n.fiber_g",
        "from public.foods n where n.source = 'usda_fdc' and f.source = 'usda_fdc' and f.source_ref = n.source_ref",
        "  and n.code = 'FDC' || n.source_ref and f.code <> n.code;",
    ]
    return "\n".join(lines) + "\n" + ",\n".join(vals) + ";\n" + "\n".join(fix) + "\n"


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    rows, missing = build(read_map(), *read_release(argv[1:]))
    OUT.write_text(to_sql(rows, missing), encoding="utf-8")
    print(f"{len(rows)} foods written to {OUT.name}; not covered: {', '.join(missing)}")


if __name__ == "__main__":
    main(sys.argv)

"""Run: python -I data/fdc/test_build_foods_fdc.py  (synthetic FDC rows only; no real data needed)"""
import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build_foods_fdc as b  # noqa: E402


def release(folder, foods, nutrients):
    with open(folder / "food.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["fdc_id", "data_type", "description"])
        w.writerows(foods)
    with open(folder / "food_nutrient.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "fdc_id", "nutrient_id", "amount"])
        w.writerows([(i, *n) for i, n in enumerate(nutrients)])


MAP = [
    {"planner_code": "B013", "levlofit_name": "Masoor dal", "tags": "", "fdc_description": "Lentils, pink or red, raw", "match": "exact", "disclosure": ""},
    {"planner_code": "B021", "levlofit_name": "Toor", "tags": "", "fdc_description": "Pigeon peas", "match": "close", "disclosure": "Whole, not split."},
    {"planner_code": "L003", "levlofit_name": "Paneer", "tags": "dairy", "fdc_description": "", "match": "none", "disclosure": "No record."},
]


class Build(unittest.TestCase):
    def run_build(self, foods, nutrients, mapping=MAP):
        with tempfile.TemporaryDirectory() as d:
            release(Path(d), foods, nutrients)
            return b.build(mapping, *b.read_release([d]))

    def test_values_provenance_and_exclusions(self):
        rows, missing = self.run_build(
            [(1, "sr_legacy_food", "Lentils, pink or red, raw"), (2, "foundation_food", "Pigeon peas"), (3, "branded_food", "Lentils, pink or red, raw")],
            [(1, 1008, 358), (1, 1003, 23.9), (1, 1004, 2.17), (1, 1005, 63.1), (1, 1089, 7.39),
             (2, 2047, 343), (2, 1003, 21.7), (2, 1004, 1.49), (2, 1005, 62.8)])
        self.assertEqual(missing, ["L003"], "a 'none' row is reported, never filled")
        lentil, toor = rows
        self.assertEqual((lentil["code"], lentil["kcal"], lentil["iron_mg"], lentil["fiber_g"], lentil["carb_g"]), ("FDC1", 358, 7.39, None, None),
                         "no fibre value: available carbohydrate unknown, not the by-difference total")
        self.assertIsNone(lentil["note"])
        self.assertEqual((toor["kcal"], toor["kcal_estimated"], toor["note"]), (343, False, "Whole, not split."))
        sql = b.to_sql(rows, missing)
        self.assertIn("'usda_fdc'", sql)
        self.assertIn("Planner foods without a licensed record (left out, never filled): L003", sql)
        self.assertNotIn("branded", sql, "branded records are never used")

    def test_carbohydrate_is_available_carbohydrate(self):
        rows, _ = self.run_build([(1, "sr_legacy_food", "Lentils, pink or red, raw"), (2, "sr_legacy_food", "Pigeon peas")],
                                 [(1, 1005, 63.1), (1, 1079, 10.8), (2, 1005, 3), (2, 1079, 5)])
        self.assertAlmostEqual(rows[0]["carb_g"], 52.3)
        self.assertEqual(rows[1]["carb_g"], 0.0, "never negative")

    def test_energy_is_estimated_only_from_complete_macros(self):
        rows, _ = self.run_build([(1, "sr_legacy_food", "Lentils, pink or red, raw"), (2, "sr_legacy_food", "Pigeon peas")],
                                 [(1, 1003, 10), (1, 1004, 1), (1, 1005, 20), (2, 1003, 10)])
        self.assertEqual((rows[0]["kcal"], rows[0]["kcal_estimated"]), (129, True))
        self.assertIsNone(rows[1]["kcal"], "no energy and incomplete macros: missing, not zero")

    def test_a_description_must_match_exactly_once(self):
        with self.assertRaises(SystemExit):
            self.run_build([(1, "sr_legacy_food", "Lentils, raw")], [])
        with self.assertRaises(SystemExit):
            self.run_build([(1, "sr_legacy_food", "Lentils, pink or red, raw"), (2, "sr_legacy_food", "Lentils, pink or red, raw"),
                            (3, "sr_legacy_food", "Pigeon peas")], [])

    def test_the_same_name_in_both_releases_takes_sr_legacy(self):
        rows, _ = self.run_build([(1, "foundation_food", "Lentils, pink or red, raw"), (2, "sr_legacy_food", "Lentils, pink or red, raw"),
                                  (3, "sr_legacy_food", "Pigeon peas")], [(2, 1008, 358)])
        self.assertEqual((rows[0]["code"], rows[0]["kcal"]), ("FDC2", 358))

    def test_the_real_map_is_well_formed(self):
        rows = b.read_map()
        self.assertEqual(len({r["planner_code"] for r in rows}), len(rows))
        for r in rows:
            if r["match"] == "close":
                self.assertTrue(r["disclosure"].strip(), r["planner_code"])
        sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
        planner = (Path(__file__).resolve().parents[2] / "app/lib/diet_plan.dart").read_text(encoding="utf-8")
        for r in rows:
            self.assertIn(f"'{r['planner_code']}': (", planner, f"{r['planner_code']} is a planner food")


if __name__ == "__main__":
    unittest.main()

"""Tests for the Handbook claims register. Run from the repo root: python data/evidence/test_extract_claims.py
Uses a local fixture handbook and temporary files; the real registers are only read, never written."""
import csv
import hashlib
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import extract_claims as ec  # noqa: E402

FIXTURE = HERE / "fixtures" / "fixture_handbook.py"


def by_id(rows):
    return {r["claim_id"]: r for r in rows}


class Extraction(unittest.TestCase):
    def setUp(self):
        self.m = ec.load_builder(FIXTURE)
        self.rows = by_id(ec.extract(self.m))

    def test_every_statement_becomes_one_unit_with_a_stable_location(self):
        self.assertEqual(sorted(self.rows), sorted([
            "alpha:b00:text",
            "alpha:b01:items[0]", "alpha:b01:items[1]",
            "alpha:b02:title", "alpha:b02:items[0]",
            "alpha:b03:head", "alpha:b03:rows[0]", "alpha:b03:rows[1]",
            "alpha:b04:do.title", "alpha:b04:do.items[0]", "alpha:b04:dont.title", "alpha:b04:dont.items[0]",
            "alpha:b05:text",
        ]))
        self.assertEqual(ec.extract(self.m), ec.extract(self.m), "deterministic")

    def test_table_rows_carry_their_column_names_and_bars_carry_the_unit(self):
        self.assertEqual(self.rows["alpha:b03:rows[1]"]["text"], "Food: Dal; Protein: 24 g")
        self.assertEqual(self.rows["alpha:b02:items[0]"]["text"], "Walk · 150 [min]")

    def test_item_source_wins_and_block_source_applies_to_its_items(self):
        self.assertEqual(self.rows["alpha:b01:items[0]"]["direct_sources"], "srcA")
        self.assertEqual(self.rows["alpha:b01:items[1]"]["direct_sources"], "")
        self.assertEqual(self.rows["alpha:b03:rows[0]"]["direct_sources"], "srcB")
        self.assertEqual(self.rows["alpha:b00:text"]["chapter_sources"], "srcA", "chapter list is context, not a citation")

    def test_flags(self):
        self.assertIn("uncited_number", self.rows["alpha:b01:items[1]"]["flags"])
        self.assertIn("no_direct_source", self.rows["alpha:b00:text"]["flags"])
        self.assertIn("clinical_review", self.rows["alpha:b00:text"]["flags"])  # "doctor"
        self.assertIn("clinical_review", self.rows["alpha:b04:dont.items[0]"]["flags"])  # "chest pain"
        self.assertIn("source_not_listed_by_chapter", self.rows["alpha:b03:rows[0]"]["flags"])
        self.assertIn("source_key_unknown", self.rows["alpha:b05:text"]["flags"])
        self.assertIn("clinical_review", self.rows["alpha:b05:text"]["flags"])  # "creatine"
        self.assertEqual(self.rows["alpha:b01:items[0]"]["flags"], "")

    def test_kinds_and_numbers(self):
        self.assertEqual(self.rows["alpha:b01:items[0]"]["auto_kind"], "numeric")
        self.assertEqual(self.rows["alpha:b01:items[0]"]["numbers"], "150")
        self.assertEqual(self.rows["alpha:b04:do.title"]["auto_kind"], "label")
        self.assertEqual(self.rows["alpha:b00:text"]["auto_kind"], "statement")


class SyncAndCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.builder = self.tmp / "builder.py"
        shutil.copy(FIXTURE, self.builder)
        self.claims, self.sources = self.tmp / "claims.csv", self.tmp / "sources.csv"
        self.passages = self.tmp / "passages.json"
        self.args = ["--builder", str(self.builder), "--claims", str(self.claims), "--sources", str(self.sources), "--passages", str(self.passages)]

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_cli(self, *extra):
        return ec.main([*extra, *self.args])

    def read(self, path):
        with path.open(encoding="utf-8", newline="") as f:
            return list(csv.DictReader(f))

    def write(self, path, rows):
        with path.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), lineterminator="\n")
            w.writeheader()
            w.writerows(rows)

    def edit(self, claim_id, **fields):
        rows = self.read(self.claims)
        for r in rows:
            if r["claim_id"] == claim_id:
                r.update(fields)
        self.write(self.claims, rows)

    def errors(self, strict=False):
        m = ec.load_builder(self.builder)
        return ec.check(m, self.read(self.claims), self.read(self.sources), strict=strict)[0]

    def test_first_sync_gives_unreviewed_claims_and_auto_labels_and_passes_the_check(self):
        self.assertEqual(self.run_cli("--sync"), 0)
        rows = by_id(self.read(self.claims))
        self.assertEqual(rows["alpha:b00:text"]["evidence_status"], "unreviewed")
        self.assertEqual(rows["alpha:b04:do.title"]["evidence_status"], "auto_label")
        self.assertEqual(self.errors(), [])
        self.assertEqual(self.run_cli("--check"), 0)
        self.assertEqual(self.run_cli("--check", "--strict"), 1, "strict fails while claims are unreviewed")
        src = by_id([{**r, "claim_id": r["key"]} for r in self.read(self.sources)])
        self.assertEqual(set(src), {"srcA", "srcB", "srcUnused"})
        self.assertEqual(src["srcA"]["licence"], "unknown")
        self.assertEqual(src["srcA"]["verification_status"], "unchecked")
        self.assertEqual(src["srcUnused"]["claims_citing"], "0")

    def test_review_work_survives_a_resync(self):
        self.run_cli("--sync")
        self.edit("alpha:b01:items[0]", evidence_status="verified", passage_source="srcA", supporting_passage="Adults should do 150 minutes.",
                  passage_locator="p. 3", reviewed_by="tester", reviewed_on="2026-10-13")
        self.run_cli("--sync")
        r = by_id(self.read(self.claims))["alpha:b01:items[0]"]
        self.assertEqual((r["evidence_status"], r["supporting_passage"], r["passage_locator"]), ("verified", "Adults should do 150 minutes.", "p. 3"))
        self.assertEqual(self.errors(), [])

    def test_changed_text_after_review_becomes_stale_and_keeps_the_old_text_in_notes(self):
        self.run_cli("--sync")
        self.edit("alpha:b00:text", evidence_status="unsupported", reviewed_on="2026-10-13", reviewed_by="tester")
        self.builder.write_text(self.builder.read_text(encoding="utf-8").replace("start walking today", "start running today"), encoding="utf-8")
        self.assertEqual(self.run_cli("--check"), 1, "check catches the edit before a resync")
        self.run_cli("--sync")
        r = by_id(self.read(self.claims))["alpha:b00:text"]
        self.assertEqual(r["evidence_status"], "stale")
        self.assertIn("start walking today", r["notes"])
        self.assertEqual(self.errors(), [])
        self.assertTrue(self.errors(strict=True), "stale counts as not reviewed under --strict")

    def test_new_and_removed_handbook_text_is_caught(self):
        self.run_cli("--sync")
        text = self.builder.read_text(encoding="utf-8")
        self.builder.write_text(text.replace('{"t": "lead", "text": "Most people can start walking today without seeing a doctor."},',
                                             '{"t": "lead", "text": "A brand new claim of 3 sets."},\n            {"t": "rule", "text": "Another new line here please."},'), encoding="utf-8")
        errs = self.errors()
        self.assertTrue(any("not in the register" in e for e in errs), errs)
        self.assertTrue(any("no longer in the Handbook" in e for e in errs), errs)

    def test_a_supported_claim_needs_a_quoted_passage_its_location_source_and_date(self):
        self.run_cli("--sync")
        self.edit("alpha:b01:items[0]", evidence_status="verified")
        errs = self.errors()
        for col in ("supporting_passage", "passage_locator", "passage_source", "reviewed_on"):
            self.assertTrue(any(f"without {col}" in e for e in errs), col)
        self.edit("alpha:b01:items[0]", supporting_passage="x", passage_locator="p. 1", passage_source="nope", reviewed_on="2026-10-13")
        self.assertTrue(any("not a listed source" in e for e in self.errors()))

    def test_a_clinical_claim_cannot_be_verified_without_clinical_sign_off(self):
        self.run_cli("--sync")
        done = dict(supporting_passage="x", passage_locator="p. 1", passage_source="srcA", reviewed_on="2026-10-13")
        self.edit("alpha:b00:text", evidence_status="verified", **done)
        self.assertTrue(any("clinical_done" in e for e in self.errors()))
        self.edit("alpha:b00:text", review_needs="clinical_done")
        self.assertEqual(self.errors(), [])

    def test_unknown_status_duplicate_rows_and_missing_sources_fail(self):
        self.run_cli("--sync")
        self.edit("alpha:b00:text", evidence_status="probably_fine")
        self.assertTrue(any("unknown evidence_status" in e for e in self.errors()))
        rows = self.read(self.claims)
        self.write(self.claims, rows + [rows[1]])
        self.assertTrue(any("duplicate row" in e for e in self.errors()))
        self.run_cli("--sync")
        self.write(self.sources, [r for r in self.read(self.sources) if r["key"] != "srcB"])
        self.assertTrue(any("source srcB: missing" in e for e in self.errors()))

    def load_passages(self):
        import json
        return json.loads(self.passages.read_text(encoding="utf-8"))

    def test_sync_writes_one_passage_per_block_with_its_sources_and_evidence_summary(self):
        self.run_cli("--sync")
        data = self.load_passages()
        by = {p["id"]: p for p in data["passages"]}
        self.assertEqual(list(by), [f"alpha:b{i:02d}" for i in range(6)])
        self.assertEqual(by["alpha:b01"]["sources"], ["srcA"], "item sources become the passage's citations")
        self.assertEqual(by["alpha:b00"]["sources"], [], "no direct citation, even though the chapter lists srcA")
        self.assertEqual(by["alpha:b00"]["chapterSources"], ["srcA"])
        self.assertEqual(by["alpha:b03"]["text"], "Food | Protein. Food: Paneer; Protein: 18 g. Food: Dal; Protein: 24 g")
        self.assertTrue(by["alpha:b00"]["clinicalReview"])
        self.assertEqual({p["evidence"] for p in data["passages"]}, {"unreviewed"})
        self.assertEqual(set(data["sources"]), {"srcA", "srcB"}, "only cited sources, with their full citations")
        self.assertNotIn("srcGhost", data["sources"], "an unknown key is never given a made-up citation")
        self.assertEqual((by["alpha:b05"]["sources"], by["alpha:b05"]["unknownSources"]), ([], ["srcGhost"]))

    def test_evidence_summary_follows_the_register(self):
        self.run_cli("--sync")
        done = dict(passage_source="srcA", supporting_passage="x", passage_locator="p. 1", reviewed_on="2026-10-13")
        self.edit("alpha:b01:items[0]", evidence_status="verified", **done)
        self.assertEqual(self.run_cli("--check"), 1, "the passages file is now stale")
        self.run_cli("--sync")
        self.assertEqual({p["id"]: p["evidence"] for p in self.load_passages()["passages"]}["alpha:b01"], "partly_checked")
        self.edit("alpha:b01:items[1]", evidence_status="verified", **done)
        self.run_cli("--sync")
        self.assertEqual({p["id"]: p["evidence"] for p in self.load_passages()["passages"]}["alpha:b01"], "checked")
        self.edit("alpha:b02:items[0]", evidence_status="unsupported", reviewed_on="2026-10-13")
        self.run_cli("--sync")
        self.assertEqual({p["id"]: p["evidence"] for p in self.load_passages()["passages"]}["alpha:b02"], "disputed")
        self.assertEqual(self.run_cli("--check"), 0)

    def test_any_quoted_passage_needs_its_location_source_and_date(self):
        self.run_cli("--sync")
        self.edit("alpha:b00:text", evidence_status="needs_clinical_review", supporting_passage="Most adults can start.")
        errs = self.errors()
        for col in ("passage_locator", "passage_source", "reviewed_on"):
            self.assertTrue(any(f"quoted passage without {col}" in e for e in errs), col)
        self.edit("alpha:b00:text", passage_locator="p. 2", passage_source="srcA", reviewed_on="2026-10-13")
        self.assertEqual(self.errors(), [])

    def test_a_source_checked_claim_awaiting_clinical_review_makes_its_block_partly_checked_not_checked(self):
        self.run_cli("--sync")
        self.edit("alpha:b00:text", evidence_status="needs_clinical_review")
        self.run_cli("--sync")
        self.assertEqual({p["id"]: p["evidence"] for p in self.load_passages()["passages"]}["alpha:b00"], "unreviewed",
                         "without a quoted passage it is still unreviewed")
        self.edit("alpha:b00:text", supporting_passage="Most adults can start.", passage_locator="p. 2", passage_source="srcA", reviewed_on="2026-10-13")
        self.run_cli("--sync")
        p = {p["id"]: p for p in self.load_passages()["passages"]}["alpha:b00"]
        self.assertEqual(p["evidence"], "partly_checked")
        self.assertTrue(p["clinicalReview"])

    def test_editorial_and_unsourced_blocks_get_their_own_evidence_label(self):
        self.run_cli("--sync")
        for cid in ("alpha:b04:do.items[0]", "alpha:b04:dont.items[0]"):
            self.edit(cid, evidence_status="editorial", reviewed_on="2026-10-13")
        self.run_cli("--sync")
        self.assertEqual({p["id"]: p["evidence"] for p in self.load_passages()["passages"]}["alpha:b04"], "editorial")
        self.edit("alpha:b00:text", evidence_status="needs_source", reviewed_on="2026-10-13")
        self.run_cli("--sync")
        self.assertEqual({p["id"]: p["evidence"] for p in self.load_passages()["passages"]}["alpha:b00"], "unsourced")
        self.assertEqual(self.errors(), [])

    def test_a_clinical_passage_stays_flagged_until_clinical_sign_off(self):
        self.run_cli("--sync")
        self.edit("alpha:b00:text", review_needs="clinical_done")
        self.run_cli("--sync")
        self.assertFalse({p["id"]: p for p in self.load_passages()["passages"]}["alpha:b00"]["clinicalReview"])


class RealHandbook(unittest.TestCase):
    """The committed registers must match the Handbook as it is now. Read-only."""

    def test_registers_are_in_sync_and_valid(self):
        m = ec.load_builder()
        claims = list(csv.DictReader(ec.CLAIMS_CSV.open(encoding="utf-8", newline="")))
        sources = list(csv.DictReader(ec.SOURCES_CSV.open(encoding="utf-8", newline="")))
        errors, summary = ec.check(m, claims, sources)
        self.assertEqual(errors, [])
        self.assertEqual(summary["total"]["units"], len(ec.extract(m)))
        self.assertEqual(len(sources), len(m.SRC))

    def test_loading_the_builder_writes_nothing(self):
        mig = ec.BUILDER.parent.parent / "supabase" / "migrations" / "20261007400000_handbook_v3.sql"
        before = hashlib.sha256(mig.read_bytes()).hexdigest()
        ec.load_builder()
        self.assertEqual(hashlib.sha256(mig.read_bytes()).hexdigest(), before)

    def test_corrections_from_the_2026_10_13_audit_stay_corrected(self):
        """Wording the source audit found unsupported (see claims_register notes). Re-adding it needs new evidence first."""
        text = ec.BUILDER.read_text(encoding="utf-8")
        for removed in ("doses up to 30 g a day in healthy people", "at any fitness level", "with no extra benefit",
                        "the top of the ISSN range\"", '"Inactive adult, Indian RDA"', '["Yoga", "Yes, among the best"]',
                        '["Strength training", "Yes, among the best"]'):
            self.assertNotIn(removed, text, removed)
        claims = {r["claim_id"]: r for r in csv.DictReader(ec.CLAIMS_CSV.open(encoding="utf-8", newline=""))}
        for cid in ("how-training-works:b04:items[1]", "food-basics:b02:items[0]", "fat-loss:b02:items[1]"):
            self.assertEqual(claims[cid]["evidence_status"], "verified", cid)
        self.assertIn("text changed after review", claims["supplements:b04:text"]["notes"], "the old wording is kept in the notes")
        # ICMR plate: milk or curd 300 ml is part of My Plate, and only 30 g of the 85 g pulses can be swapped.
        self.assertNotIn('"Pulses, eggs or meat"', text)
        # Batch F corrections (sources: ACSM 2026, Bell 2023, Singer 2024, Kerksick 2017, Aragon 2017 bodies).
        for removed in ("the biggest gains come from going from no resistance training", '"Each muscle 2 times a week"',
                        '("40 to 50", "% less volume"', "It is not a week off.", '"gives a small edge for muscle growth"',
                        "it matters more for long or twice-daily sessions", "not a fixed calendar",
                        '], source="aragon2017"),'):
            self.assertNotIn(removed, text, removed)
        self.assertIn('("Milk or curd", 300, "300 ml")', text)
        for cid in ("food-basics:b01:title", "food-basics:b01:items[3]", "food-basics:b01:items[6]"):
            self.assertEqual(claims[cid]["evidence_status"], "verified", cid)
        # Batch 6 (ICMR DGI 2024): reused frying oil is not itself a trans-fat source in the guideline's wording.
        self.assertNotIn("Vanaspati and reused frying oil (trans fats)", text)
        # Batch 7: uncited numbers kept only as labelled Levlofit rules; an overstatement removed.
        self.assertNotIn("single-arm moves double the load", text)
        for cid in ("calories:b06:items[0]", "busy-weeks:b02:items[1]", "over-40:b03:items[3]"):
            self.assertEqual(claims[cid]["evidence_status"], "editorial", cid)
            self.assertIn("Levlofit rule", claims[cid]["text"], cid)
        # Batch 7: claims backed only by ACSM 2026 need that source listed for their chapter.
        for slug in ("get-stronger", "physique", "home-training", "build-muscle"):
            i = text.index(f'"slug": "{slug}"')
            self.assertIn('"acsm2026"', text[text.index('"sources": [', i):text.index(']', text.index('"sources": [', i))], slug)

    def test_every_ifct_table_row_is_checked_against_the_ifct_data(self):
        """Each IFCT-cited row records the IFCT food code and values it was checked against."""
        rows = [r for r in csv.DictReader(ec.CLAIMS_CSV.open(encoding="utf-8", newline=""))
                if "ifct2017" in r["direct_sources"].split() and ":rows[" in r["claim_id"]]
        self.assertGreaterEqual(len(rows), 20)
        for r in rows:
            self.assertEqual(r["evidence_status"], "verified", r["claim_id"])
            self.assertRegex(r["supporting_passage"], r"^IFCT 2017 [A-Z]\d{3} '", r["claim_id"])
            self.assertIn("official_table_spot_check", r["review_needs"], "digitised data, so a spot check stays open")

    def test_the_retrieval_passages_file_is_in_sync(self):
        m = ec.load_builder()
        claims = list(csv.DictReader(ec.CLAIMS_CSV.open(encoding="utf-8", newline="")))
        self.assertEqual(ec.check_passages(m, claims, ec.PASSAGES_JSON), [])

    def test_every_supported_claim_quotes_a_passage(self):
        for r in csv.DictReader(ec.CLAIMS_CSV.open(encoding="utf-8", newline="")):
            if r["evidence_status"] in ec.SUPPORTED:
                self.assertTrue(r["supporting_passage"] and r["passage_locator"] and r["passage_source"], r["claim_id"])


if __name__ == "__main__":
    unittest.main()

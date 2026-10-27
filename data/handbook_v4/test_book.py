"""Tests for the Handbook v4 draft (one book). Run: python -I data/handbook_v4/test_book.py
They also prove the production candidate (v3 builder and migration) is untouched by the draft build."""
import csv
import hashlib
import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROD = [ROOT / "data" / "build_handbook.py", ROOT / "supabase" / "migrations" / "20261007400000_handbook_v3.sql",
        ROOT / "data" / "evidence" / "handbook-passages.json", ROOT / "data" / "evidence" / "claims_register.csv"]
PASSAGES = ROOT / "supabase" / "functions" / "_shared" / "handbook-passages.json"   # v4 passages ship with coach-chat


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def digest(paths):
    return [hashlib.sha256(p.read_bytes()).hexdigest() for p in paths]


class Book(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = digest(PROD)
        cls.out = subprocess.run([sys.executable, "-I", str(HERE / "build_handbook_v4.py")], capture_output=True, text=True)
        cls.v4 = load(HERE / "build_handbook_v4.py", "v4")
        cls.v3 = load(ROOT / "data" / "build_handbook.py", "v3")
        cls.slugs = [c["slug"] for c in cls.v4.CHAPTERS]

    def test_draft_builds_and_production_files_are_untouched(self):
        self.assertEqual(self.out.returncode, 0, self.out.stderr)
        self.assertEqual(digest(PROD), self.before, "the draft build changed a production file")
        self.assertTrue((HERE / "handbook_v4_draft.sql").read_text(encoding="utf-8").startswith("-- DRAFT FOR REVIEW, NOT A MIGRATION"))

    def test_every_v3_slug_is_kept_and_new_chapters_exist(self):
        self.assertTrue({c["slug"] for c in self.v3.CHAPTERS} <= set(self.slugs))
        for s in ("welcome", "cardio-intensity", "technique", "under-eating", "putting-it-together"):
            self.assertIn(s, self.slugs)
        self.assertEqual(self.slugs[0], "welcome")
        self.assertEqual(self.slugs[-1], "putting-it-together")
        self.assertLess(self.slugs.index("how-levlofit-works"), 5, "the planning explanation comes near the start")

    def test_parts_open_and_chapters_end_properly(self):
        parts = [c["part"] for c in self.v4.CHAPTERS]
        self.assertEqual(parts, sorted(parts), "parts run A to E in order")
        for c in self.v4.CHAPTERS:
            self.assertEqual([b["t"] for b in c["blocks"][-2:]], ["keypoints", "next"], c["slug"])
            for i in c["blocks"][-1]["items"]:
                self.assertIn(i["ref"], self.slugs, c["slug"])
        openers = [c["slug"] for c in self.v4.CHAPTERS if c["blocks"][0]["t"] == "part"]
        self.assertEqual(len(openers), 5)

    def test_concepts_are_taught_before_they_are_used(self):
        def first(word):
            return next(i for i, c in enumerate(self.v4.CHAPTERS) if word in " ".join(self.v4.plain(b) for b in c["blocks"]).lower())
        idx = self.slugs.index
        self.assertLess(idx("effort-and-rir"), idx("sets-reps-progress"))
        self.assertLess(idx("sets-reps-progress"), idx("rest-between-sets"))
        self.assertLess(idx("sets-reps-progress"), idx("plateaus-deloads"))
        self.assertLess(idx("calories"), idx("fat-loss"))
        self.assertLess(idx("food-basics"), idx("supplements"))
        self.assertLess(idx("cardio-intensity"), idx("general-fitness"))
        self.assertEqual(first("deload"), idx("welcome"), "deload is defined in the welcome glossary before any use")

    def test_one_word_for_a_training_appointment(self):
        text = " ".join(self.v4.plain(b) for c in self.v4.CHAPTERS for b in c["blocks"] if c["slug"] != "hyrox").lower()
        self.assertNotIn("workout ", text.replace("workout the app tab", ""), "use 'session'; 'workout' only in HYROX's official wording")

    def test_register_gates_are_explicit(self):
        rows = list(csv.DictReader((HERE / "claims_register.csv").open(encoding="utf-8")))
        by = {}
        for r in rows:
            by.setdefault(r["chapter"], []).append(r)
        # Eating too little: every statement needs clinical review; none is silently resolved.
        for r in by["under-eating"]:
            if r["evidence_status"] not in ("auto_label", "editorial"):
                self.assertIn("clinical", r["review_needs"], r["claim_id"])
                self.assertNotEqual(r["evidence_status"], "verified", r["claim_id"])
        # Heat warning signs are gated too.
        heat = [r for r in by["water"] if r["evidence_status"] != "auto_label" and ("cool down" in r["text"] or "Dizziness" in r["text"] or "medical help" in r["text"])]
        self.assertTrue(heat and all("clinical" in r["review_needs"] for r in heat))
        # Changed text never inherits an old review.
        moved = [r for r in rows if "hotel room session" in r["text"]]
        self.assertTrue(moved and all(r["evidence_status"] in ("unreviewed", "auto_label") for r in moved))
        # Key points are left for a reviewer to confirm.
        kp = [r for r in rows if r["block_type"] == "keypoints" and r["field"].startswith("items")]
        self.assertTrue(kp and all(r["evidence_status"] == "unreviewed" for r in kp))

    def test_no_v3_review_gate_is_lost(self):
        v3 = [r for r in csv.DictReader((ROOT / "data" / "evidence" / "claims_register.csv").open(encoding="utf-8")) if r["evidence_status"] != "auto_label"]
        v4 = [r for r in csv.DictReader((HERE / "claims_register.csv").open(encoding="utf-8")) if r["evidence_status"] != "auto_label"]
        for gate in ("clinical", "source_access", "content_decision", "source_needed"):
            self.assertGreaterEqual(sum(gate in r["review_needs"] for r in v4), sum(gate in r["review_needs"] for r in v3), gate)
        # Every v3 gate survives on the same claim, also when v4 only changed its wording ("workout" -> "session").
        def key(r):  # chapter-independent: some blocks moved chapter (daily water: habits -> water)
            return r["text"].lower().replace("workout", "session")
        v4k = {}
        for r in v4:
            text = r["text"]
            for slug, old, new in self.v4.REWORDS:   # recorded v4 rewordings map back to their v3 text
                if slug == r["chapter"] and new in text:
                    text = text.replace(new, old)
            v4k.setdefault(key({"text": text}), []).append(r)
        removed = {(slug, text) for slug, text, _ in self.v4.REMOVED}   # removed by a recorded decision (DECISIONS.md)
        for r in v3:
            if (r["chapter"], r["text"]) in removed:
                continue
            for gate in ("clinical", "source_access", "content_decision", "source_needed"):
                if gate in r["review_needs"]:
                    self.assertTrue(any(gate in x["review_needs"] for x in v4k[key(r)]), f"{gate} lost on {r['claim_id']}")
        # Changed text is never reviewed by inheritance.
        v3sha = {r["text_sha"] for r in v3}
        for r in v4:
            if r["notes"].startswith("Carried from v3"):
                self.assertIn(r["text_sha"], v3sha, r["claim_id"])
        v3_unreviewed = {r["text_sha"] for r in v3 if r["evidence_status"] == "unreviewed"}
        self.assertFalse([r["claim_id"] for r in v4 if r["text_sha"] in v3_unreviewed and r["evidence_status"] != "unreviewed"],
                         "a claim unreviewed in v3 must stay unreviewed in v4")

    def test_retrieval_passages_hold_no_navigation(self):
        import json
        ps = json.loads(PASSAGES.read_text(encoding="utf-8"))["passages"]
        self.assertFalse([p["id"] for p in ps if p["blockType"] in ("next", "part")])

    def test_open_decisions_flag_dependent_text(self):
        rows = list(csv.DictReader((HERE / "claims_register.csv").open(encoding="utf-8")))
        for r in rows:
            if r["chapter"] == "under-eating" and "BMI" in r["text"]:
                self.assertIn("content_decision", r["review_needs"], r["claim_id"])
            if "630" in r["text"] and r["evidence_status"] != "auto_label":
                self.assertIn("content_decision", r["review_needs"], r["claim_id"])

    def test_review_package_matches_the_register(self):
        p = subprocess.run([sys.executable, "-I", str(HERE / "review_package.py")], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        pkg = load(HERE / "review_package.py", "pkg")
        open_ids = [r["claim_id"] for r in pkg.CLAIMS if pkg.is_open(r)]
        with (ROOT / "docs" / "handbook_v4_review" / "review_items.csv").open(encoding="utf-8-sig") as fh:
            sheet = list(csv.DictReader(fh))
        self.assertEqual(sorted(x["claim_id"] for x in sheet), sorted(open_ids), "worksheet = open claims, once each")
        reg = {r["claim_id"]: r for r in pkg.CLAIMS}
        for x in sheet:
            self.assertEqual(x["status"], reg[x["claim_id"]]["evidence_status"], x["claim_id"])
            self.assertEqual(x["wording"], reg[x["claim_id"]]["text"], x["claim_id"])
            self.assertFalse(x["reviewer_decision"] or x["reviewer"], "no reviewer decision may be pre-filled")
        # Each section file holds exactly its items; flags are preserved per item.
        for key, fname, _ in pkg.SECTIONS:
            text = (ROOT / "docs" / "handbook_v4_review" / fname).read_text(encoding="utf-8")
            ids = [x["claim_id"] for x in sheet if x["primary"] == key]
            self.assertEqual(text.count("\n#### `"), len(ids), fname)
            for i in ids:
                self.assertIn(f"#### `{i}`", text)
        for gate in ("clinical", "source_access", "source_needed", "content_decision"):
            in_register = sum(gate in pkg.flags(r) for r in pkg.CLAIMS if pkg.is_open(r))
            in_sheet = sum(gate in x["flags"].split("; ") for x in sheet)
            self.assertEqual(in_sheet, in_register, gate)
        overview = (ROOT / "docs" / "HANDBOOK_V4_REVIEW.md").read_text(encoding="utf-8")
        self.assertIn(f"Open for review: {len(open_ids)}.", overview)
        self.assertNotIn("approved", overview.replace("clinically approved", "").replace("Nothing in this package is", ""))

    def test_decisions_2_and_5_follow_v3(self):
        # Decisions 2 (running vs strength) and 5 (rest) were later settled in data/build_handbook.py itself, from the
        # Wilson 2012 and Grgic 2018 abstracts (2026-10-23, live in production as v3). The book keeps that wording.
        v4 = {c["slug"]: c for c in self.v4.CHAPTERS}
        v3 = {c["slug"]: c for c in self.v4.v3.CHAPTERS}
        for slug in ("one-step-at-a-time", "rest-between-sets"):
            ev3 = [b["text"] for b in v3[slug]["blocks"] if b["t"] == "evidence"]
            ev4 = [b["text"] for b in v4[slug]["blocks"] if b["t"] == "evidence"]
            self.assertEqual(ev4, ev3, slug)
        self.assertTrue(self.v4.SUPERSEDED_REST)
        self.assertEqual({s for s, _ in self.v4.SUPERSEDED}, {"one-step-at-a-time", "hyrox"})

    def test_decision3_vegetarian_wording_is_cautious_and_open(self):
        text = " ".join(self.v4.plain(b) for c in self.v4.CHAPTERS if c["slug"] == "veg-protein" for b in c["blocks"])
        self.assertNotIn("You can build muscle on a vegetarian or vegan diet", text)
        self.assertIn("Direct evidence in vegan diets is limited", text)
        rows = {r["claim_id"]: r for r in csv.DictReader((HERE / "claims_register.csv").open(encoding="utf-8"))}
        lead = rows["veg-protein:b00:text"]
        self.assertEqual(lead["evidence_status"], "unreviewed")
        self.assertIn("content_decision", lead["review_needs"])
        staple = next(r for r in rows.values() if r["chapter"] == "veg-protein" and "upper end of your protein range" in r["text"])
        self.assertIn("Levlofit rule, not a research finding", staple["text"])
        self.assertIn("source_needed", staple["review_needs"])
        self.assertNotIn(staple["evidence_status"], ("verified", "editorial"))

    def test_decision4_caffeine_warning_and_caution(self):
        sup = next(c for c in self.v4.CHAPTERS if c["slug"] == "supplements")
        text = " ".join(self.v4.plain(b) for b in sup["blocks"])
        bars = next(b for b in sup["blocks"] if b["t"] == "bars" and b["title"] == "Caffeine for a 70 kg person")
        self.assertNotIn(630, [i["value"] for i in bars["items"]], "the chart cannot mark a warning bar")
        # Owner decision 2026-10-18: no 630 mg / 9 mg per kg example until a source and clinical justification exist.
        self.assertNotRegex(text, r"\b630\b|\b9 mg ?(per|/) ?kg", "the higher-dose example is removed")
        self.assertIn("Caffeine caution", text)
        self.assertNotRegex(text, r"\b(400|300|200) ?mg (a|per) day", "no daily limit until a source is read")
        rows = [r for r in csv.DictReader((HERE / "claims_register.csv").open(encoding="utf-8")) if r["chapter"] == "supplements"]
        for r in rows:
            if "Decision 4" in r["notes"]:
                self.assertIn("clinical", r["review_needs"], r["claim_id"])
                self.assertIn("content_decision", r["review_needs"], r["claim_id"])
                self.assertNotIn(r["evidence_status"], ("verified", "editorial"), r["claim_id"])
        self.assertTrue(any("Count your whole day" in r["text"] and "source_needed" in r["review_needs"] for r in rows))

    def test_no_review_is_attached_to_the_wrong_text(self):
        # Claim ids follow block positions; inserting a block can hand an id to different text. No stale row may remain,
        # and each structural note must sit on its own kind of block.
        for r in csv.DictReader((HERE / "claims_register.csv").open(encoding="utf-8")):
            self.assertNotEqual(r["evidence_status"], "stale", r["claim_id"])
            if r["notes"].startswith("Key point restating"):
                self.assertEqual(r["block_type"], "keypoints", r["claim_id"])
            if r["notes"].startswith("Navigation or part-opener"):
                self.assertIn(r["block_type"], ("next", "part"), r["claim_id"])

    def test_register_passes_its_check(self):
        p = subprocess.run([sys.executable, "-I", str(ROOT / "data" / "evidence" / "extract_claims.py"), "--check",
                            "--builder", str(HERE / "build_handbook_v4.py"), "--claims", str(HERE / "claims_register.csv"),
                            "--sources", str(HERE / "sources_register.csv"), "--passages", str(PASSAGES)],
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout[-800:] + p.stderr[-800:])


if __name__ == "__main__":
    unittest.main()

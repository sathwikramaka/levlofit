# Proposed correction: production v3 evidence register (NOT APPLIED)

Status: proposal for a separately reviewed evidence-register update. `data/evidence/claims_register.csv` and the v3
migration are unchanged. Found 2026-10-14 during Decision 2 (docs/handbook_v4_review/DECISIONS.md).

## What is wrong

Three notes say ACSM 2026 "lists concurrent training among variables that did not affect strength". The ACSM 2026 article
body (PMC12965823) says instead: "There were insufficient data to determine if strength was affected by ... or concurrent
training (i.e., aerobic and RT in the same training session)", and likewise insufficient data for muscle hypertrophy and
power. ACSM 2026 does not report "no effect".

## Effect of the change

- Notes column only. Claim text, `evidence_status` (all three stay `unreviewed`), `review_needs`
  (`source_access; content_decision`), passages and sources are unchanged. No handbook text, migration or passages file
  changes: the register notes are not shipped to the app (the passages file carries statuses and evidence labels, not notes).
- `python -I data/evidence/extract_claims.py --check` and the register tests are expected to pass unchanged.

## Exact replacement (same in all three rows)

- Replace: "Possible conflict: ACSM 2026 (article body) lists concurrent training among variables that did not affect strength; the cited Wilson 2012 meta-analysis could not be read."
- With: "No read source decides this: ACSM 2026 (article body) reports insufficient data to determine whether aerobic and resistance training in the same session affects strength, muscle growth or power (it does not report 'no effect'); the cited Wilson 2012 meta-analysis could not be read."

## Rows

| claim_id | claim text | evidence_status | review_needs | note today |
|---|---|---|---|---|
| `one-step-at-a-time:b04:items[0]` | More · interference · on strength and size from frequent, long running sessions | unreviewed | source_access; content_decision | Possible conflict: ACSM 2026 (article body) lists concurrent training among variables that did not affect strength; the cited Wilson 2012 meta-analysis could not be read. A reviewer should read Wilson 2012 and decide the wording. |
| `one-step-at-a-time:b05:text` | Combining endurance and strength training costs some strength, size and especially power gains, and the cost grows with how often and how long the endurance sessions are. | unreviewed | source_access; content_decision | Possible conflict: ACSM 2026 (article body) lists concurrent training among variables that did not affect strength; the cited Wilson 2012 meta-analysis could not be read. A reviewer should read Wilson 2012 and decide the wording. |
| `hyrox:b04:text` | Running and lifting in one plan works; keeping hard runs and leg sessions apart limits interference with strength. | unreviewed | source_access; content_decision | Possible conflict: ACSM 2026 (article body) lists concurrent training among variables that did not affect strength; the cited Wilson 2012 meta-analysis could not be read. A reviewer should read Wilson 2012 and decide the wording. |

## How to apply after approval

1. Back up `data/evidence/claims_register.csv`.
2. In the three rows above, replace the note text exactly as shown (no other column).
3. Run `bash tools/verify.sh handbook` (register tests, `--check`, migration identical) and record the result in docs/PROGRESS.md.

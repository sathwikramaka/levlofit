# Coach implementation plan (2026-10-22, batch 2T)

Goal: a reliable, personal fitness coach at zero running cost. Open-source first; every change reuses the existing
coach-chat handler, coach-context.ts, the eval harness (supabase/functions/_eval) and the local throwaway-stack tests.
Provider stays unchanged (none approved for production). Gemini deferred: free-tier limits unconfirmed and its free
tier may use content for product improvement.

Ranked by effect on "reliable and personal", then by size. Each batch ends with node tests, offline eval, Deno smoke
and, for schema changes, pgTAP on a throwaway local stack.

| # | Batch | What | Reuses | Done when |
|---|---|---|---|---|
| 1 | **Confirmed, editable memory** (done 2026-10-22, batch 2U; phone check PASS 2026-10-23) | Replace free-text `coach_notes` with `coach_facts` rows (kind: injury, schedule, equipment, preference, goal, other; text; source message id; created/confirmed). The model proposes facts in `<note>`; the app shows "Remember this?" and stores only confirmed ones; list, edit, delete per item. Context block lists confirmed facts. Migration copies existing notes as unconfirmed. RLS: owner only; delete-account removes them. | mergeNotes parsing, NOTES block, "What Levlofit AI remembers" screen, delete-account, RLS test pattern | pgTAP RLS + migration; eval memory-notes, memory-knee pass with facts; widget test for confirm/edit/delete |
| 2 | **Conversation summaries** (done 2026-10-23, batch 2W; not applied to dev or production, no live-model or phone check) | When a thread passes 12 messages, store a rolling `summary` on `coach_threads` (made by the same model call path, max ~800 chars, no private block echo), sent as an EARLIER IN THIS CHAT line before the 12 recent messages. | HISTORY_LIMIT, replyProblem, harness `history` cases | new eval case with 20-turn history recalls a turn-3 fact; summary never contains the context block |
| 3 | **Coach actions with confirmation** | Small fixed action set as structured output, never free tool access: swap today's exercise (same muscle, allowed equipment, no injury conflict), make session lighter (sets -1, RPE cap), move session to another day, log a meal from the food diary list. Server validates against plan-engine rules; app shows a confirm card; only confirmed actions write. | plan-engine.ts, exercises catalogue, week_schedule, food_diary | each action has unit tests for rejection (injury, equipment, excluded food) and an eval case |
| 4 | **Evidence retrieval** | Keep keyword retrieval; add synonym/stem expansion and a local embedding index built offline (open-source, e.g. a small sentence-embedding model run at build time, vectors shipped as data). Only `supported`/reviewed passages cited; no Postgres extension needed. | handbook.ts retrieve, validateCitations, register statuses | paraphrase eval cases hit the right passage; no citation of unreviewed claims |
| 5 | **Workout and nutrition correctness** | Close open clinical items as text only (caffeine example cap, waist-to-height 0.6 wording, pregnancy stop list) after the owner's decision; property tests on plan-engine (calorie floor, protein range 1.4 to 2.0 g/kg, deload, injury exclusions) and diet feasibility. | ROUND8_REVIEW.md, plan-engine.test.ts, diet_feasibility_test | property tests pass; no clinical claim marked approved |
| 6 | **Security** | Prompt-injection cases for memory and actions (a message trying to store or run something unconfirmed); per-user rate limits on new endpoints; facts and summaries excluded from logs; advisor-style local RLS check. | reliability_and_limits migration, eval injection case, privacy scorer | new injection eval cases strict-pass; pgTAP denies cross-user reads |

Not now: streaming (UX polish after 1 to 3), proactive check-ins (needs notifications policy), iOS (deferred).

Local models (batch 2T, synthetic only) are for development and offline evaluation; results in AI_PROVIDER_COMPARISON.md.

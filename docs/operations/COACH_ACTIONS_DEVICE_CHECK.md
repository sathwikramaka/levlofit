# Coach actions and chat summaries: on-device check (prepared 2026-10-24, NOT RUN)

Covers batches 2W (chat summaries) and 3a-3d (swap, lighter day, move, log meal). Same set-up as
`COACH_MEMORY_DEVICE_CHECK.md`: throwaway stack `levlo_phone_2i` only (Kong 54326, DB 54328), existing synthetic account
`memcheck@test.local`, deterministic stub provider `llm-stub` (no network, no keys), debug build, `adb reverse
tcp:54321 tcp:54326`. The dev stack (54321/54322) and production are never touched.

## Approvals needed before running (each is a write to the throwaway database)
1. **Synthetic catalogue rows**: insert about 10 rows into `public.exercises` on the throwaway DB (the real catalogue
   exists only in the cloud project), with made-up names and equipment/target values for today's moves and their
   candidate replacements (same shape as the rows in `coach-chat.test.ts` CATALOGUE). Without them every swap is
   refused as `not_in_catalogue`.
2. **Chat, swap, session-change and diary rows** written by the app for `memcheck@test.local` while testing (no new
   account).
3. Afterwards: optionally delete those rows and the synthetic catalogue rows (owner decides; deletion is also a write).

No approval needed (local files only): refresh the scratch copy of `supabase/functions` from the repo, extend the scratch
stub (below), restart `supabase functions serve` with `stub.env`.

## Stub behaviour to add (scratch copy only, never in the repository)
- message contains "swap": reply with a sentence and `SWAP: <first move id> -> <its first option id>` read from the
  `TODAY'S SWAP OPTIONS (` block of the system prompt.
- "tired" or "take it easy": `LIGHTER` (only if the `TODAY'S SESSION CAN BE MADE LIGHTER (` block is present).
- "move": `MOVE: <first [date]>` from the `TODAY'S SESSION CAN MOVE TO (` block.
- "log my": `MEAL: lunch <first [code]> 100` from the `FOODS THEY CAN LOG (` block.
- a chat with more than 12 earlier messages and a system prompt starting "You keep a short running summary": reply
  "They train in the evening and like split squats." (the summary call).

## Steps (about 10 minutes, on a training day; Monday to Saturday so a later free day exists)
1. Open the dashboard (today's session shows). Open Levlofit AI, send "Can I swap the goblet squat?" Expect a
   "SWAP TODAY'S MOVE?" card, no "SWAP:" text in the reply. Tap **Not now**: the session is unchanged. Repeat and tap
   **Swap**: the card says Swapped; back on the dashboard today's session shows the replacement.
2. Send "I slept badly, can we take it easy?" Expect "MAKE TODAY LIGHTER?". Tap **Make it lighter**: the session screen
   shows the lighter-day line and one set fewer per lift. Send "I have chest pain, go lighter?": no lighter card.
3. Send "No time today, can I move my session?" Expect "MOVE TODAY'S SESSION?" naming a later day. Tap **Move**:
   today shows a rest day; the Workout week view shows the session on the new day and "Session moved to <day>" today.
4. Log one food in the Food diary first. Then send "Log my lunch". Expect "LOG THIS MEAL?" listing that food. Tap
   **Not now** (diary unchanged), repeat, tap **Log it**: the diary shows the entry for today.
5. Send 7 more short messages in one chat (more than 12 stored messages). Then confirm in the stub log that a summary
   call was made and in the DB (read-only) that `coach_threads.summary` is set for that thread; the next reply request
   carries it as the first user message.
6. Read-only checks: `exercise_swaps` and `session_changes` rows exist only for memcheck on the throwaway DB, none in the
   dev DB; server logs contain no message, fact or food text.

Afterwards: `adb reverse --remove-all`.

## Results, 2026-10-23 18:17-18:20 UTC (API level; phone not connected)
Owner-approved writes on throwaway `levlo_phone_2i` only, account `memcheck@test.local`; 8 synthetic catalogue rows
(`source = 'synthetic-test'`); scratch functions refreshed from the repo; stub answers from the offered blocks.
Script: `tools/coach_actions_api_check.mjs` (same server paths the app calls; the UI cards are covered by Flutter tests).

| Check | Result | Evidence |
|---|---|---|
| Swap proposed, line hidden, stored unconfirmed | PASS | 200; Squat -> Jump squat; row `proposed` |
| Not now deletes the proposal | PASS | delete 200; 0 rows left |
| Swap confirmed by the server | PASS | confirm 200; row `confirmed` |
| App cannot insert/edit swaps or session changes | PASS | 403, 403, 403 |
| Signed-out read | PASS | 401 |
| Unknown or malformed confirms | PASS | 404, 400, 404; nothing written |
| Lighter day proposed and confirmed | PASS | change `lighter`; confirm 200 |
| No lighter day when the message mentions pain | PASS | no change offered |
| Move to a later free day, confirmed | PASS | to 2026-10-24; confirm 200 |
| Meal proposal from own diary foods, server writes nothing | PASS | lunch X001 100 g; diary 1 -> 1 |
| Log it writes the diary entry | PASS | diary 1 -> 2 |
| Long chat gets a stored summary | PASS | thread 8 -> 16 messages, summary 58 chars after 4 sends |
| Logs carry no message, food, summary or account text | PASS | 119 log lines, events only |
| Dev DB untouched | PASS | users 2, memcheck 0, exercises 0, threads 0, messages 0, food_log 0, new tables absent (same as before) |
| On-screen cards, dashboard and week view on the phone | BLOCKED | no device attached (`adb devices` empty) |

Cleanup: this run's swap, session-change and diary rows for memcheck deleted; the 8 synthetic catalogue rows and the
chat thread are kept for the on-screen check.

## Results, 2026-10-24 00:46-01:05 IST (on screen, OnePlus 358edd6b, fresh debug build of the current tree)
Same approval and restrictions; `adb reverse` was exactly `tcp:54321 tcp:54326` (throwaway Kong) and was removed after.

| Check | Result | Evidence |
|---|---|---|
| Today is a rest day for memcheck (Sat): no swap card | PASS | reply "No checked swap is available.", no card (the app sends no session on a rest day) |
| Rest day: no lighter card | PASS | reply "Rest if you feel unwell.", no card |
| Swap, lighter and move cards on a training day | BLOCKED | today is a rest day in memcheck's plan; not changing the phone date or the account plan (outside the approval). Server paths PASS at API level above |
| Meal card from own diary food | PASS | after logging rice (A015, 50 g) in Food diary: card "LOG THIS MEAL? Lunch: Rice, raw, milled 100 g"; diary still 1 entry |
| Not now writes nothing | PASS | "Kept as planned."; diary still 1 |
| Log it writes the entry | PASS | "Logged to today's food diary."; diary 2 (lunch A015 100 g, day 2026-10-24) |
| Long chat gets a summary | PASS | same chat: 14 stored messages, next send stored a 58-character summary; replies kept working |
| Logs carry no message or food text | PASS | last 300 log lines: rice 0, check-in 0, lunch 0 |
| Dev DB untouched | PASS | users 2, memcheck 0, exercises 0, threads 0, messages 0, food_log 0, new tables absent |

Cleanup: memcheck's two diary rows from this run deleted. Kept: the 8 synthetic catalogue rows and the chats (for the
training-day check of swap, lighter and move).

## Summary and owner decision (2026-10-24)
- **API level, PASS for all three actions:** swap, lighter session and move session (proposal, Not now, confirm,
  server-only writes, pain guard, unknown and malformed confirms), 2026-10-23 run above.
- **On screen, UNVERIFIED for the swap, lighter and move cards:** the test account was on a rest day, so the app
  offered none of them. The owner accepted the API-level result and chose not to change the account's plan or the
  phone's date to show the cards (2026-10-24). The cards themselves are covered by Flutter widget tests only.
- **On screen, PASS on the phone:** meal logging, Not now, Log it, chat summaries, and rest-day behaviour (no swap or
  lighter card).
- The development database stayed untouched (same read-only counts before and after) and the `adb reverse` port
  mapping was removed after the run.

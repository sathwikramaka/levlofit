# Coach memory: on-device check (batch 2V)

Throwaway stack `levlo_phone_2i` only (API 54326, DB 54328), synthetic account, a deterministic stub "provider"
(`llm-stub`, an Edge Function that exists only in the scratch copy of the stack; no network, no keys, no AI service).
The stub replies to "evening" and "burpee" with a memory suggestion, and to anything else with the list of confirmed
facts it received, so the phone shows what reached the coach.

API dry run 2026-10-22 on the same stack: 10/10 checks pass (suggest, hidden NOTE line, nothing auto-confirmed,
confirm, reject, confirmed fact sent, rejected not sent, edit sent, deleted not sent, deletion persists).

Scratch workdir of the stack: `%TEMP%\claude\C--Projects-Fitness-App\c617cfb4-d771-4288-bd17-86f471ad8878\scratchpad\phone2i`
(project_id `levlo_phone_2i`; Kong 54326, DB 54328). The development stack uses 54321 (Kong) and 54322 (DB).
Checked 2026-10-22: the local publishable key is the SAME for both stacks, so only the adb mapping separates them.

Proof the phone reaches the throwaway stack: (a) `adb reverse --list` shows `tcp:54321 tcp:54326`; (b) after sign-up,
`memcheck@test.local` exists in `supabase_db_levlo_phone_2i` and not in `supabase_db_Fitness_App` (read-only counts);
(c) coach replies contain "Facts I was given", which only the throwaway stub writes (the dev stack serves no functions).

## Safety before starting

1. Phone connected by USB, unlocked. `adb reverse tcp:54321 tcp:54326` then `adb reverse --list` must show exactly
   `tcp:54321 tcp:54326`. Port 54321 on the laptop is the development stack: a mapping to 54321 would reach it.
2. Debug build with the throwaway key: the app refuses any URL but `http://127.0.0.1:54321` and refuses the cloud key,
   so production cannot be reached from this build.

## Steps (about 5 minutes)

1. Sign up with a new synthetic email (for example `memcheck@test.local`), finish onboarding with made-up answers.
2. Open Levlofit AI, send **"I like training in the evening."** Expect a card "REMEMBER THIS? · SCHEDULE / trains in
   the evening" and no "NOTE:" text in the reply. Tap **Remember**. Menu > Memory: the fact is under **REMEMBERED**.
3. Send **"I hate burpees."** Tap **Not now** on its card. Send **"What should I train today?"** The reply lists
   `[schedule] trains in the evening` and does not mention burpees.
4. Memory > edit the fact to **"trains in the evening after 7 pm"** > Save. Close and reopen Memory: the new text is
   there. Send "Any tips for my next session?": the reply lists the new text. Memory > delete it. Reopen Memory: gone.
   Send the same question: the reply says `(none yet)`.
5. Automated tests (laptop): `bash tools/verify.sh functions deno flutter` and pgTAP on the throwaway copy.

Afterwards: `adb reverse --remove-all`. The synthetic account stays on the throwaway stack until it is deleted.

Result 2026-10-23: all four steps PASS on device 358edd6b; see docs/PROGRESS.md (batch 2V phone check).

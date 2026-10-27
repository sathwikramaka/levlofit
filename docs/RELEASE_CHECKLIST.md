# Levlofit production release checklist

Updated 2026-10-16 (Levlofit-4). Replaces the 2026-10-13 version. **Nothing below has been run against production.**
Tick an item only with a record (command output, reviewer name, date). **Approval** = the owner's explicit approval in
chat for that one step (CLAUDE.md); one approval never covers the next step. Details: BACKUP_RECOVERY_PLAN.md (backup
and restore), MIGRATION_RECONCILIATION.md (per-item preflight, verify, rollback), PROD_MIGRATION_SAFETY_REVIEW.md
(read-only queries Q0-Q8), PLAY_DATA_SAFETY_DRAFT.md.

## 0. Protect what already exists (do first)

| # | Step | Who | Approval |
|---|---|---|---|
| 0.1 | **Status 2026-10-16: attempted twice, paused (no output written, source unchanged; PROGRESS CC, CD).** Needs the owner at the Windows passphrase dialog; if gpg reports "problem with the agent", run `gpgconf --kill gpg-agent` first. Seal the existing **unencrypted** production backup `C:\Projects\levlo-secure-backups\levlo-pre-migration-20261014T162118Z`: `bash tools/backup_seal.sh --legacy <that folder>` (verifies its SHA256SUMS first, writes `.tar.gpg` + `.sha256`, writes no plaintext, deletes nothing). Copy both files to an offline drive and run `sha256sum -c` there. | Owner (passphrase) | Owner's own action; no production access |
| 0.2 | Remove the extra Administrators entry on the backup root: `icacls C:\Projects\levlo-secure-backups /remove:g *S-1-5-32-544` (the hardened wrapper refuses to run while it exists) | Owner | Owner's own action |
| 0.3 | Delete the plaintext 2026-10-14 folder only after 0.1 is verified on the offline copy | Owner | **Yes** (deletion of personal data) |

## 1. Backup and verification

| # | Step | Who | Approval |
|---|---|---|---|
| 1.1 | Read-only state, before: tools/schema_state.sql (12 kinds) and Q0-Q8 | Owner (or Claude via MCP/CLI) | **Yes** (production read) |
| 1.2 | `powershell -ExecutionPolicy Bypass -File tools\backup_prod.ps1` (Session pooler string + a personal access token created for this run; never `supabase link`) -> PASS + BACKUP_PASS | Owner | **Yes** (production access) |
| 1.3 | Same read-only state, after; Q7 counts before = after (quiet window) | Owner | **Yes** |
| 1.4 | `bash tools/backup_seal.sh <folder>`; offline copy; `sha256sum -c` there; revoke the access token | Owner | Owner's action |
| 1.5 | Isolated RAM-only restore of the sealed backup and every BACKUP_RECOVERY_PLAN.md section 7 check against the 1.1 values | Claude on the owner's machine | **Yes** (personal data) |

## 2. Reconciliation and migration rehearsal

| # | Step | Who | Approval |
|---|---|---|---|
| 2.1 | Rehearse the fourteen pending items (3.1-3.7h) in order on the restored copy, each with its preflight, verify and rollback test | Claude | **Yes** |
| 2.2 | Choose Option A (re-align history) or B (forward-only, recommended) for the unrecorded handbook_v3 state | Owner | **Yes** (decision) |
| 2.3 | Remove the drill container and any plaintext | Claude/owner | **Yes** (deletion) |

## 3. Production change (one approval per row, in order; stop at the first failed check)

Path: **Option B, forward-only**, applying one file at a time with `psql -v ON_ERROR_STOP=1 --single-transaction -f
<file>` on the session pooler URL (no `supabase link`, no `db push`; Option A in MIGRATION_RECONCILIATION.md needs
`supabase link` and pushes every pending file at once, so it is not used). For every row:

- **Before:** the row's preflight (MIGRATION_RECONCILIATION.md) passes; Q7 counts equal the 1.3 values (else take a new
  backup first); `sha256sum` of the file equals the one rehearsed in 2.1 (several files were edited after commit
  daaea96: 20261007400000, 20261013100000, 20261016100000); the rollback below was rehearsed in 2.1.
- **On an apply error:** the transaction rolls back by itself; re-run the preflight, record the error, stop.
- **After:** the verify passes and Q7 still equals the 1.3 values (no user rows changed); log time, file hash, operator.

| # | Item | Preflight (stop if not met) | Verify | Rollback (rehearsed in 2.1; every `drop` uses `if exists`) |
|---|---|---|---|---|
| 3.1 | 20261007400000_handbook_v3 | P1, P3, Q5 hash = 432c7c6f; P2 export of the **10 stored columns** (not `select *`: `search` is a generated column) returns 38 rows; the file's expected hash, recomputed read-only with `tools/handbook_fingerprint_sql.py`, is **b3b87df6** (2026-10-24; was af1ea000 at commit 1803009) | handbook hash = b3b87df6 and 38 rows | `begin; delete from public.handbook_chapters; insert into public.handbook_chapters (<10 columns>) select <10 columns> from jsonb_populate_recordset(null::public.handbook_chapters, '<P2>'); commit;` then Q5 = 432c7c6f |
| 3.2 | 20261013100000_reliability_and_limits (check_rate limits now server-side, Levlofit-4 batch CE) | Q2/Q3/Q4 (record the "own levels" policy text) | objects present; anon cannot execute check_rate; levels <= 3 | drop triggers app_feedback_limit, contact_messages_limit; drop functions limit_app_feedback(), limit_contact_messages(), check_rate(text,int,interval), coach_commit_turn(uuid,text,bigint,uuid,text,text); drop table rate_events; drop index contact_messages_created_at; drop column coach_messages.client_msg_id; drop the 4 new goal_levels policies; re-create "own levels" from the Q4 record. Loses rate events and client ids |
| 3.3 | 20261014100000_custom_reminders | table absent | table + RLS + limit trigger | drop table custom_reminders; drop function custom_reminders_limit() (loses reminders saved since) |
| 3.4 | 20261016100000_food_diary (day range check added in CE) | Q3b = 1 (foods.code unique) | table + RLS; anon none | drop table food_log; drop function food_log_limit() (loses diary entries saved since) |
| 3.5 | 20261016200000_food_micronutrients | Q5 codes hash 66bf5cf3f1c8 | 8 columns; A013 calcium 10.93 | drop the 8 columns (licence still open: section 6) |
| 3.6 | 20261016300000_recipes | Q3b = 1; tables and save_recipe absent | tables, function; anon cannot execute save_recipe | drop tables recipe_items, recipes; drop functions save_recipe(text,int,jsonb), recipe_limits() (loses recipes saved since) |
| 3.7 | 20261016400000_revoke_anon_user_tables | record `pg_class.relacl` and `pg_attribute.attacl` of the six tables (table and column grants) | anon_access query returns '' | restore exactly the recorded ACLs |
| 3.7b | 20261017100000_revoke_anon_sequences (added 2026-10-17, low finding; run only on a fresh throwaway local DB: all 34 migrations applied, pgTAP 64/64, the assertion fails as expected when anon is re-granted; never run on the dev DB or production) | record `pg_class.relacl` of the 4 public sequences and `pg_default_acl` for schema public | pgTAP anon_access test 4: anon holds nothing on public sequences | restore the recorded ACLs (`grant usage, select, update on sequence ... to anon`) and the default ACL |
| 3.7c | 20261023100000_coach_facts (batch 2U; copies existing coach_notes lines as unconfirmed suggestions) | table absent; record `select count(*) from coach_notes` and its non-empty lines | table + RLS + trigger; migrated rows = recorded note lines, all `suggested`; coach_notes unchanged | drop table coach_facts; drop function coach_facts_stamp() (coach_notes was never changed) |
| 3.7d | 20261023200000_thread_summaries (batch 2W) | columns absent | 2 columns + checks; authenticated may update only summary, summary_upto, title, updated_at | `alter table coach_threads drop column summary, drop column summary_upto` |
| 3.7e | 20261024100000_exercise_swaps (batch 3a) | table absent; `public.exercises` present | table + RLS; authenticated has select and delete only | drop table exercise_swaps (loses swaps saved since) |
| 3.7f | 20261024200000_session_changes (batches 3b, 3c) | table absent | table + RLS; authenticated has select and delete only | drop table session_changes (loses lighter days and moves saved since) |
| 3.7g | 20261025100000_food_sources (food licence gate, 2026-10-24) | `select to_regclass('public.food_sources') is null` = t; record `select count(*) from foods` (543 expected) and `select policyname from pg_policies where tablename='foods'` (= "foods are public") | food_sources has 3 rows (ifct2017 false; usda_fdc and levlofit_recipe true); every food has a source; as authenticated, `select count(*) from foods where source='ifct2017'` = 0; policy "foods from allowed sources" | `drop policy "foods from allowed sources" on foods; create policy "foods are public" on foods for select to anon, authenticated using (true); alter table foods drop column source, drop column source_ref; drop table food_sources;` (no data lost) |
| 3.7h | 20261025200000_foods_usda_fdc (USDA planner foods, 2026-10-24) | `select count(*) from foods where code like 'FDC%'` = 0; record X001's row | 28 FDC rows with source usda_fdc; X001 carb_g = 16.42; as authenticated (IFCT hidden) 29 usda_fdc rows visible | `delete from foods where code like 'FDC%' and source = 'usda_fdc'` (only if no food_log or recipe_items row references them: check first) and restore X001's recorded row; `alter table foods drop column source_note` |
| 3.7i | 20261027100000_diet_pace_region (plate builder, 2026-10-27) | columns absent | dietary_profiles.diet_pace = 'balanced' and cuisine_region = 'any' on every row | `alter table dietary_profiles drop column diet_pace, drop column cuisine_region` |
| 3.7j | 20261027200000_body_check_rate (body check, 2026-10-27) | `check_rate('body_check_day', ...)` raises unknown bucket | the 4th call in a day returns false | re-run the check_rate definition from 20261013100000 |
| 3.7k | 20261027300000_app_errors (crash log, 2026-10-27) | table absent | table + RLS; authenticated can insert, not select; 31st report in a day dropped | `drop table app_errors; drop function app_errors_limit()` (loses error reports only) |
| 3.7l | 20261028100000_ifct_release (owner decision, step A20) | ifct2017 release_allowed = false | true; IFCT foods visible to authenticated users | `update food_sources set release_allowed = false where source = 'ifct2017'` |
| 3.8 | All fourteen done (2026-10-24: 3.7c-3.7h added; each was tested only with pgTAP on a throwaway local stack, 121/121; rehearse them in 2.1 like the rest) | | tools/schema_state.sql (12 kinds) equals the **2.1 rehearsal copy after all eight** (production-only objects from Q8 excepted). Expected movement: fngrant 0 -> 2 after 3.2 -> 3 after 3.6; after 3.7b the anon seqgrant rows (4 sequences x SELECT, USAGE, UPDATE) disappear and defacl changes (fresh local DB: seqgrant 12 12aaba92b25e, defacl 6 35ea73e534f5); authenticated seqgrant rows keep the backup values | |
| 3.9 | Record deployed function versions (A4) and secret names (A5); deploy coach-chat, generate-plan, delete-account. Set `LLM_DATA_APPROVED=<provider>` first (batch 2E; `<provider>@<host>` when LLM_BASE_URL or LLM_FALLBACK_BASE_URL points away from the preset host, batch 2H): without it coach-chat answers 503 | | versions changed; LLM_* secret names present, incl. LLM_DATA_APPROVED | redeploy the recorded previous versions |

Q8 and W4 must sort inside `string_agg` by name (`order by event_object_table, trigger_name` / `order by tablename,
policyname`), not `order by 1`, or their hashes are arbitrary. Items 3, 4 and 6 use plain `create`: a partial manual
re-run fails at its first statement, so always apply with `--single-transaction`.

## 4. Production smoke test (test account only; **Yes** approval)

Sign up / sign in; onboarding and plan build; plan rebuild; coach chat send and resend (same message ID saved once);
feedback (rate limit); coach Memory (suggest, confirm, edit, delete); a long chat gets a summary; coach actions swap, lighter
day, move and log meal are proposed, confirmed and applied (and Not now leaves nothing); food diary add/edit and recipe save/log; custom reminder; profile photo upload; signed-out REST
requests to per-user tables return nothing; delete account removes photos then the account. Remove the test account's
data by id afterwards.

## 5. App and website release

| # | Step | Who | Approval |
|---|---|---|---|
| 5.1 | Release keystore + key.properties (outside git); `flutter build appbundle --release --dart-define=LEVLOFIT_BACKEND=production` (without the define the build has no backend, batch 2E; steps in RELEASE_SETUP.md); `apksigner verify --print-certs` is not the debug certificate. Locally verified 2026-10-16: without a keystore the build stops with the intended message; a debug-signed local release builds (not debuggable, allowBackup false, minSdk 24, targetSdk 36). Re-verified 2026-10-24 (efc2c02 + working tree): no-keystore guard stops `flutter build appbundle --release`; `LEVLOFIT_DEBUG_SIGNED_RELEASE=true flutter build apk --release --dart-define=LEVLOFIT_BACKEND=production` builds 63.1 MB, not debuggable, minSdk 24, targetSdk 36, allowBackup false, no Health Connect permission, backend host = the cloud project, signer "CN=Android Debug" (local check only: never install against production or upload) | Owner | Owner's credential |
| 5.2 | Device pass on the signed build: reminder delivery, permission revoke, reboot, BMI, dashboard customise, daily goal, coach chat, session screen | Owner + Claude | **Yes** (phone) |
| 5.3 | Choose website host; deploy; `curl -I` headers/CSP on the real URL; /privacy, /terms, /delete-account live | Owner | **Yes** |
| 5.4 | Git remote, reviewed commits, CI green (5 jobs) | Owner/Claude | **Yes** (commit, push) |
| 5.5 | Play Console: listing, data safety (from the reviewed draft), deletion URL = /delete-account, content rating, internal testing track, then staged rollout | Owner | Owner |

## 6. Blockers that code cannot remove (owner or external)

| Blocker | Needed from | Blocks |
|---|---|---|
| Clinical review: handbook (444 items, 150 clinical), BMI and WHtR cut-offs, micronutrient targets, referral wording; 2026-10-24 owner decisions (caffeine example, single WHtR band from 0.5, pregnancy stop list) and five passages reworded from abstracts (REVIEW_PACKAGES.md section 6) | Qualified clinician | Areas 1, 2, 9, 10, 18; any health claim |
| Coach review of the session-estimate assumptions; dietitian review of nutrition rules | Coach, dietitian | Areas 3, 4 |
| Legal/privacy review: privacy text (REVIEW GATE markers), retention periods, /delete-account page, data-safety draft | Lawyer / privacy reviewer | Areas 7, 19; publication; Play |
| Licences: IFCT values incl. micronutrients (NIN), INDB, wger per-entry, **ExerciseDB media (non-commercial)**, MuscleWiki (paid) | Licensors / owner | Areas 12, 17, 18; commercial release |
| AI provider key and data terms; live evaluation (`_eval/run.ts --live`) with zero safety-critical failures | Owner | Areas 5, 6, 19 |
| Health Connect / step counter approval and Play declaration | Owner | Area 16 |
| Alarm-clock reminder mode decision (and Play exact-alarm policy check) | Owner | Area 13 |
| Release keystore, website host, Git remote | Owner | 5.1, 5.3, 5.4 |
| Phone available for device checks | Owner | 5.2 |

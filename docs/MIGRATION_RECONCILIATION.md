# Cloud migration history reconciliation (prepared 2026-10-13, extended 2026-10-16 to seven pending items and 2026-10-17 to eight, 2026-10-24 to fourteen; nothing applied)

> **Corrections 2026-10-16 (Levlofit-4, independent audit, PROGRESS batch CE). Where this file disagrees,
> docs/RELEASE_CHECKLIST.md section 3 is authoritative.** Option A is not used (it needs `supabase link`, which is
> forbidden, and pushes all seven at once); Option B applies one file per approval. P2 must export the 10 stored
> columns (`search` is generated). Item 2's rollback must also drop the four new goal_levels policies, the
> contact_messages_created_at index and both limit triggers. Items 4 and 6 need Q3b in their preflight. Item 7 must
> record table and column ACLs, not only table grants. Q8/W4 must order inside `string_agg` by name. The `data`
> fingerprint kind hashes reference tables only, never user data. The local migration count is now 33.


Project `levlo` (ref ndeozgxowggkljluaccz). Evidence: read-only queries through the Supabase MCP on 2026-10-13
(migration records, whitespace-normalised md5 of each recorded migration's SQL, and a full fingerprint of the public
schema, storage buckets/policies, auth triggers and extensions; see tools/schema_state.sql). No write was made.

## Result

Cloud history was written by `apply_migration` with apply-time versions; local files use hand-picked versions. Content:

| Local file | Cloud record(s) | Status |
|---|---|---|
| 20260928120000_init | 20260928174658 init | Applied, same SQL |
| 20260928130000_six_goals | 20260928182245 | Applied, same SQL |
| 20260928140000_other_restrictions | 20260928182954 | Applied, same SQL |
| 20260929090000_goal_catalog | 20260928183912 | Applied, same SQL |
| 20260929130000_ensure_profile | 20260929123123 | Applied, same SQL |
| 20260929140000_trim_goal_catalog | 20260929124453 + 20260929124512 rename_hybrid_category | Applied as two records; concatenated SQL identical |
| 20260929150000_curriculum_levels | 20260929134407 | Applied, same SQL |
| 20260929160000_profile_self_insert | 20260929134655 | Applied, same SQL |
| 20260929170000_foods_ifct2017 | 20260929135530 + 20260929135833 (part1/part2) | Applied in two parts; SQL text differs, resulting `foods` data identical |
| 20260929180000_coach_profile_v2 | 20260929142821 | Applied, same SQL |
| 20260929190000_waitlist | 20260929164332 | Applied, same SQL (table later dropped) |
| 20260929200000_contact_messages | 20260929170329 | Applied, same SQL |
| 20260929210000_handbook_v1 | 20260929171600/171749/172515 (schema, content, q3 wording) | Applied in three parts; text differs; content superseded by v3 |
| 20260929220000_handbook_grades | 20260929173613 | Applied, same SQL |
| 20260929230000_exercises_catalog | 20260929180006 + 20260929180518 exercises_import_cleanup | Text differs; schema identical; exercise rows were imported outside migrations (local DB has none) |
| 20260930000000_exercises_has_media | 20260930045317 | Applied, same SQL |
| 20261003000000_revoke_truncate | 20261003044920 revoke_truncate_from_api_roles | Applied, same SQL |
| 20261003100000_coach_memory | 20261003053618 | Applied, same SQL |
| 20261003200000_threads_measurements_photos | 20261003081358 | Applied, same SQL |
| 20261003300000_handbook_v2 | 20261003090315 | Text differs; content superseded by v3 |
| 20261003400000_levels_water_habits_reminders | 20261003090402 + 20261003091951 goal_levels_upsert_grant | Text differs; schema and grants identical |
| 20261003500000_protocol_sets_budget | 20261003101127 | Applied, same SQL |
| 20261007100000_soya_chunks | 20261007072328 | Applied, same SQL |
| 20261007200000_profile_avatar | 20261007083557 | Applied, same SQL |
| 20261007300000_app_feedback | 20261007084949 + 20261007085015 app_feedback_user_index | Applied as two records; concatenated SQL identical |
| 20261007400000_handbook_v3 | none | **Partly applied, unrecorded**: v3 columns exist; 38 chapters hold a pre-correction draft (data hash 432c7c6f; committed daaea96 version fe8b8740; current builder output af1ea000 [superseded 2026-10-24 by b3b87df6: current builder output after the item 4 and item 5 Handbook edits, computed read-only from the migration's VALUES list with the same md5 expression and the table's generated search column (tools/handbook_fingerprint_sql.py; validated: it reproduces af1ea000 from the commit 1803009 file, which a throwaway DB also returned after applying it); check b3b87df6 after any production apply] (fresh local DB, all 34 migrations, 2026-10-18; was 81a79a56 before the 2026-10-18 handbook changes)) |
| 20261007500000_remove_pilates | 20261007092712 | Applied, same SQL (0 pilates rows remain) |
| 20261013100000_reliability_and_limits | none | **Not applied** (all 23 schema differences between cloud and local are this migration's objects plus the old "own levels" policy it replaces) |

Schema fingerprint: grants, columns, constraints, indexes, policies, functions, triggers, storage buckets/policies,
auth trigger and extensions are identical between cloud and a local `supabase db reset`, except the
20261013100000 objects. Reference data `foods`, `goal_catalog`, `curriculum_levels` identical.

## Data-loss risks
- `supabase db push` today would try to re-run all 28 local files (versions unknown remotely). `init` would fail
  inside its transaction (objects exist), so the likely outcome is an aborted push, but do not rely on it: never run it
  before reconciliation. Never run `supabase db reset --linked` (wipes the cloud database).
- Applying the current handbook_v3 file replaces all 38 chapter rows (content only). Only `goal_catalog.handbook_chapter`
  references them; 0 rows set (checked). No user data involved.
- 20261013100000 deletes nothing; it adds objects and swaps the goal_levels policy within one transaction.
- `migration repair --status reverted` deletes rows from `supabase_migrations.schema_migrations` (history only, including
  the stored SQL of each record). Export that table first (step 2 below).
- The cloud `exercises` rows exist only in the cloud; never seed or reset them from a local copy.

## Backup requirement (must be confirmed by the owner before any write)
Dashboard > Database > Backups shows a completed backup (or PITR) dated within the last 24 hours, or the owner takes a
fresh logical dump (`supabase db dump --linked -f <secure path outside the repo>`; it contains personal data, store it
encrypted, never in git). Backup status was not visible to the read-only tools used here.

## Options (owner chooses; none run)
**A. Re-align history to local files, then push (recommended: makes `db push` usable again).**
1. Confirm backup. 2. Export history: `supabase db query --project-ref ndeozgxowggkljluaccz "select version, name from
   supabase_migrations.schema_migrations order by version" > <secure path>` (keep with the backup).
3. `supabase link --project-ref ndeozgxowggkljluaccz`
4. `supabase migration repair --status reverted 20260928174658 20260928182245 20260928182954 20260928183912 20260929123123 20260929124453 20260929124512 20260929134407 20260929134655 20260929135530 20260929135833 20260929142821 20260929164332 20260929170329 20260929171600 20260929171749 20260929172515 20260929173613 20260929180006 20260929180518 20260930045317 20261003044920 20261003053618 20261003081358 20261003090315 20261003090402 20261003091951 20261003101127 20261007072328 20261007083557 20261007084949 20261007085015 20261007092712`
5. `supabase migration repair --status applied 20260928120000 20260928130000 20260928140000 20260929090000 20260929130000 20260929140000 20260929150000 20260929160000 20260929170000 20260929180000 20260929190000 20260929200000 20260929210000 20260929220000 20260929230000 20260930000000 20261003000000 20261003100000 20261003200000 20261003300000 20261003400000 20261003500000 20261007100000 20261007200000 20261007300000 20261007500000`
6. `supabase migration list` must show those 26 as applied and only the fourteen items under "Pending production items"
   pending (20261007400000, 20261013100000, 20261014100000, 20261016100000, 20261016200000, 20261016300000,
   20261016400000, 20261017100000); `supabase db push --dry-run` must list exactly those eight.
7. `supabase db push`. 8. Verify (below).

**B. Forward-only, leave history as is.** Apply the fourteen pending files' SQL as new records (Dashboard SQL editor or
`apply_migration`) in the order of "Pending production items", handbook_v3 first. History stays mismatched; `db push` must then never be
used for this project, and every future migration must be applied the same way.

No new migration file is proposed: the pending local files are already safe to apply in order (ALTERs are
`if not exists`; FK refs 0; reliability objects absent remotely). A copy-named handbook file would duplicate 130 KB.

## Verification after either option (read-only; values below are for items 1-2 only, see "Expected fingerprint after all seven")
`supabase db query --project-ref ndeozgxowggkljluaccz -f tools/schema_state.sql` must equal the local result:
colgrant 447 18aa28f3d534, column 163 37752a1a59a5, constraint 110 5c013aebb422, function 6 4aff81f36859, grant 64
3751b1e2ab49, index 40 c614a2c5128f, policy 27 16e4c8f9aa56, trigger 2 5c55166e758e. `data` will differ only by the
cloud's exercise rows; handbook_chapters must hash af1ea000 [superseded 2026-10-24 by b3b87df6: current builder output after the item 4 and item 5 Handbook edits, computed read-only from the migration's VALUES list with the same md5 expression and the table's generated search column (tools/handbook_fingerprint_sql.py; validated: it reproduces af1ea000 from the commit 1803009 file, which a throwaway DB also returned after applying it); check b3b87df6 after any production apply] (fresh local DB, all 34 migrations, 2026-10-18; was 81a79a56 before the 2026-10-18 handbook changes) (check with the handbook line of the query). Then deploy the
three functions and run the release smoke test.

## Forward-only preflight (Option B, recommended 2026-10-14; still not authorised)

Inspection results (read-only, 2026-10-14):
- handbook_v3: `alter table ... add column if not exists` (all five columns already exist in the cloud, so the whole
  ALTER is a no-op, including `unique` on slug), `delete from public.handbook_chapters`, one `insert` of 38 rows with
  explicit ids. `search` is a generated column, recomputed on insert. Cloud ids 1-38 and slugs are identical to the
  new rows (id:slug hash dfba87e4ff both sides), so app deep links and the plan engine's chapter references keep working.
  Only FK into the table: goal_catalog.handbook_chapter, 0 rows set. No user data.
- reliability_and_limits: rehearsed locally on a recreated cloud pre-state (old "own levels" policy, no new objects),
  inside a rolled-back transaction: applies cleanly, leaves 4 goal_levels policies and 4 functions. Cloud data is tiny
  (2 users, 2 threads, 4 messages, 0 goal_levels, 0 contact messages, 0 feedback), so index builds and locks are brief.
  The unique index is on a new all-null column: cannot fail on duplicates.
- Compatibility with the deployed (old) functions: old coach-chat keeps inserting messages without client_msg_id
  (allowed); old generate-plan unaffected. Old app builds that try to save a level of 4 or 5 now get a permission error
  (intended level lock).

Remaining uncertainty: backup status and plan tier (not visible); whether the chosen execution path wraps each file in
one transaction (wrap explicitly, below); the provenance of the current cloud handbook draft (irrelevant once replaced,
but it cannot be restored without the backup or the export in P2).

### Backup verification (owner)
1. Dashboard > Project levlo > Database > Backups: note plan tier and the newest completed backup time (must be < 24 h).
   Free-tier daily backups may not be self-restorable; if no restorable backup or PITR is listed, do step 2.
2. Logical dump to an encrypted location outside the repo (contains personal data):
   `supabase db dump --db-url "<connection string from Dashboard > Connect>" -f <secure>/levlo-schema.sql`
   `supabase db dump --db-url "<same>" --data-only -f <secure>/levlo-data.sql`
   Never paste the connection string (it holds the DB password) into chat or files in the repo.
3. Optional (CLI token): `supabase backups list --project-ref ndeozgxowggkljluaccz`.

### Migration 1: 20261007400000_handbook_v3 (content replacement)
Preflight (read-only, all must hold):
- P1 `select count(*) from public.goal_catalog where handbook_chapter is not null;` = 0
- P2 export current rows for rollback: `supabase db query --db-url "<conn>" "select * from public.handbook_chapters order by id" -o json > <secure>/handbook_before.json`
- P3 `select count(*) from information_schema.columns where table_schema='public' and table_name='handbook_chapters' and column_name in ('slug','part_title','summary','minutes','blocks');` = 5
Apply (owner, after approval): run the file wrapped as `begin;` + file + `commit;` in one execution.
Verify:
- V1 `select count(*), min(id), max(id), left(md5(string_agg(id||':'||slug, ',' order by id)),10) from public.handbook_chapters;` = 38, 1, 38, dfba87e4ff
- V2 `select count(*) filter (where body_md like '%Vanaspati (trans fats) and oil reused for frying%') as fixed, count(*) filter (where body_md like '%not a week off%') as old_text from public.handbook_chapters;` = 1, 0
- V3 `select left(md5(string_agg(h::text, '' order by h::text)),8) from public.handbook_chapters h;` = af1ea000 [superseded 2026-10-24 by b3b87df6: current builder output after the item 4 and item 5 Handbook edits, computed read-only from the migration's VALUES list with the same md5 expression and the table's generated search column (tools/handbook_fingerprint_sql.py; validated: it reproduces af1ea000 from the commit 1803009 file, which a throwaway DB also returned after applying it); check b3b87df6 after any production apply] (fresh local DB, all 34 migrations, 2026-10-18; was 81a79a56 before the 2026-10-18 handbook changes) (local result; a different value with V1/V2 passing means a text-search config difference, not a content error: then compare `md5(string_agg(body_md,'' order by id))` with local)
Rollback: restore rows from P2 export (or backup).

### Migration 2: 20261013100000_reliability_and_limits
Preflight:
- R1 `select count(*) from pg_policies where tablename='goal_levels';` = 1 (policy "own levels")
- R2 `select count(*) from pg_proc where proname in ('coach_commit_turn','check_rate','limit_app_feedback','limit_contact_messages');` = 0
- R3 `select count(*) from information_schema.columns where table_name='coach_messages' and column_name='client_msg_id';` = 0
- R4 `select count(*) from public.goal_levels where level > 3;` = 0
Apply (owner, after approval): `begin;` + file + `commit;`.
Verify:
- W1 `select string_agg(policyname, ', ' order by policyname) from pg_policies where tablename='goal_levels';` = add own self-assessed levels, change own self-assessed levels, delete own levels, read own levels
- W2 `select string_agg(proname, ',' order by proname) from pg_proc where pronamespace='public'::regnamespace;` = check_rate,coach_commit_turn,handle_new_user,limit_app_feedback,limit_contact_messages,words
- W3 `select has_function_privilege('anon','public.check_rate(text,int,interval)','execute') as anon_exec, has_function_privilege('authenticated','public.check_rate(text,int,interval)','execute') as auth_exec, has_function_privilege('anon','public.coach_commit_turn(uuid,text,bigint,uuid,text,text)','execute') as anon_commit;` = false, true, false
- W4 `select string_agg(event_object_table||'.'||trigger_name, ',' order by 1) from information_schema.triggers where trigger_schema='public';` = app_feedback.app_feedback_limit,contact_messages.contact_messages_limit (listed once per event)
- W5 `select string_agg(indexname, ',' order by indexname) from pg_indexes where indexname in ('coach_messages_client_msg','rate_events_lookup','contact_messages_created_at');` = all three
- W6 `select relrowsecurity from pg_class where oid='public.rate_events'::regclass;` = true; `select count(*) from information_schema.role_table_grants where table_name='rate_events' and grantee in ('anon','authenticated');` = 0
- W7 full fingerprint: `tools/schema_state.sql` equals the local values listed above.
Rollback: see "Rollback limits" in docs/PROGRESS.md runbook (drop the new triggers/functions/table/index/column, restore
policy "own levels"); no data is deleted by the forward migration.

Then: deploy coach-chat, generate-plan, delete-account; smoke test with a test account.

## Pending production items (17), updated 2026-10-27 (documentation only; nothing applied)

**Read-only state, 2026-10-28 (step A1, owner-approved, no writes):** migration history has 33 rows, last
20261007092712 remove_pilates; none of the 17 items below is recorded. Functions: delete-account v8, generate-plan v13,
coach-chat v13 (body-check absent). Exact counts: auth.users 2, profiles 2, generated_plans 1, workout_logs 0,
coach_messages 4, progress_photos 0, handbook_chapters 38 (fingerprint 432c7c6f, the pre-correction draft, as expected),
goal_catalog 12, curriculum_levels 36, foods 543, exercises 1500 (all with gif_url), contact_messages 0, app_feedback 0.
Tables from items 2-17 (rate_events, custom_reminders, food_log, recipes, coach_facts, food_sources, app_errors, ...) are absent.

**Backup and rehearsal, 2026-10-28:** owner ran tools/backup_prod.ps1 (folder levlo-pre-migration-20261027T190443Z):
roles, schema, data, platform schema and migration history OK; the Storage copy failed (scoped tokens are refused by
`storage cp`), so the one stored file (progress-photos, 34 KB) is not in the backup; owner accepted. Isolated restore
(postgres 17.6.1.171, --network none, tmpfs, removed after): every count equal to the A1 values, handbook 432c7c6f,
RLS on every public table. Rehearsal on the restored copy, as postgres, one --single-transaction file at a time: all 17
items plus remove_pilates (already live under 20261007092712; re-runs cleanly) applied without error. After: handbook
f17e603d, user rows unchanged (2 users, 2 profiles, 1 plan, 4 coach messages), foods 571 (28 USDA), food_sources
ifct2017 hidden / usda_fdc and levlofit_recipe allowed, the 10 new tables present with RLS, 0 tables without RLS.

**Production apply log** (owner runs tools/apply_prod.ps1; Claude verifies read-only; one approval per item):
- 2026-10-28 item 1, 20261007400000_handbook_v3 (sha256 63373479ed6a5618...): APPLIED. Verify: handbook 38 rows,
  fingerprint f17e603d (= rehearsal), body-measures uses WHO, no waist-to-height; users 2, profiles 2, plans 1,
  coach messages 4 (unchanged). First run did not execute (script parse error, fixed in 5430365); nothing applied then.
- 2026-10-28 item 2, 20261013100000_reliability_and_limits (sha256 2b06bc0ba5a84572...): APPLIED. Verify: rate_events
  present; check_rate (security definer), coach_commit_turn and limit_app_feedback present, anon cannot execute any;
  app_feedback_limit trigger present; goal_levels has 4 policies; users 2, profiles 2, coach messages 4 (unchanged).

**Update 2026-10-24 (later):** item 13, `20261025100000_food_sources` (food licence gate). Tested only on a disposable
local stack (levlo_mig_fs: all migrations and the seed, pgTAP 129/129). **Behaviour change in production:** once
applied, every IFCT food value is hidden from the app and the coach (`food_sources.ifct2017.release_allowed = false`).
The diet plan, food library and diary then show the "food values are not available" note until USDA rows are
imported or NIN grants permission. Apply it together with item 14 (the USDA import, 2026-10-24), or decide explicitly to ship without food
values. `supabase/seed.sql` turns IFCT on for local stacks only: never run `db push --include-seed` against production.

**Update 2026-10-24:** items 9-12 below (coach memory facts, chat summaries, exercise swaps, session changes), written
after the 2026-10-17 list, tested only with pgTAP on throwaway local stacks (121/121) and in the CI database job
definition (CI not yet run: no Git remote). Never applied to the dev DB or production. Preflight, verify and rollback
for each are rows 3.7c-3.7f of RELEASE_CHECKLIST.md; the handbook_v3 file (item 1) changed on 2026-10-27 (BMI chapter moved to the WHO bands, waist-to-height removed), so b3b87df6 is superseded; the file now produces f17e603d (computed read-only, 2026-10-28).

**Update 2026-10-17:** an 8th item, `20261017100000_revoke_anon_sequences` (revokes anon on the 4 public sequences,
all backing identity columns of per-user tables; and the matching default privilege). Written locally with a pgTAP
assertion; run 2026-10-17 (batch 2I) only on fresh throwaway local databases (all 34 migrations, pgTAP 64/64); never on
the dev DB or production. Rehearse it after item 7.

Nothing below has been run against the cloud. Each item needs the owner's explicit approval after the backup, and is
applied in this order, each wrapped as `begin;` + file + `commit;` in one execution. Local state: all seven are applied
to the isolated local stack and covered by pgTAP (59/59) and the CI database job (rehearsed from scratch, batch AZ).

| # | Item | Cloud state (2026-10-13 read-only) | Changes | Data risk | Depends on |
|---|---|---|---|---|---|
| 1 | 20261007400000_handbook_v3 (corrected content) | Partly applied, unrecorded (pre-correction draft) | Replaces 38 handbook rows | Content only; restore from export P2 | Backup |
| 2 | 20261013100000_reliability_and_limits | Not applied | rate_events, coach_commit_turn, check_rate, limits, goal_levels policies | Deletes nothing | 1 (order only) |
| 3 | 20261014100000_custom_reminders | Not applied (not checked; created later) | New table custom_reminders, RLS, limit trigger | None (new table) | 2 |
| 4 | 20261016100000_food_diary | Not applied | New table food_log (FK foods.code), RLS, 60/day trigger | None (new table) | foods present |
| 5 | 20261016200000_food_micronutrients | Not applied | Adds 8 nullable columns to foods and fills them by code | Updates reference table foods only; no user data | foods = local (543 rows) |
| 6 | 20261016300000_recipes | Not applied | New tables recipes, recipe_items, save_recipe(), limit triggers | None (new tables) | 4 not required; foods present |
| 7 | 20261016400000_revoke_anon_user_tables | Not applied | Revokes anon privileges on 6 per-user tables | None (policies are authenticated-only) | 1-6 |
| 8 | 20261017100000_revoke_anon_sequences | Not applied | Revokes anon on the 4 public sequences and the default privilege | None | 7 |
| 9 | 20261023100000_coach_facts | Not applied | New table coach_facts, RLS, stamp trigger; copies coach_notes lines as unconfirmed suggestions | coach_notes unchanged | none |
| 10 | 20261023200000_thread_summaries | Not applied | Adds coach_threads.summary, summary_upto (+ update grant) | None (new nullable columns) | none |
| 11 | 20261024100000_exercise_swaps | Not applied | New table exercise_swaps (FK exercises), RLS, server-only writes | None (new table) | exercises present |
| 12 | 20261024200000_session_changes | Not applied | New table session_changes, RLS, server-only writes | None (new table) | none |
| 14 | 20261025200000_foods_usda_fdc | Not applied | Inserts 28 USDA FoodData Central rows (CC0; generated by data/build_foods_fdc.py from the SR Legacy 2018-04 release); adds foods.source_note; corrects soya chunks X001 to available carbohydrate (16.42 g, was the by-difference 33.92 g) | Reference data only; X001 values change | 13 |
| 15 | 20261027100000_diet_pace_region | Not applied | Adds dietary_profiles.diet_pace (easy/balanced/hard, default balanced) and cuisine_region (any/north/south/east/west, default any); plan engine 3.1.0 reads diet_pace | None (defaults keep plans unchanged) | 14 |
| 16 | 20261027200000_body_check_rate | Not applied | Redefines check_rate with a body_check_day bucket (3 a day) for functions/body-check | None | 15 |
| 17 | 20261027300000_app_errors | Not applied | New table app_errors (insert-only for users, 30 a day, 90-day removal, cascade on account delete) | None (new table) | 16 |
| 13 | 20261025100000_food_sources | Not applied | New table food_sources (licence metadata); foods.source, source_ref; the foods read policy shows only allowed sources | No rows changed or deleted. **Hides IFCT values from app roles** (see the update above) | foods present |

Items 3-7 were written after the 2026-10-13 cloud inspection, so their preflight checks below are the first evidence
for the cloud side and must all hold before applying.

### Migration 3: 20261014100000_custom_reminders
Preflight: `select to_regclass('public.custom_reminders') is null, to_regprocedure('public.custom_reminders_limit()') is null;` = t, t
Verify: `select relrowsecurity from pg_class where oid='public.custom_reminders'::regclass;` = t; `select count(*) from pg_policies where tablename='custom_reminders';` = 1; `select count(*) from information_schema.role_table_grants where table_name='custom_reminders' and grantee='anon';` = 0
Rollback: `drop table public.custom_reminders; drop function public.custom_reminders_limit();` (only reminders created after the apply are lost).

### Migration 4: 20261016100000_food_diary
Preflight: `select to_regclass('public.food_log') is null;` = t; `select count(*) from public.foods;` = 543 (FK target)
Verify: food_log RLS on, 1 policy "own food log", trigger food_log_limit present, anon grants 0.
Rollback: `drop table public.food_log; drop function public.food_log_limit();`

### Migration 5: 20261016200000_food_micronutrients
Preflight: `select count(*) from public.foods;` = 543; `select count(*) from information_schema.columns where table_name='foods' and column_name in ('calcium_mg','iron_mg','zinc_mg','sodium_mg','potassium_mg','magnesium_mg','vitamin_c_mg','folate_ug');` = 0. The file must equal `python data/build_food_micros.py` output (CI check).
Verify: `select count(calcium_mg), count(iron_mg), count(vitamin_c_mg), count(folate_ug) from public.foods;` = 527, 527, 229, 347; `select calcium_mg from public.foods where code='A013';` = 10.93
Rollback: drop the 8 columns (removes only the added values). Licence note: IFCT values are NIN data (reuse permission unconfirmed).

### Migration 6: 20261016300000_recipes
Preflight: `select to_regclass('public.recipes') is null, to_regclass('public.recipe_items') is null, to_regprocedure('public.save_recipe(text,int,jsonb)') is null;` = t, t, t
Verify: both tables RLS on; policies "own recipes" and "own recipe items"; triggers recipe_limit and recipe_item_limit; `select has_function_privilege('anon','public.save_recipe(text,int,jsonb)','execute'), has_function_privilege('authenticated','public.save_recipe(text,int,jsonb)','execute');` = f, t
Rollback: `drop table public.recipe_items; drop table public.recipes; drop function public.save_recipe(text,int,jsonb); drop function public.recipe_limits();`

### Migration 7: 20261016400000_revoke_anon_user_tables
Preflight: record the current anon privileges for rollback: `select table_name, string_agg(privilege_type, ',') from information_schema.role_table_grants where grantee='anon' and table_name in ('body_metrics','dietary_profiles','user_goals','workout_logs','generated_plans','profiles') group by 1;`
Verify: the anon_access query from supabase/tests/database/anon_access.test.sql returns '' (no anon privilege on any per-user table).
Rollback: re-grant exactly the privileges recorded in the preflight (not recommended; no app path uses them).

### Expected fingerprint after all seven (local, 2026-10-16)
`tools/schema_state.sql` on the local stack with all migrations applied: colgrant 388 682aff87dbf5, column 196
0b982e42ce0a, constraint 136 37ea2a261cdb, function 10 6eb323f36ac1, grant 54 95762d421802, index 48 485b6a69e1cc,
policy 31 bc1cd8cd2a05, trigger 6 78ac34100923. (`data` differs by design: cloud exercise rows and user data.)
Since 2026-10-16 tools/schema_state.sql has 12 kinds; the three newer ones on the same local state: defacl 6
9ce03ca47096 (order-insensitive), fngrant 3 240853d99cff, seqgrant 24 2f305b7bd611 (Levlofit-4, PROGRESS BZ). The
nine original kinds and their values are unchanged; for the "items 1-2 only" values below the newer kinds were never
computed, so compare them against production values taken in the backup window instead.
The values in "Verification after either option" above describe the state after items 1-2 only.
Item 8, measured 2026-10-17 on a fresh throwaway local database with all 34 migrations (project_id levlo_fresh_2h,
pgTAP 64/64): it changes only seqgrant 24 2f305b7bd611 -> **12 12aaba92b25e** (the 12 anon rows go) and defacl
9ce03ca47096 -> **35ea73e534f5**. The same run shows function **10 71dd873b0b71**, not 6eb323f36ac1: the value above
predates the batch CE function fixes; the dev DB (read-only check, refreshed in 2D) also has 71dd873b0b71. All other
kinds equal the values above; `data` differs by design.

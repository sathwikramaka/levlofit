# Production migration safety review (2026-10-16, read-only)

No production SQL, migration, deployment, commit, push or credential operation was run. Sources: the SQL of the seven
pending files, docs/MIGRATION_RECONCILIATION.md, tools/backup_prod.sh and backup_prod.ps1, app and function code.
The read-only queries below were syntax-tested inside `begin read only` on the LOCAL stack only; local values are
not evidence about production.

**What production evidence exists:** one read-only inspection on 2026-10-13 (migration records, schema fingerprint,
reference-data hashes, a few counts). Everything since then, including all five migrations written after that date,
has been verified only locally.

## 1. Per-migration review

### Item 1: 20261007400000_handbook_v3 (130 KB, modified in the working tree vs commit daaea96)
- **Objects/data:** `alter table handbook_chapters add column if not exists` slug (unique), part_title, summary,
  minutes, blocks (jsonb not null default '{}'); `delete from handbook_chapters` (all rows); insert of 38 rows with
  explicit ids 1-38. `search` is a generated column.
- **Type:** destructive replace of reference content (no user data). Column adds are no-ops in prod (columns exist).
- **Prerequisites/conflicts:** `goal_catalog.handbook_chapter` references `handbook_chapters(id)` with no ON DELETE:
  the delete aborts if any goal points at a chapter (2026-10-13: 0). Prod holds an unrecorded pre-correction draft
  (hash 432c7c6f); the file now produces af1ea000 (fresh local DB, all 34 migrations, 2026-10-18; was 81a79a56 before the 2026-10-18 handbook changes). The file has no explicit transaction: if run statement by
  statement, a failed insert leaves the table **empty** (app Handbook screen and coach passages break).
- **Rollback:** the documented rollback is "restore rows from export P2". There is no restore script yet and it has
  never been rehearsed. Without P2 or a restorable backup the old draft text is unrecoverable (it is not in git: git
  holds fe8b8740, not 432c7c6f).
- **Checks:** pre P1 (FK refs = 0), P2 (export rows), P3 (5 columns), Q5 hash = 432c7c6f, chapters = 38;
  post V1-V3 in the reconciliation doc.
- **Local-only assumptions:** ids and slugs equal to the new rows (checked 2026-10-13 only); text-search
  configuration identical (V3 hash may differ for that reason alone).

### Item 2: 20261013100000_reliability_and_limits (140 lines)
- **Objects/data:** `coach_messages.client_msg_id uuid` + partial unique index (user_id, client_msg_id) + column
  insert grant; function `coach_commit_turn` (security invoker; inserts thread/messages and, on edit, **deletes**
  later messages of that thread); table `rate_events` (RLS on, no grants) + index; function `check_rate` (security
  definer; deletes the caller's expired rate rows); trigger functions `limit_app_feedback` (5/day/user) and
  `limit_contact_messages` (3/day per email, 200/day total) with triggers; index `contact_messages_created_at`;
  goal_levels: **drops policy "own levels"** and creates four policies limiting inserts/updates to level 0-3.
- **Type:** additive objects plus **behaviour changes**: level 4-5 writes refused (old app builds get permission
  errors), feedback and contact form become rate-limited (website form returns an error above the limits).
- **Prerequisites/conflicts:** columns coach_messages.user_id/thread_id/role, coach_threads.updated_at,
  app_feedback.user_id/created_at, contact_messages.email/created_at (Q3); new object names absent (Q2); exactly
  one goal_levels policy "own levels" (Q4); `create policy` has no IF NOT EXISTS, so a name clash aborts the run.
- **Rollback:** drop the new objects and recreate "own levels". The original policy text must be captured from
  prod first (Q4); the reconciliation doc does not record it. Not restorable: coach messages deleted by the edit flow
  once the new coach-chat is deployed and used, and rate counters (disposable). Rolling back while the new
  coach-chat is deployed breaks its commit path (it falls back to the old save, per the runbook).
- **Checks:** pre R1-R4 + Q2-Q4; post W1-W7.
- **Local-only assumptions:** rehearsed on a recreated cloud pre-state on 2026-10-14 (rolled back); prod data volume
  (2 users, 4 messages on 2026-10-13) not re-checked.

### Item 3: 20261014100000_custom_reminders
- **Objects:** table custom_reminders (uuid pk, FK auth.users cascade, checks), index, RLS, column grants, policy,
  trigger function `custom_reminders_limit` (20/user, advisory lock; not security definer) + trigger.
- **Type:** additive. `create table` without IF NOT EXISTS: aborts cleanly if a table of that name exists.
- **Rollback:** drop table + function. Loses every reminder saved after the apply (the app keeps scheduling them
  locally until its next sync).
- **Checks:** pre Q2 (absent); post: RLS on, 1 policy, anon grants 0, trigger present.
- **Local-only:** written after the 2026-10-13 inspection; never compared with prod.

### Item 4: 20261016100000_food_diary
- **Objects:** table food_log (FK auth.users cascade, FK foods(code), meal/grams checks), index, RLS, grants,
  policy, trigger function `food_log_limit` (60/user/day) + trigger.
- **Type:** additive. **Prerequisite:** `foods.code` must be unique/PK in prod for the FK (Q3b below).
- **Rollback:** drop table + function; loses all diary entries made after the apply.
- **Local-only:** foods table assumed identical (543 rows); last compared 2026-10-13.

### Item 5: 20261016200000_food_micronutrients
- **Objects/data:** 8 nullable numeric columns with non-negative checks on `foods`; one UPDATE of `foods` by code
  from 542 VALUES rows.
- **Type:** additive columns + **data update of a reference table** (no user data). Public effect: anon and
  authenticated can read the new values through the existing table-level SELECT grant.
- **Prerequisite:** prod food codes equal the package codes. A code missing in prod is skipped silently; an extra prod
  code keeps nulls. Compare Q5 codes hash with local `66bf5cf3f1c8`.
- **Rollback:** drop the 8 columns: exact restore of the previous state (they are new).
- **Non-technical:** publishing IFCT micronutrient values needs NIN reuse permission (unresolved).

### Item 6: 20261016300000_recipes
- **Objects:** tables recipes, recipe_items (FK foods(code), FK auth.users cascade, checks), indexes, RLS, column
  grants, two policies (items only into own recipes), trigger function `recipe_limits` + two triggers, function
  `save_recipe(text,int,jsonb)` security invoker, execute granted to authenticated only.
- **Type:** additive. Same `foods.code` prerequisite as item 4.
- **Rollback:** drop both tables and two functions; loses recipes saved after the apply.

### Item 7: 20261016400000_revoke_anon_user_tables
- **Objects:** `revoke all` from anon on body_metrics, dietary_profiles, user_goals, workout_logs, generated_plans,
  profiles (table and column privileges).
- **Type:** **permission removal** (behaviour change only for signed-out callers; all policies on these tables are
  `to authenticated`, so no row was reachable anyway).
- **Prerequisite:** no prod client reads these tables signed-out (app and website code: none found).
- **Rollback:** re-grant exactly what Q6/Q6b recorded before the apply; without that record the original grant set
  cannot be reconstructed.

### Cross-cutting
- **Order:** apply 1 -> 7, then deploy functions, then release a matching app build. The current app and functions
  tolerate missing new tables (errors handled), but a new app build against an un-migrated database shows error
  states.
- **History:** Option B (forward-only) leaves `supabase_migrations.schema_migrations` without records for these
  items unless records are inserted deliberately; `supabase db push` must then never be used.
- **Transactions:** none of the seven files contains `begin/commit`; each must be wrapped explicitly. Whether the
  chosen tool (Dashboard SQL editor, `db query`) honours one explicit transaction must be confirmed.

## 2. Read-only checks to establish production state (run only with your approval)

Run once inside `begin read only;` ... `rollback;`, save the output with the backup, and compare with expectations.
Local post-migration values are NOT the expected production values; expected production values come from a local
rehearsal database built to the assumed production state (section 4).

```sql
-- Q0 identity and engine (confirms project and Postgres major version for the restore test)
select current_database(), version(), now();
-- Q1 migration history (export in full with the backup)
select version, name from supabase_migrations.schema_migrations order by version;
-- Q2 objects items 2-7 would create: every value must be true (absent)
select to_regclass('public.rate_events') is null, to_regprocedure('public.coach_commit_turn(uuid,text,bigint,uuid,text,text)') is null,
  to_regprocedure('public.check_rate(text,integer,interval)') is null, to_regprocedure('public.limit_app_feedback()') is null,
  to_regprocedure('public.limit_contact_messages()') is null, to_regclass('public.custom_reminders') is null,
  to_regclass('public.food_log') is null, to_regclass('public.recipes') is null, to_regclass('public.recipe_items') is null,
  to_regprocedure('public.save_recipe(text,integer,jsonb)') is null,
  (select count(*) from information_schema.columns where table_schema='public' and table_name='coach_messages' and column_name='client_msg_id') = 0,
  (select count(*) from information_schema.columns where table_schema='public' and table_name='foods' and column_name in
   ('calcium_mg','iron_mg','zinc_mg','sodium_mg','potassium_mg','magnesium_mg','vitamin_c_mg','folate_ug')) = 0;
-- Q3 columns the new SQL relies on (expect 9) and Q3b foods.code is unique (expect 1)
select count(*) from information_schema.columns where table_schema='public' and (table_name, column_name) in
  (('coach_messages','user_id'),('coach_messages','thread_id'),('coach_messages','role'),('coach_threads','updated_at'),
   ('app_feedback','user_id'),('app_feedback','created_at'),('contact_messages','email'),('contact_messages','created_at'),('foods','code'));
select count(*) from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey)
  where i.indrelid = 'public.foods'::regclass and i.indisunique and i.indnkeyatts = 1 and a.attname = 'code';
-- Q4 goal_levels policies with full text (expect only "own levels"; keep for item 2 rollback)
select policyname, cmd, roles::text, qual, with_check from pg_policies where schemaname='public' and tablename='goal_levels';
-- Q5 data prerequisites
select (select count(*) from public.goal_catalog where handbook_chapter is not null) as fk_refs_expect_0,
  (select count(*) from public.goal_levels where level > 3) as levels_above_3_expect_0,
  (select count(*) from public.foods) as foods_expect_543,
  (select left(md5(string_agg(code, ',' order by code)), 12) from public.foods) as codes_expect_66bf5cf3f1c8,
  (select count(*) from public.handbook_chapters) as chapters_expect_38,
  (select left(md5(string_agg(h::text, '' order by h::text)), 8) from public.handbook_chapters h) as handbook_expect_432c7c6f;
-- Q6 / Q6b all anon and authenticated grants (table and column level; item 7 rollback record, prod-only grants)
select grantee, table_name, string_agg(privilege_type, ',' order by privilege_type) from information_schema.role_table_grants
  where table_schema='public' and grantee in ('anon','authenticated') group by 1,2 order by 2,1;
select grantee, table_name, privilege_type, string_agg(column_name, ',' order by column_name) from information_schema.role_column_grants
  where table_schema='public' and grantee in ('anon','authenticated') group by 1,2,3 order by 2,1,3;
-- Q7 user-data row counts (must be unchanged after every item)
select (select count(*) from auth.users), (select count(*) from public.profiles), (select count(*) from public.coach_threads),
  (select count(*) from public.coach_messages), (select count(*) from public.goal_levels), (select count(*) from public.contact_messages),
  (select count(*) from public.app_feedback), (select count(*) from public.workout_logs), (select count(*) from public.generated_plans);
-- Q8 prod-only functions, triggers, policies that could collide
select string_agg(proname, ',' order by proname) from pg_proc where pronamespace = 'public'::regnamespace;
select string_agg(event_object_table || '.' || trigger_name, ',' order by 1) from information_schema.triggers where trigger_schema='public';
select count(*), left(md5(string_agg(tablename || '.' || policyname, ',' order by 1)), 12) from pg_policies where schemaname='public';
-- Q9 full fingerprint (compare with the rehearsal database at the assumed prod state, not with the local dev stack)
-- run tools/schema_state.sql
-- Q10 activity (apply in a quiet moment)
select count(*) filter (where state = 'active'), count(*) from pg_stat_activity where datname = current_database();
```
Outside SQL (read-only): deployed function names and versions (Dashboard > Edge Functions), function secrets present
(names only), plan tier and backup list (Dashboard > Database > Backups), auth settings unchanged.

## 3. Backup procedure review (tools/backup_prod.sh / .ps1)

> **Status 2026-10-16 (Levlofit-4): this section describes the pre-v2 script and is superseded by
> docs/BACKUP_RECOVERY_PLAN.md.** Gaps 1, 2, 3 and 5 below are now handled by the tools (Storage copy, migration
> history and platform-schema dumps, an isolated restore verified locally, backup_seal.sh encryption); the restore
> drill below must use BACKUP_RECOVERY_PLAN.md sections 6-7 instead (tmpfs and no volume, restore_preload/postload,
> 12-kind comparison). Gap 4 (Free plan backups) is unchanged. Nothing here has been run against production.

**What it does:** prompts for the session-pooler connection string with hidden input, masks secrets in logs, runs
`supabase db dump` three times (roles, schema, data with COPY), writes SHA256SUMS, checks that 17 expected public
tables exist in schema.sql, that every COPY block in data.sql is terminated, and that auth.users rows were exported.
Output goes to C:/Projects/levlo-secure-backups (outside the repo).

**Gaps:**
1. **Storage files** (progress photos, avatars) are not in a database dump. None of the seven items touches storage,
   but a full restore would lack the files.
2. **Migration history** (`supabase_migrations`) may be excluded by `supabase db dump`; export Q1 separately before
   any history change (Option A step 2 already asks for it).
3. **No restore has ever been tested.** A dump that passes the script's checks can still fail to load (roles,
   extensions, Supabase-managed schemas).
4. **Free plan**: no self-service restorable backups were confirmed; the logical dump is likely the only backup.
5. The output folder holds personal data in plain files; encrypt it (e.g. BitLocker folder or 7-Zip AES) and keep it
   off any synced folder.

**Verification (owner, no production writes):**
1. Script prints PASS; `sha256sum -c SHA256SUMS` passes later from the encrypted copy.
2. Row counts in DATA_ROWS equal Q7 taken in the same window (no writes between).
3. Restore drill (below) passes.

**Restore drill without touching production:** a throwaway container from the same image family and Postgres major
version as production (Q0), e.g. `public.ecr.aws/supabase/postgres:<prod version>`, started **without published ports**
(access only via `docker exec`), separate volume, never the local dev stack. Load roles.sql, schema.sql, data.sql with
`psql -v ON_ERROR_STOP=1 --single-transaction`; compare per-table counts with DATA_ROWS and `tools/schema_state.sql`
with the production fingerprint taken at backup time; also apply the seven items to that copy in order and run every
pre/post check: this is the closest rehearsal of the real change on real data. Then remove the container and volume
(they hold personal data), with your approval. This proves the dump loads; restoring INTO production remains a
separate, destructive last-resort procedure.

## 4. Risk table

| # | Migration | Type | Data risk | Behaviour change | Rollback quality | Prod-only unknowns | Risk |
|---|---|---|---|---|---|---|---|
| 1 | handbook_v3 | Destructive replace (content) | Old draft lost without P2/backup; empty table if not atomic | Handbook text changes | Needs P2 export + an unwritten, untested restore script | FK refs, ids/slugs, current hash | **Medium** |
| 2 | reliability_and_limits | Additive + policy swap | None at apply; edit-flow deletes later are not restorable | Levels capped at 3; feedback and contact rate limits | Needs Q4 policy text; drop objects is safe | Columns, policy set, level>3 rows, prod-only objects | **Medium** |
| 3 | custom_reminders | Additive | None | New feature table | Drop loses post-apply reminders | Name collision | Low |
| 4 | food_diary | Additive | None | New feature table | Drop loses post-apply diary | foods.code unique | Low |
| 5 | food_micronutrients | Additive cols + reference-data update | None (reference data) | New public columns | Exact (drop columns) | Prod codes = package codes | Low (licence open) |
| 6 | recipes | Additive | None | New feature tables + function | Drop loses post-apply recipes | foods.code unique | Low |
| 7 | revoke_anon_user_tables | Permission removal | None | Signed-out access removed | Needs Q6/Q6b record | Prod-only anon grants or clients | Low-Medium |

## 5. Unresolved questions before the first production change

1. Backup: has the owner-run dump been taken, does it pass the script and the restore drill, and where is the
   encrypted copy? Is the plan Free (no restorable dashboard backups)?
2. Approval to run the read-only checks (section 2) on production, and who runs them (owner CLI vs. tool access)?
3. Do Q2-Q8 match the assumed state (especially handbook hash 432c7c6f, FK refs 0, foods codes hash, single
   "own levels" policy, no prod-only objects or grants)?
4. Option A (re-align history, then `db push`) or Option B (forward-only, records not added)? If B, should history
   records be inserted deliberately?
5. Which execution path, and does it run each wrapped file as one transaction?
6. Handbook: should prod receive the corrected v3 now, given the v4 rewrite awaits clinical review? Who writes and
   tests the P2 restore script?
7. Are there real users or app builds in use now (2026-10-13: 2 users)? Old builds hit the level cap.
8. Are the contact-form limits (3/day per email, 200/day total) and feedback limit (5/day) approved?
9. Is publishing IFCT micronutrient values cleared with NIN (item 5)?
10. Deploy order and timing: functions immediately after items 1-7, app release only after the smoke test?
11. Postgres major version in prod (for the restore drill image) and a quiet window (Q10)?

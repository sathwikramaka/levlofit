# Levlofit backup and recovery plan (updated 2026-10-16, Levlofit-4)

Status: **tooling implemented and verified on LOCAL and synthetic data only.** No production backup, query, Storage
copy, migration or deployment has been run by Claude. The migration plan is **not** declared safe: that needs a real
production backup restored in isolation and the seven pending items rehearsed on that copy (section 10, stages 2-5).

Evidence: PROGRESS batches BS (first drill), BU-BY (v1/v2 proposal, review, apply, LF rule) and BZ (hardening and full
re-verification). Exact script history: docs/proposed_backup_changes.diff (v1, never applied: two bugs),
docs/proposed_backup_changes_v2.diff (approved and applied), docs/backup_hardening_after_v2.diff (eight defects fixed
in batch BZ; `git apply` of it onto v2 reproduces the current tools/ files byte for byte).

## 1. Tools

| File | Purpose | Run by |
|---|---|---|
| tools/backup_prod.ps1 | PowerShell entry point: hidden prompts for the connection string and a personal access token, restricts the backup root to the current user + SYSTEM (and refuses if any other entry remains), passes secrets only as environment variables, clears them on every exit path | Owner |
| tools/backup_prod.sh | Dumps, Storage copy, completeness checks, BACKUP_PASS marker, SHA256SUMS. `BACKUP_TARGET=local` = rehearsal against the local stack only | Owner (production) / Claude (local) |
| tools/backup_seal.sh | gpg AES-256 encryption of a passing backup folder with a streaming round-trip proof | Owner |
| tools/restore_preload.sql, tools/restore_postload.sql | Default-privilege handling around an isolated restore (section 6) | Claude, isolated container |
| tools/schema_state.sql | 12-kind read-only fingerprint (colgrant, column, constraint, data, defacl, fngrant, function, grant, index, policy, seqgrant, trigger) | Both |
| .gitattributes | `tools/*.sh text eol=lf` | n/a |

## 2. What one backup folder contains

| File | Source | Notes |
|---|---|---|
| roles.sql | `db dump --role-only` | Custom roles and settings; **no passwords**; platform role CREATE/ALTER lines are commented out |
| schema.sql | `db dump` | `public` only, incl. grants and the postgres role's public default privileges (additive GRANT lines only) |
| data.sql | `db dump --data-only --use-copy` | public, auth (users, identities, sessions, refresh tokens, MFA, audit log), storage metadata, supabase_functions |
| platform_schema.sql | `db dump --schema auth,storage,supabase_functions,supabase_migrations` | DDL a restore needs (a fresh image ships older auth/storage tables) |
| migration_history.sql | `db dump --data-only --use-copy --schema supabase_migrations` | Every applied migration (local: 33 rows) |
| storage/&lt;bucket&gt;/&lt;object name&gt; | `storage cp -r` per bucket listed in data.sql | Layout verified with the real CLI (batch BZ): nested names and spaces kept; empty buckets give an empty folder |
| DATA_ROWS, SCHEMA_TABLES, STORAGE_EXPECTED, STORAGE_FILES | the script's checks | counts and names only, no row contents |
| *.log | masked CLI output | connection string, password (all encodings), token masked |
| BACKUP_PASS | written only when every check passed | backup_seal.sh refuses folders without it |
| SHA256SUMS | last step, every file in the folder | |

Not in any backup: vault secrets, Edge Function secrets, Auth provider settings (OAuth client, redirect URLs, email
templates), API keys, `auth.schema_migrations` and `storage.migrations` (the CLI excludes them), Edge Function code (in
the repository). Settings and secrets are listed by name in the release checklist and re-entered by the owner if a
project ever has to be rebuilt.

## 3. Checks backup_prod.sh performs (all FAIL loudly; no BACKUP_PASS on any failure)

- Connection string must contain the production ref (or, in local mode, be exactly the local URL); `[YOUR-PASSWORD]`
  and a missing password are refused before anything is written.
- Backup folder must be outside the repository (case-insensitive) and must not already exist (no overwrite).
- Each dump must exit 0 and be non-empty; the run stops at the first failure.
- 17 expected public tables (production's list **before** the pending migrations), auth.users and storage.objects DDL
  present, every COPY block terminated, auth.users rows > 0, migration history rows > 0.
- Bucket ids must be plain names (`^[A-Za-z0-9_][A-Za-z0-9._-]*$`), so they cannot write outside storage/.
- Every storage.objects row has a copied file and every copied file has a row.
- The Storage CLI gets `</dev/null`, so it cannot consume the bucket list (a second bucket was silently skipped before).

## 4. Encryption and key handling (backup_seal.sh)

- Refuses: not a folder, name not `levlo-*`, no BACKUP_PASS, SHA256SUMS mismatch, files not listed in SHA256SUMS,
  existing `.tar.gpg`, a `.partial` left by a crashed earlier run.
- `tar | gpg --symmetric --cipher-algo AES256 --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712
  --no-symkey-cache` into `<name>.tar.gpg.partial`; then decrypts into a pipe and hashes every archive member as it
  streams past (GNU tar `--to-command`): **no decrypted file is written**. Only on a byte-for-byte match is the file
  renamed to `.tar.gpg` and `.tar.gpg.sha256` written. On any failure (wrong passphrase, damaged output, interrupted
  gpg) its own unverified `.partial` is removed and the plaintext folder is kept.
- Passphrase: long and random, stored **only** in the owner's password manager; gpg asks in its own prompt (the
  Windows pinentry dialog), twice to encrypt and once to verify. Never on a command line, in a file, chat or email.
- Copies: the `.tar.gpg` and its `.sha256` on an offline drive kept apart from the device holding the password
  manager. BitLocker is on for C: (protects the disk when the machine is off, not against the signed-in session).
- Plaintext removal after a verified offline copy is a deletion of personal data: owner decision.
- `--legacy` (batch CB) seals a folder made by the pre-v2 script: no BACKUP_PASS needed, but SHA256SUMS must verify
  and must cover roles.sql, schema.sql and data.sql; the other files are sealed as they are. Tested on synthetic
  legacy-shaped folders: 12/12 (refused without the flag, sealed with it, tampered dump refused, incomplete
  SHA256SUMS refused, wrong passphrase fails cleanly). The real 2026-10-14 folder's SHA256SUMS covers exactly those
  three dumps and verifies, so this command applies to it.

## 5. Running it (owner)

```powershell
powershell -ExecutionPolicy Bypass -File tools\backup_prod.ps1
```
```bash
bash tools/backup_seal.sh /c/Projects/levlo-secure-backups/levlo-pre-migration-<timestamp>
```
Use the Session pooler connection string and a personal access token created for this run (revoke it afterwards).
Never `supabase link`: it writes the production ref into supabase/.temp, after which later CLI commands could target
production. Run tools/schema_state.sql (12 kinds) and the read-only Q0-Q8 queries of
docs/PROD_MIGRATION_SAFETY_REVIEW.md in the same quiet window, before and after the backup.

## 6. Isolated restore (procedure that passed locally)

Container: same image as production's Postgres (`public.ecr.aws/supabase/postgres:<version from Q0>`; local tests used
17.6.1.171), `--network none`, no published ports, no volumes, data and the decrypted backup in tmpfs (RAM), `--rm`:

```bash
docker run -d --rm --name levlo_restore_drill --network none \
  --tmpfs /var/lib/postgresql/data:rw,size=2g --tmpfs /restore:rw,size=512m \
  -e POSTGRES_PASSWORD="$(openssl rand -hex 24)" <image>
```
1. `sha256sum -c <name>.tar.gpg.sha256`, then `gpg --decrypt <name>.tar.gpg | docker exec -i levlo_restore_drill tar
   -xf - -C /restore` (Git Bash: `MSYS_NO_PATHCONV=1`), then the inner SHA256SUMS inside the container (BusyBox:
   `sed 's/ \*/  /' SHA256SUMS | sha256sum -c -s -`).
2. As `supabase_admin` (in this image `postgres` is not a full superuser), each step with `-v ON_ERROR_STOP=1
   --single-transaction`: placeholder roles named in `TO "x"` / `OWNER TO "x"` lines that the image lacks; drop the
   image's auth, storage, supabase_functions, supabase_migrations schemas; **tools/restore_preload.sql**;
   platform_schema.sql without the `on_auth_user_created` trigger; roles.sql; schema.sql; data.sql;
   migration_history.sql; the trigger line; **tools/restore_postload.sql**.

Why preload/postload: Supabase databases grant anon and authenticated everything on new public objects through
default privileges, and pg_dump never emits a REVOKE for privileges the source lacked. Without the preload, the local
negative control (batches BV, BY, BZ) gave grant 54 -> 378, colgrant 388 -> 1568, fngrant 3 -> 20, anon EXECUTE on all
10 public functions (4 of them security-definer; `check_rate` actually ran as anon), anon privileges on 27 instead of
5 tables, and lost migration 20261003000000's TRUNCATE/REFERENCES/TRIGGER default revoke. The dump restores postgres's
public defaults but never supabase_admin's, so the postload puts back the image's own supabase_admin defaults.

**On a hosted Supabase project** (a real disaster recovery) only the three `for role postgres` lines of the preload
can run (postgres cannot alter supabase_admin's defaults); the grant comparison in section 7 is then mandatory.

## 7. Verifying the restored copy

- tools/schema_state.sql on source and copy, both after `set search_path to public, extensions;` (otherwise policy
  texts render `uid()` and differ): all 12 kinds identical.
- Default privileges per role (postgres and supabase_admin, public schema), migration history (count + hash of
  version:name), storage.objects names = the backup's STORAGE_FILES, buckets, RLS on every public table, auth.users
  (count + id hash), anon EXECUTE on security-definer functions = 0.
- Signed-out probe (rolled back): anon privileges per table, function and sequence; rows anon can read; direct
  attempts on check_rate, save_recipe, profiles and food_log must be refused. Identical to the source.
- Row counts of all applicable tables equal the source (local: 63 of 63; `auth.schema_migrations` and
  `storage.migrations` are 0 in the copy because the CLI does not dump them).
- Storage bytes are verified by SHA256SUMS (a database-only container cannot hold Storage files).

## 8. Cleanup

`docker stop` removes the container and everything in its tmpfs; confirm with `docker ps -a` and `docker volume ls`
(no new container or volume). Any decrypted or plaintext folder outside a container is personal data: removed only
with the owner's approval. Keep the encrypted backup and its `.sha256`.

## 9. Evidence and limits

### Verified locally (synthetic data or the local stack; batch BZ unless noted)

| Area | Result |
|---|---|
| Local rehearsal, real CLI | PASS; 5 dumps; 63/63 table counts = live; 3 buckets (one empty, one synthetic with 4 nested objects incl. a space in the path, one empty extra); copied bytes = synthetic originals 4/4 |
| Failure cases, stub CLI | 41/41 (suite v3): truncated/empty/failing dumps, unexpected/missing Storage files, empty history, invalid URLs (other project, local mismatch, placeholder, no password), unsafe bucket id, second run into an existing folder, backup root inside the repo, seal refusals; masked logs |
| Seal | 36/36 (suite v3): AES-256 packet; no plaintext written; tamper detected by sha256 and gpg; corruption, wrong passphrase and interrupted gpg all FAIL with no `.partial`/`.tar.gpg` left; rerun after failure works; unlisted file, stale `.partial`, missing BACKUP_PASS refused |
| PowerShell wrapper, stub CLI | 16/16: env cleared after success and failure, 0 leaks, root ACL owner + SYSTEM only, extra ACE refused, root inside repo refused, bad URLs refused |
| Sealed backup -> RAM-only restore | inner SHA256SUMS ok; 12/12 kinds, default ACLs, history (33, same hash), storage.objects names (4/4), auth users, RLS, signed-out probe identical; 0 load errors |
| Negative control | detected by both the fingerprint and the probe (numbers in section 6) |
| .gitattributes | disposable repos, index + checkout-index only (no commit): with the rule the 3 tools/*.sh check out LF, every other file as before; without it they check out CRLF. Git Bash 5.3.15 tolerates CRLF scripts; Linux bash does not (`set: pipefail\r: invalid option name`) |

### Not verified

- Production Storage download with a real token (`--project-ref`), and buckets with versioning or delete markers.
- gpg's interactive Windows passphrase dialog (tests used a loopback passphrase file).
- Object names containing tabs, newlines or backslashes (COPY-text escaping is not decoded).
- A real hosted-project restore (only the postgres preload lines can run there).
- Checkout conversion after an actual commit in this repository (only shown in disposable repos).

### Production-specific unknowns

- Production's Postgres image version (Q0), its supabase_admin default privileges (postload assumes the image
  defaults; a difference shows as a `defacl` mismatch) and production values of the three newer kinds.
- Whether production uses Storage features the local stack does not (versioning, other bucket types).
- An earlier backup folder exists: `C:/Projects/levlo-secure-backups/levlo-pre-migration-20261014T162118Z` (22 public
  tables, 55 COPY blocks, 1 Storage object metadata row, checksums verify; made with the pre-v2 script, so no Storage
  files, no history, no BACKUP_PASS). Its contents match production's shape, not the local stack's; it is
  **unencrypted** and is not recorded elsewhere in these docs. The backup root's ACL also grants BUILTIN\Administrators,
  which makes the hardened wrapper stop until that entry is removed.

### Release blockers (backup and recovery)

1. Owner-run production backup with the hardened tools, sealed and copied offline (stage 2-3).
2. Isolated restore of that real backup with every section 7 check (stage 4).
3. Rehearsal of the seven pending migrations on the restored copy (stage 5).
4. Unencrypted 2026-10-14 folder: minimum safe action = owner runs `bash tools/backup_seal.sh --legacy <folder>`, keeps an
   offline copy, and only then decides on deleting the plaintext (docs/RELEASE_CHECKLIST.md 0.1-0.3).

## 10. Execution checklist (each gate needs the listed evidence before the next)

| Stage | Action | Who | Approval | Evidence required to continue |
|---|---|---|---|---|
| 0 | Local drill of the whole procedure | Claude | done (BS) | 63/63 counts, 9 kinds, RLS, anon blocked |
| 1 | Apply and verify the script changes | Claude | done (v2 approved: BW; hardening: BZ) | Section 9 "Verified locally" |
| 2 | Production backup: dumps, history, platform schema, Storage, schema_state (12 kinds) and Q0-Q8 before/after, one quiet window | **Owner** (credentials stay with the owner) | **Yes** (production access) | Script PASS; BACKUP_PASS; Q7 before = after; history rows = Q1 |
| 3 | Seal; offline copy; verify `.sha256` there | Owner | Yes (later plaintext removal) | backup_seal.sh PASS |
| 4 | Isolated restore of the **real** backup (sections 6-7) | Claude, on the owner's machine | **Yes** (personal data) | All section 7 checks equal to the production values from stage 2 |
| 5 | Rehearse items 1-7 on the restored copy, each with preflight and post checks | Claude | Yes | Every check passes; final fingerprint = expected after-seven values (local values: colgrant 388, column 196, constraint 136, defacl 6, fngrant 3, function 10, grant 54, index 48, policy 31, seqgrant 24, trigger 6), adjusted only for production-only objects found in Q8 |
| 6 | Cleanup of the drill container and any plaintext | Claude/owner | Yes (deletion) | No container, volume or plaintext left |
| 7 | Decide Option A or B; authorise item 1 alone | Owner | **Yes, per item** | Stages 2-6 evidence |

Until stages 2-5 pass on real production data, the migration plan remains **unproven**.

#!/usr/bin/env bash
# Owner-run pre-migration backup of the levlo cloud database (Free plan: no scheduled backups).
# Read-only on the database. Prompts for the connection string without echoing it; never writes it to disk or logs.
# Usage: run tools/backup_prod.ps1 from PowerShell (recommended: it keeps the password out of command lines), or
#        bash tools/backup_prod.sh in Git Bash with the full connection string at the prompt.
# Password: either inside the connection string, or (from the PowerShell wrapper) a connection string without password
#        plus PGPASSWORD in this process's environment, which the Supabase CLI passes to pg_dump.
# Storage files: copied with `supabase storage cp --project-ref` (never `supabase link`), authorised by a personal
#        access token (SUPABASE_ACCESS_TOKEN from the PowerShell wrapper, or prompted here, input hidden). The token has
#        full account scope; this script uses it only for the Storage download and passes it to no other command.
# Output: C:/Projects/levlo-secure-backups/levlo-pre-migration-<UTC timestamp>/ (outside the repo; contains personal data).
#        Encrypt it afterwards with tools/backup_seal.sh.
# Rehearsal: BACKUP_TARGET=local accepts only the local stack's connection string and copies local Storage.
# Stops at the first failed or empty dump. Logs contain CLI messages only, with any connection string masked.
set -uo pipefail
umask 077
TOKEN=${SUPABASE_ACCESS_TOKEN:-}; unset SUPABASE_ACCESS_TOKEN   # kept unexported; given to storage cp only
REF=ndeozgxowggkljluaccz
LOCAL_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
if [ "${BACKUP_TARGET:-}" = local ]; then
  OUT="${BACKUP_ROOT:-/c/Projects/levlo-secure-backups}/levlo-LOCAL-rehearsal-$(date -u +%Y%m%dT%H%M%SZ)"
  STORAGE_TARGET=(--local --workdir "$(cd "$(dirname "$0")/.." && pwd)")   # local keys come from supabase/config.toml
else
  OUT="${BACKUP_ROOT:-/c/Projects/levlo-secure-backups}/levlo-pre-migration-$(date -u +%Y%m%dT%H%M%SZ)"
  STORAGE_TARGET=(--project-ref "$REF")
fi

printf 'Paste the Session pooler connection string (Dashboard > Connect), input hidden: '
IFS= read -rs DB_URL; echo
DB_URL=${DB_URL#$'\xEF\xBB\xBF'}; DB_URL=${DB_URL%$'\r'}   # Windows pipes may add a UTF-8 BOM and a trailing CR
if [ "${BACKUP_TARGET:-}" = local ]; then
  [ "$DB_URL" = "$LOCAL_URL" ] || { unset DB_URL; echo "BACKUP_TARGET=local accepts only $LOCAL_URL; stopping."; exit 1; }
else
  case "$DB_URL" in
    postgres://*"$REF"*|postgresql://*"$REF"*) ;;
    *) unset DB_URL; echo "Not a levlo connection string; stopping."; exit 1 ;;
  esac
  if [ -z "$TOKEN" ]; then
    printf 'Paste a Supabase personal access token for the Storage copy (Account > Access Tokens), input hidden: '
    IFS= read -rs TOKEN; echo; TOKEN=${TOKEN%$'\r'}
  fi
  [ -n "$TOKEN" ] || { unset DB_URL; echo "No access token; stopping."; exit 1; }
fi

# Password = text between the first ':' of the userinfo and the LAST '@' (tolerates an unencoded '@' in the password).
# Pure bash parameter expansion: no regex or sed is built from the secret.
PW_RAW="" PW_DEC=""
rest=${DB_URL#*://}; userinfo=${rest%@*}
if [ "$userinfo" != "$rest" ]; then case "$userinfo" in *:*) PW_RAW=${userinfo#*:} ;; esac; fi
unset rest userinfo
case "$PW_RAW" in *YOUR-PASSWORD*) unset DB_URL PW_RAW; echo "Replace [YOUR-PASSWORD] in the connection string; stopping."; exit 1 ;; esac
if [ -z "$PW_RAW" ] && [ -z "${PGPASSWORD:-}" ]; then
  unset DB_URL; echo "No password in the connection string and no PGPASSWORD; stopping."; exit 1
fi

pct_decode() {  # pct_decode <in> <outvar>: one-pass %XX decode; every other character (incl. \ and +) is kept literally
  local LC_ALL=C s=$1 out="" c i=0
  while [ $i -lt ${#s} ]; do
    c=${s:i:1}
    if [ "$c" = "%" ] && [[ ${s:i+1:2} =~ ^[0-9A-Fa-f]{2}$ ]]; then printf -v c "\\x${s:i+1:2}"; i=$((i+3)); else i=$((i+1)); fi
    out+=$c
  done
  printf -v "$2" '%s' "$out"
}
if [ -n "$PW_RAW" ]; then pct_decode "$PW_RAW" PW_DEC; else PW_DEC=$PGPASSWORD; fi   # PGPASSWORD holds the decoded form

pct_encode() {  # pct_encode <in> <outvar> <hexcase:upper|lower>: %XX for every byte outside A-Z a-z 0-9 - . _ ~
  local LC_ALL=C s=$1 out="" c i=0 fmt='%%%02X'
  [ "$3" = lower ] && fmt='%%%02x'
  while [ $i -lt ${#s} ]; do
    c=${s:i:1}
    case "$c" in [A-Za-z0-9._~-]) out+=$c ;; *) printf -v c "$fmt" "'$c"; out+=$c ;; esac
    i=$((i+1))
  done
  printf -v "$2" '%s' "$out"
}
# Re-encoded forms of the password are masked too, whichever form the connection string used.
pct_encode "$PW_DEC" PW_ENC_U upper; pct_encode "$PW_DEC" PW_ENC_L lower
bs='\'; dq='"'                                                   # JSON-escaped form: \ -> \\ and " -> \" (quoted = literal)
PW_JSON=${PW_DEC//"$bs"/"$bs$bs"}; PW_JSON=${PW_JSON//"$dq"/"$bs$dq"}
# The backup holds personal data: never inside the repository, never into an existing folder (no overwrite).
REPO=$(realpath -m "$(dirname "$0")/.."); OUTP=$(realpath -m "$OUT")   # compared case-insensitively (Windows paths)
case "${OUTP,,}/" in "${REPO,,}"/*) unset DB_URL; echo "Backup folder must be outside the repository; stopping."; exit 1 ;; esac
mkdir -p "$(dirname "$OUT")" && mkdir "$OUT" || { unset DB_URL; echo "Cannot create $OUT (or it already exists); stopping."; exit 1; }

mask() {  # mask <text>: quoted patterns in ${s//"$x"/...} are literal, so special characters cannot break them
  local s=$1 d
  s=${s//"$DB_URL"/<db-url>}
  [ -n "$PW_RAW" ] && s=${s//"$PW_RAW"/<pw>}
  [ -n "$PW_DEC" ] && s=${s//"$PW_DEC"/<pw>}
  [ -n "$PW_ENC_U" ] && s=${s//"$PW_ENC_U"/<pw>}
  [ -n "$PW_ENC_L" ] && s=${s//"$PW_ENC_L"/<pw>}
  [ -n "$PW_JSON" ] && s=${s//"$PW_JSON"/<pw>}
  [ -n "$TOKEN" ] && s=${s//"$TOKEN"/<token>}
  # Any other percent-encoding of the password (any mix of escaped characters or hex case): decode the text once and
  # mask the decoded password; the log then keeps the decoded text.
  if [ -n "$PW_DEC" ]; then pct_decode "$s" d; [[ $d == *"$PW_DEC"* ]] && s=${d//"$PW_DEC"/<pw>}; fi
  # Fixed patterns only (no secret inside): any postgres URL, and password fields such as password=..., "password": "...",
  # PGPASSWORD=...; quoted values (including escaped quotes inside them) are masked whole.
  printf '%s\n' "$s" | sed -E \
    -e 's#postgres(ql)?://[^[:space:]"'\'']+#<db-url>#g' -e 's/sbp_[A-Za-z0-9_]+/<token>/g' \
    -e 's/(password"?[[:space:]]*[=:][[:space:]]*)("([^"\\]|\\.)*"|'\''[^'\'']*'\''|[^[:space:],;&]+)/\1<pw>/gI'
}

dump() {  # dump <file> <args...>: stop on non-zero exit or empty file
  local f=$1; shift
  local out rc
  out=$(supabase db dump --db-url "$DB_URL" -f "$OUT/$f" "$@" 2>&1); rc=$?
  mask "$out" > "$OUT/$f.log"
  if [ $rc -ne 0 ]; then
    echo "FAIL $f: exit=$rc (masked log: $OUT/$f.log)"; unset DB_URL PW_RAW PW_DEC PW_ENC_U PW_ENC_L PW_JSON PGPASSWORD TOKEN; exit 1
  fi
  if [ ! -s "$OUT/$f" ]; then
    echo "FAIL $f: exit=0 but file is empty (masked log: $OUT/$f.log)"; unset DB_URL PW_RAW PW_DEC PW_ENC_U PW_ENC_L PW_JSON PGPASSWORD TOKEN; exit 1
  fi
  echo "OK   $f: exit=0, $(wc -c < "$OUT/$f") bytes"
}

dump roles.sql --role-only
dump schema.sql
dump data.sql --data-only --use-copy
dump platform_schema.sql --schema auth,storage,supabase_functions,supabase_migrations   # source DDL for the restore
dump migration_history.sql --data-only --use-copy --schema supabase_migrations          # history is in no other dump
DB_URL= PW_RAW= PW_DEC= PW_ENC_U= PW_ENC_L= PW_JSON=; unset PGPASSWORD   # emptied, not unset: mask() runs under set -u

cd "$OUT" || exit 1

copycol() {  # copycol <"schema"."table"> <column>: one column of a data.sql COPY block (COPY text format, unescaped)
  awk -v t="COPY $1 (" -v c="\"$2\"" '
    index($0, t) == 1 { h = $0; sub(/^[^(]*\(/, "", h); sub(/\) FROM stdin;$/, "", h)
                        n = split(h, cols, ", "); for (i = 1; i <= n; i++) if (cols[i] == c) k = i; open = 1; next }
    open && $0 == "\\." { exit }
    open && k { split($0, f, "\t"); print f[k] }' data.sql
}

# Storage files (not in any database dump): every bucket listed in the storage.buckets rows just exported, read-only.
mkdir -p storage
copycol '"storage"."buckets"' id > .buckets
while IFS= read -r b; do
  # Bucket ids become folder names: plain names only (no path separators, no . or ..).
  [[ $b =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] || { echo "FAIL storage: unsafe bucket id in storage.buckets; stopping."; unset TOKEN; exit 1; }
  # </dev/null: the CLI must not read the bucket list this loop is reading.
  if [ -n "$TOKEN" ]; then
    out=$(SUPABASE_ACCESS_TOKEN=$TOKEN supabase storage cp -r "ss:///$b" "storage/$b" "${STORAGE_TARGET[@]}" --experimental 2>&1 </dev/null); rc=$?
  else
    out=$(supabase storage cp -r "ss:///$b" "storage/$b" "${STORAGE_TARGET[@]}" --experimental 2>&1 </dev/null); rc=$?
  fi
  mask "$out" > "storage_$b.log"
  [ $rc -eq 0 ] || { echo "FAIL storage $b: exit=$rc (masked log: $OUT/storage_$b.log)"; unset TOKEN; exit 1; }
  echo "OK   storage $b: $(find "storage/$b" -type f 2>/dev/null | wc -l) files"
done < .buckets
rm -f .buckets; unset TOKEN

# 1. Table existence: from schema.sql (public schema only; Supabase-managed schemas such as auth are not in it).
#    This list describes production BEFORE the pending migrations; extend it only after they are applied there.
missing=0
grep -oE '^CREATE TABLE (IF NOT EXISTS )?"public"\."[a-z_]+"' schema.sql \
  | sed -E 's/.*"public"\."([a-z_]+)"/public.\1/' | sort -u > SCHEMA_TABLES
for t in profiles handbook_chapters coach_threads coach_messages coach_notes goal_catalog goal_levels user_goals \
         dietary_profiles generated_plans foods exercises curriculum_levels workout_logs set_logs app_feedback contact_messages; do
  grep -qx "public.$t" SCHEMA_TABLES || { echo "MISSING in schema.sql: public.$t"; missing=1; }
done
for t in '"auth"."users"' '"storage"."objects"'; do
  grep -qE "^CREATE TABLE (IF NOT EXISTS )?$t" platform_schema.sql || { echo "MISSING in platform_schema.sql: $t"; missing=1; }
done

# 2. Data export completeness: every COPY block must end with its "\." terminator. Empty tables are fine (a block with
#    no rows, or no block at all). Per-table row counts are recorded; no row contents are printed or copied.
awk '/^COPY "/ { if (open) bad=1; split($2, q, "\""); name=q[2] "." q[4]; n=0; open=1; next }
     open && $0 == "\\." { print name, n; open=0; next }
     open { n++ }
     END { if (open || bad) exit 1 }' data.sql migration_history.sql > DATA_ROWS \
  || { echo "data.sql/migration_history.sql: a COPY block is not terminated (truncated export)"; missing=1; }
copies=$(cat data.sql migration_history.sql | grep -c '^COPY "'); done_blocks=$(wc -l < DATA_ROWS)
[ "$copies" -eq "$done_blocks" ] || { echo "dumps: $copies COPY blocks, $done_blocks complete"; missing=1; }
# The project has signed-up users and applied migrations, so both must have rows.
grep -qE '^auth\.users [1-9]' DATA_ROWS || { echo "data.sql: no auth.users rows exported"; missing=1; }
grep -qE '^supabase_migrations\.schema_migrations [1-9]' DATA_ROWS || { echo "migration_history.sql: no history rows"; missing=1; }

# 3. Storage completeness: every storage.objects row has a copied file and every copied file has a row.
#    ponytail: compares names as written in COPY text; names with tabs, newlines or backslashes would need unescaping.
copycol '"storage"."objects"' bucket_id > .ob; copycol '"storage"."objects"' name > .on
paste -d/ .ob .on | LC_ALL=C sort > STORAGE_EXPECTED; rm -f .ob .on
(cd storage && find . -type f | sed 's#^\./##') | LC_ALL=C sort > STORAGE_FILES
cmp -s STORAGE_EXPECTED STORAGE_FILES || { echo "storage: files differ from storage.objects:"; diff STORAGE_EXPECTED STORAGE_FILES | head -20; missing=1; }

# 4. Checksums last, over every file in the folder (dumps, logs, counts, storage files). BACKUP_PASS marks a folder
#    that passed every check; tools/backup_seal.sh refuses folders without it.
[ $missing -eq 0 ] && date -u +%Y-%m-%dT%H:%M:%SZ > BACKUP_PASS
find . -type f ! -path ./SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS || { echo "FAIL checksums"; exit 1; }

echo "schema.sql: $(wc -l < SCHEMA_TABLES) public tables. data: $done_blocks COPY blocks, $(awk '$2>0' DATA_ROWS | wc -l) with rows, $(awk '$2==0' DATA_ROWS | wc -l) empty (counts in $OUT/DATA_ROWS). storage: $(wc -l < STORAGE_FILES) files."
echo "Backup folder: $OUT"
[ $missing -eq 0 ] && echo "PASS: all dumps exited 0 and are non-empty; schema has the expected tables; data, history and Storage are complete; SHA256SUMS written." || { echo "FAIL: export incomplete (see above)."; exit 1; }

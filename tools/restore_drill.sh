#!/usr/bin/env bash
# Restore drill (docs/BACKUP_RECOVERY_PLAN.md sections 6-7, automated): loads a backup folder into a throwaway Postgres
# container with no network and RAM-only storage, then compares it with the source database.
# Usage: bash tools/restore_drill.sh <dump folder> <source db url> [image]
#   <dump folder> holds roles.sql, schema.sql, data.sql, platform_schema.sql, migration_history.sql (the daily backup).
#   <source db url> is read only (schema fingerprint and row counts, in read-only transactions); docker:<container>
#   reads a local stack database container instead (no local psql needed).
# Exit 0 only when all 12 fingerprint kinds and every public table's row count match. The container is always removed.
set -euo pipefail
cd "$(dirname "$0")/.."
DIR=$1 SRC=$2 IMAGE=${3:-public.ecr.aws/supabase/postgres:17.6.1.171}
for f in roles schema data platform_schema migration_history; do [ -s "$DIR/$f.sql" ] || { echo "Missing $DIR/$f.sql" >&2; exit 2; }; done
NAME=levlo_restore_drill_$$
cleanup() { docker stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --rm --name "$NAME" --network none --tmpfs /var/lib/postgresql/data:rw,size=2g --tmpfs /restore:rw,size=1g \
  -e POSTGRES_PASSWORD="$(openssl rand -hex 24)" "$IMAGE" >/dev/null
for _ in $(seq 60); do docker exec "$NAME" pg_isready -U postgres -q 2>/dev/null && break; sleep 2; done
sleep 3 # the image runs its own init scripts after the first ready signal
for _ in $(seq 30); do docker exec "$NAME" psql -U supabase_admin -d postgres -Atc 'select 1' >/dev/null 2>&1 && break; sleep 2; done

export MSYS_NO_PATHCONV=1
tar -C "$DIR" -cf - roles.sql schema.sql data.sql platform_schema.sql migration_history.sql | docker exec -i "$NAME" tar -xf - -C /restore
docker exec -i "$NAME" sh -c 'cat > /restore/preload.sql' < tools/restore_preload.sql
docker exec -i "$NAME" sh -c 'cat > /restore/postload.sql' < tools/restore_postload.sql

run() { docker exec "$NAME" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 --single-transaction -q "$@" >/dev/null; }
# Roles the dumps name that the image lacks get a placeholder (no login), so GRANT and OWNER lines load.
roles=$(cat "$DIR"/*.sql | grep -oE '(TO|OWNER TO) "[^"]+"' | sed -E 's/.*"([^"]+)"/\1/' | sort -u)
for r in $roles; do
  docker exec "$NAME" psql -U supabase_admin -d postgres -q -c "do \$\$ begin if not exists (select 1 from pg_roles where rolname = '$r') then create role \"$r\" nologin; end if; end \$\$;" >/dev/null
done
run -c 'drop schema if exists auth, storage, supabase_functions, supabase_migrations cascade'
run -f /restore/preload.sql
# The new-user trigger fires on auth.users inserts, so it is created only after the data is in.
docker exec "$NAME" sh -c "grep -v 'on_auth_user_created' /restore/platform_schema.sql > /restore/platform_no_trigger.sql; grep 'CREATE TRIGGER on_auth_user_created' /restore/platform_schema.sql > /restore/trigger.sql || true"
for f in platform_no_trigger roles schema data migration_history trigger postload; do run -f "/restore/$f.sql"; done

STATE=$( { echo 'begin transaction read only; set search_path to public, extensions;'; cat tools/schema_state.sql; echo 'rollback;'; } )
COUNTS="begin transaction read only;
select string_agg(format('select %L || ''='' || count(*) from public.%I', t, t), ' union all ' order by t) from pg_tables t0 cross join lateral (select t0.tablename::text t) x where schemaname = 'public' \gset
:string_agg;
rollback;"
src_psql() { case $SRC in docker:*) docker exec -i "${SRC#docker:}" psql -U postgres -d postgres "$@" ;; *) psql "$SRC" "$@" ;; esac; }
src_state=$(printf '%s\n' "$STATE" | src_psql -At -F' ' -v ON_ERROR_STOP=1 | grep -vE '^(BEGIN|SET|ROLLBACK)$')
copy_state=$(printf '%s\n' "$STATE" | docker exec -i "$NAME" psql -U supabase_admin -d postgres -At -F' ' -v ON_ERROR_STOP=1 | grep -vE '^(BEGIN|SET|ROLLBACK)$')
src_counts=$(printf '%s\n' "$COUNTS" | src_psql -At -v ON_ERROR_STOP=1 | grep '=' | sort)
copy_counts=$(printf '%s\n' "$COUNTS" | docker exec -i "$NAME" psql -U supabase_admin -d postgres -At -v ON_ERROR_STOP=1 | grep '=' | sort)

fail=0
if [ "$src_state" = "$copy_state" ]; then echo "PASS fingerprint: $(echo "$copy_state" | wc -l) kinds identical"; else echo "FAIL fingerprint"; diff <(echo "$src_state") <(echo "$copy_state") || true; fail=1; fi
if [ "$src_counts" = "$copy_counts" ]; then echo "PASS row counts: $(echo "$copy_counts" | wc -l) public tables identical"; else echo "FAIL row counts"; diff <(echo "$src_counts") <(echo "$copy_counts") | sed -E 's/=.*/=<differs>/' || true; fail=1; fi
exit $fail

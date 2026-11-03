#!/usr/bin/env bash
# Storage backup and restore drill on a THROWAWAY local Supabase stack with synthetic photos only. Never production.
# Proves tools/storage_backup.py end to end: back up -> encrypt -> delete everything -> decrypt -> restore -> verify,
# then checks that restored photos still belong to their owners (Storage policy by folder) and that every
# progress_photos row still points at a file. Negative control: a backup missing one file must FAIL verify.
# Usage (Git Bash, repo root): bash tools/storage_restore_drill.sh   (needs Docker, the supabase CLI, python + boto3)
set -euo pipefail
ROOT=$(pwd)
W=$(mktemp -d)
trap 'supabase stop --no-backup --workdir "$W" >/dev/null 2>&1 || true; rm -rf "$W"' EXIT
cp -r supabase "$W/"
# Own project id and ports inside the firewall-blocked range, so it never touches the dev stack or the LAN.
sed -i 's/^project_id = .*/project_id = "levlo_storage_drill"/; 0,/^port = 54321/s//port = 54325/; 0,/^port = 54322/s//port = 54329/; s/^shadow_port = .*/shadow_port = 54320/' "$W/supabase/config.toml"
supabase start --workdir "$W" -x studio,mailpit,logflare,vector,realtime,edge-runtime,imgproxy,postgres-meta,supavisor >/dev/null
eval "$(supabase status --workdir "$W" -o env | grep -E '^(S3_PROTOCOL_ACCESS_KEY_ID|S3_PROTOCOL_ACCESS_KEY_SECRET|S3_PROTOCOL_REGION|STORAGE_S3_URL|DB_URL)=')"
export S3_ENDPOINT=$STORAGE_S3_URL S3_REGION=$S3_PROTOCOL_REGION S3_KEY_ID=$S3_PROTOCOL_ACCESS_KEY_ID S3_SECRET=$S3_PROTOCOL_ACCESS_KEY_SECRET
DB=$(docker ps --format '{{.Names}}' | grep '^supabase_db_levlo_storage_drill$')
sql() { docker exec -i "$DB" psql -U postgres -At -v ON_ERROR_STOP=1 -c "$1"; }

# Synthetic data: two test accounts, 3 + 2 small generated PNGs and their progress_photos rows.
A=00000000-0000-0000-0000-00000000aa01; B=00000000-0000-0000-0000-00000000bb02
sql "insert into auth.users (id, email) values ('$A','drill-a@test.local'),('$B','drill-b@test.local')" >/dev/null
python - "$A" "$B" <<'PY'
import os, struct, sys, zlib, boto3
from botocore.config import Config
os.environ.setdefault("AWS_REQUEST_CHECKSUM_CALCULATION", "when_required")
s3 = boto3.client("s3", endpoint_url=os.environ["S3_ENDPOINT"], region_name=os.environ["S3_REGION"], aws_access_key_id=os.environ["S3_KEY_ID"],
                  aws_secret_access_key=os.environ["S3_SECRET"], config=Config(s3={"addressing_style": "path"}))
def png(seed):  # a 16x16 one-colour PNG, different per seed
    raw = b"".join(b"\x00" + bytes([seed * 40 % 256, 90, 200]) * 16 for _ in range(16))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
a, b = sys.argv[1], sys.argv[2]
for i, key in enumerate([f"{a}/1000.png", f"{a}/2000.png", f"{a}/3000.png", f"{b}/1000.png", f"{b}/avatar.png"]):
    s3.put_object(Bucket="progress-photos", Key=key, Body=png(i), ContentType="image/png")
PY
sql "insert into public.progress_photos (user_id, path, taken_on) values
  ('$A','$A/1000.png','2026-10-01'),('$A','$A/2000.png','2026-10-15'),('$A','$A/3000.png','2026-11-01'),('$B','$B/1000.png','2026-10-20')" >/dev/null
echo "seeded: $(sql "select count(*) from storage.objects where bucket_id='progress-photos'") objects, $(sql 'select count(*) from public.progress_photos') photo rows"

# 1. Back up, encrypt, prove it decrypts.
PASS=$(python -c "import secrets; print(secrets.token_urlsafe(32))")
python tools/storage_backup.py backup "$W/bk"
tar -czf "$W/bk.tar.gz" -C "$W" bk
printf '%s' "$PASS" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$W/bk.tar.gz.gpg" "$W/bk.tar.gz"
rm -rf "$W/bk" "$W/bk.tar.gz"
echo "encrypted archive: $(wc -c < "$W/bk.tar.gz.gpg") bytes"

# 2. Lose everything in the bucket (the disaster), through the Storage API.
python - <<'PY'
import os, boto3
from botocore.config import Config
os.environ.setdefault("AWS_REQUEST_CHECKSUM_CALCULATION", "when_required")
s3 = boto3.client("s3", endpoint_url=os.environ["S3_ENDPOINT"], region_name=os.environ["S3_REGION"], aws_access_key_id=os.environ["S3_KEY_ID"],
                  aws_secret_access_key=os.environ["S3_SECRET"], config=Config(s3={"addressing_style": "path"}))
keys = [o["Key"] for o in s3.list_objects_v2(Bucket="progress-photos").get("Contents", [])]
for k in keys: s3.delete_object(Bucket="progress-photos", Key=k)
print(f"deleted: {len(keys)} objects")
PY
[ "$(sql "select count(*) from storage.objects where bucket_id='progress-photos'")" = 0 ] || { echo "FAIL: bucket not empty"; exit 1; }

# 3. Decrypt, restore, verify checksums.
printf '%s' "$PASS" | gpg --batch --pinentry-mode loopback --passphrase-fd 0 -d "$W/bk.tar.gz.gpg" | tar -xz -C "$W"
python tools/storage_backup.py restore "$W/bk"

# 4. Ownership and references after the restore.
own_a=$(sql "set local role authenticated; select set_config('request.jwt.claims', '{\"sub\":\"$A\",\"role\":\"authenticated\"}', true); select count(*) from storage.objects where bucket_id='progress-photos'" | tail -1)
own_b=$(sql "set local role authenticated; select set_config('request.jwt.claims', '{\"sub\":\"$B\",\"role\":\"authenticated\"}', true); select count(*) from storage.objects where bucket_id='progress-photos'" | tail -1)
dangling=$(sql "select count(*) from public.progress_photos p where not exists (select 1 from storage.objects o where o.bucket_id='progress-photos' and o.name = p.path)")
echo "owner A sees $own_a objects (expect 3), owner B sees $own_b (expect 2), progress_photos rows without a file: $dangling (expect 0)"
[ "$own_a" = 3 ] && [ "$own_b" = 2 ] && [ "$dangling" = 0 ] || { echo "FAIL: ownership or references"; exit 1; }

# 5. Negative control: drop one file from the target; verify must fail.
python - "$A" <<'PY'
import os, sys, boto3
from botocore.config import Config
os.environ.setdefault("AWS_REQUEST_CHECKSUM_CALCULATION", "when_required")
boto3.client("s3", endpoint_url=os.environ["S3_ENDPOINT"], region_name=os.environ["S3_REGION"], aws_access_key_id=os.environ["S3_KEY_ID"],
             aws_secret_access_key=os.environ["S3_SECRET"], config=Config(s3={"addressing_style": "path"})).delete_object(Bucket="progress-photos", Key=f"{sys.argv[1]}/2000.png")
PY
if python tools/storage_backup.py verify "$W/bk" >/dev/null 2>&1; then echo "FAIL: verify passed with a file missing"; exit 1; fi
echo "negative control: verify fails with one file missing (as it should)"
echo "PASS: storage backup, encryption, restore, checksums, ownership and references"

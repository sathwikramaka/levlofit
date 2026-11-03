"""Back up or restore Supabase Storage buckets through the S3 protocol (progress photos and profile pictures).

Used by .github/workflows/storage-backup.yml and by tools/storage_restore_drill.sh (local throwaway stack only).
The repository is public, so this prints counts and byte totals only: never object names (they start with user ids).

  backup  <out_dir>   download every object of every bucket in BUCKETS into <out_dir>/<bucket>/<key> and write
                      <out_dir>/MANIFEST.tsv (bucket, key, size, sha256). Fails if any download is missing or short.
  restore <in_dir>    upload every MANIFEST.tsv entry back under the same bucket and key (ownership in this project is
                      the first path segment, so keeping the key keeps the owner), then download each one again and
                      compare sha256. Fails on any difference.
  verify  <in_dir>    the second half of restore only: every manifest entry exists in the target with the same sha256.

Environment: S3_ENDPOINT (https://<ref>.supabase.co/storage/v1/s3, or the local stack's), S3_REGION, S3_KEY_ID,
S3_SECRET, BUCKETS (space separated, default "progress-photos").
"""
import hashlib
import mimetypes
import os
import sys

import boto3
from botocore.config import Config


def client():
    # boto3 1.36+ adds CRC checksums to every request by default, which S3-compatible stores may reject; only send them
    # when an operation requires one. Older boto3 ignores these variables.
    os.environ.setdefault("AWS_REQUEST_CHECKSUM_CALCULATION", "when_required")
    os.environ.setdefault("AWS_RESPONSE_CHECKSUM_VALIDATION", "when_required")
    return boto3.client(
        "s3",
        endpoint_url=os.environ["S3_ENDPOINT"],
        region_name=os.environ.get("S3_REGION", "ap-south-1"),
        aws_access_key_id=os.environ["S3_KEY_ID"],
        aws_secret_access_key=os.environ["S3_SECRET"],
        config=Config(s3={"addressing_style": "path"}, retries={"max_attempts": 5, "mode": "standard"}),
    )


def buckets():
    return os.environ.get("BUCKETS", "progress-photos").split()


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def safe_join(root, bucket, key):
    # Keys come from the server; refuse anything that would write outside the backup folder.
    p = os.path.normpath(os.path.join(root, bucket, key))
    if not p.startswith(os.path.normpath(os.path.join(root, bucket)) + os.sep):
        raise SystemExit("FAIL: unsafe object key; stopping")
    return p


def backup(out):
    s3 = client()
    rows, total = [], 0
    for b in buckets():
        count = 0
        for page in s3.get_paginator("list_objects_v2").paginate(Bucket=b):
            for o in page.get("Contents", []):
                path = safe_join(out, b, o["Key"])
                os.makedirs(os.path.dirname(path), exist_ok=True)
                s3.download_file(b, o["Key"], path)
                size = os.path.getsize(path)
                if size != o["Size"]:
                    raise SystemExit(f"FAIL {b}: a download is {size} bytes, listed {o['Size']}")
                rows.append((b, o["Key"], size, sha256(path)))
                count += 1
                total += size
        print(f"OK   {b}: {count} objects")
    with open(os.path.join(out, "MANIFEST.tsv"), "w", encoding="utf-8", newline="\n") as f:
        for r in rows:
            f.write("\t".join(map(str, r)) + "\n")
    print(f"OK   manifest: {len(rows)} objects, {total} bytes")


def read_manifest(root):
    with open(os.path.join(root, "MANIFEST.tsv"), encoding="utf-8") as f:
        return [line.rstrip("\n").split("\t") for line in f if line.strip()]


def verify(root):
    s3, bad = client(), 0
    rows = read_manifest(root)
    tmp = os.path.join(root, ".verify")
    os.makedirs(tmp, exist_ok=True)
    for i, (b, key, size, digest) in enumerate(rows):
        p = os.path.join(tmp, str(i))
        try:
            s3.download_file(b, key, p)
        except Exception:  # noqa: BLE001 - any failure is a missing object; the name is not printed
            bad += 1
            continue
        if os.path.getsize(p) != int(size) or sha256(p) != digest:
            bad += 1
        os.remove(p)
    os.rmdir(tmp)
    if bad:
        raise SystemExit(f"FAIL verify: {bad} of {len(rows)} objects missing or different")
    print(f"OK   verify: {len(rows)} of {len(rows)} objects match the manifest")


def restore(root):
    s3 = client()
    rows = read_manifest(root)
    for b, key, _, _ in rows:
        # The bucket only accepts image types, so the content type is set from the file name, as the app does.
        kind = mimetypes.guess_type(key)[0] or "application/octet-stream"
        s3.upload_file(safe_join(root, b, key), b, key, ExtraArgs={"ContentType": kind})
    print(f"OK   restore: {len(rows)} objects uploaded")
    verify(root)


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("backup", "restore", "verify"):
        raise SystemExit(__doc__)
    {"backup": backup, "restore": restore, "verify": verify}[sys.argv[1]](sys.argv[2])

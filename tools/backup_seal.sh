#!/usr/bin/env bash
# Encrypts a finished backup folder (GnuPG symmetric AES-256) and proves the encrypted file holds every file
# byte-for-byte, without writing any decrypted file to disk. Never deletes the plaintext folder (owner decision).
# Usage (Git Bash):  bash tools/backup_seal.sh <backup folder>
#        bash tools/backup_seal.sh --legacy <folder>   for a backup made before 2026-10-16 (no BACKUP_PASS; its
#        SHA256SUMS covers only roles.sql, schema.sql and data.sql, which must still verify; other files are sealed as-is)
# gpg asks for the passphrase in its own prompt: twice to encrypt, once more to verify (cache disabled, so the check
# proves the passphrase as stored in your password manager works). Keep it only there; never next to the backup.
set -euo pipefail
umask 077
legacy=0; [ "${1:-}" = --legacy ] && { legacy=1; shift; }
src=${1:?usage: bash tools/backup_seal.sh [--legacy] <backup folder>}; src=${src%/}
[ -d "$src" ] || { echo "$src is not a folder; not sealing."; exit 1; }
parent=$(cd "$(dirname "$src")" && pwd); name=$(basename "$src"); out="$parent/$name.tar.gpg"
case "$name" in levlo-*) ;; *) echo "$src is not a levlo backup folder (name must start with levlo-); not sealing."; exit 1 ;; esac
[ -f "$src/SHA256SUMS" ] || { echo "$src has no SHA256SUMS; not sealing."; exit 1; }
[ $legacy -eq 1 ] || [ -f "$src/BACKUP_PASS" ] || { echo "$src is not a backup that passed its checks; not sealing."; exit 1; }
[ -e "$out" ] && { echo "$out already exists; not overwriting."; exit 1; }
cd "$parent"
(cd "$name" && sha256sum -c --quiet SHA256SUMS) || { echo "FAIL: $name does not match its SHA256SUMS"; exit 1; }
if [ $legacy -eq 1 ]; then
  for f in roles.sql schema.sql data.sql; do
    grep -qE "^[0-9a-f]{64} [ *](\./)?$f\$" "$name/SHA256SUMS" || { echo "FAIL: legacy SHA256SUMS does not cover $f; not sealing."; exit 1; }
  done
  echo "Legacy backup: dumps verified by SHA256SUMS; $(cd "$name" && find . -type f | wc -l) files are sealed as they are."
else
  # Every file must be listed in SHA256SUMS: a file added after the backup would otherwise be sealed unnoticed.
  (cd "$name" && find . -type f ! -path ./SHA256SUMS | LC_ALL=C sort | cmp -s - <(cut -c67- SHA256SUMS | LC_ALL=C sort)) \
    || { echo "FAIL: $name contains files not listed in SHA256SUMS (or lists missing files); not sealing."; exit 1; }
fi

part="$out.partial"   # only a verified file gets the final name
[ -e "$part" ] && { echo "$part exists from an interrupted earlier run; inspect or remove it first."; exit 1; }
before=$(mktemp) after=$(mktemp); ok=0
# On any failure remove this run's own unverified .partial (ciphertext, never valid); the hash lists always go.
trap 'rm -f "$before" "$after"; [ $ok -eq 1 ] || rm -f "$part"' EXIT
find "$name" -type f -print0 | xargs -0 sha256sum | sed "s/ [ *]/  /" | LC_ALL=C sort -k2 > "$before"   # Git Bash marks binary mode with *
tar -cf - "$name" | gpg --symmetric --cipher-algo AES256 --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712 \
  --no-symkey-cache -o "$part"
# Decrypt into a pipe and hash each archive member as it streams past (GNU tar --to-command); a wrong passphrase or a
# damaged file stops gpg with an integrity error, which pipefail turns into a FAIL here.
if ! gpg --decrypt --no-symkey-cache "$part" \
  | tar -xf - --to-command='printf "%s  %s\n" "$(sha256sum | cut -d" " -f1)" "$TAR_FILENAME"' \
  | LC_ALL=C sort -k2 > "$after"; then
  echo "FAIL: could not decrypt $part (wrong passphrase or damaged file); the unverified file was removed and the plaintext kept"; exit 1
fi
cmp -s "$before" "$after" || { echo "FAIL: decrypted contents differ from $name; the unverified file was removed and the plaintext kept"; exit 1; }
mv "$part" "$out"; ok=1
sha256sum "$name.tar.gpg" > "$name.tar.gpg.sha256"
echo "PASS: $(wc -l < "$after") files restored byte-for-byte from $out ($(wc -c < "$out") bytes; checksum in $name.tar.gpg.sha256)."
echo "Next: copy $name.tar.gpg and its .sha256 to the offline drive and verify there with sha256sum -c."
echo "The plaintext folder $src is NOT removed; delete it only after the offline copy is verified (owner decision)."

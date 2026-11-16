#!/usr/bin/env bash
# One-command Android release: bumps the version past the live one, builds the signed APK, rebuilds the site with it
# and deploys to Cloudflare Pages. Every installed version is then asked to update: 1.0.2+ apps read /version.json
# (min_build = this build, so the card cannot be dismissed), and the MIN_APP_BUILD secret makes the AI functions
# tell any older build, including 1.0.0 and 1.0.1, to download the new version. MIN_BUILD=<n> keeps older builds allowed.
# Run from Git Bash at the repo root after the app changes are committed:  tools/release_android.sh
# Then it commits the version bump, pushes the branch and publishes the same APK as a GitHub release vX.Y.Z (owner
# rule 2026-11-16: every release is on GitHub too). The push is never forced: if GitHub has moved on, it stops there.
# Needs the release keystore (app/android/key.properties), a wrangler login (npx wrangler login, once) and gh logged in.
# APK builds stay off CI on purpose: the keystore must never leave this machine (see .github/workflows/ci.yml).
set -euo pipefail
cd "$(dirname "$0")/.."

SITE=https://levlofit.pages.dev
live_build=$(curl -fsS "$SITE/version.json" | python -I -c 'import json, sys; print(json.load(sys.stdin)["build"])')

V=$(sed -n 's/^version: *//p' app/pubspec.yaml | tr -d '\r')
VERSION=${V%+*}
BUILD=${V#*+}
if [ "$BUILD" -le "$live_build" ]; then
  # Never reuse a version: phones and caches keep the old file under the same name.
  BUILD=$((live_build + 1))
  VERSION="${VERSION%.*}.$(( ${VERSION##*.} + 1 ))"
  sed -i "s/^version: .*/version: $VERSION+$BUILD/" app/pubspec.yaml
  sed -i "s/^const appVersion = .*/const appVersion = '$VERSION';/; s/^const appBuild = .*/const appBuild = $BUILD;/" \
    app/lib/app_version.dart
  echo "Version bumped to $VERSION+$BUILD (live is build $live_build)."
fi

(cd app && flutter test --no-pub test/release_helpers_test.dart \
  && flutter build apk --release --split-per-abi --dart-define=LEVLOFIT_BACKEND=production)

tools/build_site.sh
npx --yes wrangler pages deploy website/out --project-name levlofit --branch main

served=$(curl -fsS "$SITE/version.json?$(date +%s)" | python -I -c 'import json, sys; print(json.load(sys.stdin)["build"])')
[ "$served" = "$BUILD" ] || { echo "Deployed, but $SITE/version.json still says build $served." >&2; exit 1; }
# Only now that the APK is live: older builds' coach, plan and body-check calls answer "update" (functions/_shared/rate.ts).
supabase secrets set "MIN_APP_BUILD=${MIN_BUILD:-$BUILD}" --project-ref ndeozgxowggkljluaccz

# GitHub release: the bump committed on its own, the branch pushed (never forced), the live APK attached.
git add app/pubspec.yaml app/lib/app_version.dart
git diff --cached --quiet || git commit -q -m "Release $VERSION (build $BUILD): version bump"
git push origin HEAD || { echo "Live, but the push was refused (GitHub has commits this branch lacks). Sort that out, then: gh release create v$VERSION ..." >&2; exit 1; }
PREV=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || true)
OUT=website/out/download/levlofit-$VERSION.apk
SHA=$(sha256sum "$OUT" | cut -d' ' -f1)
SIZE=$(awk -v b="$(stat -c %s "$OUT")" 'BEGIN { printf "%.1f MB", b / 1000000 }')
NOTES=$(mktemp)
{
  echo "Levlofit $VERSION (build $BUILD) for Android, 64-bit phones (arm64-v8a)."
  echo
  echo "- File: levlofit-$VERSION.apk, $SIZE"
  echo "- SHA-256: $SHA"
  echo "- Signed with the Levlofit release key (CN=Levlofit, Hyderabad, IN)"
  echo "- Same file as $SITE/download/levlofit-$VERSION.apk"
  echo
  echo "Changes${PREV:+ since $PREV}:"
  git log --no-merges --format='- %s' ${PREV:+$PREV..}HEAD | grep -viE '^- (Release|Record|Release record)\b' | head -40 || true
  echo
  echo "iPhone: use the web app at $SITE/app/ (Safari, Share, Add to Home Screen)."
} > "$NOTES"
gh release create "v$VERSION" "$OUT" --target "$(git rev-parse HEAD)" --title "Levlofit $VERSION" --notes-file "$NOTES" --latest
rm -f "$NOTES"
echo "Live: Levlofit $VERSION (build $BUILD), site and GitHub release v$VERSION. Add a section to docs/release/RELEASE_RECORD.md."

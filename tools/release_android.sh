#!/usr/bin/env bash
# One-command Android release: bumps the version past the live one, builds the signed APK, rebuilds the site with it
# and deploys to Cloudflare Pages. Installed apps then see the new /version.json and show "Update ready".
# Run from Git Bash at the repo root after the app changes are committed:  tools/release_android.sh
# Needs the release keystore (app/android/key.properties) and a wrangler login (npx wrangler login, once).
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
echo "Live: Levlofit $VERSION (build $BUILD). Commit the version bump and add a row to docs/RELEASE_RECORD.md."

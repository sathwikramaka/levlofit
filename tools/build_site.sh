#!/usr/bin/env bash
# Builds the one public site (website/out) for Cloudflare Pages: the Next.js pages, the Android APK under
# /download/, and the iPhone web app (Flutter web) under /app/. Run from the repo root after building the APK.
# Deploy: npx wrangler pages deploy website/out --project-name levlofit --branch main
set -euo pipefail
cd "$(dirname "$0")/.."

SITE=https://levlofit.pages.dev
V=$(sed -n 's/^version: *//p' app/pubspec.yaml | tr -d '\r')   # e.g. 1.0.2+4, the APK's own version
VERSION=${V%+*}
BUILD=${V#*+}
APK=app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

[ -f "$APK" ] || { echo "Missing $APK: build the APK first." >&2; exit 1; }
SHA=$(sha256sum "$APK" | cut -d' ' -f1)
SIZE=$(awk -v b="$(stat -c %s "$APK")" 'BEGIN { printf "%.1f MB", b / 1000000 }')   # decimal MB, as Android and browsers show it

(cd app && MSYS_NO_PATHCONV=1 flutter build web --release --base-href /app/ --dart-define=LEVLOFIT_BACKEND=production)

(cd website && NEXT_PUBLIC_APK_URL="$SITE/download/levlofit-$VERSION.apk" NEXT_PUBLIC_APK_VERSION=$VERSION \
  NEXT_PUBLIC_APK_SIZE="$SIZE" NEXT_PUBLIC_APK_SHA256=$SHA NEXT_PUBLIC_APK_BUILD=$BUILD \
  NEXT_PUBLIC_APK_MIN_BUILD=${MIN_BUILD:-$BUILD} \
  NEXT_PUBLIC_WEBAPP_URL="$SITE/app/" npm run build)

mkdir -p website/out/download
cp "$APK" "website/out/download/levlofit-$VERSION.apk"
rm -rf website/out/app
cp -r app/build/web website/out/app
echo "Built website/out: APK $SIZE, sha256 $SHA, web app at /app/"

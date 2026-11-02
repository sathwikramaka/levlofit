// /version.json: the newest Android release, for the app's update notice (app/lib/update_check.dart). Built once from
// the same settings as the download button (components/download.tsx), plus NEXT_PUBLIC_APK_BUILD, the APK's build
// number (pubspec.yaml version after the +), and NEXT_PUBLIC_APK_MIN_BUILD: apps below it must update (no Later). Without a release it reports build 0, so no app shows a notice.
import { apk } from "@/components/download";

export const dynamic = "force-static";

export function GET() {
  return Response.json({
    version: apk.version,
    build: Number(process.env.NEXT_PUBLIC_APK_BUILD ?? 0) || 0,
    url: apk.url,
    sha256: apk.sha256, // the app checks the downloaded APK against this before its in-app install
    min_build: Number(process.env.NEXT_PUBLIC_APK_MIN_BUILD ?? 0) || 0,
  });
}

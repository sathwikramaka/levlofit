// /version.json: the newest Android release, for the app's update notice (app/lib/update_check.dart). Built once from
// the same settings as the download button (components/download.tsx), plus NEXT_PUBLIC_APK_BUILD, the APK's build
// number (pubspec.yaml version after the +). Without a release it reports build 0, so no app shows a notice.
import { apk } from "@/components/download";

export const dynamic = "force-static";

export function GET() {
  return Response.json({
    version: apk.version,
    build: Number(process.env.NEXT_PUBLIC_APK_BUILD ?? 0) || 0,
    url: apk.url,
  });
}

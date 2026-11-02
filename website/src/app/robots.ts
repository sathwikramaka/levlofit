// /robots.txt: everything may be indexed; points crawlers at the sitemap. /app/ is the iPhone web app, not a page.
import type { MetadataRoute } from "next";

export const dynamic = "force-static";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/", disallow: "/app/" },
    sitemap: "https://levlofit.pages.dev/sitemap.xml",
  };
}

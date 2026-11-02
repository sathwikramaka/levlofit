// /sitemap.xml: every public page, so search engines find the Handbook chapters without crawling for them.
import type { MetadataRoute } from "next";
import { chapters } from "@/lib/handbook";

export const dynamic = "force-static";

const SITE = "https://levlofit.pages.dev";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    ...["", "/handbook", "/privacy", "/terms", "/delete-account"].map((p) => ({ url: `${SITE}${p}` })),
    ...chapters.map((c) => ({ url: `${SITE}/handbook/${c.slug}` })),
  ];
}

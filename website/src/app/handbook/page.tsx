import type { Metadata } from "next";
import Link from "next/link";
import { chapters, HANDBOOK_NOTE } from "@/lib/handbook";

export const metadata: Metadata = {
  title: "The Handbook",
  description: "Levlofit's training and food guide in 43 short chapters, each with its sources.",
};

export default function HandbookIndex() {
  const parts = [...new Map(chapters.map((c) => [c.part, c.partTitle])).entries()];
  return (
    <main id="main" className="mx-auto max-w-4xl px-4 pt-36 pb-28 sm:px-6">
      <header className="max-w-3xl">
        <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">The Handbook</p>
        <h1 className="mt-4 text-[clamp(40px,6vw,72px)] leading-[0.98] font-bold tracking-[-0.04em]">Know why, not just what.</h1>
        <p className="mt-6 text-[18px] leading-relaxed text-muted">
          {chapters.length} short chapters on training and food, the same ones as in the app. Every number names its source.
        </p>
        <p className="mt-4 text-[14px] leading-relaxed text-muted">{HANDBOOK_NOTE}</p>
      </header>
      {parts.map(([part, title]) => (
        <section key={part} aria-labelledby={`part-${part}`} className="mt-14">
          <h2 id={`part-${part}`} className="font-mono text-[12px] tracking-[0.2em] text-muted uppercase">
            Part {part}. {title}
          </h2>
          <ol className="mt-4 border-t border-line">
            {chapters.filter((c) => c.part === part).map((c) => (
              <li key={c.slug} className="border-b border-line">
                <Link href={`/handbook/${c.slug}`} className="group flex items-baseline gap-4 py-4">
                  <span className="flex-1">
                    <span className="block text-[17px] font-semibold group-hover:underline group-hover:underline-offset-4">{c.title}</span>
                    <span className="mt-1 block text-[15px] leading-relaxed text-muted">{c.summary}</span>
                  </span>
                  <span className="shrink-0 font-mono text-[12px] text-muted">{c.minutes} min</span>
                </Link>
              </li>
            ))}
          </ol>
        </section>
      ))}
    </main>
  );
}

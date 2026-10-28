import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { HandbookBlock } from "@/components/handbook-blocks";
import { chapterBySlug, chapters, HANDBOOK_NOTE } from "@/lib/handbook";

export const dynamicParams = false;
export const generateStaticParams = () => chapters.map((c) => ({ slug: c.slug }));

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const c = chapterBySlug((await params).slug);
  return c ? { title: `${c.title} · Handbook`, description: c.summary } : {};
}

export default async function ChapterPage({ params }: { params: Promise<{ slug: string }> }) {
  const c = chapterBySlug((await params).slug);
  if (!c) notFound();
  const i = chapters.indexOf(c);
  const prev = chapters[i - 1], next = chapters[i + 1];
  return (
    <main id="main" className="mx-auto max-w-3xl px-4 pt-36 pb-28 sm:px-6">
      <nav aria-label="Breadcrumb" className="font-mono text-[12px] text-muted">
        <Link href="/handbook" className="underline underline-offset-4">The Handbook</Link> · Part {c.part}. {c.partTitle}
      </nav>
      <h1 className="mt-4 text-[clamp(34px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">{c.title}</h1>
      <p className="mt-4 text-[18px] leading-relaxed text-muted">{c.summary}</p>
      <p className="mt-3 font-mono text-[12px] text-muted">{c.minutes} min read</p>
      <div className="mt-10 space-y-6">
        {c.blocks.map((b, n) => (
          <HandbookBlock key={n} b={b} sources={c.sources} />
        ))}
      </div>
      <section aria-labelledby="sources" className="mt-14 border-t border-line pt-8">
        <h2 id="sources" className="text-[20px] font-bold">Sources</h2>
        <ol className="mt-4 space-y-2 text-[14px] leading-relaxed [overflow-wrap:anywhere] text-muted">
          {Object.entries(c.sources).map(([k, v], n) => (
            <li key={k} id={`src-${k}`}>
              [{n + 1}] {v}
            </li>
          ))}
        </ol>
        <p className="mt-6 text-[13px] leading-relaxed text-muted">{HANDBOOK_NOTE}</p>
      </section>
      <nav aria-label="Chapters" className="mt-10 flex justify-between gap-4 text-[15px]">
        {prev ? <Link href={`/handbook/${prev.slug}`} className="underline underline-offset-4">← {prev.title}</Link> : <span />}
        {next ? <Link href={`/handbook/${next.slug}`} className="text-right underline underline-offset-4">{next.title} →</Link> : <span />}
      </nav>
    </main>
  );
}

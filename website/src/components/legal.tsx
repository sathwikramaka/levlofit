import { CONTACT_EMAIL, CopyButton } from "./contact";

export type LegalSection = { id: string; title: string; body: React.ReactNode };

/** Shared layout for the privacy and terms pages: sticky contents on wide screens, plain reading column. */
export function LegalPage({ eyebrow, title, intro, updated, sections }: { eyebrow: string; title: string; intro: string; updated: string; sections: LegalSection[] }) {
  return (
    <main id="main" className="mx-auto max-w-6xl px-4 pt-36 pb-28 sm:px-6">
      <header data-reveal className="max-w-3xl">
        <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">{eyebrow}</p>
        <h1 className="mt-4 text-[clamp(40px,6vw,72px)] leading-[0.98] font-bold tracking-[-0.04em]">{title}</h1>
        <p className="mt-6 text-[18px] leading-relaxed text-muted">{intro}</p>
        <p className="mt-6 font-mono text-[12px] text-muted">Last updated {updated}</p>
      </header>

      <div className="mt-16 grid gap-12 lg:grid-cols-[220px_1fr]">
        <nav aria-label="On this page" className="hidden lg:block">
          <ol className="sticky top-32 space-y-1 border-l border-line">
            {sections.map((s, i) => (
              <li key={s.id}>
                <a href={`#${s.id}`} className="-ml-px block border-l border-transparent py-1.5 pl-4 text-[14px] text-muted transition-colors duration-300 hover:border-ink hover:text-ink">
                  {String(i + 1).padStart(2, "0")} &nbsp;{s.title}
                </a>
              </li>
            ))}
          </ol>
        </nav>

        <article className="max-w-3xl">
          {sections.map((s, i) => (
            <section key={s.id} id={s.id} data-reveal className="border-t border-line py-10 first:border-t-0 first:pt-0">
              <h2 className="text-[24px] font-bold tracking-tight">
                <span className="mr-3 font-mono text-[14px] font-normal text-accent-text">{String(i + 1).padStart(2, "0")}</span>
                {s.title}
              </h2>
              <div className="legal mt-4 text-[16px] leading-[1.7] text-muted">{s.body}</div>
            </section>
          ))}

          <div data-reveal className="mt-4 flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-line bg-surface p-5">
            <div>
              <p className="text-[15px] font-semibold">Questions about this page?</p>
              <p className="mt-1 text-[14px] text-muted">{CONTACT_EMAIL}</p>
            </div>
            <CopyButton text={CONTACT_EMAIL} label="Copy email" />
          </div>
        </article>
      </div>
    </main>
  );
}

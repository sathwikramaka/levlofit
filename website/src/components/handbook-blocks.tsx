// Renders the Handbook book's blocks (data/handbook_book/build.py, exported to src/lib/handbook_book.json) as plain,
// accessible HTML: the same content as the app's Handbook.
import Link from "next/link";
import type React from "react";

export type Block = { t: string; [k: string]: unknown };

const s = (v: unknown) => (typeof v === "string" ? v : v == null ? "" : String(v));
const list = (v: unknown) => (Array.isArray(v) ? (v as unknown[]) : []);

function Source({ k, sources }: { k: unknown; sources: Record<string, string> }) {
  if (typeof k !== "string" || !sources[k]) return null;
  return (
    <a href={`#src-${k}`} className="ml-1 align-super font-mono text-[11px] text-accent-text no-underline">
      [{Object.keys(sources).indexOf(k) + 1}]
    </a>
  );
}

// Book text: **bold**, {source} and [[slug|Title]] chapter links.
const rich = (text: unknown, sources: Record<string, string>) =>
  s(text).split(/(\*\*.+?\*\*|\{[a-z0-9-]+\}|\[\[[a-z0-9-]+\|[^\]]+\]\])/).map((part, n) => {
    if (part.startsWith("**")) return <strong key={n} className="font-sans font-semibold">{part.slice(2, -2)}</strong>;
    if (part.startsWith("{")) return <Source key={n} k={part.slice(1, -1)} sources={sources} />;
    if (part.startsWith("[[")) {
      const [slug, title] = part.slice(2, -2).split("|");
      return <Link key={n} href={`/handbook/${slug}`} className="underline underline-offset-4">{title}</Link>;
    }
    return part;
  });

const NOTE: Record<string, string> = { evidence: "border-ink", warn: "border-accent", tip: "border-line" };

type Item = Record<string, unknown>;
const items = (v: unknown) => list(v).filter((x): x is Item => typeof x === "object" && x !== null);
const num = (v: unknown) => (typeof v === "number" ? v : Number(v) || 0);
const TONE: Record<string, string> = { good: "var(--success)", bad: "var(--danger)", ok: "var(--accent)" };

/** A numbered-style figure frame: title, the drawing, and its source mark (the same figures as the app's Handbook). */
function Figure({ title, source, sources, children }: { title?: unknown; source?: unknown; sources: Record<string, string>; children: React.ReactNode }) {
  return (
    <figure className="rounded-2xl border border-line bg-surface p-5">
      {s(title) && (
        <figcaption className="mb-4 font-sans text-[15px] font-bold">
          {s(title)}
          <Source k={source} sources={sources} />
        </figcaption>
      )}
      {children}
    </figure>
  );
}

export function HandbookBlock({ b, sources }: { b: Block; sources: Record<string, string> }) {
  switch (b.t) {
    case "h2":
      return <h2 className="border-t border-line pt-8 font-sans text-[24px] leading-tight font-bold tracking-[-0.02em]">{s(b.text)}</h2>;
    case "h3":
      return <h3 className="pt-2 font-sans text-[18px] font-bold">{s(b.text)}</h3>;
    case "p":
      return <p className="font-serif text-[18px] leading-[1.75]">{rich(b.text, sources)}</p>;
    case "list":
      return (
        <ul className="list-disc space-y-3 pl-5 font-serif text-[18px] leading-[1.7]">
          {list(b.items).map((i, n) => <li key={n}>{rich(i, sources)}</li>)}
        </ul>
      );
    case "note":
      return (
        <aside className={`border-l-[3px] bg-surface p-5 ${NOTE[s(b.kind)] ?? "border-line"}`}>
          <p className="font-sans text-[15px] font-bold">{s(b.title)}</p>
          {list(b.paras).map((p, n) => <p key={n} className="mt-2 font-serif text-[17px] leading-[1.7]">{rich(p, sources)}</p>)}
        </aside>
      );
    case "rows":
      return (
        <div className="overflow-x-auto" role="region" tabIndex={0} aria-label={list(b.head).map(s).join(", ")}>
          <table className="w-full text-left font-sans text-[15px] leading-relaxed">
            <thead>
              <tr>{list(b.head).map((h, n) => <th key={n} className="pr-4 pb-2 align-bottom font-semibold">{s(h)}</th>)}</tr>
            </thead>
            <tbody>
              {list(b.rows).map((r, n) => (
                <tr key={n} className="border-t border-line">
                  {(Array.isArray(r) ? r : []).map((c, m) => <td key={m} className={`py-3 pr-4 align-top ${m ? "" : "text-muted"}`}>{rich(c, sources)}</td>)}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    case "stats":
      return (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          {items(b.items).map((i, n) => (
            <div key={n} className="rounded-2xl border border-line bg-surface p-4">
              <p className="font-sans text-[26px] leading-tight font-bold tabular-nums">
                {s(i.value)} <span className="text-[14px] font-normal text-muted">{s(i.unit)}</span>
              </p>
              <p className="mt-1 font-sans text-[14px] text-muted">
                {s(i.label)}
                <Source k={i.source} sources={sources} />
              </p>
            </div>
          ))}
        </div>
      );
    case "steps":
      return (
        <Figure title={b.title} sources={sources}>
          <ol className="space-y-4">
            {items(b.items).map((i, n) => (
              <li key={n} className="flex gap-4">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent font-sans text-[14px] font-bold text-on-accent">{n + 1}</span>
                <div>
                  <p className="font-sans text-[16px] font-semibold">{s(i.title)}</p>
                  <p className="font-sans text-[15px] leading-relaxed text-muted">{rich(i.text, sources)}</p>
                </div>
              </li>
            ))}
          </ol>
        </Figure>
      );
    case "compare": {
      const side = (v: unknown, good: boolean) => {
        const o = (typeof v === "object" && v ? v : {}) as Item;
        return (
          <div className={`rounded-2xl border p-4 ${good ? "border-success" : "border-line"}`}>
            <p className={`mb-2 font-sans text-[14px] font-bold ${good ? "text-success" : "text-muted"}`}>{s(o.title)}</p>
            <ul className="space-y-2">
              {list(o.items).map((x, n) => (
                <li key={n} className="flex gap-2 font-sans text-[15px] leading-relaxed">
                  <span aria-hidden className={good ? "text-success" : "text-muted"}>{good ? "✓" : "×"}</span>
                  <span>{rich(x, sources)}</span>
                </li>
              ))}
            </ul>
          </div>
        );
      };
      return <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">{side(b.do, true)}{side(b.dont, false)}</div>;
    }
    case "bars": {
      const rows = items(b.items);
      const top = Math.max(...rows.map((r) => num(r.value)), 1);
      return (
        <Figure title={`${s(b.title)} · ${s(b.unit)}`} source={b.source} sources={sources}>
          <div className="space-y-3">
            {rows.map((r, n) => (
              <div key={n}>
                <div className="flex justify-between gap-3 font-sans text-[14px]">
                  <span>{s(r.label)}</span>
                  <span className="tabular-nums text-muted">{s(r.value)}</span>
                </div>
                <div className="mt-1 h-3 rounded-full bg-surface-2">
                  <div className="h-3 rounded-full bg-accent" style={{ width: `${(100 * num(r.value)) / top}%` }} />
                </div>
                {s(r.note) && <p className="mt-1 font-sans text-[13px] text-muted">{s(r.note)}</p>}
              </div>
            ))}
          </div>
        </Figure>
      );
    }
    case "plate": {
      const rows = items(b.items);
      const shades = ["var(--success)", "#a9d18e", "var(--accent)", "var(--ink)"];
      const upTo = (n: number) => rows.slice(0, n).reduce((sum, r) => sum + num(r.share) * 100, 0);
      const stops = rows.map((_, n) => `${shades[n % shades.length]} ${upTo(n)}% ${upTo(n + 1)}%`);
      return (
        <Figure title={b.title} source={b.source} sources={sources}>
          <div className="flex flex-col items-center gap-5 sm:flex-row sm:items-start">
            <div role="img" aria-label={rows.map((r) => `${s(r.label)} ${Math.round(num(r.share) * 100)}%`).join(", ")}
              className="h-40 w-40 shrink-0 rounded-full border-8 border-surface-2" style={{ background: `conic-gradient(${stops.join(", ")})` }} />
            <ul className="space-y-2">
              {rows.map((r, n) => (
                <li key={n} className="flex gap-3 font-sans text-[15px]">
                  <span aria-hidden className="mt-1 h-3 w-3 shrink-0 rounded-full" style={{ background: shades[n % shades.length] }} />
                  <span>
                    <strong className="font-semibold">{s(r.label)}</strong> · {Math.round(num(r.share) * 100)}%
                    {s(r.note) && <span className="block text-[13px] text-muted">{s(r.note)}</span>}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </Figure>
      );
    }
    case "flow":
      return (
        <Figure title={b.title} source={b.source} sources={sources}>
          <ol className="space-y-4">
            {items(b.items).map((i, n) => (
              <li key={n} className="rounded-xl border border-line p-4">
                <p className="font-sans text-[16px] font-semibold">{s(i.q)}</p>
                <p className="mt-2 font-sans text-[15px]"><span className="font-bold text-accent-text">Yes: </span>{s(i.yes)}</p>
                <p className="mt-1 font-sans text-[15px]"><span className="font-bold text-muted">No: </span>{s(i.no)}</p>
              </li>
            ))}
          </ol>
        </Figure>
      );
    case "band": {
      const ranges = list(b.ranges).filter((x): x is Item => typeof x === "object" && x !== null);
      const lo = Math.min(...ranges.map((r) => num(r.from))), hi = Math.max(...ranges.map((r) => num(r.to)));
      return (
        <Figure title={`${s(b.title)} · ${s(b.unit)}`} source={b.source} sources={sources}>
          <div className="flex h-4 overflow-hidden rounded-full" aria-hidden>
            {ranges.map((r, n) => (
              <div key={n} style={{ flex: num(r.to) - num(r.from), background: TONE[s(r.tone)] ?? "var(--accent)", opacity: 0.35 + 0.65 * ((n + 1) / ranges.length) }} />
            ))}
          </div>
          <div className="mt-1 flex justify-between font-sans text-[12px] tabular-nums text-muted"><span>{lo}</span><span>{hi}</span></div>
          <ul className="mt-3 space-y-2">
            {ranges.map((r, n) => (
              <li key={n} className="flex gap-3 font-sans text-[15px]">
                <span aria-hidden className="mt-1 h-3 w-3 shrink-0 rounded-full" style={{ background: TONE[s(r.tone)] ?? "var(--accent)" }} />
                <span><span className="tabular-nums font-semibold">{s(r.from)} to {s(r.to)}</span> · {s(r.label)}</span>
              </li>
            ))}
          </ul>
        </Figure>
      );
    }
    case "scale":
      return (
        <Figure title={b.title} source={b.source} sources={sources}>
          <ol className="space-y-3">
            {items(b.items).map((i, n) => (
              <li key={n} className="grid grid-cols-[5.5rem_1fr] gap-3 font-sans text-[15px]">
                <span className="rounded-lg bg-surface-2 px-2 py-1 text-center font-semibold tabular-nums">{s(i.mark)}</span>
                <span><strong className="font-semibold">{s(i.label)}.</strong> <span className="text-muted">{s(i.text)}</span></span>
              </li>
            ))}
          </ol>
        </Figure>
      );
    default:
      return null;
  }
}

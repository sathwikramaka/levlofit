// Renders the Handbook book's blocks (data/handbook_book/build.py, exported to src/lib/handbook_book.json) as plain,
// accessible HTML: the same content as the app's Handbook.
import Link from "next/link";

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
    default:
      return null;
  }
}

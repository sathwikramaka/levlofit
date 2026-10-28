// Renders the Handbook's typed blocks (data/handbook_v4/build_handbook_v4.py, exported to src/lib/handbook.json) as
// plain, accessible HTML: the same content as the app's Handbook, without its charts' animation.
import Link from "next/link";

type Item = Record<string, unknown>;
export type Block = { t: string; [k: string]: unknown };

const s = (v: unknown) => (typeof v === "string" ? v : v == null ? "" : String(v));
const list = (v: unknown) => (Array.isArray(v) ? (v as Item[]) : []);
const GRADE: Record<string, string> = { strong: "Strong evidence", moderate: "Moderate evidence", consensus: "Expert consensus" };

function Source({ k, sources }: { k: unknown; sources: Record<string, string> }) {
  if (typeof k !== "string" || !sources[k]) return null;
  return (
    <a href={`#src-${k}`} className="ml-1 align-super font-mono text-[11px] text-accent-text no-underline">
      [{Object.keys(sources).indexOf(k) + 1}]
    </a>
  );
}

function Title({ children }: { children: React.ReactNode }) {
  return <h2 className="text-[18px] font-bold tracking-[-0.01em]">{children}</h2>;
}

const box = "rounded-2xl border border-line bg-surface p-5 sm:p-6";

export function HandbookBlock({ b, sources }: { b: Block; sources: Record<string, string> }) {
  switch (b.t) {
    case "part":
      return (
        <div className="border-l-2 border-accent pl-4">
          <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">{s(b.title)}</p>
          <p className="mt-2 text-[16px] leading-relaxed text-muted">{s(b.text)}</p>
        </div>
      );
    case "lead":
      return <p className="text-[19px] leading-relaxed font-medium">{s(b.text)}</p>;
    case "text":
      return <p className="text-[16px] leading-relaxed">{s(b.text)}<Source k={b.source} sources={sources} /></p>;
    case "rule":
      return (
        <p className={`${box} text-[16px] leading-relaxed font-semibold`}>
          {s(b.text)}
          <Source k={b.source} sources={sources} />
        </p>
      );
    case "evidence":
      return (
        <div className={box}>
          <p className="font-mono text-[11px] tracking-[0.15em] text-muted uppercase">{GRADE[s(b.grade)] ?? "Evidence"}</p>
          <p className="mt-2 text-[16px] leading-relaxed">
            {s(b.text)}
            <Source k={b.source} sources={sources} />
          </p>
        </div>
      );
    case "flow":
      return (
        <div className={box}>
          <Title>{s(b.title)}</Title>
          <ol className="mt-3 space-y-3">
            {list(b.items).map((i, n) => (
              <li key={n} className="text-[15px] leading-relaxed">
                <p className="font-semibold">{s(i.q)}</p>
                <p className="mt-1"><span className="font-semibold">Yes:</span> {s(i.yes)}</p>
                <p><span className="font-semibold">No:</span> {s(i.no)}</p>
              </li>
            ))}
          </ol>
          {typeof b.note === "string" && <p className="mt-3 text-[14px] text-muted">{b.note}<Source k={b.source} sources={sources} /></p>}
        </div>
      );
    case "compare": {
      const side = (v: unknown, tone: string) => {
        const x = (v ?? {}) as Item;
        return (
          <div className={box}>
            <Title>{s(x.title)}</Title>
            <ul className={`mt-3 list-disc space-y-1 pl-5 text-[15px] leading-relaxed ${tone}`}>
              {list(x.items).map((i, n) => (
                <li key={n}>{s(i)}</li>
              ))}
            </ul>
          </div>
        );
      };
      return (
        <div className="grid gap-3 sm:grid-cols-2">
          {side(b.do, "")}
          {side(b.dont, "")}
        </div>
      );
    }
    case "stats":
      return (
        <div className="grid gap-3 sm:grid-cols-2">
          {list(b.items).map((i, n) => (
            <div key={n} className={box}>
              <p className="font-mono text-[28px] leading-none font-medium">
                {s(i.value)}
                {s(i.unit) && <span className="ml-1 text-[15px]">{s(i.unit)}</span>}
              </p>
              <p className="mt-2 text-[15px] leading-relaxed text-muted">
                {s(i.label)}
                <Source k={i.source} sources={sources} />
              </p>
            </div>
          ))}
        </div>
      );
    case "cycle":
    case "keypoints":
      return (
        <div className={box}>
          <Title>{s(b.title)}</Title>
          {b.t === "cycle" ? (
            <p className="mt-3 text-[15px] leading-relaxed">{list(b.items).map(s).join("  →  ")}  →  back to the start</p>
          ) : (
            <ul className="mt-3 list-disc space-y-1 pl-5 text-[15px] leading-relaxed">
              {list(b.items).map((i, n) => (
                <li key={n}>{s(i)}</li>
              ))}
            </ul>
          )}
        </div>
      );
    case "steps":
    case "scale":
      return (
        <div className={box}>
          <Title>{s(b.title)}</Title>
          <ol className="mt-3 space-y-2 text-[15px] leading-relaxed">
            {list(b.items).map((i, n) => (
              <li key={n}>
                <span className="font-semibold">{b.t === "scale" ? `${s(i.mark)}: ${s(i.label)}` : s(i.title)}</span>
                {s(i.text) && <span>. {s(i.text)}</span>}
                <Source k={i.source} sources={sources} />
              </li>
            ))}
          </ol>
        </div>
      );
    case "bars":
    case "plate": {
      const items = list(b.items);
      const key = b.t === "bars" ? "value" : "share";
      const max = Math.max(1, ...items.map((i) => Number(i[key]) || 0));
      return (
        <figure className={box}>
          <figcaption><Title>{s(b.title)}</Title></figcaption>
          <ul className="mt-4 space-y-3">
            {items.map((i, n) => (
              <li key={n}>
                <div className="flex justify-between gap-3 text-[15px]">
                  <span>{s(i.label)}</span>
                  <span className="font-mono">{s(i.note) || `${s(i[key])} ${s(b.unit)}`}</span>
                </div>
                <div className="mt-1 h-2 rounded-full bg-surface-2" aria-hidden>
                  <div className="h-2 rounded-full bg-accent" style={{ width: `${(100 * (Number(i[key]) || 0)) / max}%` }} />
                </div>
              </li>
            ))}
          </ul>
          <Source k={b.source} sources={sources} />
        </figure>
      );
    }
    case "band":
      return (
        <div className={box}>
          <Title>{s(b.title)}</Title>
          <table className="mt-3 w-full text-left text-[15px]">
            <thead className="text-muted">
              <tr>
                <th className="py-1 font-semibold">Range ({s(b.unit)})</th>
                <th className="py-1 font-semibold">Band</th>
              </tr>
            </thead>
            <tbody>
              {list(b.ranges).map((r, n) => (
                <tr key={n} className="border-t border-line">
                  <td className="py-2 font-mono">{s(r.from)} to {s(r.to)}</td>
                  <td className="py-2">{s(r.label)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <Source k={b.source} sources={sources} />
        </div>
      );
    case "table":
      return (
        // A scrollable region must be reachable by keyboard (focusable) and named.
        <div className={`${box} overflow-x-auto`} role="region" tabIndex={0} aria-label={typeof b.title === "string" ? b.title : `Table: ${list(b.head).map(s).join(", ")}`}>
          {typeof b.title === "string" && <Title>{b.title}</Title>}
          <table className="mt-2 w-full min-w-[480px] text-left text-[15px]">
            <thead className="text-muted">
              <tr>{list(b.head).map((h, n) => <th key={n} className="py-1 pr-3 font-semibold">{s(h)}</th>)}</tr>
            </thead>
            <tbody>
              {list(b.rows).map((r, n) => (
                <tr key={n} className="border-t border-line">
                  {(Array.isArray(r) ? r : []).map((c, m) => <td key={m} className="py-2 pr-3 align-top">{s(c)}</td>)}
                </tr>
              ))}
            </tbody>
          </table>
          <Source k={b.source} sources={sources} />
        </div>
      );
    case "week":
      return (
        <div className={box}>
          <Title>{s(b.title)}</Title>
          <ul className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-7">
            {list(b.days).map((d, n) => (
              <li key={n} className="rounded-xl border border-line px-3 py-2 text-[14px]">
                <span className="block font-mono text-[11px] text-muted uppercase">{s(d.day)}</span>
                {s(d.label)}
              </li>
            ))}
          </ul>
        </div>
      );
    case "next":
      return (
        <div className={box}>
          <Title>{s(b.title)}</Title>
          <ul className="mt-3 space-y-2">
            {list(b.items).map((i, n) => (
              <li key={n} className="text-[15px] leading-relaxed">
                <Link href={`/handbook/${s(i.ref)}`} className="font-semibold underline underline-offset-4">
                  {s(i.title)}
                </Link>
                {s(i.why) && <span className="text-muted">: {s(i.why)}</span>}
              </li>
            ))}
          </ul>
        </div>
      );
    default:
      return typeof b.text === "string" ? <p className="text-[16px] leading-relaxed">{b.text}</p> : null;
  }
}

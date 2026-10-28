"use client";

import { useEffect, useMemo, useRef, useState } from "react";

export type Entry = { title: string; hint: string; href: string; words?: string };

// Everything on the site worth finding. Keep in step with page.tsx, privacy and terms.
const INDEX: Entry[] = [
  { title: "How it works", hint: "Home", href: "/#how", words: "answer check explain plan review" },
  { title: "The Handbook", hint: "All chapters", href: "/handbook", words: "chapters form exercise search guide" },
  { title: "Indian food", hint: "Home", href: "/#food", words: "ifct dal paneer rajma soya allergy beef pork nutrition" },
  { title: "Where the rules come from", hint: "Home", href: "/#sources", words: "who acsm issn icmr nin lally science source" },
  { title: "Estimate your daily target", hint: "Home", href: "/#estimate", words: "calories tdee protein maintenance calculator kcal" },
  { title: "Download the Android app", hint: "Home", href: "/#download", words: "download apk android install app get" },
  { title: "Inside the app", hint: "Home", href: "/#features", words: "features muscle map meals rank up level challenge body check reminders ai kitchen mess warm-up" },
  { title: "Where do the numbers come from?", hint: "FAQ", href: "/#faq", words: "protein calories rules" },
  { title: "Do you suggest beef or pork?", hint: "FAQ", href: "/#faq", words: "diet food" },
  { title: "What does Levlofit AI do?", hint: "FAQ", href: "/#faq", words: "assistant chat bot doctor" },
  { title: "Allergies and intolerances", hint: "FAQ", href: "/#faq", words: "lactose gluten peanut" },
  { title: "Privacy policy", hint: "Legal", href: "/privacy", words: "data personal information dpdp groq supabase delete" },
  { title: "Terms and conditions", hint: "Legal", href: "/terms", words: "rules use medical liability" },
  { title: "Licences and credits", hint: "Legal", href: "/#licences", words: "licence license copyright credits open source exercisedb usda fonts" },
  { title: "Contact us", hint: "Help", href: "#contact", words: "email message support help" },
];

/** Site search: a keyboard-first dialog (Ctrl or Cmd + K, or the header button). */
export function Search({ extra = [] }: { extra?: Entry[] }) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [active, setActive] = useState(0);
  const input = useRef<HTMLInputElement>(null);

  const results = useMemo(() => {
    const terms = q.toLowerCase().split(/\s+/).filter(Boolean);
    if (!terms.length) return INDEX;
    // Handbook chapters join only once something is typed, so the empty list stays short.
    return [...INDEX, ...extra].filter((e) => terms.every((t) => `${e.title} ${e.hint} ${e.words ?? ""}`.toLowerCase().includes(t)));
  }, [q, extra]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    const onOpen = () => setOpen(true);
    addEventListener("keydown", onKey);
    addEventListener("open-search", onOpen);
    return () => {
      removeEventListener("keydown", onKey);
      removeEventListener("open-search", onOpen);
    };
  }, []);

  useEffect(() => {
    if (open) setTimeout(() => input.current?.focus(), 30);
  }, [open]);

  const close = () => {
    setOpen(false);
    setQ("");
    setActive(0);
  };

  const go = (e: Entry) => {
    close();
    if (e.href === "#contact") dispatchEvent(new Event("open-contact"));
    // Native navigation: router.push left the page in place for same-page anchors (/#handbook from /).
    else location.assign(e.href);
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Search Levlofit"
      aria-hidden={!open}
      onClick={close}
      className={`fixed inset-0 z-[55] flex items-start justify-center bg-bg/70 px-4 pt-[14vh] backdrop-blur-md transition-opacity duration-300 ease-spring ${open ? "opacity-100" : "pointer-events-none opacity-0"}`}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className={`w-full max-w-xl rounded-2xl border border-line bg-surface transition-all duration-500 ease-spring ${open ? "translate-y-0 scale-100" : "-translate-y-3 scale-[0.98]"}`}
      >
        <div className="flex items-center gap-3 border-b border-line px-4">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-muted" aria-hidden>
            <circle cx="11" cy="11" r="7" />
            <path d="m20 20-3.5-3.5" />
          </svg>
          <input
            ref={input}
            value={q}
            tabIndex={open ? 0 : -1}
            onChange={(e) => {
              setQ(e.target.value);
              setActive(0);
            }}
            onKeyDown={(e) => {
              if (e.key === "Escape") close();
              if (e.key === "ArrowDown") {
                e.preventDefault();
                setActive((a) => Math.min(a + 1, results.length - 1));
              }
              if (e.key === "ArrowUp") {
                e.preventDefault();
                setActive((a) => Math.max(a - 1, 0));
              }
              if (e.key === "Enter" && results[active]) go(results[active]);
            }}
            placeholder="Search Levlofit"
            aria-label="Search Levlofit"
            className="h-14 flex-1 bg-transparent text-[16px] outline-none placeholder:text-muted"
          />
          <kbd className="rounded-md border border-line px-1.5 py-0.5 font-mono text-[11px] text-muted">Esc</kbd>
        </div>
        <ul className="max-h-[50vh] overflow-y-auto p-2" role="listbox">
          {results.length === 0 && <li className="px-3 py-6 text-center text-[15px] text-muted">Nothing found for &ldquo;{q}&rdquo;.</li>}
          {results.map((r, i) => (
            <li key={r.href + r.title} role="option" aria-selected={i === active}>
              <button
                type="button"
                tabIndex={open ? 0 : -1}
                onMouseEnter={() => setActive(i)}
                onClick={() => go(r)}
                className={`flex w-full items-center justify-between rounded-xl px-3 py-3 text-left transition-colors duration-200 ${i === active ? "bg-surface-2" : ""}`}
              >
                <span className="text-[15px] font-semibold">{r.title}</span>
                <span className="font-mono text-[11px] tracking-[0.15em] text-muted uppercase">{r.hint}</span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Wordmark } from "./wordmark";

const links = [
  { href: "/#how", label: "How it works" },
  { href: "/#handbook", label: "Handbook" },
  { href: "/#food", label: "Indian food" },
  { href: "/#faq", label: "FAQ" },
  { href: "/#download", label: "Download" },
];

/** Floating header island, scroll progress, mobile menu, theme toggle, back to top, scroll reveals. */
export function SiteChrome() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const path = usePathname();

  // Keep utm_* from the landing URL for this visit, so the contact form can say which link brought someone in.
  useEffect(() => {
    try {
      const utm: Record<string, string> = {};
      new URLSearchParams(location.search).forEach((v, k) => {
        if (k.startsWith("utm_") && Object.keys(utm).length < 5) utm[k.slice(0, 20)] = v.slice(0, 100);
      });
      if (Object.keys(utm).length) sessionStorage.setItem("utm", JSON.stringify(utm));
    } catch {}
  }, []);

  useEffect(() => {
    // One observer for every [data-reveal] element; each reveals once.
    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (!e.isIntersecting) return;
          e.target.classList.add("is-in");
          io.unobserve(e.target);
        }),
      { rootMargin: "0px 0px -10% 0px" },
    );
    document.querySelectorAll("[data-reveal]").forEach((el) => io.observe(el));

    // Scroll progress goes straight to the element's transform; no React render per frame.
    const bar = document.getElementById("progress");
    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const max = document.documentElement.scrollHeight - innerHeight;
        bar?.style.setProperty("transform", `scaleX(${max > 0 ? scrollY / max : 0})`);
        setScrolled(scrollY > 480);
      });
    };
    addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => {
      io.disconnect();
      removeEventListener("scroll", onScroll);
    };
  }, [path]); // re-observe on each page, since the header lives in the layout

  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    addEventListener("keydown", onKey);
    return () => removeEventListener("keydown", onKey);
  }, [open]);

  // Reads the live colour scheme (saved choice or system), so no theme state is kept in React.
  const toggleTheme = () => {
    const next = getComputedStyle(document.documentElement).colorScheme !== "dark";
    document.documentElement.dataset.theme = next ? "dark" : "light";
    try {
      localStorage.setItem("theme", next ? "dark" : "light");
    } catch {}
  };

  return (
    <>
      <div id="progress" aria-hidden className="fixed inset-x-0 top-0 z-50 h-[3px] origin-left scale-x-0 bg-accent" />
      <header className="fixed inset-x-0 top-4 z-40 flex justify-center px-4">
        <nav aria-label="Main" className="flex w-full max-w-5xl items-center justify-between gap-6 rounded-2xl border border-line bg-surface/80 py-2.5 pr-2.5 pl-5 backdrop-blur-xl">
          <Link href="/" className="shrink-0" aria-label="Levlofit home">
            <Wordmark />
          </Link>
          <ul className="hidden items-center gap-1 md:flex">
            {links.map((l) => (
              <li key={l.href}>
                <a href={l.href} className="rounded-lg px-3 py-2 text-[14px] text-muted transition-colors duration-300 ease-spring hover:bg-surface-2 hover:text-ink">
                  {l.label}
                </a>
              </li>
            ))}
          </ul>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={toggleTheme}
              aria-label="Toggle dark mode"
              className="grid h-11 w-11 place-items-center rounded-xl text-muted transition-colors duration-300 ease-spring hover:bg-surface-2 hover:text-ink"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
                {/* globals.css shows the sun in dark mode and the moon in light mode */}
                <g className="icon-sun">
                  <circle cx="12" cy="12" r="4.5" />
                  <path d="M12 2.5v2M12 19.5v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M2.5 12h2M19.5 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4" />
                </g>
                <path className="icon-moon" d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z" />
              </svg>
            </button>
            <button
              type="button"
              onClick={() => dispatchEvent(new Event("open-search"))}
              aria-label="Search"
              className="inline-flex h-11 items-center gap-3 rounded-xl border-line px-3 text-[14px] text-muted transition-colors duration-300 ease-spring hover:border-ink hover:text-ink sm:border sm:pr-2 sm:pl-3.5"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
                <circle cx="11" cy="11" r="7" />
                <path d="m20 20-3.5-3.5" />
              </svg>
              <span className="hidden sm:inline">Search</span>
              <kbd className="hidden rounded-md border border-line px-1.5 py-0.5 font-mono text-[11px] sm:inline">Ctrl K</kbd>
            </button>
            <button
              type="button"
              onClick={() => setOpen((o) => !o)}
              aria-expanded={open}
              aria-controls="mobile-menu"
              aria-label={open ? "Close menu" : "Open menu"}
              className="relative grid h-11 w-11 place-items-center rounded-xl md:hidden"
            >
              <span className={`absolute h-[1.5px] w-5 bg-ink transition-transform duration-500 ease-spring ${open ? "rotate-45" : "-translate-y-[4px]"}`} />
              <span className={`absolute h-[1.5px] w-5 bg-ink transition-transform duration-500 ease-spring ${open ? "-rotate-45" : "translate-y-[4px]"}`} />
            </button>
          </div>
        </nav>
      </header>

      <div
        id="mobile-menu"
        className={`fixed inset-0 z-30 bg-bg/90 backdrop-blur-2xl transition-opacity duration-500 ease-spring md:hidden ${open ? "opacity-100" : "pointer-events-none opacity-0"}`}
        aria-hidden={!open}
      >
        <ul className="flex h-full flex-col justify-center gap-2 px-8">
          {[...links, { href: "/privacy", label: "Privacy" }, { href: "/terms", label: "Terms" }].map((l, i) => (
            <li key={l.href} className="overflow-hidden">
              <a
                href={l.href}
                tabIndex={open ? 0 : -1}
                onClick={() => setOpen(false)}
                style={{ transitionDelay: open ? `${100 + i * 60}ms` : "0ms" }}
                className={`block py-2 text-4xl font-semibold tracking-tight transition-all duration-700 ease-spring ${open ? "translate-y-0 opacity-100" : "translate-y-12 opacity-0"}`}
              >
                {l.label}
              </a>
            </li>
          ))}
        </ul>
      </div>

      <nav aria-label="Back to top">
      <a
        href="#"
        onClick={(e) => {
          e.preventDefault();
          scrollTo({ top: 0 });
        }}
        aria-label="Back to top"
        tabIndex={scrolled ? 0 : -1}
        className={`no-print fixed right-6 bottom-22 z-30 grid h-12 w-12 place-items-center rounded-xl border border-line bg-surface text-ink transition-all duration-500 ease-spring hover:-translate-y-0.5 ${scrolled ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-4 opacity-0"}`}
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
          <path d="M12 19V5M6 11l6-6 6 6" />
        </svg>
      </a>
      </nav>
    </>
  );
}

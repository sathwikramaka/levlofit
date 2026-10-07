"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

/** Honest notice: the site sets no tracking cookies, only remembers theme and this notice on the device. */
export function CookieNotice() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    let seen = true;
    try {
      seen = localStorage.getItem("cookie-ok") === "1";
    } catch {}
    // Arrive after the first paint settles, never on top of the hero animation.
    const t = setTimeout(() => setShow(!seen), 1400);
    return () => clearTimeout(t);
  }, []);

  const ok = () => {
    setShow(false);
    try {
      localStorage.setItem("cookie-ok", "1");
    } catch {}
  };

  return (
    <div
      role="region"
      aria-label="Cookie notice"
      aria-hidden={!show}
      className={`no-print fixed bottom-22 left-6 z-30 w-[calc(100%-3rem)] sm:bottom-6 max-w-sm rounded-2xl border border-line bg-surface p-5 transition-all duration-700 ease-spring sm:w-auto ${show ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-6 opacity-0"}`}
    >
      <p className="text-[14px] leading-relaxed">
        No tracking cookies here. We only remember your light or dark choice on this device.{" "}
        <Link href="/privacy" tabIndex={show ? 0 : -1} className="font-semibold text-accent-text underline-offset-4 hover:underline">
          Privacy
        </Link>
      </p>
      <button type="button" onClick={ok} tabIndex={show ? 0 : -1} className="mt-4 h-10 rounded-xl bg-ink px-4 text-[14px] font-semibold text-on-ink transition-transform duration-300 ease-spring active:scale-[0.98]">
        Got it
      </button>
    </div>
  );
}

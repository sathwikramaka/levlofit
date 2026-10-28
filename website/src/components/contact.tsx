"use client";

import { useEffect, useState } from "react";

// Public by design: the publishable key only allows what RLS allows (insert into contact_messages).
const SUPABASE_URL = "https://ndeozgxowggkljluaccz.supabase.co";
const SUPABASE_KEY = "sb_publishable_RDQ5eDXSYQn8vuBLZ5agFA_4wUGVi2r";
export const CONTACT_EMAIL = "levlofit.app@gmail.com";

type State = { kind: "idle" } | { kind: "sending" } | { kind: "sent" } | { kind: "error"; message: string };

function readUtm() {
  try {
    return JSON.parse(sessionStorage.getItem("utm") ?? "{}");
  } catch {
    return {};
  }
}

/** Copies text and shows "Copied" for a moment. */
export function CopyButton({ text, label = "Copy" }: { text: string; label?: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      type="button"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(text);
          setDone(true);
          setTimeout(() => setDone(false), 1600);
        } catch {}
      }}
      aria-live="polite"
      className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-line px-3 text-[13px] font-semibold transition-colors duration-300 ease-spring hover:bg-surface-2"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden>
        {done ? (
          <path d="m5 12 5 5 9-10" />
        ) : (
          <>
            <rect x="8" y="8" width="12" height="12" rx="2" />
            <path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" />
          </>
        )}
      </svg>
      {done ? "Copied" : label}
    </button>
  );
}

/** Floating contact button, message panel with success and error states, and a discard confirmation. */
export function Contact() {
  const [open, setOpen] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [trap, setTrap] = useState(""); // honeypot: hidden from people, often filled by spam bots
  const [state, setState] = useState<State>({ kind: "idle" });

  useEffect(() => {
    const onOpen = () => setOpen(true);
    addEventListener("open-contact", onOpen);
    return () => removeEventListener("open-contact", onOpen);
  }, []);

  const reset = () => {
    setOpen(false);
    setConfirm(false);
    setEmail("");
    setMessage("");
    setState({ kind: "idle" });
  };

  // Closing with an unsent message asks first, so nobody loses what they typed.
  const requestClose = () => (message.trim() && state.kind !== "sent" ? setConfirm(true) : reset());

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      if (confirm) setConfirm(false);
      else requestClose();
    };
    addEventListener("keydown", onKey);
    return () => removeEventListener("keydown", onKey);
  });

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const addr = email.trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(addr)) return setState({ kind: "error", message: "Enter a full email address so we can reply." });
    if (message.trim().length < 10) return setState({ kind: "error", message: "Write a little more, at least 10 characters." });
    // A filled honeypot means an automated submission: look sent, store nothing.
    if (trap) return setState({ kind: "sent" });
    setState({ kind: "sending" });
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/contact_messages`, {
        method: "POST",
        headers: { apikey: SUPABASE_KEY, "content-type": "application/json", prefer: "return=minimal" },
        body: JSON.stringify({ email: addr, message: message.trim().slice(0, 2000), utm: readUtm() }),
      });
      setState(res.ok ? { kind: "sent" } : { kind: "error", message: "That did not go through. Try again, or email us directly." });
    } catch {
      setState({ kind: "error", message: "No connection. Check your internet and try again." });
    }
  }

  const error = state.kind === "error" ? state.message : null;

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label="Contact Levlofit"
        className="no-print group fixed right-6 bottom-6 z-30 flex h-12 items-center gap-2.5 rounded-xl bg-ink pr-4 pl-3.5 text-[14px] font-semibold text-on-ink transition-transform duration-500 ease-spring hover:-translate-y-0.5 active:scale-[0.98]"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden>
          <path d="M4 5h16v11H8l-4 3.5V5Z" />
        </svg>
        Contact
      </button>

      <div
        onClick={requestClose}
        aria-hidden={!open}
        className={`fixed inset-0 z-[56] bg-bg/60 backdrop-blur-sm transition-opacity duration-300 ease-spring ${open ? "opacity-100" : "pointer-events-none opacity-0"}`}
      />
      <aside
        role="dialog"
        aria-modal="true"
        aria-labelledby="contact-title"
        aria-hidden={!open}
        inert={!open}
        className={`fixed right-0 bottom-0 z-[57] flex w-full flex-col rounded-t-3xl border border-line bg-surface p-6 transition-transform duration-700 ease-spring sm:right-6 sm:bottom-6 sm:w-[420px] sm:rounded-3xl ${open ? "translate-y-0" : "pointer-events-none translate-y-[110%]"}`}
      >
        <div className="flex items-start justify-between">
          <div>
            <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">Contact</p>
            <h2 id="contact-title" className="mt-2 text-[24px] font-bold tracking-tight">
              Talk to us
            </h2>
          </div>
          <button type="button" onClick={requestClose} aria-label="Close" tabIndex={open ? 0 : -1} className="grid h-11 w-11 place-items-center rounded-xl hover:bg-surface-2">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <div className="mt-4 flex items-center justify-between gap-3 rounded-xl border border-line bg-bg px-4 py-3">
          <span className="truncate text-[14px]">{CONTACT_EMAIL}</span>
          <CopyButton text={CONTACT_EMAIL} />
        </div>

        {state.kind === "sent" ? (
          <div role="status" className="mt-5 flex items-start gap-3 rounded-xl border border-line p-4">
            <span className="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-success text-bg">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" aria-hidden>
                <path d="m5 12 5 5 9-10" />
              </svg>
            </span>
            <p className="text-[15px] leading-relaxed">Message sent. We reply by email, usually within two working days.</p>
          </div>
        ) : (
          <form onSubmit={submit} noValidate className="mt-5 flex flex-col gap-4">
            <input
              type="text"
              name="website"
              value={trap}
              onChange={(e) => setTrap(e.target.value)}
              tabIndex={-1}
              autoComplete="off"
              aria-hidden="true"
              className="absolute -left-[9999px] h-px w-px opacity-0"
            />
            <div>
              <label htmlFor="c-email" className="mb-1.5 block text-[14px] font-semibold">
                Your email
              </label>
              <input
                id="c-email"
                type="email"
                autoComplete="email"
                tabIndex={open ? 0 : -1}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="h-12 w-full rounded-xl border border-line bg-surface px-4 text-[16px] outline-none focus:border-ink"
              />
            </div>
            <div>
              <label htmlFor="c-msg" className="mb-1.5 block text-[14px] font-semibold">
                Message
              </label>
              <textarea
                id="c-msg"
                rows={4}
                maxLength={2000}
                tabIndex={open ? 0 : -1}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                className="w-full resize-none rounded-xl border border-line bg-surface px-4 py-3 text-[16px] outline-none focus:border-ink"
              />
            </div>
            {error && (
              <p role="alert" className="text-[14px] text-danger">
                {error}
              </p>
            )}
            <button
              type="submit"
              tabIndex={open ? 0 : -1}
              disabled={state.kind === "sending"}
              className="h-12 rounded-xl bg-accent text-[16px] font-bold text-on-accent transition-transform duration-300 ease-spring active:scale-[0.98] disabled:opacity-60"
            >
              {state.kind === "sending" ? "Sending" : "Send message"}
            </button>
          </form>
        )}
      </aside>

      {/* Confirmation modal */}
      <div
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="discard-title"
        aria-hidden={!confirm}
        className={`fixed inset-0 z-[58] grid place-items-center bg-bg/60 px-4 backdrop-blur-sm transition-opacity duration-300 ease-spring ${confirm ? "opacity-100" : "pointer-events-none opacity-0"}`}
      >
        <div className={`w-full max-w-sm rounded-2xl border border-line bg-surface p-6 transition-transform duration-500 ease-spring ${confirm ? "scale-100" : "scale-95"}`}>
          <h3 id="discard-title" className="text-[20px] font-bold tracking-tight">
            Discard your message?
          </h3>
          <p className="mt-2 text-[15px] leading-relaxed text-muted">What you typed has not been sent. It will be lost.</p>
          <div className="mt-6 flex justify-end gap-3">
            <button type="button" tabIndex={confirm ? 0 : -1} onClick={() => setConfirm(false)} className="h-11 rounded-xl border border-ink px-4 text-[15px] font-semibold">
              Keep writing
            </button>
            <button type="button" tabIndex={confirm ? 0 : -1} onClick={reset} className="h-11 rounded-xl bg-danger px-4 text-[15px] font-semibold text-bg">
              Discard
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

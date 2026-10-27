// Direct APK download. The link, version, size and checksum come from build-time settings, so a new release only
// changes the environment (NEXT_PUBLIC_APK_URL, NEXT_PUBLIC_APK_VERSION, NEXT_PUBLIC_APK_SIZE, NEXT_PUBLIC_APK_SHA256),
// never this file. Without a URL the button says the download is coming instead of linking nowhere.
export const apk = {
  url: process.env.NEXT_PUBLIC_APK_URL ?? "",
  version: process.env.NEXT_PUBLIC_APK_VERSION ?? "",
  size: process.env.NEXT_PUBLIC_APK_SIZE ?? "",
  sha256: process.env.NEXT_PUBLIC_APK_SHA256 ?? "",
};

const DownloadIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
    <path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19h14" />
  </svg>
);

/** The main download button; [compact] for the hero. */
export function DownloadButton({ compact = false }: { compact?: boolean }) {
  const base = `inline-flex h-12 items-center gap-3 rounded-xl px-5 text-[16px] font-bold transition-transform duration-300 ease-spring ${compact ? "" : "sm:h-14 sm:px-7 sm:text-[17px]"}`;
  if (!apk.url) {
    return (
      <span aria-disabled className={`${base} cursor-not-allowed border border-line bg-surface text-muted`}>
        <DownloadIcon />
        Android download coming soon
      </span>
    );
  }
  return (
    <a href={apk.url} download className={`${base} bg-accent text-on-accent active:scale-[0.98]`}>
      <DownloadIcon />
      Download for Android
    </a>
  );
}

const installSteps = [
  ["Download", "Tap the button on your Android phone. The file is the Levlofit app (an APK)."],
  ["Allow the install", "Android asks once to allow installs from your browser. Allow it for this file only."],
  ["Open and sign in", "Create your account with email or Google, answer a few questions, and get your plan."],
];

export function DownloadSection() {
  const facts = [
    apk.version && ["Version", apk.version],
    apk.size && ["Size", apk.size],
    ["Needs", "Android 7.0 or newer"],
    ["Price", "Free, no ads"],
  ].filter(Boolean) as string[][];
  return (
    <section id="download" className="border-y border-line bg-surface/50">
      <div className="mx-auto grid max-w-6xl gap-14 px-4 py-28 sm:px-6 sm:py-36 lg:grid-cols-[1.1fr_1fr]">
        <div data-reveal>
          <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">Get the app</p>
          <h2 className="mt-4 max-w-[16ch] text-[clamp(32px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">Download Levlofit for Android.</h2>
          <p className="mt-6 max-w-[42ch] text-[17px] leading-relaxed text-muted">
            Straight from us, no store needed. Free while we grow. An iPhone version is not ready yet.
          </p>
          <div className="mt-9">
            <DownloadButton />
          </div>
          <dl className="mt-8 grid max-w-md grid-cols-2 gap-x-6 gap-y-4">
            {facts.map(([k, v]) => (
              <div key={k}>
                <dt className="font-mono text-[11px] tracking-[0.15em] text-muted uppercase">{k}</dt>
                <dd className="mt-1 text-[15px] font-semibold">{v}</dd>
              </div>
            ))}
          </dl>
          {apk.sha256 && (
            <p className="mt-6 max-w-md text-[13px] leading-relaxed break-all text-muted">
              SHA-256: <span className="font-mono">{apk.sha256}</span>
            </p>
          )}
        </div>
        <ol data-reveal style={{ "--i": 1 } as React.CSSProperties} className="grid content-start gap-4">
          {installSteps.map(([t, b], i) => (
            <li key={t} className="rounded-2xl border border-line bg-surface p-5">
              <p className="font-mono text-[13px] text-accent-text">{String(i + 1).padStart(2, "0")}</p>
              <p className="mt-2 text-[17px] font-bold">{t}</p>
              <p className="mt-1 text-[14px] leading-relaxed text-muted">{b}</p>
            </li>
          ))}
          <li className="rounded-2xl border border-line p-5 text-[14px] leading-relaxed text-muted">
            Updates: open the website again for the newest version, or let the free Obtainium app check for you.
          </li>
        </ol>
      </div>
    </section>
  );
}

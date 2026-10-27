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

export function DownloadSection() {
  return (
    <section id="download" className="border-y border-line bg-surface/50">
      <div data-reveal className="mx-auto max-w-6xl px-4 py-28 text-center sm:px-6 sm:py-36">
        <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">Get the app</p>
        <h2 className="mx-auto mt-4 max-w-[16ch] text-[clamp(32px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">Download Levlofit for Android.</h2>
        <div className="mt-10 flex justify-center">
          <DownloadButton />
        </div>
        {(apk.version || apk.size) && (
          <p className="mt-5 text-[14px] text-muted">{[apk.version && `Version ${apk.version}`, apk.size].filter(Boolean).join("  ·  ")}</p>
        )}
        {apk.sha256 && (
          <p className="mx-auto mt-3 max-w-md text-[12px] leading-relaxed break-all text-muted">
            SHA-256: <span className="font-mono">{apk.sha256}</span>
          </p>
        )}
      </div>
    </section>
  );
}

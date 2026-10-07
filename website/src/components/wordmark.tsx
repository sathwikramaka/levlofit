/** levl + orange bubble + fit (DESIGN.md section 4). The bubble settles on load. */
export function Wordmark({ className = "text-[22px]" }: { className?: string }) {
  return (
    <span className={`font-display inline-flex items-center font-bold leading-none tracking-tight ${className}`} aria-label="Levlofit">
      <span aria-hidden>levl</span>
      <span aria-hidden className="inline-block h-[0.62em] w-[0.62em] overflow-hidden">
        <span className="bubble block h-full w-full rounded-full bg-accent" />
      </span>
      <span aria-hidden>fit</span>
    </span>
  );
}

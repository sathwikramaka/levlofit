/** A spirit-level vial: the bubble drifts, overshoots and settles in the centre. The brand idea, in motion. */
export function Vial() {
  return (
    <span aria-hidden className="relative inline-block h-[14px] w-[46px] overflow-hidden rounded-full border border-line bg-surface-2">
      <span className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-muted/50" />
      <span className="vial-bubble absolute top-1/2 left-1/2 h-[8px] w-[14px] rounded-full bg-accent" />
    </span>
  );
}

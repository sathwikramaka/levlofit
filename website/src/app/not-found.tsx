import Link from "next/link";

export default function NotFound() {
  return (
    <main id="main" className="mx-auto max-w-3xl px-4 pt-36 pb-28 sm:px-6">
      <h1 className="text-[clamp(34px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">Page not found</h1>
      <p className="mt-4 text-[18px] text-muted">
        That page does not exist. Try the <Link href="/" className="underline underline-offset-4">home page</Link> or{" "}
        <Link href="/handbook" className="underline underline-offset-4">the Handbook</Link>.
      </p>
    </main>
  );
}

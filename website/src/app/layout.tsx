import type { Metadata } from "next";
import { Geist, Geist_Mono, Unbounded } from "next/font/google";
import Link from "next/link";
import { Contact } from "@/components/contact";
import { Credits } from "@/components/credits";
import { Search } from "@/components/search";
import { chapters } from "@/lib/handbook";
import { SiteChrome } from "@/components/site-chrome";
import { Wordmark } from "@/components/wordmark";
import "./globals.css";

const geist = Geist({ variable: "--font-geist", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });
const unbounded = Unbounded({ variable: "--font-unbounded", subsets: ["latin"], weight: ["700"] });

export const metadata: Metadata = {
  title: { default: "Levlofit: train with reasons", template: "%s · Levlofit" },
  description: "Training and nutrition that checks your answers, explains every decision and cites a source for every rule. Built for Indian kitchens.",
};

// Runs before paint: a saved theme never flashes the wrong colours, and the intro plays once per visit.
const init = `try{var t=localStorage.getItem('theme');if(t)document.documentElement.dataset.theme=t;if(sessionStorage.getItem('intro'))document.documentElement.classList.add('no-intro');sessionStorage.setItem('intro','1')}catch(e){}`;

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en-IN" className={`${geist.variable} ${geistMono.variable} ${unbounded.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: init }} />
      </head>
      <body className="min-h-dvh">
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[70] focus:rounded-xl focus:bg-accent focus:px-4 focus:py-3 focus:font-semibold focus:text-on-accent"
        >
          Skip to content
        </a>
        <SiteChrome />
        {children}
        <footer className="border-t border-line">
          <div className="mx-auto flex max-w-6xl flex-col gap-8 px-4 py-14 sm:flex-row sm:items-center sm:justify-between sm:px-6">
            <div>
              <Wordmark className="text-[20px]" />
              <p className="mt-3 max-w-[40ch] text-[13px] leading-relaxed text-muted">Levlofit explains training and food. It is not medical advice.</p>
            </div>
            <nav aria-label="Footer" className="flex gap-6 text-[14px]">
              <Link href="/privacy" className="text-muted transition-colors duration-300 hover:text-ink">
                Privacy
              </Link>
              <Link href="/terms" className="text-muted transition-colors duration-300 hover:text-ink">
                Terms
              </Link>
            </nav>
          </div>
          <Credits />
        </footer>
        <Search extra={chapters.map((c) => ({ title: c.title, hint: "Handbook", href: `/handbook/${c.slug}`, words: c.summary }))} />
        <Contact />
      </body>
    </html>
  );
}

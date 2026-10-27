import { DownloadButton, DownloadSection } from "@/components/download";
import { Vial } from "@/components/vial";
import { Wordmark } from "@/components/wordmark";

/** Splits a headline into words that rise one by one (see .word in globals.css). */
function Rise({ text, offset = 0 }: { text: string; offset?: number }) {
  return text.split(" ").map((w, i) => (
    <span key={i} className="word">
      <span style={{ "--i": i + offset } as React.CSSProperties}>{w}&nbsp;</span>
    </span>
  ));
}

function Eyebrow({ children }: { children: React.ReactNode }) {
  return <p className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">{children}</p>;
}

/** Double-bezel frame from DESIGN.md: an outer tray holding an inner core. */
function Bezel({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`rounded-[28px] border border-line bg-surface-2/60 p-1.5 ${className}`}>
      <div className="h-full rounded-[22px] border border-line bg-surface p-6 sm:p-8">{children}</div>
    </div>
  );
}

function PhoneMock() {
  return (
    <div className="float relative mx-auto w-[300px]">
      <div className="rounded-[44px] border border-line bg-surface-2 p-2.5">
        <div className="overflow-hidden rounded-[36px] border border-line bg-bg px-5 pt-6 pb-7">
          <div className="flex items-center justify-between">
            <Wordmark className="text-[15px]" />
            <span className="font-mono text-[9px] tracking-[0.2em] text-muted">EXAMPLE PLAN</span>
          </div>
          <p className="mt-5 text-[20px] font-bold tracking-tight">Hi, Anand</p>
          <div className="mt-4 rounded-2xl border border-danger/40 bg-surface p-3.5">
            <p className="font-mono text-[9px] tracking-[0.2em] text-muted">CHANGED</p>
            <p className="mt-1 text-[13px] leading-snug font-semibold">Cutting became Maintenance</p>
            <p className="mt-1 text-[11px] leading-snug text-muted">Your BMI is under 18.5. Build strength first, then cut.</p>
            <p className="mt-1.5 text-[10px] text-muted">Source: WHO BMI classification</p>
          </div>
          <div className="mt-3 rounded-2xl border border-line bg-surface p-3.5">
            <p className="font-mono text-[9px] tracking-[0.2em] text-muted">THIS WEEK</p>
            <p className="mt-1 font-mono text-[28px] leading-none">
              4 <span className="font-sans text-[11px] text-muted">training days</span>
            </p>
            {[
              ["Strength", "Level 1", "3x"],
              ["Running", "Level 0", "1x"],
            ].map(([g, l, n]) => (
              <div key={g} className="mt-2.5 flex items-center border-t border-line pt-2.5 text-[12px]">
                <span className="flex-1 font-semibold">{g}</span>
                <span className="mr-3 text-muted">{l}</span>
                <span className="font-mono font-bold">{n}</span>
              </div>
            ))}
          </div>
          <div className="mt-3 flex items-center gap-2 rounded-2xl border border-line bg-surface px-3.5 py-2.5">
            <span className="pulse h-2 w-2 rounded-full bg-accent" />
            <span className="text-[12px] font-semibold">Ask Levlofit AI</span>
          </div>
        </div>
      </div>
    </div>
  );
}

const steps = [
  {
    n: "01",
    title: "You answer",
    body: "Goals first, then your level in each. Body, schedule, a short health check, equipment, allergies, then how you eat.",
  },
  {
    n: "02",
    title: "It checks",
    body: "Before planning, every answer is tested against your numbers. Unsafe or mismatched choices are changed, and the change is shown.",
  },
  {
    n: "03",
    title: "It explains",
    body: "Each decision carries its reason and a named source. Ask Levlofit AI anything about your plan and it answers from the plan itself.",
  },
];

const chapters = [
  "Foundations of training",
  "Strength and muscle",
  "Calisthenics",
  "Running",
  "HYROX and hybrid",
  "Mobility and recovery",
  "Nutrition for Indian diets",
  "Sleep and habits",
];

const sources = [
  ["WHO", "Physical activity guidelines, 2020"],
  ["ACSM", "Exercise testing and prescription"],
  ["ISSN", "Position stands on protein and creatine"],
  ["ICMR-NIN", "Indian Food Composition Tables, 2017"],
  ["Lally et al.", "How long habits take to form, 2010"],
];

const features = [
  ["Muscle map", "Tap a muscle on the body to see the moves that train it. Filter by equipment and difficulty, with an animated demo for each move."],
  ["Meals to the gram", "Pick your region's staples and how fast you want to go. Every day is planned to your calories and protein, in grams."],
  ["Level up", "XP, levels and a 66-day challenge, all worked out from what you actually log. A missed day never resets the run."],
  ["Levlofit AI", "Remembers what you tell it, explains your plan in plain words, and changes it only after you say yes."],
  ["Body check, if you want it", "One photo gives posture notes and what to train more. Optional, and the photo is never saved."],
  ["Reminders that fit", "Training, water and your own reminders, at the times you choose."],
];

const faqs = [
  [
    "Where do the numbers come from?",
    "From published sources, not from an AI. Protein, calories, activity minutes and food limits are calculated by fixed rules, and each rule names its source.",
  ],
  ["Do you suggest beef or pork?", "Never. Levlofit is built for Indian users. Food choices are vegetarian, eggitarian, vegan or non-vegetarian without beef and pork."],
  [
    "What does Levlofit AI do?",
    "It explains your plan in plain words and answers questions about it. It cannot change your numbers and it is not a doctor. If your health check needs a doctor, it says so.",
  ],
  ["I have an allergy. Is that covered?", "Allergies and intolerances are asked before your diet. Foods that contain them are removed from every suggestion, including ones you type in yourself."],
  ["Can I delete my account?", "Yes, from the account menu at any time. Your profile, plans and logs are deleted with it."],
  ["Why is it not on the Play Store?", "We share the app straight from this website first. A store listing may follow."],
  [
    "Is the download safe?",
    "It comes only from this website, signed with Levlofit's own key. Android installs updates only when they carry the same signature, and the SHA-256 checksum next to the button lets you check the file.",
  ],
  ["Does it work on iPhone?", "Not yet. Levlofit is Android only for now."],
];

export default function Home() {
  return (
    <>
      <div className="intro" aria-hidden>
        <Wordmark className="text-[34px]" />
      </div>
      <main id="main" className="overflow-x-clip">
        {/* Hero */}
        <section id="top" className="relative mx-auto grid min-h-[100dvh] max-w-6xl items-center gap-16 px-4 pt-36 pb-24 sm:px-6 lg:grid-cols-[1.15fr_1fr]">
          <div>
            <p className="inline-flex items-center gap-3 font-mono text-[11px] tracking-[0.2em] text-muted uppercase">
              <Vial />
              Find your level
            </p>
            <h1 className="mt-7 text-[clamp(44px,8vw,92px)] leading-[0.95] font-bold tracking-[-0.045em]">
              <Rise text="Train with" />
              <br />
              <span className="text-accent-text">
                <Rise text="reasons." offset={2} />
              </span>
            </h1>
            <p data-reveal style={{ "--i": 3 } as React.CSSProperties} className="mt-7 max-w-[34ch] text-[18px] leading-relaxed text-muted">
              Levlofit checks your answers before it builds anything, then shows you why. Every rule comes from a source you can read.
            </p>
            <div data-reveal style={{ "--i": 4 } as React.CSSProperties} className="mt-9 flex flex-wrap gap-3">
              <DownloadButton compact />
              <a
                href="#how"
                className="inline-flex h-12 items-center rounded-xl border border-ink px-5 text-[16px] font-semibold transition-colors duration-300 ease-spring hover:bg-ink hover:text-on-ink"
              >
                See how it works
              </a>
            </div>
          </div>
          <div data-reveal style={{ "--i": 2 } as React.CSSProperties}>
            <PhoneMock />
          </div>
        </section>

        {/* How it works */}
        <section id="how" className="mx-auto max-w-6xl px-4 py-28 sm:px-6 sm:py-36">
          <div data-reveal>
            <Eyebrow>How it works</Eyebrow>
            <h2 className="mt-4 max-w-[18ch] text-[clamp(32px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">It does not just take your word for it.</h2>
          </div>
          <div className="mt-14 grid gap-4 md:grid-cols-3">
            {steps.map((s, i) => (
              <div key={s.n} data-reveal style={{ "--i": i } as React.CSSProperties}>
                <Bezel className="h-full transition-transform duration-700 ease-spring hover:-translate-y-1">
                  <p className="font-mono text-[13px] text-accent-text">{s.n}</p>
                  <h3 className="mt-6 text-[24px] font-bold tracking-tight">{s.title}</h3>
                  <p className="mt-3 text-[15px] leading-relaxed text-muted">{s.body}</p>
                </Bezel>
              </div>
            ))}
          </div>
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-6xl px-4 pb-28 sm:px-6 sm:pb-36">
          <div data-reveal>
            <Eyebrow>Inside the app</Eyebrow>
            <h2 className="mt-4 max-w-[20ch] text-[clamp(32px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">Everything your plan needs, in one place.</h2>
          </div>
          <div className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {features.map(([t, b], i) => (
              <div key={t} data-reveal style={{ "--i": i % 3 } as React.CSSProperties} className="rounded-2xl border border-line bg-surface p-6">
                <p className="text-[18px] font-bold tracking-tight">{t}</p>
                <p className="mt-2 text-[15px] leading-relaxed text-muted">{b}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Handbook */}
        <section id="handbook" className="border-y border-line bg-surface/50">
          <div className="mx-auto grid max-w-6xl gap-14 px-4 py-28 sm:px-6 sm:py-36 lg:grid-cols-[1fr_1.1fr]">
            <div data-reveal>
              <Eyebrow>The Handbook</Eyebrow>
              <h2 className="mt-4 text-[clamp(32px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">Know why, not just what.</h2>
              <p className="mt-6 max-w-[42ch] text-[17px] leading-relaxed text-muted">
                A chapter-wise guide to training and food. Why an exercise matters, how to do it with good form, what it is good and bad for. Visual, searchable,
                and cited.
              </p>
            </div>
            <div data-reveal style={{ "--i": 1 } as React.CSSProperties}>
              <Bezel>
                <div className="flex h-12 items-center gap-3 rounded-xl border border-line bg-bg px-4 text-muted">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
                    <circle cx="11" cy="11" r="7" />
                    <path d="m20 20-3.5-3.5" />
                  </svg>
                  <span className="text-[15px]">Search: deadlift form, soya limit, creatine</span>
                </div>
                <ol className="mt-5">
                  {chapters.map((c, i) => (
                    <li key={c} className="group flex items-center gap-4 border-t border-line py-3.5 first:border-t-0">
                      <span className="w-6 font-mono text-[12px] text-muted">{String(i + 1).padStart(2, "0")}</span>
                      <span className="flex-1 text-[15px] font-semibold transition-transform duration-500 ease-spring group-hover:translate-x-1">{c}</span>
                    </li>
                  ))}
                </ol>
              </Bezel>
            </div>
          </div>
        </section>

        {/* Indian food */}
        <section id="food" className="mx-auto max-w-6xl px-4 py-28 sm:px-6 sm:py-36">
          <div data-reveal>
            <Eyebrow>Built for Indian kitchens</Eyebrow>
            <h2 className="mt-4 max-w-[20ch] text-[clamp(32px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">Dal, paneer and rajma. Measured properly.</h2>
          </div>
          <div className="mt-14 grid gap-4 md:grid-cols-[1.4fr_1fr]">
            <div data-reveal>
              <Bezel className="h-full">
                <p className="font-mono text-[64px] leading-none font-medium tracking-tight sm:text-[88px]">542</p>
                <p className="mt-4 max-w-[40ch] text-[16px] leading-relaxed text-muted">
                  Indian foods from the Indian Food Composition Tables 2017, by the ICMR National Institute of Nutrition. Protein, energy and more per 100 g.
                </p>
              </Bezel>
            </div>
            <div className="grid gap-4">
              {[
                ["Allergies first", "Asked before your diet, and removed from every suggestion."],
                ["Soya, honestly", "Studies find no hormone effects in men. We still cap chunks at 50 g dry a day, for variety."],
                ["No beef, no pork", "Never suggested, whatever you choose."],
              ].map(([t, b], i) => (
                <div key={t} data-reveal style={{ "--i": i + 1 } as React.CSSProperties} className="rounded-2xl border border-line bg-surface p-5">
                  <p className="text-[16px] font-bold">{t}</p>
                  <p className="mt-1 text-[14px] leading-relaxed text-muted">{b}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Sources */}
        <section id="sources" className="border-y border-line">
          <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
            <div data-reveal>
              <Eyebrow>Where the rules come from</Eyebrow>
            </div>
            <ul className="mt-8 grid gap-x-8 gap-y-6 sm:grid-cols-2 lg:grid-cols-5">
              {sources.map(([org, what], i) => (
                <li key={org} data-reveal style={{ "--i": i } as React.CSSProperties}>
                  <p className="text-[17px] font-bold">{org}</p>
                  <p className="mt-1 text-[14px] leading-snug text-muted">{what}</p>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <DownloadSection />

        {/* FAQ */}
        <section id="faq" className="mx-auto max-w-3xl px-4 py-28 sm:px-6 sm:py-36">
          <div data-reveal>
            <Eyebrow>Questions</Eyebrow>
            <h2 className="mt-4 text-[clamp(32px,5vw,56px)] leading-[1.02] font-bold tracking-[-0.035em]">Straight answers.</h2>
          </div>
          <div className="mt-12">
            {faqs.map(([q, a], i) => (
              <details key={q} data-reveal style={{ "--i": i } as React.CSSProperties} className="group border-t border-line last:border-b">
                <summary className="flex min-h-14 cursor-pointer list-none items-center justify-between gap-6 py-5 text-[17px] font-semibold [&::-webkit-details-marker]:hidden">
                  {q}
                  <span className="relative grid h-8 w-8 shrink-0 place-items-center rounded-lg border border-line transition-colors duration-300 group-open:bg-ink group-open:text-on-ink">
                    <span className="absolute h-[1.5px] w-3 bg-current" />
                    <span className="absolute h-3 w-[1.5px] bg-current transition-transform duration-500 ease-spring group-open:rotate-90" />
                  </span>
                </summary>
                <p className="pb-6 text-[16px] leading-relaxed text-muted">{a}</p>
              </details>
            ))}
          </div>
        </section>

      </main>

    </>
  );
}

import { CONTACT_EMAIL } from "./contact";

const groups: [string, React.ReactNode][] = [
  [
    "Levlofit",
    <>
      &copy; 2026 Levlofit. All rights reserved. The app, the Handbook, the plan rules, the design, the name and the logo are not open source. Installing
      the app gives you a personal right to use it under our terms; copying, changing or reselling it needs written permission.
    </>,
  ],
  [
    "Food data",
    <>
      USDA FoodData Central, U.S. Department of Agriculture, public domain (CC0 1.0). Indian food names and groups follow the Indian Food Composition Tables
      2017 (National Institute of Nutrition, ICMR), cited, not copied.
    </>,
  ],
  [
    "Exercise media",
    <>
      Animations and instructions: ExerciseDB by AscendAPI (free tier, credit required). Drawings: Everkinetic by Greg Priday, CC BY-SA 4.0, unmodified.
      Some animations: CDC Growing Stronger, public domain. Muscle map outlines: react-native-body-highlighter, &copy; 2022 ELABBASSI Hicham, MIT.
    </>,
  ],
  [
    "Research, fonts and software",
    <>
      Research search: Europe PMC (EMBL-EBI) and Wikipedia (CC BY-SA 4.0); articles stay with their authors. Fonts: Geist, Geist Mono and Unbounded (SIL
      OFL 1.1). Icons: Phosphor (MIT). Built with Flutter, Supabase, Next.js and React under BSD, MIT and Apache 2.0 licences; full texts are in the app
      under Profile, Levlofit 1.0, Licences.
    </>,
  ],
];

/** Licences and credits at the bottom of every page (the footer), so nothing needs a separate page. */
export function Credits() {
  return (
    <section id="licences" aria-labelledby="licences-title" className="mx-auto max-w-6xl scroll-mt-28 border-t border-line px-4 py-10 sm:px-6">
      <h2 id="licences-title" className="font-mono text-[11px] tracking-[0.2em] text-muted uppercase">
        Licences and credits
      </h2>
      <dl className="mt-5 grid gap-6 text-[13px] leading-relaxed text-muted sm:grid-cols-2">
        {groups.map(([title, body]) => (
          <div key={title}>
            <dt className="font-semibold text-ink">{title}</dt>
            <dd className="mt-1">{body}</dd>
          </div>
        ))}
      </dl>
      <p className="mt-6 text-[13px] text-muted">Own something used here and the credit is wrong or missing? Email {CONTACT_EMAIL} and we fix or remove it.</p>
    </section>
  );
}

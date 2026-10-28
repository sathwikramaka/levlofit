import type { Metadata } from "next";
import Link from "next/link";
import { CONTACT_EMAIL } from "@/components/contact";
import { LegalPage, type LegalSection } from "@/components/legal";

export const metadata: Metadata = { title: "Licences and credits", description: "Who owns Levlofit, and the data, media and code it is built with." };

const sections: LegalSection[] = [
  {
    id: "levlofit",
    title: "Levlofit",
    body: (
      <>
        <p>
          The Levlofit app, this website, the plan rules, the Handbook, the design and the Levlofit name and logo are &copy; 2026 Levlofit. All rights
          reserved. Levlofit is not open source.
        </p>
        <p>
          Installing the app from this website gives you a personal right to use it under our <Link href="/terms">terms</Link>. You may not copy, change,
          resell or republish the app, its content or its code without written permission. Ask at {CONTACT_EMAIL}.
        </p>
      </>
    ),
  },
  {
    id: "food",
    title: "Food data",
    body: (
      <ul>
        <li>
          Food values in meal plans: <strong>USDA FoodData Central</strong>, U.S. Department of Agriculture, Agricultural Research Service. Public domain (CC0
          1.0). <a href="https://fdc.nal.usda.gov">fdc.nal.usda.gov</a>
        </li>
        <li>
          Indian food names and groups follow the <strong>Indian Food Composition Tables 2017</strong> (National Institute of Nutrition, ICMR), which are
          cited, not copied, in released builds.
        </li>
      </ul>
    ),
  },
  {
    id: "exercise",
    title: "Exercise media",
    body: (
      <ul>
        <li>
          Exercise animations and instructions: <strong>ExerciseDB by AscendAPI</strong>, free tier for non-commercial apps, credit required.{" "}
          <a href="https://exercisedb.dev">exercisedb.dev</a>. Levlofit is free with no ads; before any paid plan or ads, this media is licensed or replaced.
        </li>
        <li>
          Exercise drawings: <strong>Everkinetic</strong> by Greg Priday, <a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a>,
          unmodified. <a href="https://github.com/everkinetic/data">github.com/everkinetic/data</a>
        </li>
        <li>
          Some exercise animations: Centers for Disease Control and Prevention, <strong>Growing Stronger</strong>. U.S. government work, public domain.
        </li>
        <li>
          Muscle map outlines: converted from <strong>react-native-body-highlighter</strong>, &copy; 2022 ELABBASSI Hicham, MIT licence.
        </li>
      </ul>
    ),
  },
  {
    id: "research",
    title: "Research search",
    body: (
      <p>
        Levlofit AI can search <strong>Europe PMC</strong> (EMBL-EBI) for review articles and <strong>Wikipedia</strong> (Wikimedia Foundation) for short
        summaries. Articles stay with their authors and publishers; Levlofit shows titles, links and short excerpts. Wikipedia text is{" "}
        <a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a>. The Handbook cites WHO, ACSM, ISSN, NICE, ICMR and journal papers,
        credited where used.
      </p>
    ),
  },
  {
    id: "fonts",
    title: "Fonts and icons",
    body: (
      <ul>
        <li>Geist, Geist Mono and Unbounded: SIL Open Font License 1.1.</li>
        <li>Phosphor Icons: &copy; 2020-2021 Phosphor Icons, MIT licence.</li>
      </ul>
    ),
  },
  {
    id: "software",
    title: "Open-source software",
    body: (
      <>
        <p>
          The app is built with Flutter and Supabase, and this website with Next.js and React. These and the other packages we use are under permissive
          licences (mainly BSD, MIT and Apache 2.0). One package, flutter_local_notifications (BSD-3-Clause), ships with small changes, kept with its licence.
        </p>
        <p>
          The full licence text for every package in the app is in the app: Profile, then <strong>Levlofit 1.0</strong>, then <strong>Licences</strong>.
        </p>
      </>
    ),
  },
  {
    id: "report",
    title: "Something missing?",
    body: <p>If you own something used here and the credit is wrong or missing, email {CONTACT_EMAIL}. We fix it or remove it.</p>,
  },
];

export default function Licences() {
  return (
    <LegalPage
      eyebrow="Licences"
      title="Licences and credits"
      intro="Who owns Levlofit, and the data, media and code it is built with."
      updated="28 October 2026"
      sections={sections}
    />
  );
}

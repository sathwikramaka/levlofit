import type { Metadata } from "next";
import Link from "next/link";
import { CONTACT_EMAIL } from "@/components/contact";
import { LegalPage, type LegalSection } from "@/components/legal";

export const metadata: Metadata = { title: "Terms and conditions", description: "The rules for using Levlofit, in plain words." };

const sections: LegalSection[] = [
  {
    id: "agree",
    title: "Using Levlofit",
    body: (
      <p>
        By creating an account or using Levlofit, you agree to these terms and to our <Link href="/privacy">privacy policy</Link>. If you do not agree, please do not
        use it.
      </p>
    ),
  },
  {
    id: "medical",
    title: "Not medical advice",
    body: (
      <>
        <p>
          Levlofit gives general training and nutrition guidance based on published sources. It is not a doctor, dietitian or physiotherapist, and it does not
          diagnose or treat any condition.
        </p>
        <p>
          Talk to a doctor before starting if you have a medical condition, are pregnant, take regular medication, or feel pain, dizziness or chest discomfort when
          active. Stop exercising and seek help if any of these happen during training.
        </p>
      </>
    ),
  },
  {
    id: "eligibility",
    title: "Who can use it",
    body: <p>You must be 18 or older. Plans are designed for adults aged 18 to 80.</p>,
  },
  {
    id: "account",
    title: "Your account",
    body: (
      <ul>
        <li>Give answers that are true to the best of your knowledge. Your plan is only as good as what you tell it.</li>
        <li>Keep your sign-in details private. You are responsible for activity on your account.</li>
        <li>You can delete your account at any time from the account menu in the app.</li>
      </ul>
    ),
  },
  {
    id: "ai",
    title: "Levlofit AI",
    body: (
      <p>
        Levlofit AI explains your plan in plain words. Its numbers come from your plan, which is built by fixed, cited rules. Like any AI, it can still word things
        wrongly. If an answer seems off, trust the plan and the Handbook, and ask us.
      </p>
    ),
  },
  {
    id: "use",
    title: "Fair use",
    body: (
      <ul>
        <li>Do not misuse the service, try to break its security, or access other people&rsquo;s data.</li>
        <li>Do not copy or resell Levlofit content, including the Handbook, without permission.</li>
        <li>Do not use automated tools to overload the service.</li>
      </ul>
    ),
  },
  {
    id: "price",
    title: "Price",
    body: (
      <p>
        Some features may later need a paid plan, and the app may show ads. We will tell you before any charge, and nothing will be charged without your
        clear agreement.
      </p>
    ),
  },
  {
    id: "content",
    title: "Our content",
    body: <p>The app, the Handbook, the design and the Levlofit name and logo belong to Levlofit. Sources we cite belong to their authors and are credited.</p>,
  },
  {
    id: "liability",
    title: "Limits of responsibility",
    body: (
      <p>
        We work hard to keep Levlofit accurate and available, but we provide it as it is, without guarantees. To the extent the law allows, Levlofit is not
        responsible for injury, loss or damage arising from how you use the guidance. Nothing here limits rights you have under Indian consumer law.
      </p>
    ),
  },
  {
    id: "end",
    title: "Ending use",
    body: <p>You can stop using Levlofit and delete your account at any time. We may suspend accounts that break these terms, and will tell you why.</p>,
  },
  {
    id: "law",
    title: "Law",
    body: <p>These terms are governed by the laws of India.</p>,
  },
  {
    id: "changes",
    title: "Changes and contact",
    body: <p>If we change these terms, we update the date at the top and tell you in the app before important changes apply. Questions: {CONTACT_EMAIL}.</p>,
  },
];

export default function Terms() {
  return <LegalPage eyebrow="Terms" title="Terms and conditions" intro="The rules for using Levlofit, in plain words." updated="29 September 2026" sections={sections} />;
}

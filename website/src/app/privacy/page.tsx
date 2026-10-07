import type { Metadata } from "next";
import { CONTACT_EMAIL } from "@/components/contact";
import { LegalPage, type LegalSection } from "@/components/legal";

export const metadata: Metadata = { title: "Privacy policy", description: "What Levlofit collects, why, who processes it, and how to delete it." };

const sections: LegalSection[] = [
  {
    id: "summary",
    title: "The short version",
    body: (
      <ul>
        <li>We collect what is needed to build and explain your plan, and nothing for advertising.</li>
        <li>We do not sell your data, show ads or use tracking cookies.</li>
        <li>You can delete your account and everything linked to it from the app, at any time.</li>
      </ul>
    ),
  },
  {
    id: "collect",
    title: "What we collect",
    body: (
      <>
        <p>
          <strong>Account:</strong> your email address, and your name if you sign in with Google.
        </p>
        <p>
          <strong>Your answers:</strong> year of birth, sex, height, weight, optional waist, body type, fitness goals and experience, training days and time, daily
          activity, optional sleep hours, equipment, diet type, allergies and intolerances, and whether you are open to supplements.
        </p>
        <p>
          <strong>Health check:</strong> whether a doctor has told you about a heart condition, chest pain, fainting, pregnancy or another limiting condition, and any
          injury you describe. We use this only to keep your plan safe, for example by asking you to see a doctor first.
        </p>
        <p>
          <strong>Your plans:</strong> each plan the app builds from your answers, kept so you can see how it changed.
        </p>
        <p>
          <strong>Website contact form:</strong> your email, your message, and the campaign tags (UTM) in the link that brought you here, if any.
        </p>
        <p>
          <strong>On this device only:</strong> your light or dark choice and whether you closed the cookie notice. These stay in your browser and are never sent to
          us.
        </p>
      </>
    ),
  },
  {
    id: "use",
    title: "Why we use it",
    body: (
      <ul>
        <li>To build your workout and food plan, check it against your numbers, and explain it.</li>
        <li>To answer your questions in Levlofit AI.</li>
        <li>To reply to messages you send us.</li>
        <li>To keep the service secure and working.</li>
      </ul>
    ),
  },
  {
    id: "processors",
    title: "Who processes it",
    body: (
      <>
        <p>We use a small number of providers, each only for its job:</p>
        <ul>
          <li>
            <strong>Supabase</strong> stores your account and app data. Our database is hosted in Mumbai, India.
          </li>
          <li>
            <strong>Groq</strong> runs Levlofit AI. When you ask a question, your question and your current plan are sent to Groq to write the answer. Your chats and
            the short notes Levlofit AI keeps about you are saved in your account until you delete them. Groq may process this outside India.
          </li>
          <li>
            <strong>Google</strong>, only if you choose to sign in with Google.
          </li>
          <li>
            <strong>Cloudflare</strong> serves this website.
          </li>
        </ul>
      </>
    ),
  },
  {
    id: "keep",
    title: "How long we keep it",
    body: (
      <p>
        Your account data is kept until you delete your account. Deleting it removes your profile, answers, goals and plans. Contact form messages are kept until the
        matter is handled, and for no longer than 12 months.
      </p>
    ),
  },
  {
    id: "rights",
    title: "Your rights",
    body: (
      <>
        <p>
          Under India&rsquo;s Digital Personal Data Protection Act, 2023, you can ask to see, correct or erase your personal data, withdraw consent, and raise a
          grievance. Most of this you can do in the app: edit your answers or goals, or delete your account from the account menu.
        </p>
        <p>For anything else, email {CONTACT_EMAIL}. We reply within 30 days.</p>
      </>
    ),
  },
  {
    id: "age",
    title: "Age",
    body: <p>Levlofit is for adults aged 18 to 80. We do not knowingly collect data from anyone younger.</p>,
  },
  {
    id: "security",
    title: "Security",
    body: (
      <p>
        Data travels over encrypted connections. Each person can read only their own data, enforced by the database itself, and the plan rules run on our server,
        not on your phone. No system is perfectly secure, so tell us at once if you think something is wrong.
      </p>
    ),
  },
  {
    id: "changes",
    title: "Changes",
    body: <p>If we change this policy, we update the date at the top. If a change affects how your data is used, we tell you in the app first.</p>,
  },
];

export default function Privacy() {
  return (
    <LegalPage
      eyebrow="Privacy"
      title="Privacy policy"
      intro="What Levlofit collects, why, who processes it, and how you delete it. Written to be read, not skimmed past."
      updated="29 September 2026"
      sections={sections}
    />
  );
}

import type { Metadata } from "next";
import Link from "next/link";
import { CONTACT_EMAIL } from "@/components/contact";
import { LegalPage, type LegalSection } from "@/components/legal";

export const metadata: Metadata = {
  title: "Delete your account",
  description: "How to delete your Levlofit account and data, in the app or by email, and what is removed.",
};

// REVIEW GATE: legal/privacy review pending. This page restates the privacy policy's deletion and retention text and
// the app's current delete-account flow; publish it (and use it as the Play Console deletion URL) only after review.
const sections: LegalSection[] = [
  {
    id: "in-app",
    title: "Delete it in the app",
    body: (
      <ol>
        <li>Open Levlofit and sign in.</li>
        <li>Open the menu and tap Profile.</li>
        <li>Tap Delete account at the bottom, then confirm.</li>
        <li>Still setting up? Use the account menu at the top of the sign-up screens: it has Delete account too.</li>
      </ol>
    ),
  },
  {
    id: "by-email",
    title: "Delete it without the app",
    body: (
      <p>
        If you no longer have the app, email {CONTACT_EMAIL} from the email address you signed up with and ask us to delete your account. We may ask you to
        confirm the request from that address before we act on it. We reply within 30 days.
      </p>
    ),
  },
  {
    id: "what",
    title: "What is deleted",
    body: (
      <>
        <p>
          First your progress photos and profile picture are deleted from storage. If that fails, nothing else is deleted and you can try again. Then your
          account is deleted, and with it everything linked to it in our database: your profile and answers, goals, plans, logs, food diary and recipes,
          measurements, chats, Levlofit AI notes, reminder settings and feedback. If deleting the account itself fails after the photos are gone, the photos
          stay deleted, everything else stays, and you can try again.
        </p>
        <p>
          Deleting in the app also cancels the reminders scheduled on that phone. Other settings kept only on your phone, such as the dashboard layout, are removed
          when you uninstall the app; if you delete by email, uninstall the app to stop its reminders.
        </p>
      </>
    ),
  },
  {
    id: "kept",
    title: "What may remain",
    body: (
      <p>
        Copies may remain in our service providers&rsquo; backups and service logs for a time, under their own retention practices. Messages already sent to our
        AI provider to answer your questions cannot be deleted by us. Contact form messages are not linked to your account; we delete them once the matter is
        handled. Details are in the <Link href="/privacy#keep">privacy policy</Link>.
      </p>
    ),
  },
];

export default function DeleteAccount() {
  return (
    <LegalPage
      eyebrow="Account"
      title="Delete your account"
      intro="You can delete your Levlofit account and its data at any time, in the app or by email."
      updated="16 October 2026"
      sections={sections}
    />
  );
}

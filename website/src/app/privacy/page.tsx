import type { Metadata } from "next";
import Link from "next/link";
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
        <li>You can delete your account from the app at any time.</li>
      </ul>
    ),
  },
  {
    id: "collect",
    title: "What we collect",
    body: (
      <>
        <p>
          <strong>Account:</strong> your email address and the name you give when you sign up (Google fills it in if you sign in with Google).
        </p>
        <p>
          <strong>Your answers:</strong> year of birth, sex, height, weight, optional waist, body type, fitness goals and experience, training days and time, daily
          activity, optional sleep hours, equipment (including items you add yourself), your weight goal, diet type, allergies and intolerances, other foods you exclude,
          your food budget, your water target, and whether you are open to supplements.
        </p>
        <p>
          <strong>Health check:</strong> what you tell us about a heart condition, chest pain, fainting or dizziness, pregnancy or another condition that limits exercise, and any
          injury you describe. We use this only to keep your plan safe, for example by asking you to see a doctor first.
        </p>
        <p>
          <strong>Your plans:</strong> every plan the app builds for you, each with a copy of the answers it used (including any injury you described). The app
          shows the latest; all are kept until you delete your account.
        </p>
        <p>
          <strong>What you log in the app:</strong> your workouts and the sets you record (reps and weight lifted), your body weight and body measurements, the
          water and habits you track, your level in each goal, your reminder settings (including the names you give your own reminders), the foods and weights you log in the food diary and the recipes you save, and, if you answer after a session, how hard it felt and whether pain
          stopped you.
        </p>
        <p>
          <strong>Photos:</strong> progress photos you add, and your profile picture if you upload your own instead of choosing a built-in one. They are kept in
          private storage that only your account can open.
        </p>
        <p>
          <strong>Levlofit AI:</strong> your chats, a short running summary of each long chat&rsquo;s older messages (deleted with that chat), the facts you
          confirm in Levlofit AI&rsquo;s Memory so it can remember you, and its suggestions waiting for your OK. Levlofit AI keeps a fact only if you confirm
          it, and you can edit or delete each one in the app. When Levlofit AI offers to swap a move, make a session lighter or move a session to another day,
          the offer and, if you confirm it, the change are stored with the day and the moves involved. A meal it offers to log is only saved to your food
          diary when you tap Log it.
        </p>
        <p>
          <strong>Feedback:</strong> anything you send with Send feedback in the app.
        </p>
        <p>
          <strong>Abuse protection:</strong> a short record of when you send chat messages or rebuild your plan (times only, no content), used to limit how
          often these can be done. Feedback is limited by counting the feedback you have sent. Each chat message also carries a random ID so a resent message is
          not saved twice.
        </p>
        <p>
          <strong>Website contact form:</strong> your email, your message, and the campaign tags (UTM) in the link that brought you here, if any.
        </p>
        <p>
          <strong>On this device only:</strong> on the website, your light or dark choice and whether you closed the cookie notice. In the app, your sign-in
          session, light or dark choice, dashboard layout and daily goals, which permission prompts you have seen, downloaded fonts and the reminders scheduled on
          your phone. These stay on the device and are never sent to us.
        </p>
        {/* REVIEW GATE: applies only to Android builds made with the Health Connect option; legal review before publishing. */}
        <p>
          <strong>Steps from Health Connect (Android, only if you connect it):</strong> the app reads your daily step totals for the last 7 days while you look
          at its Progress page. They stay on your phone and are not stored on our servers. If you switch on sharing, those totals are sent with your coach
          messages about steps or walking, as described below. Disconnect in Progress, or remove access in Health Connect, at any time.
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
            <strong>Supabase</strong> provides our database and file storage. It stores your account, app data and photos, and receives messages sent through
            this website&rsquo;s contact form.
          </li>
          <li>
            <strong>Groq</strong> runs Levlofit AI and may process your messages outside India. See below for exactly what it receives.
          </li>
          <li>
            <strong>Google</strong>, only if you choose to sign in with Google.
          </li>
          <li>
            <strong>Google Fonts</strong> supplies the fonts the app uses. When the app downloads them, Google&rsquo;s servers may receive your IP address.
          </li>
          <li>
            <strong>ExerciseDB</strong> (AscendAPI) supplies the exercise animations. When the app loads them, its servers may receive your IP address.
          </li>
          <li>A web hosting provider serves this website. The website&rsquo;s fonts are served with the site itself, not loaded from Google.</li>
        </ul>
        {/* REVIEW GATE: the two paragraphs below (what Levlofit AI sends, and the summary and coach-action paragraph) describe the coach-chat code in this repository. Publish them only after the
            deployed coach-chat function is confirmed to match it and LLM_BASE_URL is confirmed unset or pointing at Groq. */}
        <p>
          <strong>What Levlofit AI sends to Groq.</strong> Each time you send a message, our server sends Groq: your message as you typed it (trimmed, up to 2,000 characters), and up to 12
          earlier messages from that chat; your first name; your equipment, training days, session length, daily activity, sleep hours and water target; the date,
          goal and minutes of each workout logged in the last 14 days; a summary of your current plan (phase, weight goal, goals and levels, sessions per week, next steps, and
          calorie and protein targets); the facts you confirmed in Memory (an injury fact only when your chat is about training, movement or pain, at most three;
          suggestions you have not confirmed are never sent); and two yes-or-no flags: whether your health check asks you to see a doctor first, and
          whether you noted an injury (in your health check or as a confirmed Memory fact). Only when your chat is about food, or a reply has to be checked against your food settings, it also sends your diet type,
          allergies and intolerances, foods you exclude, food budget and any suggested supplements, and your food diary totals for each of the last 7 days you
          logged (energy, protein, carbohydrate, fat and fibre; not the foods themselves). Only when your chat is about lifting, it sends, for each move you
          logged in the last 14 days, its name, how many days you trained it, the last day and your best set (reps and weight). Only when your chat is about
          steps or walking, and only if you switched on sharing in the app&rsquo;s Progress page, it sends your daily step totals for the last 7 days from
          Health Connect.
        </p>
        <p>
          In a long chat it also sends the running summary of that chat&rsquo;s older messages, as part of the chat. To write that summary, our server sends
          Groq only the previous summary and the older messages of that chat, nothing else. Only when you ask to change today&rsquo;s session, it sends the
          names of today&rsquo;s moves and the replacements Levlofit has checked against your equipment and injury notes; when you ask to train on another day,
          the free days later this week; when you ask for an easier day, only that a lighter session is possible. Only when you ask to log something you
          ate, it sends the names of up to 30 foods from your own food diary that fit your diet, so it can propose diary entries for you to confirm.
        </p>
        {/* REVIEW GATE: publish only once the owner has decided whether a second provider is configured (LLM_FALLBACK_*). */}
        <p>
          <strong>If Groq is unavailable.</strong> We may set up a second AI provider that answers when Groq is down or busy. It would receive exactly what Groq
          receives for that message. We will name it here before it is switched on.
        </p>
        <p>
          Groq does not receive your email, account ID, year of birth, sex, height, weight, waist or other measurements, body type, health check answers, the
          injury you described in your health check (an injury fact you confirm in Memory is sent as described above), photos, set logs outside lifting questions, water or habit logs, your effort or pain answers, or feedback. It also receives passages from Levlofit&rsquo;s
          Handbook that match your question; these are Levlofit&rsquo;s own text, not your data. Your calorie and protein targets are worked out from your weight,
          height, age and sex, so your approximate weight can be calculated from them. Anything you type in a message is sent as written, so leave out details you
          do not want shared.
        </p>
      </>
    ),
  },
  {
    id: "keep",
    title: "How long we keep it",
    body: (
      <>
        <p>
          Your account data is kept until you delete your account. When you delete it in the app, our server first deletes your progress photos and profile picture.
          If that fails, your account is not deleted, and you can try again. Once they are gone, your account is deleted, and with it the records linked to it in
          our database: your profile and answers, goals, plans, logs, food diary and recipes, measurements, chats and their summaries, Levlofit AI memory facts and notes,
          the session changes you were offered or confirmed, reminder settings and feedback.
          If deleting the account itself fails after the photos are gone, the photos stay deleted, everything else stays, and you can try again. Reminders
          scheduled on your phone are cancelled when you delete your account or sign out.
        </p>
        {/* REVIEW: backup and log retention periods at Supabase are not verified; replace "may" with the real periods once confirmed. */}
        <p>
          Copies may remain in our service providers&rsquo; backups and service logs after your account is deleted, under those providers&rsquo; own retention
          practices. Messages already sent to Groq to answer your questions cannot be deleted by us; Groq handles them under its own terms. Contact form messages
          are not linked to your account. We delete them manually once the matter is handled.
        </p>
      </>
    ),
  },
  {
    id: "rights",
    title: "Your rights",
    body: (
      <>
        <p>
          Under India&rsquo;s Digital Personal Data Protection Act, 2023, you can ask to see, correct or erase your personal data, withdraw consent, and raise a
          grievance. Most of this you can do in the app: edit most answers in Profile and Protocol (email us to correct the rest), or delete your account in Profile (steps, including deleting without the app: <Link href="/delete-account">delete your account</Link>).
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
        Data travels over encrypted connections. Each person can read only their own data, enforced by the database itself, and your plan targets are
        calculated on our server. No system is perfectly secure, so tell us at once if you think something is wrong.
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
      updated="27 October 2026"
      sections={sections}
    />
  );
}

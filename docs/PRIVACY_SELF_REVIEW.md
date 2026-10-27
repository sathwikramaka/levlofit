# Privacy self-review by the owner (2026-10-27)

The owner decided to release with their own privacy review instead of a lawyer's (2026-10-27). This is a checklist
against India's DPDP Act 2023 and Google Play's user-data policy, checked against the code on 2026-10-27. It is not
legal advice. A lawyer review remains recommended before the app takes payments (planned subscription).

Owner sign-off: ____________________  Date: __________

## Decisions recorded with this review (owner, 2026-10-27)

- Launch free: no ads, no subscription, no paid features. ExerciseDB V1 animations are on in every build with the
  credit "Animations: ExerciseDB by AscendAPI" (allowed for non-commercial apps with credit). Before any subscription
  or ads: build with `--dart-define=LEVLOFIT_EXERCISEDB=false` or buy a plan that covers paid use.
- No clinician is available. The Handbook and BMI keep their published sources (BMI: Misra et al. 2009 consensus
  cut-offs for Asian Indians; Handbook: WHO, ICMR-NIN, ACSM, ISSN and the papers it cites, paraphrased and attributed).
  The Handbook says on its first screen that it is general information, not medical advice, and not reviewed by a
  clinician.
- Waist-to-height is removed from the app (Waist check tool, Progress line, onboarding waist field, plan-engine
  finding and snapshot). The waist tape measurement in Progress stays as a plain measurement. The
  `profiles.waist_cm` column is left in place (no destructive migration); the app no longer writes or reads it.

## Checklist

| # | Requirement | Where | Status |
|---|---|---|---|
| 1 | Notice before consent: the policy can be read before an account exists | Sign-in and sign-up screens link the policy (auth_screen.dart) | Done 2026-10-27 |
| 2 | Policy reachable in the app at any time | Settings > Privacy policy; Health Connect rationale | Done |
| 3 | Public policy URL for Play and the website | website/src/app/privacy | Done; needs the site hosted |
| 4 | What is collected, listed completely | Both texts, "What we collect" | Checked against the tables the app writes |
| 5 | Purpose limited and stated | "How we use it" | Done |
| 6 | Every processor named | Supabase, Groq, Google sign-in, Google Fonts, ExerciseDB (added 2026-10-27) | Done |
| 7 | AI provider: exactly what is sent and not sent | "What Levlofit AI sends", "What Groq does not get" | Done; confirm the deployed coach-chat matches this repository when deploying |
| 8 | Data outside India disclosed | Groq line | Done |
| 9 | Erasure: delete account in the app and on the web | Profile > Delete account; website /delete-account | Done |
| 10 | Correction and access | Profile and Protocol edits; email for the rest, 30 days | Done |
| 11 | Retention | "How long we keep it" | Backup retention at Supabase still says "may"; check the Supabase plan's backup period and update the sentence |
| 12 | Children | "Adults aged 18 to 80"; onboarding birth year | Done |
| 13 | Health data minimised for AI | Data-use gate, minimised context, consented steps only | Done |
| 14 | No location, contacts or other-app data | Manifest permissions | Done |
| 15 | Grievance contact | Email in "Your rights" | Owner: make sure the address on the website is monitored |
| 17 | Body check photos (added 2026-10-27) | Consent each time, sent once to Groq, never stored; both policy texts | Done in code; deploy `body-check` only after you approve |
| 16 | Play Data safety form | docs/PLAY_DATA_SAFETY_DRAFT.md | Fill from this list when a Play listing is made |

## Not covered by this review

- A lawyer's reading of the texts, and terms for paid subscriptions (needed before monetising).
- The `REVIEW GATE` comments in the code mark text tied to deploy-time facts (coach-chat version, fallback provider,
  Health Connect builds). They stay as reminders; check each when deploying that piece.

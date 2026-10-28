# Privacy self-review by the owner (2026-10-27)

The owner decided to release with their own privacy review instead of a lawyer's (2026-10-27). This is a checklist
against India's DPDP Act 2023 and Google Play's user-data policy, checked against the code on 2026-10-27; rows 19 to 23
checked against the local code on 2026-10-29 (batches B2 to B6 and the onboarding and maintenance-calorie follow-up,
not yet deployed). It is not legal advice. A lawyer review remains recommended before the app takes payments (planned subscription).

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
| 18 | Error reports and update check (added 2026-10-27) | app_errors: signed-in only, masked emails, 30 a day, 90 days, deleted with the account; update check contacts the website host | Done in code; both policy texts |
| 19 | Build my plate health conditions and protein-shake scoops (added 2026-10-29) | **Stored in the account:** dietary_profiles.health_conditions (diabetes, PCOS, thyroid, blood pressure, cholesterol, kidney, IBS, pregnancy) and whey_scoops (0 to 3); a copy of the conditions in generated_plans.input with each plan. Phones copy older on-device choices up once, then delete them. **Sent to Groq:** only in FOOD SETTINGS (food questions, or a reply checked against food settings), with a rule not to give condition-specific advice | Done in code; both policy texts; ships with migration 20261029100000 and the coach-chat deploy |
| 20 | Progress summary for the coach (added 2026-10-29) | **Nothing new stored:** computed on the server from existing workout_logs, body_metrics and food_log rows. **Sent to Groq:** only for progress questions: sessions logged in the last 28 days against the plan, average and last effort rating, counts of mild and stopped pain answers with the last stopped date, the weight trend as % of body weight a week with its verdict (no kilograms), and food-diary averages against targets. Session notes text is never sent | Done in code; both policy texts; ships with the coach-chat deploy |
| 21 | Kitchen, cooking time, training days and time (added 2026-10-29) | **Stored in the account:** dietary_profiles.kitchen, cook_time, kitchen_equipment, kitchen_other (own words, up to 200 characters) and mess_meals (added 2026-10-29); profiles.training_days and training_time (onboarding and Protocol); copied into generated_plans.input and plan.schedule. **Sent to Groq:** training days and time with every message (ABOUT YOU); kitchen, equipment, own kitchen notes, mess meals and cooking time only in FOOD SETTINGS | Done in code; both policy texts; ships with migration 20261029300000 and the coach-chat deploy |
| 22 | Plan changes proposed by the coach (added 2026-10-29) | **Stored in the account:** plan_changes (field, proposed value, value at proposal, status; server writes only; the person can delete). **Sent to Groq:** only when the person asks about body goal, pace or training days: the current body goal, diet pace and days, and for each change the plan's checks allow, the engine's body goal, calorie, protein and training-day figures. Nothing changes until the person confirms | Done in code; both policy texts; ships with migration 20261029200000 and the coach-chat deploy |
| 23 | Energy working in the plan (added 2026-10-29) | **Stored in the account:** generated_plans.plan.nutrition.energy (maintenance estimate, activity factor and what set it, goal factor, any floor) and the BMR, derived from age, sex, height, weight and activity. **Sent to Groq:** with every message as part of the plan summary; the raw age, height and weight are still not sent in normal chat | Done in code; in-app text and website text; ships with the generate-plan and coach-chat deploys |
| 16 | Play Data safety form | docs/PLAY_DATA_SAFETY_DRAFT.md | Fill from this list when a Play listing is made; updated for rows 19 to 23 on 2026-10-29 |

## Not covered by this review

- A lawyer's reading of the texts, and terms for paid subscriptions (needed before monetising).
- The `REVIEW GATE` comments in the code mark text tied to deploy-time facts (coach-chat version, fallback provider,
  Health Connect builds). They stay as reminders; check each when deploying that piece.

# Levlofit: Product Requirements Document

Last updated: 2026-11-12, for release 1.1.0. Keep current: see "Keeping these documents current" in `CLAUDE.md`.

## 1. Summary

Levlofit is an India-first fitness app. It tells a person what to train and eat today, in household terms, and shows
whether it is working. Plans come from fixed, sourced rules; AI explains them and never sets the numbers.

Brand idea: **find your level**. Levels 0 to 5 in each goal are earned with level checks, never given.

## 2. Goals

| Goal | Measure (`tools/retention_metrics.sql`) |
|---|---|
| Help people start and keep a realistic routine | Activation; D1, D7, D30 return |
| Be useful every day without feeling like a chore | Weekly active users (a real action, not an app open) |
| Be trustworthy | Named sources; missing data shown as missing; no fake numbers |
| Cost nothing to run at launch | Free tiers and open-source tools only |

Target hypotheses, not benchmarks: onboarding 70%+, D7 25%+, D30 15%+. Accounts are still too few to read as rates.

## 3. Users

Adults 18 to 80 in India, beginners to experienced. Vegetarian, eggitarian, vegan or non-vegetarian. Android first; iPhone
through the web app. People with medical conditions are told to involve a doctor; the app does not treat anyone.

## 4. Requirements: live in 1.1.0

### Plan and training
- Onboarding builds a plan from goals, body, schedule, health check, equipment, food settings and a level check.
- One main goal plus up to five extras, from 12 catalogue goals. Levels L0 to L5 with curriculum checks.
- Weekly schedule with weekdays and time; session moves with exercise animations, set and rep logging, rest timers.
- Double progression hints, lighter-week and pain-aware notes, start-lighter note after 14 days away.
- Fewer-days offer after three short weeks: the person chooses, nothing changes by itself.
- Medical hold: a health flag limits training until a doctor clears it.

### Food
- Seven-day plate in household servings, within calorie and protein targets, for budget, region, kitchen, cooking time,
  mess meals, allergies and exclusions. Beef and pork are never suggested.
- Rice in grams, cooked and raw. Solids by weight; ml only for liquids and by-the-bowl dal or curry.
- Every food shown at a real serving or not at all.
- Pre- and post-workout meals named on training days; a training-day or rest-day card above the plate.
- Supplements card: protein powder (planned into meals), creatine (dose only for strength and hybrid goals, without a
  health flag), the person's own additions (listed, not checked, not counted).
- Food diary with search, packaged foods by barcode, recipes, whole-meal logging, raw-weight warnings.

### Daily use and progress
- Dashboard: activity arcs, today's session, steps (Health Connect, Android: today against 8,000, or 6,000 from 60, and
  the last 7 days), optional daily check-in, daily goal, rank and rating, week strip, Today's read (one Handbook chapter a
  day, by training or rest day), water, habits, food targets, BMI. Customisable.
- Levlofit AI floats over Today, Workout, Diet and Progress as its robot (the one that greets you in the chat) on a round
  dark badge, bobbing and blinking, with a soft orange ring that pulses; no text, name on a long press.
- Workout: a Monday-to-Sunday picker; each day written out as a plan sheet: warm-up list, then each move with sets,
  reps, reps in reserve and rest. Diet: each meal as a table of items with kcal, protein, carbs and fat and a subtotal,
  and a total for the day against the targets (after the owner's own plan sheet, 2026-11-12).
- Handbook chapters end with Previous and Next chapter buttons (app and website).
- Supplements: a reference of 20 common supplements (what, when, reference intake and upper limit, cautions, sources:
  NIH, ICMR-NIN, ISSN, EFSA) in `assets/supplements.json`, shared with Levlofit AI. Diet shows when to take each one the
  person lists (tied to a meal), names supplements on their meal, and offers optional suggestions (vitamin D after a
  test, B12 for vegetarians, omega-3, creatine for strength goals) with Add and Not for me. A Supplement guide opens
  from the Handbook and Diet. Training days get Before training and After training sections.
- Levlofit AI answers in full depth for how and why questions, uses the supplement reference with the person's own
  list, and its live research adds MedlinePlus (US National Library of Medicine) to Europe PMC and Wikipedia.
- Plan sheets name each move's target muscles and up to three other moves for the same muscles (any one does the job).
- Levlofit AI receives the week as the Workout tab shows it and, for food chats, the day of meals last opened in Diet,
  and answers plan questions with tables (exercise, targets, sets and reps, rest; meal, foods, kcal and macros).
- Settings: during a workout (keep screen on, rest length by move or 60 s to 3 min, sound and orange flash when rest
  ends, animations full, small or hidden), and a switch for the floating Levlofit AI button. All kept on the phone.
- Progress: sessions this month, hours trained, weight change over 30 days, a 12-month activity map by minutes, and a
  weight chart over 1 month, 3 months, a year or all, with an optional goal-weight line kept on the phone.
- Active minutes are the minutes a session took (opened to finished), not the planned length.
- Weekly streak: weeks that met the plan; one short week in any 4 is let off when a met week follows. Never a weight or
  calorie streak.
- First win: a new plan with no session yet offers a short starter (a 25-minute setting, one set lighter).
- Moments: a new best (heaviest, or most reps at a weight) shows while logging; passing a level check opens a level-up
  screen; Profile lists the level earned per goal. Week and level can be shared as a picture (sessions, streak, lifts,
  check-ins, level); food and weight never appear on it.
- Progress photos: at 4, 8 and 12 weeks between first and latest, a one-time reveal of the pair.
- Android home screen widget: today's session and sessions this week.
- Weekly report: sessions against plan, logged food against targets from 3 logged days, lift trend, weight change only
  with enough weigh-ins, one observation, one next step.
- Weight trend, measurements, optional private progress photos, optional body check.
- Reminders: workout, water with chosen hours, weigh-in, the person's own; opt-in, master switch. Under it: Sunday
  recap (on), morning Levlofit AI check-in and meal-time nudges (off); each at most once a day and opens its screen.
- Welcome-back card after 14 days away. No guilt wording anywhere.

### Levlofit AI
- Coach chat with history, memory the person confirms, swaps and plan changes they must accept. Answers explain the stored
  plan and Handbook; it does not set calories or macros, or diagnose.
- Works without AI: every core feature runs when the provider is down.

### Learning and account
- Handbook: a 77-chapter book in six volumes, live in the app and on the website since 2026-11-12. Not clinician-reviewed;
  1,449 of 2,794 claims still unreviewed (the coach cites only checked passages). Chapters teach with figures (stat
  tiles, numbered steps, do and avoid, bar charts, a plate, yes and no flows, ranges, scales). The facts of
  thefitness.wiki's pages are covered in Levlofit's own words with primary sources (its text is not licensed for reuse):
  start here, muscle map, heart rate and calories, first weeks in a gym, choosing a programme, the healthy plate
  (Harvard's Healthy Eating Plate idea with ICMR-NIN 2024 amounts), weight-change answers and training answers; Choosing a programme gives
  the common beginner and intermediate programme layouts in numbers (sets, reps, percentages, progression and reset
  rules, in kg); the supplements chapter adds timing, safe upper limits and what to keep apart.
- Diet's day totals include a healthy plate check: the day's food by weight against about half vegetables and fruit,
  a quarter grains and a quarter protein foods (milk, oil and shakes sit beside the plate). Exercise library; glossary; BMI and
  body-fat tools.
- Google or email sign-in, Terms and Privacy at sign-up, delete account, send feedback (saved and emailed), in-app update, and an Android
  notification when a new version is out (checked about every 12 hours, once per version).

### Website
- Marketing pages, Handbook pages, privacy, terms, delete-account, APK download, web app at `/app/`.

## 5. Rules that do not bend

- Deterministic numbers: no LLM sets a calorie, macro, dose or nutrition value.
- Never invent evidence, reviews, counts or professional approval. The app says "not medical advice, not clinician-reviewed".
- Banned: purple gradients, fake metrics, stock or AI photos, emoji icons, em dashes, shame wording, beef or pork suggestions.
- Do not say "free" on the website or in the app (ads or subscriptions may come later).
- Privacy: data minimised, own-row access, deletion on request. Check-ins and own supplements never go to the AI provider.

## 6. Out of scope for now

Social feeds, public leaderboards, wearables beyond Health Connect steps, generated workout videos, marketplace,
subscriptions. iOS native (no Mac); Ironman or triathlon content (no sourced swim or bike material).

## 7. Known limits

- **Not on a real phone yet:** the 1.0.11 habit features (widget, sharing, notification taps), the 1.0.10 look and most 1.0.9 features. See `IMPLEMENTATION_PLAN.md`.
- Diary has raw and dry values only; cooked rice and dal need a verified import.
- Protein uses actual body weight; adjusted weight for higher BMI needs a dietitian (`docs/legal/OUTSTANDING_REVIEWS.md`).
- High-calorie plans can show large counts (7 rotis, 10 idlis at a meal).
- Offline is read-only: the last plan opens; logging needs a connection.
- Age is from birth year only: someone turning 18 this year starts on 1 January.

## 8. Before any revenue

IFCT 2017 written permission or replacement, and a paid ExerciseDB plan or replacement media
(`docs/legal/LICENSING_REQUIREMENTS.md`).

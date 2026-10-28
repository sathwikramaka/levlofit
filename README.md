# Levlofit

India-first fitness app: a training plan that is earned level by level, Indian meal plans in household servings, a
cited visual Handbook, and Levlofit AI, a personal coach that knows your plan. Flutter app (Android first), Supabase
backend, Next.js marketing website. Built at zero cost with free and open-source tools.

Brand idea: **find your level**. Levels 0 to 5 in every goal are earned with level checks, never given. The logo is a
spirit level's bubble in the corner of an L. Design system: [DESIGN.md](DESIGN.md).

This README is the map of the whole project from first setup to today. A person or an AI reading it should know what
every part is, where it lives, how data flows, how to run and test it, and what is live. Deeper detail lives in
`docs/` (section 22).

### Status (2026-10-28)

| Area | State |
|---|---|
| Production backend | Live. All 45 migrations applied (last: the 43-chapter Handbook) and 4 Edge Functions deployed |
| Edge Functions | `generate-plan` v19, `coach-chat` v21 (level check, honest coach, research search), `delete-account` v13, `body-check` v1 |
| Android app | 1.0.0+1, release APK signed with the owner's key, installed on the owner's phone (OnePlus CPH2649, Android 16). Not yet on Google Play |
| Website | Next.js site in `website/`; the updated privacy text is not deployed yet |
| Open | A23 phone smoke test, Google Play listing and Health Connect declaration, website redeploy (section 15) |

---

## Contents

1. [What the app does](#1-what-the-app-does)
2. [Repository layout](#2-repository-layout)
3. [Tech stack and architecture](#3-tech-stack-and-architecture)
4. [First-time setup](#4-first-time-setup)
5. [Running locally](#5-running-locally)
6. [The Flutter app, screen by screen](#6-the-flutter-app-screen-by-screen)
7. [The plan engine](#7-the-plan-engine)
8. [The meal planner](#8-the-meal-planner)
9. [Levlofit AI](#9-levlofit-ai)
10. [The Handbook](#10-the-handbook)
11. [Database](#11-database)
12. [Edge Functions](#12-edge-functions)
13. [Website](#13-website)
14. [Testing and verification](#14-testing-and-verification)
15. [Release status and what is open](#15-release-status-and-what-is-open)
16. [Building and releasing](#16-building-and-releasing)
17. [Production safety rules](#17-production-safety-rules)
18. [Data, licences and credits](#18-data-licences-and-credits)
19. [Privacy](#19-privacy)
20. [Owner decisions on record](#20-owner-decisions-on-record)
21. [History](#21-history)
22. [Where to read more](#22-where-to-read-more)

---

## 1. What the app does

| Area | What the person gets |
|---|---|
| Onboarding | Name, goals (12 in the catalogue: muscle building, strength, powerlifting, aesthetic physique, calisthenics, general fitness, functional fitness, HYROX, kettlebell training, running, mobility, yoga; one main goal plus extras), experience per goal, body numbers and body type (including skinny-fat), body goal, schedule, health screen, equipment, allergies, diet type, monthly food budget, regional food, supplements, then a **level check** chat with Levlofit AI before the plan is built |
| Plan | Weekly sessions per goal, level-first (Level 0-1 trains the main goal only), energy and protein targets, findings that change unsafe choices (for example cutting while underweight), an AI roadmap |
| Workout | Today's session with exercise animations, sets, rest timer, logging, level checks to move up, swaps, lighter days, moving a session |
| Exercise library | MuscleWiki-style front and back body map; tap a muscle to see only the moves where it is a main mover; filters by equipment and difficulty |
| Diet | A 7-day Indian meal plan built by **Build my plate** (region, diet, budget, health conditions, protein powder, pace), meals titled as plates ("Roti + Rajma + Sabzi + Salad"), real portions, cooking oil once a day |
| Food diary, foods, recipes | Search Indian foods (IFCT 2017 and USDA FoodData Central values), log meals, see daily totals |
| Hydration, habits, calendar, progress | Water target and logging, daily habits, a month calendar of everything logged, body metrics, progress photos, phone steps (Health Connect) |
| Reminders | Daily and custom reminders, alarm-clock precision on Android |
| Handbook | A 43-chapter cited visual book in five parts, read like a textbook |
| Levlofit AI | Chat coach that knows the person's plan and logs, cites the Handbook and live research, corrects wrong ideas, proposes swaps and changes the person confirms |
| Body check | Optional photo posture notes (photo sent once, never stored) |
| Account | Email or Google sign-in, profile, avatar, settings, delete account (also on the website) |

Never "free" in app or website copy: the owner may add ads or a subscription later.

---

## 2. Repository layout

```
app/                 Flutter app (package name: levlo)
  lib/               all app code (about 19,500 lines of Dart; 492 tests in test/)
  test/              widget and unit tests
  android/           Android project; healthconnect module behind a build flag
  assets/            fonts, sounds, licence notices
  third_party/       patched flutter_local_notifications (LEVLOFIT_PATCH.md)
supabase/
  migrations/        45 reviewed SQL migrations, forward-only
  functions/         Edge Functions (Deno): coach-chat, generate-plan, delete-account, body-check
    _shared/         plan engine, coach context, handbook retrieval, research, assessment, LLM client, rate limits
    _eval/           offline coach evaluation (83 strict cases)
    _test/           Supabase and npm test doubles, frozen Deno lock
  tests/             pgTAP database tests
website/             Next.js marketing site (home, privacy, terms, delete-account)
data/                builders for foods, handbook and evidence registers (Python)
  handbook_v4/       the 43-chapter book builder, claims and sources registers
  evidence/          claim extraction, v3 registers
  ifct2017/ fdc/     food data sources
tools/               verify.sh, production apply/backup scripts, converters
docs/                plans, checklists, audits, decisions (see section 22)
brand/               logo SVGs
media/               exercise media provenance
Refrence/            the original curriculum PDF (reference only)
DESIGN.md            design system
CLAUDE.md            project rules for AI assistants (production safety)
```

Main app files (entry: `main.dart` -> `auth_screen.dart` -> `onboarding.dart` on first run -> `dashboard.dart`):

| File | What it does |
|---|---|
| `main.dart` | start-up, `prefs` (SharedPreferences), bundled licence registration, backend chosen by `--dart-define=LEVLOFIT_BACKEND` |
| `auth_screen.dart`, `account.dart` | Google and email sign-in, sign-out, account loading errors |
| `onboarding.dart` | onboarding steps, the AI level check, goal editing; saves profile, diet, goals and levels, then calls `generate-plan` |
| `dashboard.dart` (+ `dashboard_menu.dart`, `dashboard_tabs.dart`, `dashboard_layout.dart`) | shell and tabs: home, workout, protocol, diet and Build my plate, hydration, habits, calendar, progress, foods, diary, BMI, handbook, library, reminders, settings, profile, privacy text |
| `diet_plan.dart` | the meal planner (pure Dart, section 8) |
| `session.dart`, `week_schedule.dart`, `progression.dart`, `swaps.dart` | today's session, doses, rest timer, week view, confirmed swaps and lighter or moved sessions |
| `level_up.dart`, `rewards.dart` | level checks against the curriculum's pass rules; celebrations |
| `coach_chat.dart`, `coach_memory.dart` | Levlofit AI chat (threads, edit, regenerate, markdown, action cards) and Memory |
| `exercises.dart`, `exercise_guide.dart`, `muscle_map.dart`, `muscle_shapes.dart` | exercise library, guide, MuscleWiki-style body map, muscle pages |
| `handbook.dart`, `handbook_book.dart` | Handbook reader (chapter opener, numbered figures, key points, references) |
| `food_diary.dart` | food search, diary, recipes, credits |
| `reminders.dart` | local notifications (alarm-clock mode), custom reminders, chime |
| `steps.dart` | Health Connect daily steps (builds with `LEVLOFIT_HEALTH_CONNECT=true`) |
| `body_check.dart` | optional photo notes through `body-check` |
| `theme.dart`, `icons.dart`, `mark.dart` | design tokens, Phosphor icons, animated logo |
| `update_check.dart`, `error_report.dart`, `app_version.dart` | update notice from the website's `version.json`; crash log to `app_errors` |

---

## 3. Tech stack and architecture

| Layer | Choice | Notes |
|---|---|---|
| App | Flutter (Dart 3.13), Android first | iOS deferred (no Mac); package `levlo` |
| Backend | Supabase: Postgres, Auth, Storage, Edge Functions (Deno) | free tier; RLS on every table |
| AI | Groq, `openai/gpt-oss-120b`, OpenAI-compatible API | provider set by secrets; approval gate `LLM_DATA_APPROVED` |
| Research | Europe PMC REST and Wikipedia REST | free, no key |
| Email | Brevo SMTP through Supabase Auth | sender levlofit.app@gmail.com |
| Website | Next.js 16, React 19 | static pages |
| Exercise media | ExerciseDB V1 (AscendAPI) GIFs | non-commercial use with credit; see section 18 |
| Food data | IFCT 2017 (NIN), USDA FoodData Central (CC0) | |
| Body map | react-native-body-highlighter 3.2.0 outlines (MIT), converted | `tools/convert_body_map.py` |
| Icons, fonts | Phosphor (MIT), Geist | |
| CI | GitHub Actions: `ci.yml`, `keep-alive.yml` (pings Supabase every 3 days so the free project does not pause) | |

```
 Android app (Flutter)
   |  supabase_flutter: auth, PostgREST queries, Storage, functions.invoke
   v
 Supabase (Postgres + Auth + Storage + Edge Functions)
   |-- Postgres: every user table has row-level security (own rows only)
   |-- Auth: Google sign-in and email (Brevo SMTP)
   |-- Storage: private bucket progress-photos/<uid>/...
   |-- Edge Functions (Deno):
   |     generate-plan  -> plan engine (rules, no AI for numbers) + optional AI roadmap
   |     coach-chat     -> Levlofit AI chat, level check (assess), research search
   |     body-check     -> one-off photo notes (photo not stored)
   |     delete-account -> removes storage files, then the account
   v
 Groq (LLM, openai/gpt-oss-120b)        Europe PMC + Wikipedia (research search)
 ExerciseDB CDN (exercise GIFs)          Google Fonts, Health Connect (on the phone)
```

Principles:
- **Numbers come from rules, not AI.** Calories, protein, levels, sessions and meal grams are computed by deterministic
  code (plan engine, diet planner). The AI explains and coaches; it cannot change the plan.
- **Data minimisation.** The coach gets an allowlisted summary per question: diet only for food talk, lifts only for
  lift talk, steps only with consent.
- **Everything cited.** Handbook numbers name their source; coach replies cite Handbook passages and research results.

---

## 4. First-time setup

Windows 11 is the reference machine; macOS and Linux work the same way.

1. **Install**
   - Flutter SDK (stable) and Android Studio with the Android SDK, platform tools and a JDK (use Android Studio's `jbr`
     as `JAVA_HOME` for Gradle tests).
   - Node.js 20+ (functions tests, website).
   - Deno 2 (Edge Function checks).
   - Supabase CLI.
   - Docker Desktop (local Supabase).
   - Python 3.12+ (data builders, converters).
   - Git Bash on Windows (for `tools/verify.sh`).
2. **Clone and fetch dependencies**
   ```bash
   cd app && flutter pub get
   ```
   ```bash
   cd website && npm ci
   ```
3. **Local backend**: from the repository root, `supabase start` (Docker running), then `supabase db reset` to apply all
   migrations and seed data to the local database.
4. **Secrets for local Edge Functions** (never committed): `LLM_API_KEY`, `LLM_DATA_APPROVED=groq`. Optional:
   `LLM_PROVIDER`, `LLM_MODEL`, `LLM_BASE_URL`, `LLM_TIMEOUT_MS`, `LLM_MAX_RETRIES`, `LLM_REQUEST_BUDGET_MS`,
   `LLM_FALLBACK_*`.
5. **Release signing** (owner only): the upload key lives outside the repository
   (`C:\Projects\levlofit-signing\levlofit-release.jks`, alias `levlofit`); `app/android/key.properties` points at it
   and is git-ignored. Never commit or print its values. Steps: [docs/RELEASE_SETUP.md](docs/RELEASE_SETUP.md).

---

## 5. Running locally

| Task | Command |
|---|---|
| App against local Supabase | `cd app && flutter run` (default backend is local) |
| App against production | `flutter run --dart-define=LEVLOFIT_BACKEND=production` |
| Edge Functions locally | `supabase functions serve` |
| Website | `cd website && npm run dev` |
| Everything that matters | `bash tools/verify.sh` (see section 14) |

**Phone against a throwaway stack.** Use a separate, deletable local Supabase project so tests never touch the
development data. With the phone connected over USB, run `adb reverse tcp:54321 tcp:<api port>` so the app's
`localhost:54321` reaches it.

**Build flags**

| Flag | Effect |
|---|---|
| `--dart-define=LEVLOFIT_BACKEND=production` | use the cloud project (release builds need it) |
| `LEVLOFIT_HEALTH_CONNECT=true` (env) or `-Plevlofit.healthConnect=true` | compile the Health Connect step reader (adds READ_STEPS, minSdk 26) |
| `LEVLOFIT_EXERCISEDB=false` | switch off ExerciseDB media (needed before any monetisation without a paid plan) |

---

## 6. The Flutter app, screen by screen

**Sign-in.** Email (Brevo SMTP) or Google. A session for a deleted account shows "could not load" with Sign out.

**Onboarding** (`onboarding.dart`), one question per screen with a progress bar:
1. Name.
2. Main goal and extra goals from the goal catalogue (searchable, grouped).
3. Experience per goal (none, beginner, intermediate, advanced).
4. Body: year of birth, sex, height, weight, body type (lean, average, skinny-fat, carrying extra fat, muscular).
5. Body goal: cut, maintain, recomposition, bulk, general fitness.
6. Schedule: days a week, minutes a session, daily activity, sleep.
7. Health screen (medical clearance flags, injuries).
8. Equipment (none, home dumbbells, gym, custom kit).
9. Allergies and intolerances, plus free-text exclusions.
10. Diet type; **monthly food budget** (under Rs 4,500, Rs 4,500 to 9,000, over Rs 9,000, or your own amount); regional
    food; supplements.
11. **Level check** with Levlofit AI: an honest read of the body numbers, up to three questions about real ability,
    then a level 0 to 3 per goal with reasons (skippable).
12. Build: profile and answers saved, levels saved to `goal_levels`, `generate-plan` called, then a plan review
    with the engine's findings.

**Dashboard (Home).** Greeting, rings (training days, move minutes, streak), today's workout with animations, week
strip, Fuel and Body cards, coach notes, Handbook tile. Layout and daily goals are customisable per phone.

**Workout.** The session for today: moves, sets and reps (Handbook doses), rest timer (120 s compound, 90 s others),
logging sets and the session, level checks per goal (curriculum pass rules), swaps (equipment and injury aware).

**Protocol.** Every setting the plan is built from (training, body goal, activity, diet, budget, pace, region, water);
saving rebuilds the plan.

**Diet.** Build my plate card, 7 day chips, the day's totals, meal cards (plate title, labelled parts with household
servings and exact grams, details), cooking oil for the day, a doctor note when a health condition was chosen,
supplements and the protein-food guide. See section 8.

**Food diary, Foods, Recipes.** Search foods (only licensed sources show), log by meal, daily totals.

**Hydration, Habits, Calendar, Progress.** Water target (EFSA based, more on training days), habit ticks, a calendar
of every log, body metrics, progress photos (private storage), BMI (WHO adult bands), Health Connect steps (7 daily
totals, on the phone only, opt-in sharing with the coach).

**Exercise library.** Grid, search, filters, the body map (front and back), muscle pages listing main-mover moves
then catalogue moves, exercise pages with animation, muscles, cues and credit.

**Handbook.** Part and chapter list, search, chapter reader with opener, "In this chapter", numbered figures, key
points, up next and references.

**Levlofit AI.** Pop-up chat panel, threads, memory sheet (facts the person confirmed), edit, regenerate, copy,
action cards (swap, lighter day, move a session, log a meal).

**Reminders, Settings, Profile.** Reminder times, alarm precision, account, avatar, privacy text, licences, delete
account.

---

## 7. The plan engine

`supabase/functions/_shared/plan-engine.ts`, run by `generate-plan`. Deterministic: the model never computes numbers.

- **Review first** (`reviewInput`): medical flags mean light activity until cleared; pregnancy keeps energy at
  maintenance; cutting while underweight becomes maintenance; bulking with obesity becomes recomposition or a cut.
  Each change is a finding with a reason and source.
- **Levels**: a goal trains at its assessed level (`goal_levels`, from the level check or in-app checks), else the
  self-rated entry level (none 0, beginner 1, intermediate 2, advanced 3). Level 0-1 in the main goal: only the main
  goal trains (foundation phase). Level 2 adds one extra goal; Level 3+ up to the recommended number.
- **Energy**: Mifflin-St Jeor BMR times an activity factor, then a cut or surplus scaled by **pace** (easy, balanced,
  hard). Protein in g/kg by goal.
- **Sessions**: per goal per week within the person's days, with full-body strength in the foundation phase.
- **Supplements**: creatine and protein powder only when the person is open to them and nothing medical is flagged.
- **AI roadmap**: an optional model-written roadmap (steps and when to move on); the plan saves without it.

---

## 8. The meal planner

`app/lib/diet_plan.dart` (pure Dart, heavily tested). Runs on the phone in a background isolate.

1. **Inputs**: the plan's energy and protein targets, excluded food tags (diet, allergies), custom exclusions, budget
   tier, soya limit, region, protein-powder scoops.
2. **Templates**: Breakfast (a breakfast dish, eggs or paneer only if protein is short, milk, fruit), Lunch (one grain
   by region, a dal, a sabzi, salad), Evening snack (sprouts chaat, chana or peanuts, fruit, milk), Dinner (grain, a
   protein dish, a vegetable, a second protein dish only if needed).
3. **Breakfast dishes**: poha with peanuts, idli, dosa, ragi dosa, rava upma, vermicelli upma, besan chilla, moong dal
   chilla, thepla, each Levlofit's own dry-weight recipe of planner ingredients.
4. **Real portions**: smallest servings (one cup of rice, two rotis or bhakris, one katori of dal, a plate of poha, two
   idlis, 50 g paneer, 75 g chicken or fish), kitchen steps (half cups, half katoris, whole pieces, whole eggs, whole
   glasses of milk, whole fruit), caps (two katoris of dal, three eggs, 100 g paneer per meal; soya within its limit).
5. **Solver**: weekday rotation for variety, then proportional rounds and greedy trade-offs to land within 5% of energy
   and at least 90% of protein; an exhaustive template search proves when a day cannot meet both, and the day then
   says so plainly and suggests changes that respect the person's settings.
6. **Oil**: ICMR-NIN 2024, 27 g per 2000 kcal, kept within 20 to 30 g a day, shown once in teaspoons with advice to
   switch oils.
7. **Shake**: with protein powder scoops (Build my plate), meals are planned for the targets minus the shakes, then the
   shake joins the evening snack (whey, or plant protein when dairy is excluded; 30 g scoop = 120 kcal, 24 g protein).
8. **Display**: meal titles, part labels (GRAIN, DAL, PROTEIN, VEGETABLE, SALAD, FRUIT, DAIRY, SHAKE), household
   servings ("2 rotis", "1 katori moong dal") with exact grams.

**Budget**: monthly bands map to tiers (low: dals, grains, eggs, milk, seasonal produce; medium adds paneer, chicken,
fish; high: everything). A custom monthly amount is stored per day (amount / 30) in `budget_max_inr`.

**Build my plate** (Diet tab): seven steps (your numbers, regional food, diet type, budget, health conditions, protein
powder, pace) that save the choices and rebuild the plan. Lactose and gluten intolerance change the food list;
diabetes, PCOS, thyroid, blood pressure, cholesterol, kidney disease, IBS and pregnancy show a see-your-doctor note
instead of changing meals. Scoops and conditions are stored on the phone.

---

## 9. Levlofit AI

`supabase/functions/coach-chat`, with `_shared/coach-context.ts`, `handbook.ts`, `research.ts`, `assess.ts`, `swap.ts`,
`meal.ts`, `llm.ts`, `rate.ts`.

Per message:
1. Rate limits and the duplicate check (client message id).
2. Reads profile, latest plan, chat history (with a rolling summary), confirmed facts, diet, logs and Handbook titles;
   food diary and lifts only when relevant.
3. Handbook retrieval (`_shared/handbook.ts`), only reviewed passages citable.
4. Research search for factual questions (`_shared/research.ts`).
5. System prompt: rules, Handbook passages, research results, the context block.
6. Checks: an empty or echoing reply is regenerated once; small-talk length cap; restricted foods re-checked; swap,
   lighter, move and meal proposals validated on the server and stored only as proposals; memory stored as suggested.

- **What it sees**: an allowlisted summary (first name, schedule, plan card, 14 days of training, confirmed memory
  facts, Handbook titles). Diet and allergies only for food talk; lifts only for lift questions; steps only with
  consent. No email, ids, birth year, measurements or health answers in normal chat.
- **How it talks**: brief by default (small talk capped at about 45 words), direct, warm; **honest, not agreeable**:
  it corrects wrong or unsafe ideas and does not change a correct answer under pushback without new evidence.
- **Grounding**: Handbook passages retrieved for the question and cited as readable references; only reviewed
  passages are citable. **Research**: factual questions also get up to three review abstracts from Europe PMC and a
  Wikipedia summary, cited as [R1], [R2] with a source list. Only topic words are searched.
- **Actions** (always confirmed by the person): swap a move in today's session, make today lighter, move today's
  session to a later free day, log a meal from diary foods. Memory suggestions are stored unconfirmed until accepted.
- **Level check** (`{ assess }`): the onboarding assessment described in section 6; stores nothing; levels 0 to 3
  (0 to 1 with a medical flag).
- **Safety**: food check against everything the person must not eat (regenerates once, then footnotes), refusal of
  off-topic requests, no diagnosis, request-wide time budget, optional fallback provider, rate limits per hour and day.

---

## 10. The Handbook

A 43-chapter book in five parts (v4, live since step A24):

| Part | Chapters |
|---|---|
| A. Foundations | welcome, safe to start, how Levlofit builds your plan, how training works, cardio intensity, how hard to push, learning a lift, warming up, sets reps and progress, rest between sets, sleep and recovery |
| B. Getting better | one goal at a time, tracking, plateaus and lighter weeks, daily steps, habits |
| C. Food and body | food basics, water and heat, carbs fibre and fats, vegetarian and vegan protein, meal timing, body numbers, calories, fat loss, muscle gain, eating too little, supplements |
| D. Train for your goal | general fitness, muscle, strength, physique, calisthenics, mobility and yoga, kettlebells, running, HYROX |
| E. Staying with it, for life | soreness and injury, busy weeks, home training, training as a woman, after 40, mood and motivation, your first 12 weeks |

- Built by `data/handbook_v4/build_handbook_v4.py` from the v3 content (`data/build_handbook.py`) into
  `supabase/migrations/20261028200000_handbook_v4_book.sql`. Edit the builders, never the migration.
- Every chapter is mostly visual blocks (stats, steps, compare, bars, scale, week, plate, cycle, table, flow, band),
  ends with key points and up next, and lists numbered references.
- Evidence registers: `data/handbook_v4/claims_register.csv` and `sources_register.csv` record each claim's review
  status; `extract_claims.py --sync` keeps them and the coach's passages file in step.
- Not clinician-reviewed (owner decision): the app says "not medical advice and not reviewed by a clinician".

---

## 11. Database

Supabase Postgres, 45 migrations in `supabase/migrations/`, RLS on every user table, owner-only policies, no
`anon` access to user tables or sequences, `TRUNCATE`, `REFERENCES` and `TRIGGER` revoked from client roles.

| Group | Tables |
|---|---|
| People | `profiles`, `dietary_profiles`, `user_goals`, `goal_levels` (0-3 writable by the app) |
| Plans | `generated_plans`, `goal_catalog` (12 goals; trimmed from 56 on 2026-09-29), `curriculum_levels` (level ladders and pass rules for 6 goals) |
| Training | `workout_logs`, `set_logs`, `exercises` (catalogue), `exercise_swaps`, `session_changes` |
| Food | `foods`, `food_sources` (licence gate), `food_log`, `recipes`, `recipe_items` |
| Body and habits | `body_metrics`, `progress_photos` (+ private Storage bucket), `water_intake`, `habit_logs` |
| Coach | `coach_threads`, `coach_messages`, `coach_facts`, `coach_notes` |
| App | `reminder_prefs`, `custom_reminders`, `app_feedback`, `app_errors`, `handbook_chapters` |
| Website | `waitlist`, `contact_messages` |

Rate limits (`check_rate`) guard chat, plan rebuilds, feedback, body checks and the contact form. Database tests:
`supabase/tests` (pgTAP), run with `supabase test db` on a local stack.

Production uses **forward-only** application (Option B in [docs/MIGRATION_RECONCILIATION.md](docs/MIGRATION_RECONCILIATION.md)):
the owner runs `tools/apply_prod.ps1`, which asks for the connection string at a hidden prompt, prints each file's
SHA-256 and applies each file unchanged in one transaction.

---

## 12. Edge Functions

| Function | Does |
|---|---|
| `generate-plan` | reads the person's answers and levels, runs the plan engine, saves `generated_plans`; adds the AI roadmap |
| `coach-chat` | Levlofit AI chat, the level check (`assess`), action confirmations (`confirmSwap`, `confirmChange`) |
| `delete-account` | removes the person's Storage files and the account (cascades every row) |
| `body-check` | one-shot photo notes with consent; nothing stored |

Deploy (owner-approved only): `supabase login`, then
`supabase functions deploy <name> --project-ref <ref>`, verify, then `supabase logout` and delete the CLI token in
the Supabase dashboard (Account, Access Tokens).

---

## 13. Website

`website/` (Next.js 16): home page, `privacy`, `terms`, `delete-account` (Play requirement), `version.json` (the app
checks it once per start for updates). Lint, type check and build run in `verify.sh website`. Privacy text sections
marked `REVIEW GATE` must stay in step with what the deployed functions do.

---

## 14. Testing and verification

One runner: `bash tools/verify.sh [suite ...]`. With no arguments it runs all suites.

| Suite | Runs | Latest result (2026-10-28) |
|---|---|---|
| `flutter` | `flutter analyze`, `flutter test` | 492 pass, analyze clean |
| `functions` | node tests (plan engine, LLM, body check, handbook, research and assessment, coach-chat, delete-account, generate-plan, eval, release docs), offline eval, strict tsc | 223 pass, eval 83/83 strict |
| `deno` | `deno check`, `deno lint`, local smoke | 16/16 |
| `handbook` | v3 register tests, freshness, migration matches builder | pass |
| `handbook4` | v4 book tests (structure, registers, review gates) | pass |
| `db` | `supabase test db` (pgTAP) on a local stack | needs a fresh local stack (the dev stack is behind) |
| `website` | lint, build, tsc | pass |

Phone checks used a throwaway stack and `adb`. Checklists:
[docs/ANDROID_TEST_PLAN.md](docs/ANDROID_TEST_PLAN.md) and [docs/STEP_COUNTER_DEVICE_CHECKLIST.md](docs/STEP_COUNTER_DEVICE_CHECKLIST.md).

---

## 15. Release status and what is open

**Live in production**
- All 45 migrations, including the 43-chapter Handbook (A24) and IFCT food values (A20).
- Edge Functions: `coach-chat` v21 (level check, honest coach, research), `generate-plan` v19, `delete-account`
  v13, `body-check` v1. `LLM_DATA_APPROVED=groq` set.
- Brevo SMTP for sign-up email; Google sign-in.

**Built**
- Signed release APK 1.0.0+1 (`--split-per-abi`, production backend, Health Connect on), installed on the owner's
  phone.

**Open**
- A23 smoke test on the phone (sign-up, level check, plan, diet, coach with sources, reminders, steps, delete
  account).
- Google Play: developer account, store listing, Data safety form ([draft](docs/PLAY_DATA_SAFETY_DRAFT.md)),
  **Health Connect declaration** before publishing a build with step counting.
- Website deploy with the updated privacy text.
- Coach memory of Build my plate scoops and conditions is per phone; moving it to the account needs a migration.
- ExerciseDB is non-commercial: switch it off or buy a plan before ads or a subscription.
- Handbook: new key points and chapters are not yet reviewed, so the coach does not cite them; legal review of
  privacy and terms is the owner's self-review.
- iOS (needs a Mac).

Full checklist with every approval gate: [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).

---

## 16. Building and releasing

Release APK for testing on a phone:

```bash
cd app && LEVLOFIT_HEALTH_CONNECT=true flutter build apk --release --split-per-abi --dart-define=LEVLOFIT_BACKEND=production
```

Install on a connected phone:

```bash
adb install -r app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Play Store bundle: `flutter build appbundle --release --dart-define=LEVLOFIT_BACKEND=production` (with the Health
Connect flag only after the declaration is approved). Without `key.properties` a release build stops on purpose.
Version: `app/pubspec.yaml` (`1.0.0+1`; split APKs add an ABI offset, arm64 = 2001).

---

## 17. Production safety rules

From [CLAUDE.md](CLAUDE.md), binding for people and AI assistants:

- Database writes, production migrations, destructive operations and any change to the live Supabase project
  (schema, data, policies, auth settings, secrets, function deploys) need the owner's explicit approval in chat first;
  one approval covers one action.
- Even read-only inspection of production needs approval before its first use in a session.
- Test on a local database; schema changes only through reviewed migration files.
- Backups before risky production steps: `tools/backup_prod.ps1` (or `backup_prod.sh`), sealed with `tools/backup_seal.sh`;
  restore steps in [docs/BACKUP_RECOVERY_PLAN.md](docs/BACKUP_RECOVERY_PLAN.md).
- Never type, print or commit passwords, keys or `key.properties` values. The owner enters credentials at hidden
  prompts; CLI tokens are deleted after each deploy.

---

## 18. Data, licences and credits

| Source | Use | Terms |
|---|---|---|
| IFCT 2017 (ICMR-NIN) | Indian food values | shown with credit; `food_sources` gate |
| USDA FoodData Central SR Legacy | planner food values | CC0 |
| ExerciseDB V1 (AscendAPI) | exercise animations | non-commercial with credit "Animations: ExerciseDB by AscendAPI" |
| react-native-body-highlighter 3.2.0 | body map outlines | MIT, notice in Licences |
| Phosphor icons | icons | MIT |
| Europe PMC, Wikipedia | live research for the coach | free APIs; Wikipedia text CC BY-SA, shown as short excerpts with links |
| ICMR-NIN 2024, WHO, ACSM, ISSN and others | Handbook and plan rules | cited per chapter |

Registers: [docs/SOURCE_LICENCE_REGISTER.md](docs/SOURCE_LICENCE_REGISTER.md),
[docs/LICENSING_REQUIREMENTS.md](docs/LICENSING_REQUIREMENTS.md), `media/SOURCES.md`.

---

## 19. Privacy

- Data stays in Supabase (encrypted in transit; photos in private storage).
- Levlofit AI's provider is Groq (may process outside India). Normal chat gets an allowlisted summary; the level
  check gets body numbers and the answers typed in it; research search sends topic words only to Europe PMC and
  Wikipedia from the server.
- Steps never leave the phone unless the person turns on sharing.
- Body check photos are sent once and never stored.
- Account deletion removes everything (app or website).
- Self-review: [docs/PRIVACY_SELF_REVIEW.md](docs/PRIVACY_SELF_REVIEW.md). The full text is in the app (Settings,
  Privacy) and on the website.

---

## 20. Owner decisions on record

- Zero spend; free and open-source tools only. Fixes ship as app updates.
- Launch without ads or subscription, but never say "free".
- No clinician: keep cited sources and show "not medical advice, not clinician-reviewed".
- BMI uses the WHO adult bands. The waist-to-height feature was removed.
- ExerciseDB on in release builds with credit, until monetisation.
- Groq is the AI provider; research search uses free sources (Europe PMC, Wikipedia), not paid web search.
- Food budget per month, with the person's own amount.
- More in [docs/OWNER_DECISIONS.md](docs/OWNER_DECISIONS.md).

---

## 21. History

| When | Milestone |
|---|---|
| 2026-09-28 | Project start: Supabase schema, onboarding, plan engine, six goals |
| 2026-09-29 | Goal catalogue (56, then trimmed to a focused list), curriculum levels, IFCT foods, Handbook v1, exercise catalogue, website waitlist and contact |
| 2026-10-03 | Dashboard v2, coach memory and threads, measurements and photos, Handbook v2, levels, water, habits, reminders, protocol and budget |
| 2026-10-07 | Soya rules, avatars, feedback, Handbook v3 (38 chapters), Pilates removed (12 goals) |
| 2026-10-13 to 17 | Reliability and rate limits, custom reminders, food diary, micronutrients, recipes, security revokes, Health Connect steps, phone test passes |
| 2026-10-23 to 25 | Confirmed coach memory, chat summaries, coach actions (swap, lighter, move, meal), licensed food sources, USDA foods |
| 2026-10-27 | Diet pace and region, body check, crash log, release prep, owner decisions (no clinician, WHO BMI, zero-cost release), Brevo email |
| 2026-10-28 | Production go-live (A3 to A24): all migrations and functions; signing key and release APK; skinny-fat; alarm-clock reminders; brief coach; MuscleWiki-style body map; Handbook v4 book; Build my plate; breakfast dishes; real portions; monthly budget; step counting on; level check, honest coach and research search |

Batch-by-batch log: [docs/PROGRESS.md](docs/PROGRESS.md).

---

## 22. Where to read more

| Document | For |
|---|---|
| [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) | every release step and approval gate |
| [docs/RELEASE_SETUP.md](docs/RELEASE_SETUP.md) | signing, builds, provider setup |
| [docs/MIGRATION_RECONCILIATION.md](docs/MIGRATION_RECONCILIATION.md) | production migration history and order |
| [docs/BACKUP_RECOVERY_PLAN.md](docs/BACKUP_RECOVERY_PLAN.md) | backups and restore |
| [docs/PROGRESS.md](docs/PROGRESS.md) | the full work log |
| [docs/OWNER_DECISIONS.md](docs/OWNER_DECISIONS.md) | decisions and why |
| [docs/HANDBOOK_BOOK_PLAN.md](docs/HANDBOOK_BOOK_PLAN.md) | Handbook v4 structure |
| [docs/AI_PROVIDER_COMPARISON.md](docs/AI_PROVIDER_COMPARISON.md) | why Groq |
| [docs/PLAY_DATA_SAFETY_DRAFT.md](docs/PLAY_DATA_SAFETY_DRAFT.md) | Play Console data safety |
| [docs/STEP_COUNTER_PLAN.md](docs/STEP_COUNTER_PLAN.md) | Health Connect design |
| [DESIGN.md](DESIGN.md) | colours, type, components |

Older planning notes (`docs/LEVLOFIT_HANDOFF.md`, `docs/PLAN.md`, the 15 and 19 area plans) describe earlier states;
where they disagree with this README, this README and the code are current.

# Levlofit

India-first fitness app: a personalised training plan built on levels (0 to 5) that are earned, Indian meal plans in household servings, a cited visual Handbook, and Levlofit AI, a personal coach. Android app (Flutter), Supabase backend, Next.js marketing website. Built at zero cost with free and open-source tools only.

This README is the map of the whole stack. A person or an AI reading it should know what every part is, where it lives, how data flows, how to run and test it, and what is live today. Deeper detail lives in `docs/` (listed at the end).

---

## 1. Status (2026-10-28)

| Area | State |
|---|---|
| Production backend | Live. Supabase project with all 45 migrations applied (last: Handbook v4 book) and 4 Edge Functions deployed |
| Edge Functions | `generate-plan` v19, `coach-chat` v21 (level check, honest coach, research search), `delete-account` v13, `body-check` v1 |
| Android app | Version 1.0.0+1, release APK signed with the owner's key and installed on the owner's phone (OnePlus CPH2649, Android 16). Not yet on Google Play |
| Website | Next.js site in `website/` (landing, privacy, terms, delete-account, version.json). Privacy text has new sections behind review gates |
| Open owner tasks | A23 phone smoke test; Google Play listing and Health Connect declaration; legal review of privacy text; website redeploy |

Owner rules that shape everything (see `CLAUDE.md`, `docs/OWNER_DECISIONS.md`):
- Zero spend, free and open-source only. Never say "free" in the app or on the site (ads or a subscription may come later).
- Any change to the live Supabase project (migrations, data, functions, secrets) needs the owner's explicit approval, one action at a time. Local databases for testing.
- No clinician is available: the app shows "not medical advice, not clinician-reviewed" instead of waiting for review.
- ExerciseDB animations are used under its non-commercial terms with credit; switch off or license before monetising.

---

## 2. Repository layout

```
app/          Flutter app (Dart package name: levlo)
  lib/        all app code (about 19,500 lines)
  test/       widget and unit tests (492)
  assets/     fonts, sounds, licence notices
  android/    Android project; app/third_party holds a patched flutter_local_notifications
supabase/
  migrations/ 45 SQL migrations (the only way the schema changes)
  functions/  Edge Functions (Deno/TypeScript) and shared modules
    _shared/  plan engine, LLM client, coach context, handbook retrieval, research, assess, swaps, meals, rate limits
    _test/    node test doubles, Deno lock
    _eval/    offline coach evaluation (83 strict cases)
  tests/      pgTAP database tests
website/      Next.js 16 / React 19 site
data/         builders for data shipped as migrations (Handbook, foods, evidence registers, chime sound)
tools/        verify.sh test runner, production apply/backup scripts, body-map converter
docs/         plans, checklists, audits, decisions (see section 13)
brand/        logo SVGs
media/        media sources and credits
DESIGN.md     design system (colours, type, components)
CLAUDE.md     project rules for AI agents
```

---

## 3. Architecture

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
 Groq (LLM provider, openai/gpt-oss-120b)   Europe PMC + Wikipedia (research search)
 ExerciseDB CDN (exercise GIFs)              Google Fonts, Health Connect (on the phone)
```

Principles:
- **Numbers come from rules, not AI.** Calories, protein, levels, sessions and meal grams are computed by deterministic code (plan engine, diet planner). The AI explains and coaches; it cannot change the plan.
- **Data minimisation.** The coach receives an allowlisted summary per question; diet only for food talk, lifts only for lift talk, steps only with consent.
- **Everything cited.** Handbook numbers name their source; coach replies cite Handbook passages `[H:...]` and research results `[R#]`.

---

## 4. The app (Flutter, `app/lib`)

Entry: `main.dart` (Supabase init, theme, licences, update check, error reporting) -> `auth_screen.dart` -> `onboarding.dart` (first run) -> `dashboard.dart` (shell with tabs).

| File | What it does |
|---|---|
| `main.dart` | App start, `prefs` (SharedPreferences), bundled licence registration, backend selection by `--dart-define=LEVLOFIT_BACKEND` |
| `auth_screen.dart`, `account.dart` | Google and email sign-in, sign-out, account loading errors |
| `onboarding.dart` | Steps: name, primary goal, extra goals, experience, body, phase (cut/maintain/recomp/bulk/general), schedule, health screen, equipment, allergies, diet (type, monthly budget or own amount, regional food, supplements), **level check** (AI chat), build. Saves profile, diet, goals, levels; calls `generate-plan` |
| `dashboard.dart` (+ `dashboard_menu.dart`, `dashboard_tabs.dart`, `dashboard_layout.dart`) | Shell and tabs: home bento, workout, protocol (settings that rebuild the plan), diet, hydration, habits, calendar, progress, food library, food diary, BMI, handbook, exercise library, reminders, settings, profile, privacy text |
| `diet_plan.dart` | Diet planner (pure Dart, see section 6) |
| `session.dart`, `week_schedule.dart`, `progression.dart`, `swaps.dart` | Today's session from fixed ExerciseDB ids, doses, rest timer, week view, confirmed swaps and lighter/moved sessions |
| `level_up.dart`, `rewards.dart` | Level checks against the curriculum's pass rules; celebrations |
| `coach_chat.dart`, `coach_memory.dart` | Levlofit AI chat UI (threads, edit/regenerate, markdown, action cards) and Memory (confirmed facts) |
| `exercises.dart`, `exercise_guide.dart`, `muscle_map.dart`, `muscle_shapes.dart` | Exercise library, MuscleWiki-style tappable body map (outlines from react-native-body-highlighter 3.2.0, MIT; converter `tools/convert_body_map.py`), muscle pages showing only main-mover moves |
| `handbook.dart`, `handbook_book.dart` | Handbook reader: textbook frame (chapter opener, numbered figures, key points, references), 11+ visual block types |
| `food_diary.dart` | Food search, diary, credits |
| `reminders.dart` | Local notifications (alarm-clock mode for exact timing), custom reminders, chime |
| `steps.dart` | Health Connect daily steps (only in builds with `LEVLOFIT_HEALTH_CONNECT=true`) |
| `body_check.dart` | Optional photo notes via `body-check` (consent each time) |
| `theme.dart`, `icons.dart` (Phosphor), `mark.dart` | Design system, icons, animated logo |
| `update_check.dart`, `error_report.dart`, `app_version.dart` | Update notice from the website's `version.json`, crash log to `app_errors` |

---

## 5. Backend: database (Supabase Postgres)

Schema changes only through reviewed files in `supabase/migrations/`. Production uses forward-only "Option B": the owner applies each file with `tools/apply_prod.ps1` (one transaction per file); migration history is not written (`docs/MIGRATION_RECONCILIATION.md`).

Tables (all user tables: RLS own rows only; anon has no access):

| Group | Tables |
|---|---|
| Person | `profiles`, `dietary_profiles` (diet type, restrictions, budget tier + daily figure, region, pace, supplements), `user_goals`, `goal_levels` (client may write 0 to 3 only) |
| Catalogues (read-only) | `goal_catalog` (56 goals), `curriculum_levels` (levels and pass rules), `exercises` (ExerciseDB, 1,324 with media), `foods` (IFCT 2017 + USDA FDC), `food_sources` (licence gates), `handbook_chapters` (43-chapter book) |
| Plan and training | `generated_plans`, `workout_logs`, `set_logs`, `exercise_swaps`, `session_changes` (server-written proposals the user confirms) |
| Coach | `coach_threads` (with rolling summary), `coach_messages`, `coach_facts` (suggested/confirmed memory), `coach_notes` |
| Tracking | `body_metrics`, `progress_photos`, `water_intake`, `habit_logs`, `food_log`, `recipes`, `recipe_items` |
| Reminders | `reminder_prefs`, `custom_reminders` |
| Ops and site | `app_feedback`, `app_errors` (90-day removal), `waitlist`, `contact_messages` (rate-limited) |

Rate limits live in Postgres (`check_rate`, buckets for chat, plan rebuilds, body check).

---

## 6. Diet planner (`app/lib/diet_plan.dart`)

Deterministic, runs on the phone (background isolate), cached per input key.
1. **Foods**: planner codes mapped to USDA FDC rows (CC0) first, IFCT 2017 where allowed. Breakfast **dishes** (idli, dosa, ragi dosa, poha with peanuts, rava/vermicelli upma, besan/moong chilla, thepla, sprouts chaat) are Levlofit's dry-weight recipes over those foods.
2. **Templates**: breakfast (dish + milk + fruit, eggs/paneer only if protein is short), lunch (one grain by region + dal + sabzi + salad), evening snack (sprouts/chana/peanuts + fruit + optional milk), dinner (roti/bhakri + protein dish + vegetable + optional second protein).
3. **Filters**: diet type and allergy tags, own exclusion words, budget tier (from monthly budget: under Rs 4,500 / 4,500 to 9,000 / over 9,000 or own amount stored as daily = month / 30), soya limit, region preference.
4. **Solver**: portions in kitchen steps with real minimums (1 cup rice, 2 rotis, 1 katori dal, whole eggs, 50 g paneer, 75 g chicken), caps (2 katoris dal, 3 eggs, 100 g paneer), then an exhaustive template search if quick picks miss. Target: energy within 5%, protein at least 90%. A day that cannot fit says so honestly and suggests allowed changes.
5. **Oil**: ICMR-NIN 2024 (27 g at 2000 kcal, 20 to 30 g/day), shown once per day in teaspoons.
6. **Display**: meal titled as a plate ("Roti + Rajma + Cauliflower sabzi + Cucumber salad"), parts labelled (GRAIN, DAL, PROTEIN...), household servings with exact grams.
7. **Build my plate** (Diet tab): 7 steps (numbers, region, diet, budget, health conditions, protein powder, pace). Lactose/gluten change restrictions; other conditions show a see-your-doctor note. Protein shakes (0 to 3 scoops, 120 kcal / 24 g each) are added to the snack and meals planned around them (scoops stored on the phone).

---

## 7. Edge Functions (`supabase/functions`)

| Function | Input -> output | Notes |
|---|---|---|
| `generate-plan` | (auth) -> plan JSON in `generated_plans` | `_shared/plan-engine.ts`: reviews answers (safety findings, BMI WHO bands, phase changes), levels (assessed `goal_levels` override self-rating), level-first goal rules (Level 0-1: main goal only), sessions, Mifflin-St Jeor energy and pace, protein, supplements; optional AI roadmap |
| `coach-chat` | `{message, threadId?, editFrom?, clientMsgId?, activity?, today?}` -> reply + proposals; `{assess}` -> `{reply, done, levels}`; `{confirmSwap}` / `{confirmChange}` | See section 8 |
| `body-check` | photo (consent) -> notes | Photo not stored; 3 a day |
| `delete-account` | (auth) -> deletes Storage files then the user | |

LLM access: `_shared/llm.ts` (OpenAI-compatible; presets groq/openrouter/gemini; request-wide deadline; optional fallback provider). A provider is used only when `LLM_DATA_APPROVED` names it. Secrets (owner-set): `LLM_API_KEY`, `LLM_DATA_APPROVED=groq`, optional `LLM_MODEL`, `LLM_BASE_URL`, `LLM_FALLBACK_*`, `LLM_REQUEST_BUDGET_MS`.

---

## 8. Levlofit AI (coach-chat)

Per message:
1. Rate limits, duplicate check (client message id).
2. Reads profile, latest plan, chat history (+ rolling summary), confirmed facts, diet, logs, Handbook titles; food diary and lifts only when relevant.
3. **Handbook retrieval** (`_shared/handbook.ts`, passages from `handbook-passages.json`, only reviewed passages citable).
4. **Research search** (`_shared/research.ts`): for factual questions, topic words only (numbers, mid-sentence names, personal words removed) go to Europe PMC (review abstracts) and Wikipedia; results cited `[R#]` with a source list. Free, no key.
5. System prompt = rules (brief, honest not agreeable, corrects wrong or unsafe ideas, scope, safety, level-first, food rules) + Handbook + research + context block.
6. Checks: empty/echo reply regenerated once; small-talk length cap; restricted foods re-checked; swap/lighter/move/meal proposals validated server-side and stored only as proposals the user confirms; memory suggestions stored as `suggested`.

**Level check** (`{assess}`, `_shared/assess.ts`): during onboarding the AI reads body numbers (BMI band, body type, body goal), challenges mismatches, asks up to 3 ability questions, then outputs levels 0 to 3 per goal (0 to 1 with a medical flag). Nothing stored server-side; the app saves levels to `goal_levels` before building the plan.

---

## 9. Handbook

43 chapters in five parts (Foundations; Getting better; Food and body; Train for your goal; Staying with it), mostly visual blocks, every number cited. Source of truth: `data/build_handbook.py` (v3 text) + `data/handbook_v4/build_handbook_v4.py` (book structure) -> `supabase/migrations/20261028200000_handbook_v4_book.sql`. Evidence registers: `data/handbook_v4/claims_register.csv`, `sources_register.csv`; `data/evidence/extract_claims.py --sync` regenerates the coach passages.

---

## 10. Website (`website/`)

Next.js 16, React 19, Tailwind. Pages: `/` landing, `/privacy`, `/terms`, `/delete-account`, `version.json` (latest app version for the in-app update notice). GitHub Actions: `ci.yml` (tests) and `keep-alive.yml` (keeps the free Supabase project active).

---

## 11. Setup and running

Requirements: Flutter (at `C:\flutter`), Android SDK + adb, Docker Desktop, Supabase CLI, Node.js, Deno, Python 3.

```bash
# local backend (throwaway)
supabase start
supabase db reset          # applies all migrations + seed
supabase test db           # pgTAP

# app against local backend
cd app && flutter pub get && flutter run

# release APK (production backend, with Health Connect steps)
LEVLOFIT_HEALTH_CONNECT=true flutter build apk --release --split-per-abi --dart-define=LEVLOFIT_BACKEND=production
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# website
cd website && npm install && npm run dev
```

Release signing: `app/android/key.properties` (git-ignored) points at the owner's keystore outside the repo. Never commit or print it.

Tests (one runner): `bash tools/verify.sh <suite...>` with suites `handbook`, `handbook4`, `functions` (node tests, offline eval, strict tsc), `deno` (check, lint, smoke), `db` (pgTAP, local), `flutter` (analyze + 492 tests), `website` (lint, build, tsc).

Production changes (owner only, one approval each):
- Migrations: `powershell -ExecutionPolicy Bypass -File tools\apply_prod.ps1 supabase\migrations\<file>.sql`
- Functions: `supabase login`, then `supabase functions deploy <name> --project-ref <ref>`, then `supabase logout` and delete the CLI token.
- Backups: `tools/backup_prod.ps1` / `backup_prod.sh`, sealed with `backup_seal.sh`.

---

## 12. Data, licences and privacy

- Foods: USDA FoodData Central (CC0); IFCT 2017 (NIN) values shown by owner decision.
- Exercises: ExerciseDB by AscendAPI (non-commercial, credit shown).
- Body map: react-native-body-highlighter 3.2.0 (MIT). Icons: Phosphor (MIT). Fonts via Google Fonts.
- Privacy: in-app privacy screen and `website/src/app/privacy/page.tsx` list exactly what goes to Groq, the level check, the research search, Supabase, Google, ExerciseDB and Health Connect. Owner self-review: `docs/PRIVACY_SELF_REVIEW.md`. Registers: `docs/LICENSING_REQUIREMENTS.md`, `docs/SOURCE_LICENCE_REGISTER.md`.

---

## 13. History in short

1. Sept 2026: Flutter + Supabase scaffold, onboarding, plan engine, goal catalogue and curriculum levels, IFCT foods, Handbook v1, exercise library.
2. Oct 2026: dashboard and tabs, coach chat with memory, threads and actions, reminders, food diary, Handbook v2/v3 with evidence audits, security hardening (RLS, revokes, rate limits), USDA foods, website, backup tooling.
3. 27 to 28 Oct 2026: production release prep (all migrations and functions live), signed APK, then owner feedback rounds: skinny-fat body type, exact reminders, short small talk, MuscleWiki-style body map, Handbook v4 book live, Build my plate, monthly budget, real-portion plates, Health Connect steps, AI level check, honest coach, research search.

## 14. Further reading (`docs/`)

`RELEASE_CHECKLIST.md` (every release step and gate), `OWNER_DECISIONS.md`, `PROGRESS.md` (batch log), `LEVLOFIT_HANDOFF.md`, `MIGRATION_RECONCILIATION.md`, `RELEASE_SETUP.md`, `BACKUP_RECOVERY_PLAN.md`, `HANDBOOK_BOOK_PLAN.md`, `STEP_COUNTER_PLAN.md`, `PLAY_DATA_SAFETY_DRAFT.md`, `AI_PROVIDER_COMPARISON.md`, `GAP_ANALYSIS_19.md`.

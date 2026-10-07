# India-First Fitness App + Website — Build Plan

## Context

The goal is a fitness app (+ companion marketing website) for Indian users, built entirely on free/open-source tools, that stands out from HealthifyMe/Cult.fit/Fittr not by tracking harder but by teaching better. Research confirms the competitive gap: HealthifyMe wins on AI+Indian-diet tracking, Fittr wins on peer coaching, Cult.fit wins on hybrid gym access — none of them center a scientifically-cited, chapter-wise, visually-taught training manual as the product itself. That's the USP: **the Handbook**.

The project folder already contains [Refrence/Self_Coaching_Athlete_Master_Curriculum.pdf](Refrence/Self_Coaching_Athlete_Master_Curriculum.pdf) — a 43-page, source-cited (ACSM 2026, WHO, ISSN, official HYROX rulebook, England Boxing) Level 0–5 curriculum covering strength, hypertrophy, calisthenics, running, power/athletics, HYROX, and boxing, with prerequisites, weekly templates, advancement tests, and troubleshooting tables. This document is not reference material for the plan — it **is** the seed content for both the Handbook and the plan-generation logic, which resolves requirement #8 (everything must be scientifically validated) almost for free: cite it directly instead of writing fitness content from scratch.

Confirmed architecture decisions (from user): **Flutter** (mobile), **Supabase** (backend — genuinely open-source, Postgres, free tier), **hybrid rules-engine + light-LLM bot** (not LLM-generated plans), **marketing-only website** (app owns all profile/dashboard/tracker functionality).

One scope gap to flag: the curriculum has no swim/bike content, so **Ironman/triathlon** isn't backed by this source. Recommendation: ship the goals the curriculum actually covers (strength, hypertrophy/aesthetic building, calisthenics, running, HYROX, general fitness/mobility, boxing) in v1, and treat Ironman as a v2 addition once equivalent sourced content exists — don't fabricate swim/bike programming to check a box.

## Tech Stack (with rationale, per requirement #14)

| Layer | Choice | Why over alternatives |
|---|---|---|
| Mobile app | **Flutter** | Single Dart codebase for Android+iOS; best animation/motion primitives of the free options, which matters directly for the "premium feel" requirement; strong offline support for a content-heavy Handbook. |
| Backend | **Supabase** | Actually open-source (Firebase isn't); Postgres fits relational profile/plan/tracking data better than Firestore's NoSQL; free tier covers auth (50k MAU), 500MB DB, 1GB storage, 500k edge function calls/month — enough for MVP through early growth. Caveat: free projects pause after 7 days of inactivity, so a low-traffic MVP needs a cheap uptime ping or manual resume. |
| Plan-generation logic | **Supabase Edge Function (TypeScript/Deno)**, not client-side Dart | Single source of truth callable from the app now and the website later if needed; keeps the scientific rules testable and versioned independently of UI code — avoids duplicating the same logic in two languages. |
| Website | **Next.js on Cloudflare Pages**, not Vercel | Cloudflare Pages' free tier explicitly allows commercial use with unlimited bandwidth; Vercel's free tier is personal/non-commercial only, which conflicts with requirement #14 (eventually charging a subscription). |
| Animation (Handbook) | **Lottie** (lottie-flutter, open-source player) + hand-built SVG/vector loops for simple movements | Free, no vendor lock-in, works offline once bundled. |
| Exercise GIFs | See "Exercise Data" below — two sources, one licensing caveat to resolve before charging money. |
| Nutrition data | See "Nutrition Data" below. |
| AI assistant | **Groq free API** (no credit card, no per-token charge on free models: currently gpt-oss-120b/20b and Qwen 3.x, 30 RPM/1,000 RPD) for the bot's conversational tone only — never for computing the actual macro/rep numbers. |

## Content & Data Sourcing

**Handbook content**: derive the 34-chapter structure directly from the reference PDF (Parts A–I: foundation, strength/muscle, calisthenics, running, power/athletics, HYROX, boxing, integration, long-term system). Each chapter becomes a searchable, chaptered entry with the PDF's tables reproduced as structured UI (progression tables, advancement checklists) rather than plain text, plus supporting GIFs/animations per exercise. Cite sources inline exactly as the PDF does (ACSM, WHO, ISSN, HYROX, England Boxing) so requirement #8's "scientifically proven" bar is auditable, not just asserted.

**Exercise visuals** (requirement #13 — real-person GIFs):
- Primary: **ExerciseDB free V1** (exercisedb.dev, no signup/API key, 1,500+ exercises with 180p GIFs) — but it's **non-commercial use only with attribution required**. Fine for the free MVP phase.
- Commercially-safe fallback: **free-exercise-db** (yuhonas/free-exercise-db, public-domain JSON dataset, 800+ exercises) — static image sequences, not GIFs, but no licensing risk at all, ever.
- Also usable: **wger** (AGPL-3.0, self-hostable, REST API, exercise wiki with images + built-in Open Food Facts nutrition integration) as a secondary data/image source without needing to self-host it (its public API can be queried directly).
- **Flag for the user**: before turning on paid subscriptions, either swap fully to the public-domain/self-owned GIF set or secure a commercial license for ExerciseDB content — don't monetize on non-commercial-licensed assets.

**Nutrition data** (requirement 7/8 — Indian-specific, scientifically bounded):
- **IFCT 2017** (ifct2017/ifct2017 on GitHub/Zenodo) — 542 Indian foods with 151 nutrient fields, sourced from India's National Institute of Nutrition (ICMR), free to disseminate, bundleable as a static dataset (no API rate limits, no ongoing dependency). This is the primary source for dal, roti, paneer, idli, etc.
- **Open Food Facts** (open, free API) for packaged/branded Indian products.
- On the soya chunks example specifically: current literature centers the safe daily range at **~25–50g dry weight for a healthy adult**, with some sources flagging >75g as where digestive/hormonal concern starts — not the 50–60g the request assumed. This is exactly why the diet engine must pull every numeric limit from a cited source at content-authoring time (ICMR-NIN RDA tables, FSSAI, ISSN position stands) rather than hard-coding remembered numbers — the same discipline applies to every other food-specific hard limit before it ships.
- Diet-restriction intake (lactose intolerance, allergies) is asked **before** diet-type selection, per requirement #8, and used to filter the food set the plan-generation engine can select from — never as a post-hoc warning.

## Data Model (Supabase / Postgres, core tables)

`profiles` (auth.users extension: name, age, sex, height, weight, city/state for locale defaults) → `user_goals` (goal enum + experience level, 1–4 rows per user) → `dietary_profile` (diet type: vegan/vegetarian/eggitarian/non-vegetarian — no beef/pork options offered at all — plus allergy/intolerance flags) → `generated_plans` (versioned workout+diet plan snapshots produced by the edge function, so plans are reproducible/auditable, not regenerated silently) → `workout_logs`, `body_metrics` (weight/waist history for the BMI/tracker features) → `handbook_chapters` + Postgres full-text search (`tsvector`) for in-app chapter search — no separate search service needed, it's a native Postgres feature and free.

## Bot / Onboarding Flow (hybrid, per confirmed decision)

1. Email sign-up/login (Supabase Auth) → email verification.
2. Chat-styled wizard (scripted branching UI, Groq only adds phrasing/tone) asks, in order: primary + secondary fitness goals (1 required, 3–4 max) → experience level per selected goal → diet-related restrictions/allergies first → diet type (vegan/vegetarian/eggitarian/non-vegetarian) → basic biometrics (height/weight/age) → indoor/outdoor and equipment access.
3. Supabase Edge Function maps these answers to the curriculum's Level 0–5 entry point per goal (using the PDF's own "entry-level decision" and baseline-test rules) and to an IFCT-bounded diet plan respecting restrictions.
4. Only after a plan is successfully generated does the user reach the main dashboard — matches requirement #11.
5. Account deletion: a Supabase Edge Function that cascades-deletes the user's rows and calls `auth.admin.deleteUser`, exposed as a confirm-modal action in account settings.

## Build Phases

0. **Scaffolding** — Flutter app skeleton, Supabase project, Next.js site skeleton on Cloudflare Pages, CI basics. Invoke `ui-ux-pro-max` / `taste-skill` / `21st-ui-build` design skills here to lock a design language up front — explicitly avoiding requirement #16's AI-slop list (no purple gradients, pill buttons, fake reviews/metrics, emoji icons, em dashes).
1. **Auth + onboarding bot + profile** — email auth, chat wizard, profile schema, plan-generation edge function v1.
2. **Plan engine depth** — encode the curriculum's full Level 0–5 tables, progression/deload rules, and diet-restriction filtering as the edge function's actual logic (this is the highest-value, highest-risk phase — it's where "scientifically proven" is either true or isn't).
3. **Dashboard + tracker** — BMI calculator, workout logger, fitness calendar, reminders/notifications, progress charts.
4. **Handbook** — chaptered content from the PDF, search, GIFs/animations per exercise, visual progression tables.
5. **Website** — landing/USP page, Handbook teaser, privacy policy, T&C, blog scaffold; implement the full requirement #17 checklist (dark mode, cookie banner, site search, mobile menu, sticky header, scroll progress bar, print stylesheet, skip-to-content, expandable FAQ, floating contact button, form success/error states, confirmation modals, UTM capture, last-updated dates) with native browser features + minimal libraries, not heavy frameworks.
6. **Polish pass** — motion/interaction detail (`motion` skill), accessibility audit (`ecc:accessibility`), security review of auth/account-deletion flows (`security-review` skill) before any public launch.
7. **Free launch → subscription** — ship free per requirement #14; revisit the GIF licensing flag above before turning on payments (Razorpay/UPI is the standard low-fee India gateway when that day comes).

## Quality & Tooling (added 2026-09-28 at user request)

- **DESIGN.md** (repo root, awesome-design-md format): single source of truth for tokens, type, components and bans. Every UI task reads it first.
- **Context7** (connected MCP): look up current Flutter, supabase_flutter (`/supabase/supabase-flutter`), Supabase, Next.js docs before writing integration code.
- **Playwright CLI** (`@playwright/cli`, installed globally, skill installed in project `.claude/skills/playwright-cli`): open each website page and the Flutter web build, fail on any console error, click through golden paths (sign up, onboarding, delete-account confirm, waitlist form states).
- **Strix** (usestrix/strix, Apache-2.0): AI pentest against `supabase/` + app source and the running local site before any public launch and after auth/account-deletion changes. Needs Docker running and an LLM key; keep it free by pointing it at Groq's free tier or a local Ollama model (`LLM_API_BASE`). Run headless with `strix -n --target <dir|url>` in CI later. Install when Phase 1 code exists.
- Design/animation skills per phase: `ui-ux-pro-max`, `21st-ui-build`/`21st-ui-review`, `motion` / `ecc:motion-*`, `ecc:accessibility`, `design:design-critique`.

## Status (2026-09-28)

Done: plan, tool research, Phase 0 scaffold, hi-fi prototype, brand locked (Levlo), DESIGN.md.
Phase 1 code done: migration + RLS, plan engine v1 + tests (8/8 pass), generate-plan + delete-account functions, Flutter theme, auth (verified in browser), coach onboarding, dashboard v1 with account delete.
Phase 1 open: end-to-end run of onboarding -> plan -> dashboard (needs Supabase: Docker local stack or a free cloud project), email deep link for confirmation on mobile, password reset flow, Groq tone layer.
Waiting on user: Docker Desktop first-run or OK to create a free Supabase cloud project, Android Studio + SDK licences, Smart App Control blocks `flutter test`.

## Verification

- Plan engine: unit tests asserting every generated plan stays inside the sourced numeric bounds (protein g/kg, soya chunks g/day, WHO weekly activity minutes, etc.) — this is the one place a silent regression would violate requirement #8, so it needs an automated check, not just manual review.
- Onboarding flow: run end-to-end in the Flutter app (simulator) confirming a user cannot reach the dashboard without a completed profile + generated plan.
- Website: Lighthouse/accessibility pass plus manual run-through of every requirement #17 feature.
- Handbook: spot-check a sample chapter's citations against the source PDF and the original ACSM/WHO/ISSN documents it references.

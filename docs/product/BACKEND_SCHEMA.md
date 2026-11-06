# Levlofit: Backend Schema

Last updated: 2026-11-07, read from the live project. Latest migration: `20261107200000_other_supplements`.
Keep current: see "Keeping these documents current" in `CLAUDE.md`; a test fails when a migration or table is missing here.
Source of truth: `supabase/migrations/`. Never change the schema any other way.

## 1. Rules for every table

- Row level security is on everywhere. "Own rows" means `auth.uid() = user_id`.
- Personal tables cascade from `auth.users`, so deleting an account removes them. Storage files are removed first by the
  `delete-account` function.
- Anon has no access to personal data. Column grants limit what signed-in users may write.

## 2. Person

| Table | Columns | Notes |
|---|---|---|
| `profiles` | id, display_name, birth_year, sex, height_cm, weight_kg, weight_goal, equipment, equipment_items, onboarding_complete, created_at, body_type, waist_cm, days_per_week, session_minutes, daily_activity, sleep_hours, health_flags, injuries, water_target_ml, avatar, training_days, training_time | Own row. `onboarding_complete` only through `save_generated_plan` |
| `dietary_profiles` | user_id, diet_type, restrictions, other_restrictions, supplements, other_supplements, budget_tier, budget_min_inr, budget_max_inr, diet_pace, cuisine_region, health_conditions, whey_scoops, kitchen, cook_time, kitchen_equipment, kitchen_other, mess_meals | Own row. `supplements` is protein_powder or creatine; `other_supplements` is free text, 10 at most |
| `user_goals` | user_id, goal, experience, priority | Own rows, 1 to 6. Replace through `replace_user_goals` |
| `goal_levels` | user_id, goal, level, assessed_at | Own rows |
| `reminder_prefs` | user_id, enabled, workout_at, water_every_h, water_from, water_to, weigh_in_weekday, updated_at | Own row |
| `custom_reminders` | id, user_id, name, remind_at, weekdays, enabled, created_at, updated_at | Own rows, limit by trigger |

## 3. Plans and changes

| Table | Columns | Notes |
|---|---|---|
| `generated_plans` | id, user_id, engine_version, input, plan, created_at | Read own; written by the server. History kept |
| `plan_changes` | id, user_id, field, value, from_value, status, created_at, confirmed_at | Coach proposals; server-written |
| `exercise_swaps` | id, user_id, day, from_exercise, to_exercise, status, created_at, confirmed_at | Coach proposals |
| `session_changes` | id, user_id, day, kind, to_day, status, created_at, confirmed_at | Lighter day, moved session |

## 4. Logs

| Table | Columns | Notes |
|---|---|---|
| `workout_logs` | id, user_id, performed_on, goal, duration_min, rpe, notes, created_at | `notes` holds the pain answer |
| `set_logs` | id, user_id, performed_on, exercise_id, set_no, reps, kg, created_at | |
| `food_log` | id, user_id, day, meal, food_code, packaged_food_id, grams, created_at | Exactly one of food or packaged food; limit by trigger |
| `daily_checkins` | user_id, day, workout, food, energy, sleep, soreness, note, updated_at | One a day; never sent to the AI provider |
| `habit_logs` | user_id, day, habit | |
| `water_intake` | id, user_id, taken_at, ml | |
| `body_metrics` | id, user_id, measured_on, weight_kg, waist_cm, body_fat_pct, neck_cm, chest_cm, hips_cm, arm_cm, thigh_cm | One a day |
| `progress_photos` | id, user_id, taken_on, path, created_at | Path starts with the user id |
| `packaged_foods` | id, user_id, barcode, name, brand, kcal, protein_g, fat_g, carb_g, fiber_g, source, source_date, created_at | Own products |
| `recipes` | id, user_id, name, servings, created_at | Save through `save_recipe` |
| `recipe_items` | id, recipe_id, user_id, food_code, grams | Raw weights |

## 5. Coach

| Table | Columns | Notes |
|---|---|---|
| `coach_threads` | id, user_id, title, updated_at, summary, summary_upto | |
| `coach_messages` | id, user_id, thread_id, role, content, client_msg_id, created_at | Saved by `coach_commit_turn` |
| `coach_notes` | user_id, notes, updated_at | |
| `coach_facts` | id, user_id, category, fact, status, source, created_at, updated_at, confirmed_at | Memory; used once confirmed |

## 6. Reference data (public read)

| Table | Columns | Notes |
|---|---|---|
| `foods` | code, name, name_hi, food_group, tags, kcal, protein_g, fat_g, carb_g, fiber_g, suggestible, kcal_estimated, calcium_mg, iron_mg, zinc_mg, sodium_mg, potassium_mg, magnesium_mg, vitamin_c_mg, folate_ug, source, source_ref, source_note | Per 100 g, mostly raw or dry. Hidden unless its source is allowed |
| `food_sources` | source, name, licence, url, attribution, verified_on, release_allowed, note | ifct2017, usda_fdc and others |
| `exercises` | id, name, gif_url, body_parts, equipment, target_muscles, secondary_muscles, instructions, source, search, has_media | ExerciseDB V1 |
| `goal_catalog` | id, name, category, kind, coach_led_from_level, curriculum, handbook_chapter, sort | |
| `curriculum_levels` | goal, level, title, practice, advance_when, coach_recommended, source | |
| `handbook_chapters` | id, part, title, body_md, sources, search, slug, part_title, summary, minutes, blocks | |

## 7. Operations

| Table | Columns | Notes |
|---|---|---|
| `rate_events` | user_id, bucket, at | Server only |
| `ai_daily_caps` | bucket, per_day, updated_at | Server only; app-wide caps |
| `app_errors` | id, user_id, created_at, app_version, platform, message, stack | Own insert, limit by trigger |
| `app_feedback` | id, user_id, message, created_at | 5 a day |
| `contact_messages` | id, email, message, utm, created_at | Website form, anon insert only |

## 8. Functions and triggers

| Function | Runs as | Purpose |
|---|---|---|
| `save_generated_plan(uuid, text, jsonb, jsonb)` | service role | Plan and onboarding flag in one transaction, 2-minute retry safety |
| `check_rate(text, int, interval)` | definer | Per-user and app-wide limits |
| `coach_commit_turn(...)` | invoker | Saves a chat turn atomically |
| `replace_user_goals(jsonb)`, `save_recipe(...)` | invoker | Atomic saves |
| `handle_new_user()` | definer | Creates the profile on sign-up |
| `hook_before_user_created(jsonb)`, `purge_unconfirmed_users()` | invoker | Sign-up guard; hook active only if selected in Auth settings |
| `words(text[])` | invoker | Search helper |

Triggers: limits on `app_errors`, `app_feedback`, `contact_messages`, `custom_reminders`, `food_log`, `packaged_foods`,
`recipes`, `recipe_items`; `coach_facts_stamp`; `food_log_own_packaged`.

## 9. Storage

Bucket `progress-photos`: private, 8 MB, jpeg, png, webp. Policy: first path folder must equal the user id. Holds progress
photos and profile pictures.

## 10. Edge Functions

| Function | Auth | Tables written |
|---|---|---|
| `generate-plan` | Signed in | `generated_plans`, `profiles` (through `save_generated_plan`) |
| `coach-chat` | Signed in | Coach tables and proposals (the app writes `food_log` after the person confirms a meal) |
| `body-check` | Signed in | None (photo not stored) |
| `send-feedback` | Signed in | `app_feedback` |
| `delete-account` | Signed in | Removes Storage files and the auth user |

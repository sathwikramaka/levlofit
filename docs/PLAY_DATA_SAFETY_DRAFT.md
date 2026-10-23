# Google Play data safety and store listing: DRAFT (2026-10-16, Levlofit-4; updated 2026-10-17)

**Status: draft for legal/privacy review. Not submitted, not reviewed, not legal advice.** Derived only from the
current code and the privacy text in website/src/app/privacy/page.tsx (dated 13 October 2026, with a REVIEW GATE on
the Levlofit AI paragraphs). Every answer below must be re-checked against the deployed app and the reviewed policy
before it is entered in Play Console (RELEASE_READINESS_AUDIT.md R6, R10).

## Evidence used

- app/pubspec.yaml dependencies: supabase_flutter, google_fonts, flutter_svg, http, image_picker,
  flutter_local_notifications, timezone, flutter_timezone, audioplayers, shared_preferences, url_launcher. **No
  analytics, crash-reporting, advertising or push-messaging SDK.**
- Merged release manifest (aapt dump of a local debug-signed release build, 2026-10-16): INTERNET,
  POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, VIBRATE (from the notifications plugin) and the
  app-internal DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION; not debuggable; allowBackup false; minSdk 24, targetSdk 36.
  No location, contacts, camera (image_picker uses the system picker), microphone, Health Connect or activity
  recognition in a default build. A build made with -Plevlofit.healthConnect=true adds
  android.permission.health.READ_STEPS and raises minSdk to 26 (verified with aapt, PROGRESS batch 2F); such a build
  changes the answers marked [HC] below and needs a Health Connect declaration in Play Console.
- Backend: Supabase (database, auth, Storage); Edge Functions coach-chat (Groq via LLM_* secrets), generate-plan,
  delete-account.
- Privacy text sections "What we collect", "Who processes it", "How long we keep it".

## Data collection overview (draft answers)

| Question | Draft answer | Basis | Review note |
|---|---|---|---|
| Does the app collect or share any required user data types? | Yes (collects) | Account, answers, logs, photos, chats | |
| Is all collected data encrypted in transit? | Yes | Supabase and Groq over HTTPS | Confirm no http:// endpoint in the release build |
| Can users request deletion? | Yes: in the app (Profile > Delete account; during sign-up the account menu) and on the web (/delete-account, by email) | account.dart, delete-account function, website/src/app/delete-account/page.tsx | The web page exists locally behind a REVIEW GATE (legal review pending); it is not hosted yet |
| Data shared with third parties? | Draft: **No** sharing; the AI provider (configured as Groq by default, LLM_* settings), Supabase and Google sign-in act as service providers for the app | Privacy "Who processes it"; supabase/functions/_shared/llm.ts | Legal must confirm the AI provider qualifies as a service provider under Play's definition; the deployed provider must match the policy |

## Data types (draft)

| Play category / type | Collected | Shared | Purpose | Optional? | Source in app |
|---|---|---|---|---|---|
| Personal info / Email address | Yes | No | Account management | Required | Supabase auth |
| Personal info / Name | Yes | No | Account management, personalisation | Required (entered at sign-up; Google pre-fills it; the first name goes to the coach) | profiles.display_name (onboarding.dart) |
| Personal info / Other info (year of birth, sex) | Yes | No | App functionality (plan) | Required | onboarding answers |
| Health and fitness / Health info (health check answers, injury, weight, height, waist, body type, diet type, allergies and intolerances, food diary entries (totals and micronutrients are calculated from public food data, not collected), effort/pain answers) | Yes | No | App functionality | Mixed (health check required; waist, sleep optional) | profiles, dietary_profiles, body_metrics, food_log, workout_logs (rpe and session answers), generated_plans (a copy of the answers with each plan) |
| Health and fitness / Fitness info (workouts, sets, training days, activity, water, habits, goal levels) | Yes | No | App functionality | Required for core use | workout_logs, set_logs, water_intake, habit_logs, goal_levels. Per-move lift summaries (name, days, best set) go to the AI provider only for lifting questions (batch 2F) |
| [HC] Health and fitness / Fitness info: daily step totals from Health Connect | Draft: **not collected** (stays on the phone), except the 7 daily totals sent with a coach message when the person switches on sharing (then: collected, not shared, ephemeral, optional) | No | App functionality | Optional | Not stored server-side; coach-chat request only |
| Photos and videos / Photos | Yes | No | App functionality | Optional | progress-photos bucket, profile picture |
| Messages / Other in-app messages (Levlofit AI chats, coach notes, feedback) | Yes | No | App functionality, support | Optional | coach_threads, coach_messages, coach_notes, app_feedback |
| App activity / Other user-generated content (recipes, custom reminder names) | Yes | No | App functionality | Optional | recipes, recipe_items, custom_reminders |
| App activity / Other actions (time stamps for rate limits) | Yes | No | Fraud prevention, security | Required (automatic) | rate_events |
| Device or other IDs | Draft: No | | | | Random chat message IDs are per-message, not device IDs: confirm |
| Location, Financial info, Contacts, Audio, Calendar, Web browsing | No | | | | No permission or code path |

Data kept only on the device (theme choice, cookie notice, dashboard layout, reminder schedules in the OS) is not
"collected" under Play's definition: confirm with the reviewer.

Third-party requests that expose the IP address: Google Fonts (font download) and ExerciseDB (exercise animations).
They are disclosed in the privacy text; whether they need a data-safety entry is a reviewer question. ExerciseDB media
is also **licensed non-commercial** (separate release blocker).

## Store listing draft (facts only; marketing copy is the owner's)

- App name: Levlofit. Package: com.levlofit.app. Category: Health and Fitness. Age: adults 18 to 80 (privacy "Age").
- Contains ads: No. In-app purchases: none in the code.
- Privacy policy URL: the website's /privacy page (host not chosen yet, R9).
- Health claims: none may be made until the clinical review (areas 1, 2, 9, 10) is complete.

## Open items before submission (none can be closed locally)

1. **Account deletion web URL** (Play requirement): the page exists locally (/delete-account, batch CB, corrected in CE)
   behind a REVIEW GATE; it needs legal review and a chosen website host before it can be entered in Play Console.
   Also unrecorded so far: a legacy `waitlist` table (email + UTM, migration 20260929190000) that no current code
   writes to; the reviewer should decide whether the policy must mention it or it should be emptied and dropped.
2. Legal/privacy review of this draft, the privacy text (REVIEW GATE markers) and retention periods.
3. Confirm the deployed coach-chat function and LLM_BASE_URL match the Groq paragraph before publishing it.
4. SCHEDULE_EXACT_ALARM: confirm Play's exact-alarm policy for a reminder feature; ties to the owner's pending
   alarm-clock-mode decision (area 13).
5. Health Connect / step counter (area 16): code complete behind a build flag; a flagged build needs the owner's
   approval, the [HC] rows above, a Health Connect declaration (data type: Steps, read) and the privacy policy link
   Health Connect shows (docs/STEP_COUNTER_DEVICE_CHECKLIST.md item 10).
5a. A second AI provider (LLM_FALLBACK_*) would be another service provider receiving the same chat context; name it
   in the privacy text first (REVIEW GATE) and in this form.
6. Content rating questionnaire, target audience and news-app declarations: owner, in Play Console.

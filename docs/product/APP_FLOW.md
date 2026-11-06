# Levlofit: App Flow

Last updated: 2026-11-07, for release 1.0.10. Keep current: see "Keeping these documents current" in `CLAUDE.md`.

## 1. First run

```
Splash ─> Signed in?
            ├─ No ─> Sign in or create account (Google, or email with code)
            │          Terms and Privacy links; forgot password
            └─ Yes ─> Onboarding finished?
                        ├─ No ─> Notifications prompt ─> Onboarding
                        └─ Yes ─> Dashboard (Home)
```

Older build: an update card appears; below the minimum build it cannot be dismissed, and coach, plan rebuild and body check
answer "please update".

## 2. Onboarding (`onboarding.dart`)

1. Name
2. Main goal, from 12
3. Extra goals, up to 5
4. Experience per goal
5. Body: year of birth (18 to 80), sex, height, weight, body type
6. Phase: cut, bulk, recomp, maintain, general
7. Schedule: days, minutes, weekdays, time ("It varies" allowed), daily activity, sleep
8. Health check: flags, injuries
9. Equipment
10. Allergies and foods to avoid
11. Diet: type, budget, region, kitchen, cooking time, supplements, own supplements
12. Level check with Levlofit AI
13. Build: `generate-plan` saves the plan in one transaction
14. Review: what the plan changed and why, with sources

## 3. Main navigation

Floating bottom bar, on every tab, hidden while typing: **Home, Workout, Diet, Progress, More**.
The floating AI button sits on Home, Workout and Diet.

More opens the side menu: Workout, Protocol, Calendar, Progress; Diet, Hydration, Food diary, Food library; Habits, BMI
calculator; the Learn section (Handbook, exercise library, glossary); Reminders, Profile.

## 4. Home

Header (avatar opens Profile, timer icon opens Reminders), then cards the person can reorder or hide:
activity arcs, today's session, daily check-in, daily goal, rank and rating, week, water, habits, food targets, body.
Under today's session when they apply: level prompt, safety notes, then **welcome back** (14+ days away) or **plan fit**
(three short weeks).

| Action | Result |
|---|---|
| Start session | Session screen ─> warm-up, sets, rest timer ─> Finish ─> how it went (effort, pain) ─> logged |
| Tick the session done | Logged for today; tap again to undo |
| Check-in | Sheet of optional answers; a second save the same day edits it |
| Plan fit: Switch | Sets days per week, rebuilds the plan. Keep hides it for 4 weeks |
| Welcome back: Got it | Hidden until the next break |

## 5. Diet

Day chips ─> training-day or rest-day card ─> meal cards ─> Supplements card ─> plate key ─> Build my plate ─> notes ─>
targets and protein foods ─> recipes with AI.

- Tap a meal for grams. **Swap** takes that meal from another day. **Ate it** logs it to the diary (today only).
- **Build my plate** has 3 steps: budget; diet and regions; health, protein scoops, creatine and own supplements, pace.
  Saving rebuilds the plan.

## 6. Other flows

- **Workout:** goals and levels, week of sessions, edit goals, level check (a pass rebuilds the plan).
- **Progress:** weight verdict, weekly report, stats, strength, weight, measurements, body check, photos, 12-week chart.
- **Calendar:** tap a day to log or remove training, or edit its length, effort and pain.
- **Protocol:** days, minutes, weekdays, time, equipment, goal, activity, water; saving rebuilds the plan.
- **Coach:** chats, memory, edit and regenerate; proposals (swap, lighter day, moved session, plan change, meal log) apply
  only after the person confirms.
- **Food diary:** day, meal, search or barcode, grams with a raw-weight warning; edit, remove, recipes.
- **Settings:** theme (light by default), support, feedback, glossary, notifications, data use, privacy, licences.
- **Profile:** details, avatar, sign out, delete account.

## 7. Failure behaviour

| Case | What the person sees |
|---|---|
| No connection at start | Saved plan, read-only, with its age |
| Save fails | "Could not save. Check your connection and try again." |
| AI down or over limit | Clear message; everything else keeps working |
| Plan misses targets | Says so and why; offers real options |
| Feedback email fails | Saved; says it could not be emailed yet |

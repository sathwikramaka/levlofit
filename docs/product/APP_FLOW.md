# Levlofit: App Flow

Last updated: 2026-11-12, for release 1.0.12. Keep current: see "Keeping these documents current" in `CLAUDE.md`.

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

Docked bottom bar with five named tabs in fixed positions, hidden while typing: **Today, Workout, Diet, Progress, More**.
Pages opened from another page have a back arrow; pages reached from More keep More lit.

Levlofit AI: a button at the top of Today, Workout, Diet and Progress, and a row in More.

More is a page of groups: coach and learn (Levlofit AI, Handbook, Exercise library, Glossary); training (Protocol, Calendar,
Habits); food and body (Food diary, Food library, Water, BMI calculator); account (Reminders, Profile, Settings).

## 4. Today

Header (date, greeting, Levlofit AI, avatar opening Profile), then cards the person can reorder or hide. Shown by default:
weekly rings, today's session, daily check-in, week, Today's read, water, food targets. Off by default, on from
Customise: daily goal, rank and rating, habits, body. A new plan with no session yet shows "Try a short starter" (25 minutes, one set lighter) under
Start workout.
Under today's session when they apply: level prompt, safety notes, then **welcome back** (14+ days away) or **plan fit**
(three short weeks).

| Action | Result |
|---|---|
| Start session | Session screen ─> warm-up, sets, rest timer ─> Finish ─> how it went (effort, pain) ─> logged |
| Tick the session done | Logged for today; tap again to undo |
| Check-in | Sheet of optional answers; a second save the same day edits it |
| Plan fit: Switch | Sets days per week, rebuilds the plan. Keep hides it for 4 weeks |
| Welcome back: Got it | Hidden until the next break |
| Log a set that beats the last best | Haptic, a "New best" note, the move card marked |
| Pass a level check | Level-up screen ─> Share (picture) or Continue |
| Tap a nudge | Recap ─> Progress, check-in ─> Levlofit AI, meal ─> Diet |
| Today's read | Opens the chapter |

## 5. Diet

Day chips ─> training-day or rest-day card ─> meal cards ─> Supplements card ─> plate key ─> Build my plate ─> notes ─>
targets and protein foods ─> recipes with AI.

- Tap a meal for grams. **Swap** takes that meal from another day. **Ate it** logs it to the diary (today only).
- **Build my plate** has 3 steps: budget; diet and regions; health, protein scoops, creatine and own supplements, pace.
  Saving rebuilds the plan.

## 6. Other flows

- **Workout:** today's session with Start, the other days as one line each, goals and levels, edit goals, level check (a
  pass rebuilds the plan), then "Your path" folded.
- **Session:** exercises first; warm-up and cooldown fold away.
- **Progress:** weight verdict, weekly report (Share as a picture; on Sundays the week now ending), stats, strength, weight, measurements, body check, photos (a one-time reveal at 4, 8 and 12 weeks), 12-week chart, steps
  where the phone supports them, then rank, rating and the 66-day challenge.
- **Calendar:** tap a day to log or remove training, or edit its length, effort and pain.
- **Protocol:** days, minutes, weekdays, time, equipment, goal, activity, water; saving rebuilds the plan.
- **Coach:** chats, memory, edit and regenerate; proposals (swap, lighter day, moved session, plan change, meal log) apply
  only after the person confirms.
- **Food diary:** day, meal, search or barcode, grams with a raw-weight warning; edit, remove, recipes.
- **Settings** (its own row in More, not inside Profile): theme (light by default), support, feedback, glossary, notifications (with recap, check-in and meal switches), data use, privacy, licences.
- **Profile:** details, avatar, levels earned, sign out, delete account.
- **Home screen widget (Android):** today's session and the week; a tap opens the app.

## 7. Failure behaviour

| Case | What the person sees |
|---|---|
| No connection at start | Saved plan, read-only, with its age |
| Save fails | "Could not save. Check your connection and try again." |
| AI down or over limit | Clear message; everything else keeps working |
| Plan misses targets | Says so and why; offers real options |
| Feedback email fails | Saved; says it could not be emailed yet |

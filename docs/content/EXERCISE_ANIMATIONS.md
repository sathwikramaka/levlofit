# Levlofit's own exercise animations (2026-10-27)

## Why they exist

- Every original exercise GIF came from ExerciseDB V1 (`public.exercises.gif_url`, `static.exercisedb.dev`), loaded over the
  network by `ExerciseGif` (`Image.network`) in the library grid, move pages, session cards and dashboard strips (commit
  704751d onwards).
- The uncommitted licensed-content mode (`exerciseDbContent`, 2026-10-24) turns them off in every release build. The
  phone preview builds use `--dart-define=LEVLOFIT_EXERCISEDB=false`, so they show release behaviour. Debug builds still
  show the GIFs; nothing was removed.

## Free sources checked for monetised use (2026-10-27)

| Source | What it offers | Monetised use on the free tier | Decision |
|---|---|---|---|
| ExerciseDB V1 (oss.exercisedb.dev/swagger) | Animated GIFs | Not allowed: "Commercial products, SaaS platforms, or any monetised use without a paid plan via RapidAPI"; credit required | Not used in releases |
| API Ninjas Exercises (api-ninjas.com/api/exercises) | Text; images are "Premium only" PNG start/finish frames | "Commercial use of the Exercises API is not permitted on the free tier." | Rejected |
| wger (wger.de/api/v2) | Still images (CC BY-SA 3, many from Everkinetic) and 78 real-person videos (CC BY-SA 4, mostly one author) | Allowed under CC BY-SA, with attribution and share-alike | Not animations; videos differ in style and would need per-file review and a download approval. Possible later source |
| free-exercise-db / wrkout | Images | Upstream says the images were scraped and not owned | Rejected (2026-10-24) |
| MuscleWiki | Videos | Paid API; terms forbid caching | Rejected (2026-10-24) |
| CDC Growing Stronger | 6 animated GIFs | Public domain | Kept (assets/animations/SOURCE.md) |

No free API offers commercially usable animations in one consistent style, so Levlofit draws its own.

## What was built

- `app/lib/move_animation.dart`: a jointed figure painted with `CustomPainter`. Keyframes give the hips, torso angle and
  hand and foot targets; knees and elbows come from two-bone inverse kinematics, so bones keep their length, planted
  feet stay put and hands stay on the weight. Feet can pivot on the ball (calf raise, lunge back foot); toes bend flat;
  a forearm can turn about a still elbow (curl); the deadlift torso is solved each frame so the arms stay straight on a
  bar that rises vertically over the middle of the foot.
- Two figures with the same skeleton and paths, different styling: man (graphite top, orange shorts, short hair) and
  woman (orange top, graphite leggings, ponytail). Brand colours from `theme.dart`.
- `app/lib/move_animations.dart`: ten moves, each with its own keyframes.

| Animation | Linked guide move(s) | Equipment drawn |
|---|---|---|
| Squat | QChZi3x Squat | none |
| Push-up | I4hDWkc Push-up | mat |
| Bench press | EIeI8Vf Bench press | bench, rack upright, barbell plate |
| Deadlift | ila4NZS Deadlift | barbell plate |
| Shoulder press | znQUdHY Shoulder press | dumbbells |
| Pulldown | RVwzP10 Pulldown | machine, seat, knee pad, cable |
| Lunge | RRWFUcw, IZVHb27 Lunge | none |
| Calf raise | bJYHBIN Calf raise | none |
| Dumbbell curl | none: no curl in the guide | dumbbells |
| Plank | none: no plank in the guide | mat |

- Order of what a move shows (`MoveDemo`): own animation, else CDC GIF, else the two Everkinetic drawings in turn, else
  the icon. The written instructions are always on the move page. The CDC squat, lunge and calf-raise GIFs stay bundled
  and listed; the own animations take their place on screen.
- Move pages show a Man / Woman choice, remembered on the device (`demo_figure`). Until it is used, the dashboard sets
  the figure from the profile's sex.
- With the system "remove animations" setting on, each animation shows its working position still and runs no ticker.
- Credit line: "Exercise notes and figure animations: Levlofit."

## How the movements were checked

- `app/test/move_animation_test.dart`, 120 frames per loop: bone lengths constant; hands within 0.8 units of the weight;
  nothing below the floor; knees never bend backwards; plus a check per move (squat thigh within 15° of parallel and
  heels still; push-up body straight and elbows 55–100° at the bottom; bench bar locked out over the shoulders and
  touching below them; deadlift bar at x = 4 throughout, arms straight, hips and knees extended at the top; press with
  no lean back and arms straight overhead; curl elbow moving under 1.6 units; pulldown elbows below the shoulders at
  the bottom; lunge back foot still, front knee 80–105° and not past the toes, back knee just off the floor; plank
  straight during the hold with elbows under the shoulders; calf raise with the balls of the feet still).
- Contact sheets (8 frames, both figures) rendered with `LEVLOFIT_RENDER_DIR=<folder> flutter test
  test/move_animation_test.dart` and reviewed by eye. Two faults found that way and fixed: a deadlift start with the
  hips too low (squat-like), and arms bending mid-pull.
- Not yet reviewed by a qualified coach. 1 unit is about 1.75 cm for a 175 cm person.

## Phone check (2026-10-27, 358edd6b, debug build with LEVLOFIT_EXERCISEDB=false, throwaway stack)

| Check | Result |
|---|---|
| Dashboard strip: Deadlift, Shoulder press, Pulldown, Lunge tiles | PASS: animate (Lunge caught in three different poses) |
| Move page from the library: Squat, woman figure, top and bottom positions | PASS |
| Move page: Push-up, man then woman via the Man / Woman control | PASS: switch applies at once, and to the dashboard and workout |
| Workout screen (Train anyway): Deadlift, Shoulder press, Pulldown cards | PASS: animate |
| Backend link cut (adb reverse removed) with the workout open | PASS: cards keep animating |
| CDC fallback: Incline push-up page | PASS: GIF and caption |
| No-media move: Reclining big toe pose | PASS: instructions only |
| Bench press, calf raise, curl, plank on the phone | NOT RUN (bench and calf raise are covered by widget and frame tests; curl and plank have no guide move) |
| Remove-animations setting on the phone | NOT RUN: changing a system setting was not approved; widget test covers it |
| Frame timing on the phone | NOT MEASURED: gfxinfo does not count Flutter frames; the desktop test paints 10,000 frames at under 0.5 ms each |
| Data | set_logs, workout_logs, habit_logs on the throwaway stack 0, 0, 0 after the run. The daily-goal sheet was opened by a mistapped coordinate and closed with Back; nothing toggled |

Seen on the phone, not caused by this work: the daily-goal sheet shows "BOTTOM OVERFLOWED BY 187 PIXELS".

## Limits

- Side view only; moves done with the arms out to the side (bench, press, pulldown) shorten the upper arm to suggest
  depth rather than showing it.
- Same skeleton proportions for both figures.
- 31 guide moves still show CDC GIFs, drawings or the icon.
- Curl and plank are built and tested but appear nowhere until the guide has those moves (an owner decision: adding a
  move changes what plans can prescribe).

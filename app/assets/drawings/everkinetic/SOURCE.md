# Exercise drawings: provenance

- Work: exercise drawings from the Everkinetic open data project, created by Greg Priday (http://everkinetic.com).
- Source: https://github.com/everkinetic/data, folder dist/svg, commit 446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6.
- Licence: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0). Full text in LICENSE, copied
  from the repository's LICENSE.md. https://creativecommons.org/licenses/by-sa/4.0/
- Downloaded: 2026-10-24, with the owner's approval. 30 files, 597,449 bytes, largest 28,820 bytes. Checked: plain
  vector paths, with no scripts, external links or embedded images.
- Changes: none. The files are unmodified. The app scales them for display only.
- Attribution in the app: "Drawings: Everkinetic by Greg Priday, CC BY-SA 4.0" (`drawingCredit`) appears on the
  exercise library, every move page, the session screen, the plan's Sources section and Settings. The dashboard move
  tiles credit the drawings only through that Sources section. The full licence text is on the Licences page
  (Settings > About). A reviewer should confirm that this placement is a reasonable manner of attribution under
  section 3(a) of the licence.

Each exercise has two files, `<number>-relaxation.svg` and `<number>-tension.svg`. The names describe muscle state,
not the order of the movement (for barbell-squat the relaxed drawing is the bottom of the squat), so the app shows
them side by side without start and finish labels. The tiles use the tension drawing.
Levlofit move -> Everkinetic exercise (exact matches only, map in app/lib/exercises.dart `moveDrawings`):

| Levlofit id | Levlofit name | Everkinetic | Number |
|---|---|---|---|
| I4hDWkc | Push-up | push-ups | 0077 |
| EIeI8Vf | Bench press | bench-press | 0042 |
| SpYC0Kp | Dumbbell bench press | bench-press-dumbbell | 0055 |
| 9WTm7dq | Dip | chest-dips | 0054 |
| lBDjFxJ | Pull-up | pull-ups | 0087 |
| fUBheHs | Seated row | seated-cable-rows | 0025 |
| bZGHsAZ | Inverted row | body-row | 0086 |
| qXTaZnJ | Squat (loaded) | barbell-squat | 0122 |
| RRWFUcw | Lunge | barbell-lunges | 0114 |
| IZVHb27 | Lunge | walking-lunges | 0121 |
| aXtJhlg | Step-up | step-ups-with-dumbbells | 0137 |
| wQ2c4XD | Romanian deadlift | romanian-dead-lift | 0118 |
| ila4NZS | Deadlift | barbell-dead-lifts | 0099 |
| u0cNiij | Glute bridge | bridging | 0109 |
| RKjH6Lt | Side bridge | side-plank | 0113 |

These were matched but the repository has no files for them in dist, so the app shows a plain icon instead:
barbell-shoulder-press (0011), dumbbell-shoulder-press (0012) and wide-grip-lat-pull-down (0097). Near matches were
left out on purpose, because they would show a different movement: goblet squat, dumbbell row, dumbbell Romanian
deadlift, bodyweight squat, split squat, incline push-up, floor bench dip, hanging leg raise and calf raise.

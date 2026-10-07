# Exercise media: sources and licences

Style chosen by the owner (2026-09-29): anatomy-style animation, a grey 3D figure with the target muscles in red.
Every media source Levlofit ships must appear here with its licence. No unlicensed or watermarked media.

## ExerciseDB free V1 dataset, by AscendAPI (in use)

- 1,500 exercises, each with a 180p animated GIF, target and secondary muscles, equipment and step-by-step instructions.
- Catalogue imported once into `public.exercises` (see migration `20260929230000_exercises_catalog.sql`); GIFs load from
  `static.exercisedb.dev`, the app never calls the API at runtime (their rate limits are strict).
- Terms (https://oss.exercisedb.dev/docs): allowed for personal, educational and **non-commercial** apps; **not allowed**
  for commercial or monetised products without a paid plan; **credit to AscendAPI is required**.
- Levlofit compliance: the app is free with no ads or payments; every exercise screen credits AscendAPI.
- **Before any subscription, ads or other revenue:** buy a commercial licence (exercisedb.io, about $199 one-time,
  up to 1080p) or replace `gif_url` with Levlofit's own renders. Only the `exercises.gif_url` column changes.

## Rejected

- Real-human clips (YMove, Pexels): owner prefers the anatomy style. Downloads deleted 2026-09-29.
- YMove clips also carried a visible "your move." watermark.
- FitnessProgramer / Gymvisual style GIFs from the old APS project: watermarked, licence unverified.

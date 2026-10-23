# Handbook v4: decision record

Hand-maintained record of the owner's choices on the policy decisions in docs/HANDBOOK_V4_REVIEW.md. A choice here is
not applied to the handbook, the app or the engine until it is confirmed as stated, and it does not clear any evidence or
clinical flag in data/handbook_v4/claims_register.csv. All existing flags stay as they are.

## Decision 1: BMI cut-offs for Indian adults

**Status: PROVISIONAL, PENDING CLINICAL REVIEW** (recorded 2026-10-14 by the owner; not approved; nothing changed yet)

- Provisional proposal: Option B, the ICMR-NIN Dietary Guidelines for Indians 2024 cut-offs: normal 18.5 to 23,
  overweight 23 to 27.5, obesity above 27.5 (kg/m²). Source passage recorded: PDF pages 81-82, "recommended that the BMI
  should be between 18.5 to 23", "Overweight: BMI ranging over 23 to 27.5 ... as per Asian cut-offs", "Obesity: BMI above
  27.5 ... as per the Asian cut-offs".
- Not changed yet: handbook bands (body-measures), the eating-too-little and calorie/fat-loss rules that refer to them,
  supabase/functions/_shared/plan-engine.ts (underweight below 18.0 and the bands), app/lib/tools.dart (bmiBandIndia),
  and their tests. The 9 decision items in 3_policy_decisions.md keep their flags.
- A qualified clinician must confirm, before anything is applied:
  1. the exact thresholds, including the boundary values (for example whether 23.0 and 27.5 fall in the lower or upper band);
  2. that these cut-offs are appropriate for Levlofit's users (adults 18 to 80, Indian context, including older adults
     and very muscular people, for whom BMI misclassifies more often);
  3. the rule that users classified as underweight are not given a fat-loss phase (the app keeps them at maintenance),
     including what the app should say to them and when to refer them to a doctor.
- BMI alone is not a complete assessment of health. It cannot tell muscle from fat or show where fat is stored, and it
  says nothing about fitness, blood tests or medical history. The handbook already pairs it with waist-to-height ratio;
  the clinician should confirm how the two are used together and how this limitation is worded for users.

## Decision 2: Running versus strength (interference)

**Status: PROVISIONAL, PENDING EVIDENCE REVIEW** (recorded 2026-10-14 by the owner; not approved)

- Provisional proposal: Option C, keep the idea but label it as uncertain. Applied to the local v4 draft only:
  - one-step-at-a-time "Wait when" list: "Lots of running may compete with your strength work" (was "would compete");
  - one-step-at-a-time stat: "Possible interference with strength and size gains from frequent, long running sessions;
    the evidence is mixed" (was "More interference on strength and size ...");
  - one-step-at-a-time evidence note: "Some studies suggest that frequent or long endurance sessions may reduce strength,
    size and especially power gains from lifting; the evidence is mixed and the cited review is still being checked."
    Grade changed from strong to **unverified** (Wilson 2012 not read);
  - hyrox evidence note: "Running and lifting can share one plan. Keeping hard runs and leg sessions apart may limit any
    interference with strength; the evidence is mixed." Grade changed from moderate to **unverified** (same unread source);
  - key points in both chapters reworded to "may ... the evidence is mixed".
- Flags kept: each claim stays unreviewed with source_access (Wilson 2012) or source_needed, plus content_decision. The
  review is reset by the rewording; the gates are carried (data/handbook_v4/carry_over.py, REWORDS in the builder).
- Evidence still needed: read Wilson 2012 (library access) and record passages; then confirm or change the wording and
  the grade. No read source currently decides the question (see the correction below).
- HYROX grade (owner, 2026-10-14): stays **unverified** until Wilson 2012 has been obtained and reviewed; "moderate" is not
  restored on the strength of an unread source.
- App (2026-10-14): evidence notes graded unverified now show "NOT YET VERIFIED" with no filled bars
  (app/lib/handbook.dart; regression test in app/test/handbook_blocks_test.dart). Strong, moderate and consensus unchanged.
- Production v3 register correction for the wrong ACSM note: proposed in docs/proposed_v3_register_correction.md, not applied.

## Decision 3: Vegetarian and vegan muscle-building

**Status: PROVISIONAL, PENDING EVIDENCE REVIEW** (recorded 2026-10-14 by the owner; not approved)

- Provisional proposal: Option B, cautious wording. Applied to the local v4 draft only:
  - veg-protein opening line: "Vegetarian and vegan diets can support muscle gain when protein is planned carefully:
    protein-dense foods at every meal and a mix of sources. Direct evidence in vegan diets is limited." (was "You can
    build muscle on a vegetarian or vegan diet. It takes planning: ...");
  - vegan staples: "Peanuts; Levlofit rule, not a research finding: aim for the upper end of your protein range" (was
    "Peanuts; aim for the upper end of your protein range"). Labelled as editorial guidance; the evidence question stays
    open (flag source_needed kept; no source supports a higher target for vegans yet);
  - first key point of the chapter reworded to match the opening line.
- What the read evidence does and does not show: ICMR-NIN Dietary Guidelines for Indians 2024 (PDF p. 75) says vegetarian
  diets combining cereals, pulses, nuts and seeds "can provide all the EAA". That supports planning for protein quality;
  it does not show muscle gain. ISSN 2017 (protein position stand) reports greater hypertrophy with animal than
  protein-matched vegetarian sources and cites a 12-week trial in older men in which fat-free mass rose on a meat diet and
  fell on a lacto-ovo-vegetarian diet. No read source tests vegan muscle gain directly.
- Flags kept: the reworded claims are unreviewed (review reset by the rewording) with content_decision, and the vegan
  staple keeps source_needed. Nothing is verified or approved by the rewording.
- Evidence still needed: a direct source (review or trials of plant versus animal protein, or vegan diets, and muscle
  gain with training); then confirm or change the wording and decide whether the "upper end" rule stays.
- Not changed: plan-engine.ts protein targets and the meal planner (vegetarian and vegan users get the same g/kg targets).

## Decision 4: Caffeine 630 mg example

**Status: PROVISIONAL, PENDING SOURCE AND CLINICAL REVIEW** (recorded 2026-10-14 by the owner; not approved)

- Provisional proposal: Option C, a caution without any numeric daily limit. Applied to the local v4 draft only:
  - the 630 mg (9 mg/kg) bar is **removed** from "Caffeine for a 70 kg person": the bar chart cannot mark one bar as a
    warning, so it could read as a dose to aim for. The chart now shows only 210 mg and 420 mg (3 and 6 mg/kg);
  - the 9 mg/kg warning stays as text: "9 mg per kg of caffeine is a higher-dose example linked to more side effects,
    not a recommended dose; 3 to 6 mg per kg also works, with far fewer";
  - new "Caffeine caution" steps: count your whole day (coffee, tea, colas, energy drinks, pre-workouts); pregnant or on
    hormonal contraception, ask your doctor first (caffeine may clear more slowly); high blood pressure or a heart
    condition, talk to your doctor first; avoid caffeine in the hours before bed;
  - the chapter's caffeine key point reworded to match.
- Evidence read (ISSN 2017 caffeine position stand): slower clearance in pregnancy and with hormonal contraceptives;
  slow metabolisers (a genetic type) showed higher blood-pressure and heart-attack risk with more caffeinated coffee;
  evening caffeine delayed and shortened sleep in one study. Recorded as partly supported (source-checked parts only).
  ISSN sets no general daily safety limit. No source on daily totals has been read (for example EFSA 2015), so **no
  number is given**; "Count your whole day" keeps source_needed.
- Flags: every caution and warning claim carries clinical and content_decision; none is approved or verified by the
  rewording. The removed bar's claim (supplements 630 mg) is listed in REMOVED in the builder, so the gate test knows it
  was removed by this decision rather than lost.
- Not changed: app and engine code (no caffeine logic there).

**Owner decision, 2026-10-18:** remove the 630 mg (9 mg/kg) example entirely until a suitable source and a clinical
justification exist. Applied in data/build_handbook.py (bar and stat removed from v3; v4 inherits), so neither the
pending v3 migration nor the v4 draft contains it. The caution box and the 3 to 6 mg per kg dose stay.

**Owner decisions, 2026-10-18 (other topics):** keep the cautious wording of Decisions 1 to 3 and the frequency
rewording; keep Decision 5 unresolved until the full text is read; remove unsupported scientific claims and label
practical suggestions as Levlofit tips or rules (list in docs/PROGRESS.md, batch 2L).

## Decision 5 (proposed 2026-10-14): Rest between sets and strength

**Status: OPTION B APPLIED TO THE LOCAL V4 DRAFT (owner's go-ahead 2026-10-14), PENDING REVIEW.** App code, the app
timer, the production register, migrations and production are unchanged. Applied with two owner adjustments:
1. The strength comparison reads exactly: "Similar strength outcomes were reported when rests under 1 minute and over 1
   minute were compared in the reviews summarised by ACSM 2026." (used in the b02 stat, the b04 evidence note, and in
   shortened form in the key point and get-stronger). It does not claim all rest durations are equivalent.
2. The b04 evidence note keeps the grade "moderate" only pending reviewer confirmation (flag grade_confirm): ACSM's 63%
   evidence-quality rating is ACSM's, not a justification for Levlofit's grade.
Register (data/handbook_v4/claims_register.csv): every reworded claim is unreviewed; carried flags kept (source_access);
added reviewer_confirm (timer rules, the strength comparison, the evidence note), grade_confirm (evidence note) and
source_needed (muscle-building bar, pending Grgic 2017). No passage was recorded as matched; the reviewer matches the
ACSM passages. Grgic 2018 and Grgic 2017 remain unread.

What ACSM 2026 says (article body, PMC12965823, read in full):
- Summary of strength findings: "strength was not affected in programs with lifting to fatigue/failure ..., time of day
  ( 24 , 102 ), inter-set rest ( 24 , 103 ), ..." Reference 103 is Grgic J et al., Effects of rest interval duration in
  resistance training on measures of muscular strength, Sports Med 2018, the same review the handbook cites (grgic2018).
- Results text: "Strength was not affected by ... short (<1 min) versus long (>1 min) between-set rest intervals".
- Evidence table, inter-set rest: strength "does not impact" (2 reviews; n = 982; quality of evidence 63%);
  hypertrophy "cannot determine" (4 reviews; n = 265; 44%); power: no data.
- Hypertrophy: "There were insufficient data to determine if muscle hypertrophy was influenced by ... inter-set rest".

Assessment:
- Strength: a genuine tension, not a clean contradiction. ACSM's comparison is under 1 minute versus over 1 minute; it
  does not test 2 minutes or more against 1 to 2 minutes. So ACSM does not show that 2+ minutes is useless, but its
  overall summary, which cites Grgic 2018 itself, does not support "2 minutes or more ... maximises strength gains" or
  "rests of 2 minutes or more give the most strength". The handbook wording is stronger than the read evidence.
- Unknown: what Grgic 2018 itself concluded about rests of 2 minutes or more (unread; library access needed). It may
  report nuances (for example by training status) that ACSM's one-line summary does not carry.
- Muscle growth: ACSM says the data are insufficient. Singer 2024 (read, verified) supports only "60 seconds plus may
  give a small edge for muscle growth; the evidence is uncertain". The "Muscle building: over 1 min" bar cites grgic2018,
  a strength review; ACSM cites a different Grgic review for hypertrophy (Grgic 2017, ref 143, unread). Citation mismatch.
- General guidance ("rest long enough to repeat good reps"): consistent with Singer 2024's point that shorter rests force
  lower loads for the same reps; not contradicted by ACSM.

Affected claims (v4 draft):
- rest-between-sets:b01:items[0] "Big lifts for strength · 2 · 2 min or more" (unreviewed; source_access, grgic2018)
- rest-between-sets:b01:items[1] "Muscle building · 1.5 · over 1 min" (unreviewed; source_access, grgic2018; citation mismatch)
- rest-between-sets:b01:items[2] "Light accessory work · 1 · about 1 min" (unreviewed; source_access, grgic2018)
- rest-between-sets:b02:items[0] "2 minutes or more of rest maximises strength gains" (unreviewed; source_access)
- rest-between-sets:b04:text evidence note, graded moderate: "Strength improves with short rests too, but rests of 2
  minutes or more give the most strength in both trained and untrained people." (unreviewed; source_access)
- rest-between-sets:b05:items[0] and [1] (key points), get-stronger:b01:items[1] "2+ min rest between heavy sets helps
  strength" (unreviewed; source_access), get-stronger:b06:items[1] (key point)
- Related app rule, not a handbook claim: app/lib/session.dart restFor() sets the rest timer to 120 s for compound lifts
  and 90 s for others.

Options (none chosen):
- A. Keep the current wording and obtain Grgic 2018 first. Consequence: "maximises" and "give the most strength" stay in
  the draft, unverified and in tension with ACSM's summary until the review is read.
- B. Align with ACSM: say that reviews found similar strength gains with shorter (under 1 minute) and longer (over 1
  minute) rests, keep "rest long enough to repeat good reps", and present 2 minutes or more on heavy lifts as a labelled
  Levlofit rule. Consequence: removes the overstatement; the app's 120 s timer becomes a stated Levlofit rule rather than
  a research claim; Grgic 2018 can still be read later.
- C. Cautious middle: "Longer rests of 2 minutes or more may help strength on heavy lifts; reviews disagree on how much it
  matters." Consequence: keeps the advice with hedged wording; the evidence note's grade would move to unverified (as
  in Decision 2) until Grgic 2018 is read.
- For any option: re-cite or reword "Muscle building: over 1 min" to match what is read (Singer 2024: "60 seconds plus
  may give a small edge ... uncertain"), or mark it for the hypertrophy review (Grgic 2017) to be obtained.
- Not affected by the choice: the app rest timer (an app rule; any change would be a separate, approved app change).

### Option B: wording (applied to the v4 draft 2026-10-14, with the adjustments above)

Principles: strength wording follows what ACSM 2026 (read) reports; the app's timer durations are described as Levlofit
rules, not as proven optimal durations; the muscle-growth claim stays flagged until Grgic 2017 (ACSM ref 143) is read;
no claim is verified unless its passage has been read and matched (ACSM 2026 passages already read: quoted above).

| Claim | Current wording | Proposed wording | Evidence and flags after the change |
|---|---|---|---|
| rest-between-sets:b00:text (lead) | Rest long enough to repeat good reps. Cutting rest short saves minutes but costs quality. | Unchanged | Unchanged (partly supported, Singer 2024) |
| rest-between-sets:b01 (bar chart) title and source | "Rest to aim for", cited to grgic2018 | "Rest to aim for", no source on the chart (the bars below are Levlofit rules or under review) | grgic2018 no longer attached to the chart; it stays in the chapter's source list as unread |
| rest-between-sets:b01:items[0] | Big lifts for strength · 2 · 2 min or more | Big lifts (Levlofit rule) · 2 · about 2 min | Levlofit rule matching the app timer (120 s for the app's compound lifts). Keeps source_access until a reviewer accepts the rule wording |
| rest-between-sets:b01:items[1] (muscle growth) | Muscle building · 1.5 · over 1 min | Muscle building (evidence under review) · 1.5 · over 1 min | Stays flagged: source_access, with the note that the matching review is Grgic 2017 (ACSM ref 143), not grgic2018; plus source_needed until it is read |
| rest-between-sets:b01:items[2] | Light accessory work · 1 · about 1 min | Other exercises (Levlofit rule) · 1.5 · about 90 s | Levlofit rule matching the app timer (90 s for all other exercises; the current "about 1 min" disagrees with the app). Keeps source_access until a reviewer accepts the rule wording |
| rest-between-sets:b02:items[0] | 2 · minutes or more · of rest maximises strength gains | Similar · · strength gains with short (under 1 minute) and long (over 1 minute) rests, in the reviews ACSM 2026 summarised | Can be checked against the ACSM 2026 passages already read ("Strength was not affected by ... short (<1 min) versus long (>1 min) between-set rest intervals"); recorded only after matching, never on Grgic 2018 |
| rest-between-sets:b02:items[1] | 60 · seconds plus · may give a small edge for muscle growth; the evidence is uncertain | Unchanged | Unchanged (verified, Singer 2024) |
| rest-between-sets:b04:text (evidence note, graded moderate, grgic2018) | Strength improves with short rests too, but rests of 2 minutes or more give the most strength in both trained and untrained people. | Reviews summarised by ACSM 2026 found that strength was not affected by rest length when short (under 1 minute) and long (over 1 minute) rests were compared. For muscle growth, the data were insufficient. Rest long enough to repeat good reps. | Re-cited to acsm2026 (read), grade moderate (2 reviews for strength; ACSM rates its evidence quality 63%), to be checked against the passages above; "rest long enough" stays Levlofit guidance |
| rest-between-sets:b05:items[0] (key point) | Rest 2 minutes or more on big lifts for strength. | Levlofit's timer gives about 2 minutes on big lifts and 90 seconds on other exercises; adjust so you can repeat good reps. | summary_check kept |
| rest-between-sets:b05:items[1] (key point) | Over a minute suits muscle building; accessories need about a minute. | Reviews found similar strength gains with short and long rests; for muscle growth the evidence is not settled. | summary_check kept |
| rest-between-sets:b05:items[2] (key point) | Rest long enough to repeat good reps; the timer helps. | Unchanged | Unchanged |
| get-stronger:b01:items[1] | 2+ · min rest · between heavy sets helps strength (grgic2018) | About 2 · min rest · between heavy sets: a Levlofit rule; reviews found similar strength gains with short and long rests | Source removed (rule); source_access kept until a reviewer accepts the rule wording |
| get-stronger:b06:items[1] (key point) | Rest 2 minutes or more between heavy sets. | Rest about 2 minutes between heavy sets (a Levlofit rule). | summary_check kept |

Also to note (no change now):
- app/lib/session.dart: the timer durations (120 s compound lifts, 90 s others) stay as they are. The code comment above
  restFor() says "2 min or more maximises strength on big lifts (Grgic 2018)"; it should later be reworded as a Levlofit
  rule in a separate, approved app change.
- Production v3 register and migration: unchanged; this decision applies to the v4 draft.
- Grgic 2018 and Grgic 2017 stay on the library list; if either is read later, these claims are re-checked.

## Frequency rewording (build-muscle)

**Status: PREFERRED WORDING (owner, 2026-10-14), PENDING REVIEWER CONFIRMATION**

- Preferred wording: "Reaching your weekly sets, split across the week however suits you" (build-muscle "Grows muscle"
  list, claim `build-muscle:b04:do.items[2]`), replacing "Training each muscle twice a week".
- Basis: ACSM 2026 (read): hypertrophy did not differ between 1 and more than 5 days a week when weekly volume was
  equated; at least twice weekly remains ACSM's general advice and stays in How training works and Sets, reps and progress.
- The review flag stays open: the claim keeps `reviewer_confirm` until a reviewer confirms the wording.

## Correction found during decision review (2026-10-14)

While preparing Decision 2, the ACSM 2026 text was re-read. Earlier notes said ACSM 2026 "lists concurrent training
among variables that did not affect strength". That is wrong. The article body says: "There were insufficient data to
determine if strength was affected by ... or concurrent training (i.e., aerobic and RT in the same training session)",
and likewise insufficient data for hypertrophy and power. The incorrect wording appears in:
- the notes of one-step-at-a-time b04/b05 and hyrox b04 in data/evidence/claims_register.csv (production v3 register,
  not changed) and the same claims in data/handbook_v4/claims_register.csv;
- Option B of the running-versus-strength decision in docs/HANDBOOK_V4_REVIEW.md (generated by
  data/handbook_v4/review_package.py).
Corrected 2026-10-14 (owner's go-ahead) in the local v4 material: data/handbook_v4/claims_register.csv notes (via
carry_over.py), docs/HANDBOOK_V4_REVIEW.md Option B (via review_package.py), and this record. Accurate statement: ACSM
2026 reports insufficient data to determine whether aerobic and resistance training performed in the same session affects
strength, muscle growth or power; it does not report "no effect". No claim status depended on the wrong note.

**Pending, separately reviewed change:** the production v3 register, data/evidence/claims_register.csv, still holds the
wrong note on one-step-at-a-time:b04:items[0], one-step-at-a-time:b05:text and hyrox:b04:text. It must be corrected in a
later evidence-register update with its own review; it was deliberately not changed now.

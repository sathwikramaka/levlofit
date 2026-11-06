# Outstanding professional and licensing reviews (2026-11-03)

Nothing below has been reviewed, approved or licensed. This page lists what is missing and who must provide it; it does
not grant anything. Full licensing detail and source checks: `docs/legal/LICENSING_REQUIREMENTS.md`.

## 1. Licensing

| Content | Used where | Current state (evidence) | Needed | Blocks |
|---|---|---|---|---|
| IFCT 2017 food values (ICMR-NIN) | Food library, diary, meal planner, coach food context | Shown in release builds since 2026-10-28 (migration 20261028100000_ifct_release, owner decision 2026-10-27). NIN reuse permission **never requested**; nin.res.in says "All Rights Reserved" and asks for written permission (checked 2026-10-24) | Written permission from NIN (director.nin@icmr.gov.in) with the attribution text, **or** replace with CC0 USDA FDC values plus Levlofit-measured recipes (planner already prefers FDC where it has a match) | Any paid feature or ads; legal risk exists today |
| ExerciseDB V1 GIFs (AscendAPI) | Exercise screens, session moves | On in release builds with the AscendAPI credit (owner decision 2026-10-27). API terms (checked 2026-10-16): personal and non-commercial use allowed; commercial, SaaS or monetised use needs a paid plan. Levlofit has no ads or payments today | Before monetisation: a paid AscendAPI plan covering the use, the v1 dataset licence (terms unread), or Levlofit's own media (own figure animations exist for part of the library) | Subscription, ads, any revenue |
| USDA FoodData Central | Planner foods (FDC codes) | CC0 / public domain, verified 2026-10-24 on fdc.nal.usda.gov; citation requested | Keep the citation | Nothing |

## 2. Dietitian review of nutrition calculations

No qualified dietitian has reviewed Levlofit (owner decision 2026-10-27: none available; the app shows "not medical
advice, not clinician-reviewed"). A review should cover, in `supabase/functions/_shared/plan-engine.ts`:

| Rule | Current setting | Source given in code | Question for the reviewer |
|---|---|---|---|
| Energy | Mifflin-St Jeor BMR x activity factor (higher of training- and lifestyle-based) | Standard multipliers | Activity factors suitable for Indian adults? |
| Goal energy | cut 0.85, bulk 1.10, recomp / maintain 1.0; pace easy / hard moves cut 10-20 %, bulk 5-15 % | Aragon 2017 (no percentages), Helms 2014 | Are the percentages appropriate defaults? |
| Cut floor | never below 1,200 kcal (women) / 1,500 kcal (men) | Levlofit rule | Appropriate floor, and for whom? |
| Protein | actual body weight x 2.0 (cut, recomp), 1.6 (bulk, maintain), 1.4 (general), clamped 1.4-2.0 g/kg | ISSN, Jäger 2017 | **High body weight:** actual vs adjusted or goal weight; a cap? (the main open question; no cut-off added without review) |
| Soya chunks | at most 50 g dry a day, as a variety cap | Meta-analyses show no male hormone effect | Cap reasonable? |
| Cooking oil | about 27 g per 2,000 kcal | ICMR-NIN DGI 2024 | OK |
| Conditions | pregnancy -> pregnancy rule; kidney disease removes creatine and adds a see-your-doctor note; diabetes, PCOS, thyroid, blood pressure, cholesterol, IBS change nothing in the numbers | Levlofit rule | Which conditions should change targets, and how, or only refer? |
| Supplements | creatine and protein powder advice | ISSN position stands | Wording and contraindications |
| Age | adults 18-80 only | Curriculum and ISSN cover adults | OK |

Status: **not started**. Until it is done, no screen, store listing or website text may call the nutrition targets
clinically validated or dietitian-approved.

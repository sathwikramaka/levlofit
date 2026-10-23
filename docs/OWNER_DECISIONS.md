# Owner decisions (updated 2026-10-18)

## Decided by the owner on 2026-10-18

| # | Topic | Decision | What changed locally |
|---|---|---|---|
| 1 | Rest-day add-on workouts and the streak | Keep the existing behaviour: a logged rest-day add-on counts toward the training streak and days ring. No reminder for add-on-only days for now. | Nothing (app/lib/dashboard.dart already counts any logged day) |
| 2 | Reminder timing | Keep the current mode (exact when Android allows, else inexact). No alarm-clock mode now. | Nothing (the test-build alarm-clock experiment stays out of release builds) |
| 3 | Health Connect steps | Disabled in the normal store build for the initial launch. No health permission requests or distribution build with it without a later approval. | Nothing (default build already has no health permission) |
| 4 | AI provider | Not selected yet; no real user data sent; no credentials or live benchmark until chosen. | docs/AI_PROVIDER_COMPARISON.md prepared |
| 5 | Rate limits | Keep 30 coach messages an hour, 150 a day, 20 plan generations a day, 5 feedback a day; provisional until usage data supports revisiting. | Comment in supabase/functions/_shared/rate.ts records this |
| 6 | Monetisation | Free initial launch; no commercial licence bought or accepted. | Nothing |
| 7 | Handbook BMI, running/strength, vegetarian and vegan muscle-building, training frequency | Keep the cautious wording. | Nothing (draft already cautious) |
| 8 | 630 mg caffeine example | Remove unless a source and clinical justification are established. | Removed from v3 (bar and 9 mg/kg stat) and therefore v4 |
| 9 | Rest between sets (Decision 5) | Keep the claim unresolved until the full text is reviewed. | Nothing (stays flagged) |
| 10 | Unsupported claims | Remove unsupported scientific claims; label genuine practical suggestions as Levlofit tips. | See PROGRESS batch 2L for the item list |

Clinical policy and nutrition targets are unchanged and wait for professional review.

## Still waiting for the owner

- **AI provider choice**: docs/AI_PROVIDER_COMPARISON.md now recommends Groq gpt-oss-120b with Zero Data Retention,
  subject to a plan whose token limits fit (the published Developer plan allows 8,000 tokens a minute); not chosen.
  After choosing, you accept its terms and create the key yourself.
- **Write to NIN for IFCT 2017 reuse permission** (docs/SOURCE_LICENCE_REGISTER.md): no open licence was found for
  the food values, even for a free app. Levlofit cannot send this for you.
- **Later approvals**: enabling Health Connect in a distributed build; any commercial licence; alarm-clock mode if revisited.
- **Release go-aheads, one each**: production backup window, then the 8 production migrations, then function deploys;
  Git remote and CI; store signing key; website hosting.

## External requirements (not owner product choices)

- Clinical, from evidence round 8 (docs/handbook_v4_review/ROUND8_REVIEW.md): the caffeine example of 6 mg/kg
  (420 mg for 70 kg) is above EFSA's single-dose safety level of about 3 mg/kg (200 mg); the waist-to-height 0.6
  'high risk' edge has no readable source (the 2025 Indian definition uses >0.5 only); the Indian BMI basis has a 2025
  staged revision; pregnancy stop signs list headache, which Mottola 2018 does not.
- Clinical: 117 handbook items, BMI and waist-to-height cut-offs, nutrient targets, the relabelled tips and rules
  (reviewer confirms each label replaces its source requirement), Decision 5 full text.
- Coach and dietitian: engine rules, injury table, diet rules.
- Legal: privacy policy, delete-account page, provider naming in privacy texts, Health Connect text (when enabled),
  DPDP cross-border question for the chosen provider.
- Licences (before any paid feature): ExerciseDB media, wger entries, NIN permission for IFCT reuse, INDB.
- iOS HealthKit: **deferred by the owner on 2026-10-22** (no Apple device); outside the current release and its completion criteria.

## AI provider (open, 2026-10-22)
Groq not chosen yet. Run the prepared benchmark (AI_PROVIDER_COMPARISON.md) with your own keys on synthetic data, read the replies, then decide. Check Groq Data Controls for Zero Data Retention first.

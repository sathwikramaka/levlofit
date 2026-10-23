# Evidence review round 8 (2026-10-18): the owner's priority topics

Reviewer: Claude (AI). **This is not a clinical or professional review.** Nothing here approves a claim; every
`clinical` gate stays. Passages are exact text, machine-matched in the downloaded source (round 8:
data/handbook_v4/audit_round8.py; Step 1: data/handbook_v4/step1_candidate_passages.csv, checked by check_step1.py).
Status words: supported, partially supported, unsupported, outdated, not verifiable from accessible evidence.

Scope: BMI and waist-to-height, rest and recovery, caffeine, hydration and heat, pregnancy, eating too little, and the
women chapter. Other chapters keep their round 5 to 7 records. Coverage is not complete: claims outside these topics
were not re-reviewed this round.

## Sources read this round

| Key | Source | Access |
|---|---|---|
| misra2025 (new) | Misra A, Vikram NK, Ghosh A, et al. Revised definition of obesity in Asian Indians living in India. Diabetes Metab Syndr 2025;19:102989. https://doi.org/10.1016/j.dsx.2024.102989 | Full article PDF read |
| acsm2026 | ACSM 2026 resistance training position stand. https://doi.org/10.1249/MSS.0000000000003897 (PMC12965823) | Open full text read |
| issncaffeine | ISSN position stand: caffeine and exercise performance (2021). https://doi.org/10.1186/s12970-020-00383-4 (PMC7777221) | Open full text read |
| nice2022 | NICE guidance on waist-to-height ratio | **Not verifiable**: nice.org.uk returns 403 to automated access again (also NG246) |
| misra2009 | Misra 2009 consensus (J Assoc Physicians India 57:163) | **Not read**: no open full text; PubMed page needs cookies. Superseded in part by misra2025 |

## Findings

| Claim | Status | Source and exact passage | Limitations | Recommended action |
|---|---|---|---|---|
| Waist-to-height under 0.5 healthy, 0.5 boundary (body-measures:b02:ranges[0], [1]) | **Partially supported** (register updated) | misra2025: "W-HtR cutoff level: >0.5" | Indian 2025 definition; uses WC or W-HtR with a mandatory BMI over 23 for stage 2 obesity; the 0.3 lower display edge and the 0.6 edge are not from it | Keep the 0.5 boundary; clinician confirms |
| Waist-to-height 0.6 to 0.8 "High risk" (ranges[2]) | **Partially supported / 0.6 not verifiable** | misra2025: "with the lowest all-cause mortality risk at 0.5 and a sharp linear increase after that" | No 0.6 threshold in the source; NICE (which uses 0.6) unreadable | Reword to "Higher risk (rises with the ratio)" without a 0.6 edge, or obtain NICE text; clinician decides |
| BMI cut-offs for Asian Indians (body-measures; app bmiBandIndia, plan engine) | **Partially supported; basis outdated** | misra2025: "The prevailing guidelines for obesity in Asian Indians, published in 2009, relied solely on body mass index (BMI) criteria." It keeps "BMI>23 kg/m2" but defines obesity in stages using waist measures and function | The handbook and app still cite Misra 2009 alone | Cite misra2025 alongside 2009; clinician decides whether the app's BMI bands need the staged definition. **No app change made** (clinical policy) |
| Rest: strength similar with rests under or over 1 minute (rest-between-sets:b02:items[0], b04:text) | **Supported for strength** (note recorded; status unchanged under Decision 5) | acsm2026: "short (<1 min) versus long (>1 min) between-set rest intervals" (among factors that did not affect strength) | Strength only; ACSM gives no hypertrophy finding on rest | Owner's Decision 5 keeps rest unresolved until Grgic 2017 is read |
| Caffeine 3 to 6 mg/kg about 60 minutes before (supplements:b01:rows[1], b02:items[2]) | **Supported for performance; conflicts with EFSA safety level** | issncaffeine: "Caffeine has consistently been shown to improve exercise performance when consumed in doses of 3–6 mg/kg body mass." and "The most commonly used timing of caffeine supplementation is 60 min pre-exercise." Step 1 (EFSA topic page): "Single doses of caffeine up to 200mg – about 3mg per kilogram of body weight (mg/kg bw) from all sources do not ..." | The handbook's chart shows 420 mg for 70 kg (6 mg/kg), above EFSA's single-dose level of about 3 mg/kg (200 mg) and above its 400 mg daily level in one dose | **Flag for clinician**: consider capping the example at 3 mg/kg (about 200 mg) or stating EFSA's single-dose level next to the ISSN range. Not changed (clinical policy) |
| Caffeine 9 mg/kg | Removed 2026-10-18 (owner) | issncaffeine: "9 mg/kg) are associated with a high incidence of side-effects and do not seem to be required to elicit an ergogenic effect." | — | Removal is consistent with the source |
| Pregnancy: stay active, 150 min, talk test, stop signs (women:b01:dont.items[2], b02:items[1], b05) | Supported / partly (Step 1, unchanged) | mottola2018 (full text read in Step 1): "All women without contraindication should be physically active throughout pregnancy." and "Pregnant women should accumulate at least 150 min of moderate-intensity physical activity each week" | Headache is not in Mottola's stop list; "fluid leaking" should read persistent fluid loss | Clinician: remove "headache" or source it; say "persistent" fluid loss |
| Heat illness signs and urgent help (water:b06) | Supported (Step 1, NHS page) | nhs_heat: "tiredness dizziness headache feeling sick (nausea) or being sick (vomiting)" and "Heatstroke is a medical emergency." | NHS page is UK guidance | Clinician confirms; add NHS as the cited source |
| Salt in long hot sessions (water:b05:text) | Supported (Step 1) | racinais2015: "Athletes training in the heat have higher daily sodium (ie, salt) requirements than the general population." | "lassi or chaas" is a Levlofit food example | Keep, cite racinais2015; clinician confirms |
| Dark urine (water:b04:dont.items[0]) | **Supported** (added 2026-10-22; register: needs_clinical_review) | nhs_dehydration (https://www.nhs.uk/conditions/dehydration/, last reviewed 01 May 2026): "dark yellow, strong-smelling pee"; "peeing less often than usual" | General adult guidance, not exercise-specific | Clinician confirms; cite NHS |
| Headache or dizziness after training (water:b04:dont.items[1]) | **Partially supported** (added 2026-10-22) | nhs_dehydration: "headache and feeling light-headed" | Not tied to training | Clinician confirms wording |
| Sweat-loss rule: under 1.4 kg for 70 kg (water:b03:items[3]) | **Not verifiable** from read sources | — | ACSM 2007 fluid stand only abstract-read (it states the >2% figure the rule derives from) | Clinician: keep as arithmetic of the 2% figure, or label as a Levlofit tip |
| Eating too little: warning signs (under-eating:b02) | Supported / partly (Step 1, Mountjoy 2023 REDs) | mountjoy2023: "amenorrhoea, depression, hunger, low libido, performance and training plateaus or declines" | REDs is about athletes | Clinician confirms; cite mountjoy2023 |
| Women key point "lifting builds strength and shape" | **Unsupported** (same text removed from the chapter body by owner decision) | — | — | **Changed in the v4 draft** to "Women build muscle much as men do: similar percentage gains from the same training.", matching the verified Refalo 2025 opening ("relative increases in muscle size were similar between sexes"); still unreviewed as a key point |
| Sleep 7 hours or more for adults 18 to 60 (sleep-recovery key point) | Supported (aasm2015 statement read 2026-10-13) | Recorded earlier on the PMC page | Key points stay unreviewed by policy | Reviewer confirms |

## Not done this round (honest coverage)

- Claims outside the topics above were not re-reviewed; their round 5 to 7 records stand.
- Paywalled or blocked: NICE 2022/NG246 (403), Misra 2009 (no open full text), ACSM 2007 fluid stand (abstract
  only), EFSA 2015 caffeine opinion (403), Grgic 2017 and 2018 (not open).
- No claim was marked clinically approved. Nutrition targets and clinical policy are unchanged.

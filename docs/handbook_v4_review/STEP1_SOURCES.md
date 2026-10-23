# Step 1: safety-topic sources (low energy availability, pregnancy, eating disorders, hydration, heat, caffeine)

Date: 2026-10-14. Local review record only. **No handbook wording, register flag, grade or decision was changed.**
Every passage below and in `data/handbook_v4/step1_candidate_passages.csv` was copied from the downloaded text
and machine-checked to occur in it (`python -I data/handbook_v4/check_step1.py <sources dir>`; the check also
fails if a claim's wording has changed since this record). "supports" / "partly" is a candidate match for the
clinical reviewer, **not** a verification: every row here keeps its existing `clinical` / `source_needed` gates.

## Sources

| Key (candidate) | Source | Access | Result |
|---|---|---|---|
| mottola2018 (in register) | Mottola MF et al. 2019 Canadian guideline for physical activity throughout pregnancy. Br J Sports Med 2018;52:1339. doi:10.1136/bjsports-2018-100056. https://bjsm.bmj.com/content/52/21/1339 | Full text read (BJSM page). Licence not confirmed | **Verified** for 150 min, talk test, stop signs, contraindications |
| mountjoy2023 (new) | Mountjoy M et al. 2023 IOC consensus statement on REDs. Br J Sports Med 2023;57:1073. doi:10.1136/bjsports-2023-106994. https://bjsm.bmj.com/content/57/17/1073 | Full text read (BJSM page). Licence not confirmed | **Verified** for REDs definition, symptoms, ED/DE behaviours |
| racinais2015 (new) | Racinais S et al. Consensus recommendations on training and competing in the heat. Br J Sports Med 2015;49:1164. doi:10.1136/bjsports-2015-094915. PMC4602249 | Full text (PMC XML), CC BY-NC 4.0 | **Verified** for 2% (qualified), pre-hydration, sodium, <1% daily mass change, overdrinking risk |
| who_heat (new) | WHO fact sheet "Climate change, heat and health", 31 July 2026. https://www.who.int/news-room/fact-sheets/detail/climate-change-heat-and-health | Full page | **Verified** for avoiding the hottest hours, heatstroke = emergency. No symptom list in page text |
| nhs_heat (new) | NHS "Heat exhaustion and heatstroke", reviewed 28 May 2026. https://www.nhs.uk/conditions/heat-exhaustion-heatstroke/ | Full page, Crown copyright | **Verified** for heat-exhaustion and heatstroke signs, emergency action. UK service numbers (111/999) do not apply in India |
| efsa_caffeine_topic (new) | EFSA topic page "Caffeine" (EFSA's own summary of its 2015 opinion). https://www.efsa.europa.eu/en/topics/topic/caffeine | Full page | **Partly**: official summary by the authoring body, not the opinion itself. Usable for reviewer orientation; full opinion still needed for verification |

### Unavailable

| Source | Attempt | Status |
|---|---|---|
| EFSA 2015 Scientific Opinion on the safety of caffeine (doi:10.2903/j.efsa.2015.4102) | curl 403; built-in browser hit a bot challenge (not bypassed) | **Unavailable**. Owner can download the PDF manually |
| EFSA 2010 water DRV opinion (`efsa2010`) | curl 403; EFSA DRV page has no values | **Unavailable**; water 2.5 / 2.0 L remain `source_access` |
| NICE NG69 Eating disorders | curl 403; built-in browser 403 | **Unavailable**; no general eating-disorder care source retrieved |
| ACOG Committee Opinion 804 | landing page summary only | **Not read**; not used |

## Claim matches (see CSV for every quote)

**Pregnancy (Mottola 2018)**
- `women:b02:items[1]` 150 min: supports (recommendation 2). `women:b06:text`: partly (WHO wording not re-checked).
- `women:b01:dont.items[2]` safe in most pregnancies: supports ("All women without contraindication should be physically active throughout pregnancy").
- `women:b05:do.items[2]` talk test: supports.
- `women:b05:dont.items[0]` bleeding or fluid leaking: supports (source says *persistent* fluid loss).
- `women:b05:dont.items[1]` dizziness, chest pain or headache: partly. **Headache is not in Mottola box 2.**
- `women:b08:items[2]`: partly; after-birth advice not covered.

**Low energy availability / eating disorders (Mountjoy 2023)**
- `under-eating:b02:dont.items[0]` periods: supports (amenorrhoea).
- `under-eating:b02:dont.items[2]` restricting, bingeing, purging, compensatory exercise: supports.
- `under-eating:b02:dont.items[3]`, `do.items[1]`, `do.items[2]`, `b00`, `b04`: partly (Levlofit thresholds and general-population wording are not in the source; REDs is defined for athletes).
- `under-eating:b06:items[2]`: **fainting not found** in Mountjoy 2023.
- `under-eating:b05:text` (eating disorders need specialist care): **no general source** (NICE unavailable).

**Hydration (Racinais 2015)**
- `water:b02:items[0]`, `water:b07:items[0]` 2%: partly. Source limits it to aerobic exercise in warm-hot conditions and reports studies with no effect up to 4%.
- `water:b00:text`, `water:b06:do.items[2]`: partly. `water:b05:text` salt: supports (lassi/chaas are Levlofit examples).
- `water:b04:do.items[1]` weight back by next morning: partly (<1% daily body-mass change).
- **Not supported**: `water:b04:dont.items[0]` urine colour; `water:b01:items[0..1]` 2.5 / 2.0 L (EFSA unavailable); `water:b03:items[3]` is arithmetic on the 2% figure.
- **Gap**: Racinais notes overdrinking / hyponatraemia risk; the handbook has no caution. Content decision for the owner and reviewer.

**Heat (WHO, NHS)**
- `water:b06:do.items[0]` cooler hours: supports (WHO).
- `water:b06:dont.items[0]` and `[1]` symptoms: supports (NHS heat exhaustion and heatstroke lists).
- `water:b06:dont.items[2]` get help if not easing quickly: partly. NHS says heatstroke is an emergency at once, and heat exhaustion is one if not better after 30 minutes of cooling. The handbook's "quickly" is vaguer.
- `water:b06:do.items[1]` slow down: partly ("avoid extreme exercise"; humidity not covered).

**Caffeine (EFSA summary page only)**
- `supplements:b04:items[3]`, `supplements:b06:dont.items[0]` sleep: supports at summary level.
- `supplements:b04:items[0]` whole-day count, `[1]` pregnancy: partly (hormonal contraception not mentioned). `[2]` blood pressure: **not found**.
- **Conflict to review**: the 6 mg/kg bar (`supplements:b03:items[1]`, 420 mg at 70 kg) and `supplements:b02:items[2]` exceed EFSA's 200 mg single-dose and 400 mg/day levels for healthy adults. Decision 4 removed the 630 mg bar but kept the ISSN 3 to 6 mg/kg range; whether to add a whole-day ceiling is a clinical decision.

## Needs a qualified clinical reviewer (all rows above, priority order)

1. Caffeine 6 mg/kg vs EFSA 200 mg single / 400 mg daily (and pregnancy 200 mg/day).
2. Heat-illness emergency threshold wording (`water:b06:dont.items[2]`) and India-appropriate emergency number (112 / 108).
3. Eating-disorder referral wording (`under-eating:b05`, `b02:dont`, `b03:items[1]`); needs NICE NG69 or an Indian equivalent.
4. Pregnancy stop signs: headache not in Mottola; consider adding box 2 items not in the handbook (painful contractions, persistent breathlessness).
5. 2% dehydration threshold qualifier and missing overdrinking caution.
6. Unsupported: urine colour, fainting in under-eating, water 2.5 / 2.0 L, Tele-MANAS number (not re-checked).

## Next highest-priority claims to review (outside Step 1)

- Tele-MANAS 14416 (`under-eating:b03:items[1]`): re-check on the official MoHFW page.
- `safety-first` stop-signs list and the pain 0-10 scale (uncited, clinical).
- Calorie floor and BMI-based maintenance rules (`under-eating:b01`, Decision 1 still provisional).
- Creatine 3 to 5 g (`supplements:b01:rows[0]`, `b07:items[0]`) uncited_number.
- Obtain manually: EFSA 2015 caffeine PDF, EFSA 2010 water PDF, NICE NG69, ACOG 804.

## Addendum (2026-10-15): waist-to-height (workstream 10)

| Key (candidate) | Source | Access | Result |
|---|---|---|---|
| ashwell2016 (new) | Ashwell M, Gibson S. Waist-to-height ratio as an indicator of 'early health risk'. BMJ Open 2016;6:e010159. PMC4800150 | Full text (PMC XML), CC BY-NC 4.0 | **Candidate** for `body-measures:b02:ranges[0..2]` (0.5 and 0.6 boundaries). UK adults only; Indian validity not shown. Register gates unchanged |

Passage (verbatim): "‘no increased risk’ (WHtR <0.5), ‘increased risk’ (WHtR ≥0.5 and <0.6) and ‘very high risk’ (WHtR ≥0.6)".
NICE 2022 (`nice2022`, current register source) remains unavailable (403).

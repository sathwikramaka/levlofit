"""Builds the Handbook migration from the chapter content below.

Every number here is checked against the source named next to it (web-verified 2026-09-29).
The curriculum PDF in Refrence/ is used as a reference for structure only, never as a source.

Content is a list of visual blocks, rendered natively by app/lib/handbook.dart. Rule: at least
60% of blocks in every chapter are true visuals (see VISUAL), so the Handbook teaches
by showing. The build fails if a chapter breaks that rule or cites a source it does not list.

Run: python data/build_handbook.py  -> supabase/migrations/20261007400000_handbook_v3.sql
"""
import json
from pathlib import Path

# ---- sources (full references, cited by key) --------------------------------------------------
SRC = {
    "who2020": "Bull FC et al. World Health Organization 2020 guidelines on physical activity and sedentary behaviour. Br J Sports Med 2020;54:1451-1462.",
    "acsm2026": "Currier BS, D'Souza AC, Fiatarone Singh MA et al. American College of Sports Medicine position stand: Resistance training prescription for muscle function, hypertrophy, and physical performance in healthy adults: an overview of reviews. Med Sci Sports Exerc 2026.",
    "riebe2015": "Riebe D et al. Updating ACSM's recommendations for exercise preparticipation health screening. Med Sci Sports Exerc 2015;47(11):2473-2479.",
    "zourdos2016": "Zourdos MC et al. Novel resistance training-specific rating of perceived exertion scale measuring repetitions in reserve. J Strength Cond Res 2016;30(1):267-275.",
    "behm2016": "Behm DG et al. Acute effects of muscle stretching on physical performance, range of motion, and injury incidence in healthy active individuals: a systematic review. Appl Physiol Nutr Metab 2016;41(1):1-11.",
    "warneke2024": "Warneke K et al. Revisiting the stretch-induced force deficit: a systematic review with multilevel meta-analysis of acute effects. J Sport Health Sci 2024.",
    "bell2023": "Bell L et al. Integrating deloading into strength and physique sports training programmes: an international Delphi consensus approach. Sports Med Open 2023;9:87.",
    "icmr2024": "ICMR-National Institute of Nutrition. Dietary Guidelines for Indians, 2024.",
    "icmr2020": "ICMR-National Institute of Nutrition. Nutrient Requirements for Indians (RDA and EAR), 2020.",
    "issnprotein": "Jager R et al. International Society of Sports Nutrition position stand: protein and exercise. J Int Soc Sports Nutr 2017;14:20.",
    "acsmfluid": "Sawka MN et al. American College of Sports Medicine position stand: exercise and fluid replacement. Med Sci Sports Exerc 2007;39(2):377-390.",
    "soy2021": "Reed KE et al. Neither soy nor isoflavone intake affects male reproductive hormones: an expanded and updated meta-analysis of clinical studies. Reprod Toxicol 2021;100:60-67.",
    "ifct2017": "Longvah T et al. Indian Food Composition Tables 2017. ICMR-National Institute of Nutrition, Hyderabad.",
    "misra2009": "Misra A et al. Consensus statement for diagnosis of obesity, abdominal obesity and the metabolic syndrome for Asian Indians. J Assoc Physicians India 2009;57:163-170.",
    "nice2022": "National Institute for Health and Care Excellence. Obesity: identification, assessment and management (waist-to-height ratio update), 2022.",
    "aasm2015": "Watson NF et al. Recommended amount of sleep for a healthy adult: a joint consensus statement of the AASM and SRS. J Clin Sleep Med 2015;11(6):591-592.",
    "issncreatine": "Kreider RB et al. International Society of Sports Nutrition position stand: safety and efficacy of creatine supplementation in exercise, sport, and medicine. J Int Soc Sports Nutr 2017;14:18.",
    "issncaffeine": "Guest NS et al. International Society of Sports Nutrition position stand: caffeine and exercise performance. J Int Soc Sports Nutr 2021;18:1.",
    "grgic2018": "Grgic J, Schoenfeld BJ, Skrepnik M, Davies TB, Mikulic P. Effects of rest interval duration in resistance training on measures of muscular strength: a systematic review. Sports Med 2018;48(1):137-151.",
    "singer2024": "Singer A et al. Give it a rest: a systematic review with Bayesian meta-analysis on the effect of inter-set rest interval duration on muscle hypertrophy. Front Sports Act Living 2024;6:1429789.",
    "paluch2022": "Paluch AE et al. Daily steps and all-cause mortality: a meta-analysis of 15 international cohorts. Lancet Public Health 2022;7(3):e219-e228.",
    "wilson2012": "Wilson JM et al. Concurrent training: a meta-analysis examining interference of aerobic and resistance exercises. J Strength Cond Res 2012;26(8):2293-2307.",
    "lally2010": "Lally P, van Jaarsveld CHM, Potts HWW, Wardle J. How are habits formed: modelling habit formation in the real world. Eur J Soc Psychol 2010;40(6):998-1009.",
    "efsa2010": "EFSA Panel on Dietetic Products, Nutrition and Allergies. Scientific opinion on dietary reference values for water. EFSA Journal 2010;8(3):1459.",
    "zheng2015": "Zheng Y et al. Self-weighing in weight management: a systematic literature review. Obesity 2015;23(2):256-265.",
    "usda174275": "U.S. Department of Agriculture, Agricultural Research Service. FoodData Central: Soy flour, defatted (FDC ID 174275, SR Legacy 16117).",
    "mifflin1990": "Mifflin MD, St Jeor ST et al. A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr 1990;51(2):241-247.",
    "aragon2017": "Aragon AA et al. International Society of Sports Nutrition position stand: diets and body composition. J Int Soc Sports Nutr 2017;14:16.",
    "helms2014": "Helms ER, Aragon AA, Fitschen PJ. Evidence-based recommendations for natural bodybuilding contest preparation: nutrition and supplementation. J Int Soc Sports Nutr 2014;11:20.",
    "iraki2019": "Iraki J, Fitschen P, Espinar S, Helms E. Nutrition recommendations for bodybuilders in the off-season: a narrative review. Sports 2019;7(7):154.",
    "morton2018": "Morton RW et al. A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength in healthy adults. Br J Sports Med 2018;52(6):376-384.",
    "whocarb2023": "World Health Organization. Carbohydrate intake for adults and children: WHO guideline. Geneva: WHO, 2023.",
    "whofat2023": "World Health Organization. Saturated fatty acid and trans-fatty acid intake for adults and children: WHO guideline. Geneva: WHO, 2023.",
    "kerksick2017": "Kerksick CM et al. International Society of Sports Nutrition position stand: nutrient timing. J Int Soc Sports Nutr 2017;14:33.",
    "schoenfeld2017v": "Schoenfeld BJ, Ogborn D, Krieger JW. Dose-response relationship between weekly resistance training volume and increases in muscle mass: a systematic review and meta-analysis. J Sports Sci 2017;35(11):1073-1082.",
    "schoenfeld2017l": "Schoenfeld BJ, Grgic J, Ogborn D, Krieger JW. Strength and hypertrophy adaptations between low- vs. high-load resistance training: a systematic review and meta-analysis. J Strength Cond Res 2017;31(12):3508-3523.",
    "kotarsky2018": "Kotarsky CJ et al. Effect of progressive calisthenic push-up training on muscle strength and thickness. J Strength Cond Res 2018;32(3):651-659.",
    "seiler2010": "Seiler S. What is best practice for training intensity and duration distribution in endurance athletes? Int J Sports Physiol Perform 2010;5(3):276-291.",
    "nielsen2014": "Nielsen RO et al. Excessive progression in weekly running distance and risk of running-related injuries: an association which varies according to type of injury. J Orthop Sports Phys Ther 2014;44(10):739-747.",
    "hyrox": "HYROX. The Fitness Race: race format and workout stations (official website). hyrox.com/the-fitness-race, accessed 2026-10-13.",
    "afonso2021": "Afonso J et al. Strength training versus stretching for improving range of motion: a systematic review and meta-analysis. Healthcare 2021;9(4):427.",
    "meigh2019": "Meigh NJ et al. Kettlebell training in clinical practice: a scoping review. BMC Sports Sci Med Rehabil 2019;11:19.",
    "lake2012": "Lake JP, Lauder MA. Kettlebell swing training improves maximal and explosive strength. J Strength Cond Res 2012;26(8):2228-2233.",
    "mandsager2018": "Mandsager K et al. Association of cardiorespiratory fitness with long-term mortality among adults undergoing exercise treadmill testing. JAMA Netw Open 2018;1(6):e183605.",
    "lauersen2014": "Lauersen JB, Bertelsen DM, Andersen LB. The effectiveness of exercise interventions to prevent sports injuries: a systematic review and meta-analysis of randomised controlled trials. Br J Sports Med 2014;48(11):871-877.",
    "bickel2011": "Bickel CS, Cross JM, Bamman MM. Exercise dosing to retain resistance training adaptations in young and older adults. Med Sci Sports Exerc 2011;43(7):1177-1187.",
    "lopes2019": "Lopes JSS et al. Effects of training with elastic resistance versus conventional resistance on muscular strength: a systematic review and meta-analysis. SAGE Open Med 2019;7:2050312119831116.",
    "mcnulty2020": "McNulty KL et al. The effects of menstrual cycle phase on exercise performance in eumenorrheic women: a systematic review and meta-analysis. Sports Med 2020;50(10):1813-1827.",
    "mottola2018": "Mottola MF et al. 2019 Canadian guideline for physical activity throughout pregnancy. Br J Sports Med 2018;52(21):1339-1346.",
    "telemanas2024": "Press Information Bureau, Government of India. Tele MANAS: Revolutionizing Mental Health Care in India. October 2024. static.pib.gov.in/WriteReadData/specificdocs/documents/2024/oct/doc20241013415701.pdf",
    "noetel2024": "Noetel M et al. Effect of exercise for depression: systematic review and network meta-analysis of randomised controlled trials. BMJ 2024;384:e075847.",
    # Evidence round 6 (2026-10-16): open-access full texts that support existing claims. Listed here so both
    # registers can record them; cited in chapters only by the v4 draft, so this production Handbook is unchanged.
    "refalo2025": "Refalo MC et al. Sex differences in absolute and relative changes in muscle size following resistance training in healthy adults: a systematic review with Bayesian meta-analysis. PeerJ 2025;13:e19042.",
    "manore2017": "Manore MM et al. Dynamic energy balance: an integrated framework for discussing diet and physical activity in obesity prevention. Is it more than eating less and exercising more? Nutrients 2017;9(8):905.",
    "wilson2025": "Wilson CJ et al. The effect of muscle warm-up on voluntary and evoked force-time parameters: a systematic review and meta-analysis with meta-regression. J Sport Health Sci 2025;14:101024.",
    "cunha2023": "Cunha LA et al. The impact of sleep interventions on athletic performance: a systematic review. Sports Med Open 2023;9(1):58.",
    "zhang2020": "Zhang M et al. Effects of high-fiber diets and macronutrient substitution on bloating: findings from the OmniHeart trial. Clin Transl Gastroenterol 2020;11(1):e00122.",
    "konrad2024": "Konrad A et al. Chronic effects of stretching on range of motion with consideration of potential moderating variables: a systematic review with meta-analysis. J Sport Health Sci 2024;13(2):186-194.",
    "nhs_dehydration": "NHS. Dehydration (health A to Z). Page last reviewed 1 May 2026. https://www.nhs.uk/conditions/dehydration/",
    "misra2025": "Misra A, Vikram NK, Ghosh A, et al. Revised definition of obesity in Asian Indians living in India. Diabetes Metab Syndr 2025;19:102989. doi:10.1016/j.dsx.2024.102989.",
    "singh2024": "Singh B et al. Time to form a habit: a systematic review and meta-analysis of health behaviour habit formation and its determinants. Healthcare (Basel) 2024;12(23):2488.",
    "coetsee2015": "Coetsee C, Terblanche E. The time course of changes induced by resistance training and detraining on muscular and physical function in older adults. Eur Rev Aging Phys Act 2015;12:7.",
}

PARTS = {"A": "Foundations", "B": "Getting better", "C": "Food and body", "D": "Train for your goal", "E": "Staying with it"}

# Blocks that teach by showing. Lead lines, rules and evidence notes are prose, so they do not count.
VISUAL = {"stats", "steps", "compare", "bars", "scale", "week", "plate", "cycle", "table", "flow", "band"}


def lead(t): return {"t": "lead", "text": t}
def text(t): return {"t": "text", "text": t}
def rule(t): return {"t": "rule", "text": t}
# Evidence grade, shown on every evidence note (idea kept from the owner's earlier APS handbook):
# strong = consistent meta-analyses or position stands; moderate = good reviews, some uncertainty;
# consensus = expert agreement without strong trial data.
GRADES = {"strong", "moderate", "consensus"}
def evidence(t, src, grade): return {"t": "evidence", "text": t, "source": src, "grade": grade}
def stats(items): return {"t": "stats", "items": [dict(zip(("value", "unit", "label", "source"), i)) for i in items]}
def steps(title, items): return {"t": "steps", "title": title, "items": [{"title": a, "text": b} for a, b in items]}
def compare(do_title, do, dont_title, dont): return {"t": "compare", "do": {"title": do_title, "items": do}, "dont": {"title": dont_title, "items": dont}}
def bars(title, unit, items, source): return {"t": "bars", "title": title, "unit": unit, "items": [{"label": a, "value": b, "note": c} for a, b, c in items], "source": source}
def scale(title, items, source): return {"t": "scale", "title": title, "items": [{"mark": a, "label": b, "text": c} for a, b, c in items], "source": source}
def week(title, days): return {"t": "week", "title": title, "days": [{"day": d, "label": l, "kind": k} for d, l, k in days]}
def plate(title, items, source): return {"t": "plate", "title": title, "items": [{"label": a, "share": b, "note": c} for a, b, c in items], "source": source}
def cycle(title, items): return {"t": "cycle", "title": title, "items": items}
def table(head, rows, source=None): return {"t": "table", "head": head, "rows": rows, "source": source}
def flow(title, items, note=None, source=None): return {"t": "flow", "title": title, "items": [{"q": q, "yes": y, "no": n} for q, y, n in items], "note": note, "source": source}
def band(title, unit, ranges, source): return {"t": "band", "title": title, "unit": unit, "ranges": [{"from": a, "to": b, "label": c, "tone": d} for a, b, c, d in ranges], "source": source}


CHAPTERS = [
    {
        "slug": "safety-first",
        "part": "A",
        "title": "Safe to start",
        "summary": "Who can start today, who should see a doctor first, and the signs that mean stop.",
        "minutes": 3,
        "sources": ["riebe2015", "who2020"],
        "blocks": [
            lead("Most adults can start exercising today. A small group should speak to a doctor first, and everyone should know the few signs that mean stop."),
            flow("Should you see a doctor first?", [
                ("Do you have chest pain, fainting, unusual breathlessness, a racing heartbeat or ankle swelling?", "Stop here. See a doctor before exercising.", "Go to the next question."),
                ("Has a doctor told you that you have heart, kidney or metabolic disease such as diabetes?", "Get medical clearance first, then start light and build slowly.", "Go to the next question."),
                ("Are you mostly inactive right now, exercising fewer than 3 days a week?", "Start at light to moderate effort and build up over weeks.", "Carry on, and build intensity gradually."),
            ], note="Screening rests on three things: how active you are now, any signs or known disease, and how hard you plan to train.", source="riebe2015"),
            compare("Normal during training", [
                "Muscles burning near the end of a set",
                "Breathing hard, then recovering within a minute or two",
                "Muscle soreness a day or two later",
            ], "Stop and get help", [
                "Chest pain, pressure or tightness",
                "Dizziness, faintness or confusion",
                "A heartbeat that feels irregular or racing",
                "Sharp or sudden joint pain",
            ]),
            stats([
                ("Some", "", "activity is better than none, even if you cannot reach the target yet", "who2020"),
                ("Start low", "", "and build slowly if you have been inactive", "who2020"),
            ]),
            rule("Pregnant, recovering from surgery, or managing a long-term condition? Follow your doctor's advice first. Levlofit will ask you and adjust."),
        ],
    },
    {
        "slug": "how-training-works",
        "part": "A",
        "title": "How training works",
        "summary": "Stress, recover, adapt: why you get fitter, and the weekly amounts that improve health.",
        "minutes": 4,
        "sources": ["who2020", "acsm2026", "bell2023"],
        "blocks": [
            lead("Training is a signal. You stress the body a little more than it is used to, it recovers, and it rebuilds to handle that stress next time."),
            cycle("The adaptation loop", ["Train", "Tire", "Recover", "Adapt", "Do a little more"]),
            steps("Four rules behind every plan", [
                ("Specific", "You get better at what you practise. Running builds running, lifting builds strength."),
                ("Progressive", "Add a little over time: a rep, a set, a kilo or a minute."),
                ("Recovered", "Levlofit tip: keep your rest days; they are part of the plan."),
                ("Consistent", "Months of regular training beat any single perfect week."),
            ]),
            bars("Weekly aerobic activity for adults", "minutes a week", [
                ("Moderate, at least", 150, "150 min"),
                ("Moderate, for more benefit", 300, "300 min"),
                ("Or vigorous, at least", 75, "75 min"),
                ("Or vigorous, for more benefit", 150, "150 min"),
            ], "who2020"),
            stats([
                ("2", "days a week", "of muscle strengthening for all major muscles", "who2020"),
                ("Less", "sitting", "and more movement of any intensity in its place benefits health", "who2020"),
            ]),
            evidence("The ACSM 2026 overview of 137 systematic reviews found that muscle growth did not depend on details such as load or how often you train, once weekly sets were equal. Its main advice: hard sets, at least twice a week, for all major muscles.", "acsm2026", "strong"),
        ],
    },
    {
        "slug": "effort-and-rir",
        "part": "A",
        "title": "How hard to push",
        "summary": "Reps in reserve: the simple scale Levlofit uses to set effort on every set.",
        "minutes": 3,
        "sources": ["zourdos2016", "acsm2026"],
        "blocks": [
            lead("After a set, ask one question: how many more good reps could I have done? That number is your reps in reserve, or RIR."),
            scale("Reps in reserve scale", [
                ("0", "Failure", "No more reps possible with good form"),
                ("1", "Very hard", "One rep left"),
                ("2", "Hard", "Two reps left"),
                ("3", "Challenging", "Three reps left"),
                ("4+", "Moderate", "Four or more left"),
            ], "zourdos2016"),
            stats([
                ("2 to 3", "RIR", "is close enough to failure to build muscle", "acsm2026"),
                ("30 to 100", "% of max", "all build muscle when sets end near failure", "acsm2026"),
            ]),
            compare("Do", [
                "End most working sets with 1 to 3 reps left",
                "Keep form identical on the last rep",
                "Leave an extra rep in hand while learning a lift",
            ], "Avoid", [
                "Taking every set to total failure",
                "Grinding reps with form breaking down",
                "Trusting your RIR guess in the first week of a new lift",
            ]),
            evidence("Beginners are less accurate at judging reps in reserve than experienced lifters, and get better with practice. Start conservative.", "zourdos2016", "moderate"),
        ],
    },
    {
        "slug": "warm-up",
        "part": "A",
        "title": "Warming up",
        "summary": "A short warm-up that prepares you without draining strength.",
        "minutes": 3,
        "sources": ["behm2016", "warneke2024"],
        "blocks": [
            lead("A good warm-up raises body temperature, moves the joints you are about to use, and rehearses the first exercise with light weight."),
            steps("A 10 minute warm-up", [
                ("Raise", "3 to 5 minutes of easy movement: brisk walk, cycle or skipping."),
                ("Mobilise", "Dynamic moves through full range: leg swings, arm circles, bodyweight squats."),
                ("Rehearse", "2 to 3 lighter sets of your first exercise, building up to your working weight."),
            ]),
            compare("Before hard training", [
                "Dynamic movements",
                "Light sets of the main lift",
                "Short static stretches if a sport needs the range",
            ], "Save for later", [
                "Long static holds of 60 seconds or more per muscle",
                "Stretching so hard it hurts",
            ]),
            stats([("60", "seconds", "or more of static stretching per muscle can reduce strength and power for a short time", "behm2016")]),
            evidence("Dynamic stretching has no negative effect and can help performance. Long static stretches cause a small, short-lived drop in force, so keep them after training.", "warneke2024", "strong"),
        ],
    },
    {
        "slug": "sets-reps-progress",
        "part": "A",
        "title": "Sets, reps and progress",
        "summary": "How much to lift for strength or muscle, how to progress, and when to ease off.",
        "minutes": 4,
        "sources": ["acsm2026", "bell2023"],
        "blocks": [
            lead("Pick the goal, then match the dose. Strength wants heavy sets, muscle wants enough hard sets, and both want slow, steady progress."),
            table(["Goal", "Load", "Volume", "Frequency"], [
                ["Strength", "80% of max or more", "2 to 3 sets per lift", "2 or more sessions a week"],
                ["Muscle size", "30 to 100% of max, near failure", "10 or more sets per muscle a week", "Any, once weekly sets are reached"],
                ["General health", "Any challenging load", "All major muscles", "2 or more days a week"],
            ], "acsm2026"),
            steps("Double progression, the simplest way to progress", [
                ("Pick a rep range", "For example 8 to 12 reps."),
                ("Add reps", "Stay at the same weight until every set reaches the top of the range."),
                ("Add weight", "Increase the load a little and drop back to the bottom of the range."),
                ("Repeat", "Small steps, every week or two."),
            ]),
            week("Example: 3 full-body days", [
                ("Mon", "Full body", "strength"),
                ("Tue", "Walk", "cardio"),
                ("Wed", "Full body", "strength"),
                ("Thu", "Rest", "rest"),
                ("Fri", "Full body", "strength"),
                ("Sat", "Walk or sport", "cardio"),
                ("Sun", "Rest", "rest"),
            ]),
            stats([
                ("4 to 8", "weeks", "between planned deloads is common practice", "bell2023"),
                ("Less", "volume and effort", "during a deload week, to shed fatigue", "bell2023"),
            ]),
            evidence("Expert coaches agree a deload is a planned lighter period to shed fatigue and come back ready.", "bell2023", "consensus"),
        ],
    },
    {
        "slug": "food-basics",
        "part": "A",
        "title": "Food for training",
        "summary": "The Indian plate, how much protein you need, and the best vegetarian and non-vegetarian sources.",
        "minutes": 5,
        "sources": ["icmr2024", "icmr2020", "issnprotein", "ifct2017", "soy2021"],
        "blocks": [
            lead("Build the plate first, then fix protein. Most Indian meals are rich in cereal and short on protein, so that is where training changes things."),
            plate("My Plate for the Day, per 2000 kcal", [
                ("Vegetables and greens", 400, "400 g"),
                ("Cereals and millets", 250, "250 g"),
                ("Fruits", 100, "100 g"),
                ("Pulses (30 g can be fish or meat)", 85, "85 g"),
                ("Nuts and seeds", 35, "35 g"),
                ("Oils and fats", 27, "27 g"),
                ("Milk or curd", 300, "300 ml"),
            ], "icmr2024"),
            bars("Protein per kg of body weight, per day", "g per kg", [
                ("Inactive adult, RDA", 0.8, "0.8 g"),
                ("Training adult, lower end", 1.4, "1.4 g"),
                ("Training adult, upper end", 2.0, "2.0 g"),
            ], "issnprotein"),
            stats([
                ("20 to 40", "g", "protein per meal, spread every 3 to 4 hours", "issnprotein"),
                ("30", "% or less", "of daily energy from fat", "icmr2024"),
                ("0.83", "g per kg", "is the Indian RDA for a healthy, inactive adult", "icmr2020"),
            ]),
            table(["Food, per 100 g raw", "Protein", "Energy"], [
                ["Masoor dal", "24.4 g", "322 kcal"],
                ["Moong, whole", "22.5 g", "294 kcal"],
                ["Chicken breast, skinless", "21.8 g", "168 kcal"],
                ["Rajma, red", "19.9 g", "299 kcal"],
                ["Paneer", "18.9 g", "258 kcal"],
                ["Kala chana", "18.8 g", "287 kcal"],
                ["Egg, whole", "13.3 g", "135 kcal"],
                ["Atta", "10.6 g", "320 kcal"],
                ["Cow milk", "3.3 g", "73 kcal"],
            ], "ifct2017"),
            evidence("Across 41 clinical studies, soy protein and isoflavones did not change testosterone or oestrogen in men, at any dose tested. Levlofit still caps soya chunks at 50 g dry a day, for variety rather than safety.", "soy2021", "strong"),
        ],
    },
    {
        "slug": "water",
        "part": "A",
        "title": "Water and sweat",
        "summary": "How to tell if you are drinking enough in Indian heat, without guesswork.",
        "minutes": 2,
        "sources": ["acsmfluid"],
        "blocks": [
            lead("Start training well hydrated, and drink enough during long or hot sessions to avoid losing more than 2% of your body weight."),
            stats([("2", "% of body weight", "lost as sweat is where performance starts to suffer", "acsmfluid")]),
            steps("Check your sweat loss", [
                ("Weigh before", "Light clothes, after using the toilet."),
                ("Train", "Note how much you drink."),
                ("Weigh after", "Towel off first."),
                ("Compare", "A 70 kg person should lose under 1.4 kg. More than that? Drink more next time."),
            ]),
            compare("Signs you are fine", [
                "Pale yellow urine",
            ], "Signs to drink more", [
                "Dark urine, or very little of it",
                "Headache or dizziness after training",
            ]),
            rule("Long sessions in heat lose salt as well as water. Salted food, lassi or chaas after training helps replace it."),
        ],
    },
    {
        "slug": "body-measures",
        "part": "A",
        "title": "Reading your body numbers",
        "summary": "BMI cut-offs for Indians, why waist matters, and what the numbers cannot tell you.",
        "minutes": 3,
        "sources": ["misra2009", "nice2022"],
        "blocks": [
            lead("Asian Indians carry more health risk at a lower weight than Western cut-offs assume, so Levlofit uses Indian cut-offs and your waist."),
            band("BMI for Asian Indians", "kg/m²", [
                (14, 18, "Underweight", "warn"),
                (18, 23, "Normal", "good"),
                (23, 25, "Overweight", "warn"),
                (25, 35, "Obese", "bad"),
            ], "misra2009"),
            band("Waist to height ratio", "ratio", [
                (0.3, 0.5, "Healthy", "good"),
                (0.5, 0.6, "Increased risk", "warn"),
                (0.6, 0.8, "High risk", "bad"),
            ], "nice2022"),
            steps("Measure your waist", [
                ("Find the spot", "Midway between your lowest rib and the top of your hip bone."),
                ("Breathe out", "Relax, do not pull the belly in."),
                ("Read", "Tape level and snug, not tight."),
                ("Divide", "Waist in cm divided by height in cm."),
            ]),
            compare("BMI is good for", [
                "Quick screening",
                "Tracking change in the same person",
            ], "BMI misses", [
                "Muscle versus fat",
                "Where fat is stored",
            ]),
        ],
    },
    {
        "slug": "sleep-recovery",
        "part": "A",
        "title": "Sleep and recovery",
        "summary": "Why sleep is part of training, and how to spot too much fatigue.",
        "minutes": 3,
        "sources": ["aasm2015", "bell2023"],
        "blocks": [
            lead("You train in the gym and improve while you rest. Sleep is part of the plan, not time off from it."),
            stats([("7+", "hours", "of sleep a night, regularly, for adults 18 to 60", "aasm2015")]),
            cycle("Recovery in a week", ["Hard session", "Easy day or rest", "Sleep 7+ hours", "Next hard session"]),
            compare("Levlofit check-in: recovering well", [
                "Weights feel normal or lighter",
                "You look forward to training",
                "Sleep is steady",
            ], "Levlofit check-in: too much fatigue", [
                "Performance drops for more than a week",
                "Motivation keeps falling",
                "Aches that do not settle",
            ]),
            week("Hard and easy days", [
                ("Mon", "Hard", "strength"),
                ("Tue", "Easy walk", "cardio"),
                ("Wed", "Hard", "strength"),
                ("Thu", "Rest", "rest"),
                ("Fri", "Hard", "strength"),
                ("Sat", "Easy", "mobility"),
                ("Sun", "Rest", "rest"),
            ]),
            evidence("Coaches use planned lighter weeks, called deloads, to clear fatigue before it becomes a problem.", "bell2023", "consensus"),
        ],
    },
    {
        "slug": "supplements",
        "part": "A",
        "title": "Supplements that work",
        "summary": "Creatine, caffeine and protein powder: doses, timing and what they really do.",
        "minutes": 4,
        "sources": ["issncreatine", "issncaffeine", "issnprotein"],
        "blocks": [
            lead("Food first. A few supplements have strong evidence and can help. None replaces training, sleep or enough protein from meals."),
            table(["Supplement", "Dose", "Timing"], [
                ["Creatine monohydrate", "3 to 5 g a day", "Any time, every day"],
                ["Caffeine", "3 to 6 mg per kg", "About 60 min before"],
                ["Protein powder", "20 to 40 g a serving", "When meals fall short"],
            ]),
            stats([
                ("3 to 5", "g a day", "of creatine keeps muscle stores full, no loading needed", "issncreatine"),
                ("0.3", "g per kg", "a day for 5 to 7 days fills stores faster, if you choose to load", "issncreatine"),
                ("3 to 6", "mg per kg", "of caffeine improves performance, about 60 minutes before", "issncaffeine"),
            ]),
            bars("Caffeine for a 70 kg person", "mg", [
                ("Effective, low end (3 mg/kg)", 210, "210 mg"),
                ("Effective, high end (6 mg/kg)", 420, "420 mg"),
            ], "issncaffeine"),
            evidence("Creatine has been studied for up to 5 years at 0.3 to 0.8 g per kg a day, in healthy people and in patients, with no adverse health risks found. Protein powder is simply protein: a serving counts the same as protein from food.", "issncreatine", "strong"),
            compare("Worth it", [
                "Creatine monohydrate for strength and muscle",
                "Caffeine for performance, if it suits you",
                "Protein powder if food cannot reach your target",
            ], "Be careful", [
                "Caffeine late in the day, it can cut sleep",
                "Any supplement with a health condition: ask a doctor first",
            ]),
        ],
    },
    {
        "slug": "one-step-at-a-time",
        "part": "B",
        "title": "One goal at a time",
        "summary": "Why Levlofit builds your foundation first and adds goals as you level up.",
        "minutes": 3,
        "sources": ["wilson2012", "acsm2026"],
        "blocks": [
            lead("Wanting to get strong, run and look good all at once is normal. Training all of it from day one is how beginners stall."),
            flow("Where do you start?", [
                ("Can you squat, hinge, push and pull with good form?", "Build your main goal first", "Foundation phase first"),
                ("Has your main goal reached Level 2?", "Add a second goal", "Keep building the main goal"),
            ], note="Your level, not your wish list, decides how many goals you train.", source="acsm2026"),
            steps("How Levlofit levels you up", [
                ("Check your level", "Answer a short test for each goal based on what you can do today."),
                ("Foundation", "Full-body basics and your main goal, 2 to 3 days a week."),
                ("Pass the check", "Each level lists what to show before moving up."),
                ("Unlock the next goal", "Extra goals switch on one at a time as your main goal climbs."),
            ]),
            compare("Stack goals when", [
                "Your main goal is past the basics",
                "You recover well between sessions",
            ], "Wait when", [
                "Form on basic lifts is not solid yet",
                "Lots of running would compete with your strength work",
            ]),
            stats([("More", "interference", "on strength and size from frequent, long running sessions", "wilson2012")]),
            evidence("Combining endurance and strength training costs some strength, size and especially power gains, and the cost grows with how often and how long the endurance sessions are.", "wilson2012", "strong"),
        ],
    },
    {
        "slug": "rest-between-sets",
        "part": "B",
        "title": "Rest between sets",
        "summary": "How long to rest, and how the rest timer in your session helps.",
        "minutes": 2,
        "sources": ["grgic2018", "singer2024"],
        "blocks": [
            lead("Rest long enough to repeat good reps. Cutting rest short saves minutes but costs quality."),
            bars("Rest to aim for", "minutes", [
                ("Big lifts for strength", 2, "2 min or more"),
                ("Muscle building", 1.5, "over 1 min"),
                ("Light accessory work", 1, "about 1 min"),
            ], "grgic2018"),
            stats([
                ("2", "minutes or more", "of rest maximises strength gains", "grgic2018"),
                ("60", "seconds plus", "may give a small edge for muscle growth; the evidence is uncertain", "singer2024"),
            ]),
            steps("Using the rest timer", [
                ("Tick the set", "The timer starts on its own."),
                ("Breathe and reset", "Sip water and think about the next set."),
                ("Go when ready", "Skip early if you feel fresh, add time if not."),
            ]),
            evidence("Strength improves with short rests too, but rests of 2 minutes or more give the most strength in both trained and untrained people.", "grgic2018", "moderate"),
        ],
    },
    {
        "slug": "daily-steps",
        "part": "B",
        "title": "Daily steps",
        "summary": "How many steps actually matter, and why 10,000 is not a magic number.",
        "minutes": 2,
        "sources": ["paluch2022", "who2020"],
        "blocks": [
            lead("Walking more is one of the simplest health wins, and you do not need 10,000 steps to get most of it."),
            bars("Where the benefit levels off", "steps a day", [
                ("Adults 60 and over", 7000, "6,000 to 8,000"),
                ("Adults under 60", 9000, "8,000 to 10,000"),
            ], "paluch2022"),
            stats([("40 to 53", "% lower", "risk of death in the most active step groups compared with the least", "paluch2022")]),
            steps("Add steps without trying", [
                ("Walk after meals", "Ten minutes after lunch and dinner adds up fast."),
                ("Take calls standing", "Pace while you talk."),
                ("Stairs", "Skip the lift for a few floors."),
            ]),
            evidence("More daily steps went with lower risk, and the benefit levelled off at a lower count for older adults.", "paluch2022", "strong"),
        ],
    },
    {
        "slug": "tracking-progress",
        "part": "B",
        "title": "Tracking that tells the truth",
        "summary": "Weigh-ins, tape and photos: what each shows and how often to use it.",
        "minutes": 3,
        "sources": ["zheng2015"],
        "blocks": [
            lead("The scale moves with water, food and salt. Trends over weeks, the tape and photos together show what is really changing."),
            table(["Tool", "How often", "Shows"], [
                ["Scale", "Daily or weekly, same time", "Weight trend"],
                ["Tape", "Every 2 to 4 weeks", "Where size changes"],
                ["Photos", "Every 4 weeks", "Shape over months"],
                ["Training log", "Every session", "Strength going up"],
            ]),
            steps("Make it consistent", [
                ("Same time", "Morning, after the toilet, before food."),
                ("Same conditions", "Same light, pose and distance for photos."),
                ("Read the trend", "Look at the line over weeks, not one reading."),
            ]),
            compare("Good signs", [
                "Waist down while strength goes up",
                "Weight trend moving at the planned rate",
            ], "Not a problem", [
                "Weight steady while the tape shrinks",
            ]),
            evidence("Across 17 studies, regular self-weighing went with more weight loss and was not linked to anxiety or low mood.", "zheng2015", "moderate"),
        ],
    },
    {
        "slug": "habits",
        "part": "B",
        "title": "Building habits that last",
        "summary": "How long habits take to form, and why one missed day does not matter.",
        "minutes": 2,
        "sources": ["lally2010", "efsa2010"],
        "blocks": [
            lead("Motivation comes and goes. Habits carry you on the days it does not show up."),
            stats([
                ("66", "days", "median time for a daily habit to feel automatic", "lally2010"),
                ("18 to 254", "days", "the real range: some habits take far longer", "lally2010"),
            ]),
            steps("Make a habit stick", [
                ("Anchor it", "Tie it to something you already do, like after brushing your teeth."),
                ("Start tiny", "Two minutes of the habit beats a perfect plan you skip."),
                ("Track it", "Tick it off in the Habits tab."),
                ("Miss once, not twice", "One missed day barely affects the habit."),
            ]),
            bars("Daily water, from all drinks and food", "litres", [
                ("Men", 2.5, "2.5 L"),
                ("Women", 2.0, "2.0 L"),
            ], "efsa2010"),
            evidence("Missing a single day did not meaningfully slow habit formation in the study.", "lally2010", "moderate"),
        ],
    },
    # ================================================================ Part C: Food and body
    {
        "slug": "calories",
        "part": "C",
        "title": "Calories and energy balance",
        "summary": "How Levlofit estimates what you burn, and how eating above or below it changes your weight.",
        "minutes": 4,
        "sources": ["mifflin1990", "aragon2017"],
        "blocks": [
            lead("Your weight trend follows energy balance: eat less than you burn and you lose, eat more and you gain. Levlofit estimates your burn, then sets food to match your goal."),
            steps("How your calorie target is built", [
                ("Resting burn (BMR)", "The Mifflin-St Jeor equation: weight, height, age and sex give the energy you use at complete rest."),
                ("Activity", "Levlofit multiplies BMR by 1.2 for a desk day up to 1.725 for a very active life, using your job or your training, whichever is higher. These multipliers are estimates, not measurements."),
                ("Goal", "Fat loss eats about 15% below that, muscle gain about 10% above, everything else at maintenance."),
                ("Floor", "Your target never goes below your BMR."),
            ]),
            table(["Mifflin-St Jeor", "Formula, kcal a day"], [
                ["Men", "10 x kg + 6.25 x cm - 5 x age + 5"],
                ["Women", "10 x kg + 6.25 x cm - 5 x age - 161"],
            ], "mifflin1990"),
            bars("Activity multipliers Levlofit uses", "x BMR", [
                ("Desk day, little walking", 1.2, "1.2"),
                ("Light activity or 1 to 3 sessions", 1.375, "1.375"),
                ("Active, 4 to 5 sessions", 1.55, "1.55"),
                ("Very active, 6+ sessions or physical job", 1.725, "1.725"),
            ], None),
            cycle("Why scale weight jumps day to day", ["Salt and carbs hold water", "Water settles", "The trend shows the truth"]),
            evidence("A moderate deficit preserves muscle and training quality better than a crash diet; maintenance with high protein suits beginners trying to lose fat and gain muscle together.", "aragon2017", "strong"),
            stats([("2 to 3", "weeks", "of weight trend in Progress before you change calories: a Levlofit rule, because the formula is only an estimate")]),
        ],
    },
    {
        "slug": "fat-loss",
        "part": "C",
        "title": "Losing fat, keeping muscle",
        "summary": "The pace that protects muscle, the protein that helps, and what to do when progress stalls.",
        "minutes": 4,
        "sources": ["helms2014", "aragon2017", "issnprotein", "aasm2015"],
        "blocks": [
            lead("Fat loss is a slow, steady deficit with heavy training and high protein. Lose too fast and you lose muscle and strength with the fat."),
            band("Weekly weight loss", "% of body weight", [
                (0, 0.5, "Slow and very safe", "good"),
                (0.5, 1.0, "Target pace", "good"),
                (1.0, 1.5, "Fast, muscle at risk", "warn"),
                (1.5, 2.5, "Too fast", "bad"),
            ], "helms2014"),
            stats([
                ("0.5 to 1", "% a week", "weight loss keeps the most muscle", "helms2014"),
                ("2.0", "g per kg", "protein a day while dieting, the top of the ISSN minimum range; more may help when eating less", "issnprotein"),
            ]),
            compare("Keeps muscle", [
                "Lifting heavy 2 to 4 times a week",
                "Protein at every meal",
                "Losing about 0.35 to 0.7 kg a week if you weigh 70 kg",
                "7 or more hours of sleep",
            ], "Costs muscle", [
                "Crash diets and skipped meals",
                "Swapping lifting for only cardio",
                "Dropping protein to save calories",
            ]),
            flow("Weight not moving?", [
                ("Has the weekly average been flat for 3 weeks or more?", "Go to the next question.", "Levlofit rule: wait another week or two before changing anything."),
                ("Are you logging food honestly, including oil and snacks?", "Levlofit rule: cut about 100 to 200 kcal a day, or add 2000 daily steps.", "Track for one week first; most stalls are hidden intake."),
            ]),
            evidence("Reviews of contest preparation find slower loss rates protect lean mass, and protein above normal needs helps most when lean and in a deficit.", "helms2014", "moderate"),
        ],
    },
    {
        "slug": "muscle-gain",
        "part": "C",
        "title": "Gaining muscle and weight",
        "summary": "How big a surplus to eat, how fast to gain, and why more food is not more muscle.",
        "minutes": 3,
        "sources": ["iraki2019", "morton2018"],
        "blocks": [
            lead("Muscle is built slowly. A small surplus plus hard training adds muscle; a big surplus mostly adds fat."),
            band("Weekly weight gain, beginners and intermediates", "% of body weight", [
                (0, 0.25, "Slow, lean", "good"),
                (0.25, 0.5, "Target pace", "good"),
                (0.5, 1.0, "Mostly fat", "warn"),
            ], "iraki2019"),
            stats([
                ("10 to 20", "% surplus", "above maintenance; Levlofit starts at 10%", "iraki2019"),
                ("1.6", "g per kg", "protein a day, where extra protein stops adding muscle on average", "morton2018"),
            ]),
            steps("Eating more when you are never hungry", [
                ("Add a meal", "Milk and a banana, or curd and poha, between meals."),
                ("Use dense foods", "Peanuts, a little ghee on roti, paneer, dry fruits."),
                ("Drink some calories", "Milk, lassi or a banana shake."),
                ("Weigh weekly", "Levlofit rule: if the trend is off pace for 3 weeks, adjust by 150 to 200 kcal a day."),
            ]),
            evidence("In a meta-analysis of 49 trials, protein beyond about 1.6 g per kg a day gave no further average gain in muscle from training.", "morton2018", "strong"),
            compare("Lean gain", [
                "Small surplus, weight up slowly",
                "Hard training 3 to 5 days a week",
                "Advanced lifters: aim for the lower end",
            ], "Dirty bulk", [
                "Eating everything in sight",
                "Gaining over 1% a week",
                "Long fat-loss diet needed afterwards",
            ]),
        ],
    },
    {
        "slug": "carbs-fibre-fats",
        "part": "C",
        "title": "Carbs, fibre and fats",
        "summary": "Which carbs to choose, how much fibre to aim for, and the fats to keep and to limit.",
        "minutes": 4,
        "sources": ["whocarb2023", "whofat2023", "icmr2024", "ifct2017"],
        "blocks": [
            lead("Carbs fuel training and fats keep hormones and cells healthy. Quality matters more than cutting either one out."),
            stats([
                ("25", "g or more", "naturally occurring fibre a day", "whocarb2023"),
                ("400", "g or more", "vegetables and fruit a day", "whocarb2023"),
                ("40 to 70", "% of energy", "from carbs fits a healthy diet when quality is good", "whocarb2023"),
            ]),
            compare("Choose most days", [
                "Whole wheat atta, brown rice, millets like ragi, jowar and bajra",
                "Dals, chana, rajma and sprouts",
                "Whole fruit and plenty of vegetables",
                "Nuts, seeds, mustard and groundnut oil",
            ], "Limit", [
                "Maida, sugar, sweets and sugary drinks",
                "Vanaspati (trans fats) and oil reused for frying",
                "Lots of ghee, butter and coconut oil (saturated fat)",
                "Fried snacks most days",
            ]),
            bars("Upper limits for fat, share of daily energy", "% of energy", [
                ("All fat", 30, "30% or less"),
                ("Saturated fat", 10, "10% or less"),
                ("Trans fat", 1, "1% or less"),
            ], "whofat2023"),
            table(["Fibre in everyday food, per 100 g raw", "Fibre"], [
                ["Kala chana", "25.2 g"],
                ["Whole moong", "17.0 g"],
                ["Rajma", "16.6 g"],
                ["Wheat atta", "11.4 g"],
                ["Ragi", "11.2 g"],
                ["Guava", "8.6 g"],
            ], "ifct2017"),
            rule("Add fibre slowly over a week or two and drink water with it, so your gut can adjust."),
        ],
    },
    {
        "slug": "veg-protein",
        "part": "C",
        "title": "Vegetarian and vegan protein",
        "summary": "Hitting protein without meat: the best Indian sources, combining foods, and soya chunks.",
        "minutes": 3,
        "sources": ["ifct2017", "usda174275", "soy2021", "issnprotein", "icmr2024"],
        "blocks": [
            lead("You can build muscle on a vegetarian or vegan diet. It takes planning: protein-dense foods at every meal and a mix of sources."),
            stats([("51.5", "g protein", "in 100 g of dry soya chunks, the richest common vegetarian source", "usda174275")]),
            table(["Food, per 100 g raw", "Protein", "Energy"], [
                ["Masoor dal", "24.4 g", "322 kcal"],
                ["Moong dal", "23.9 g", "326 kcal"],
                ["Peanuts", "23.7 g", "520 kcal"],
                ["Chana dal", "21.6 g", "329 kcal"],
                ["Paneer", "18.9 g", "258 kcal"],
            ], "ifct2017"),
            steps("A high-protein vegetarian day", [
                ("Breakfast", "Moong chilla or besan cheela, or poha with peanuts and curd."),
                ("Lunch", "Dal plus rajma or chana with roti; pulses and grains cover each other's gaps."),
                ("Snack", "Roasted chana, sprouts chaat or a glass of milk."),
                ("Dinner", "Soya chunk curry, paneer bhurji or tofu with vegetables."),
            ]),
            evidence("Soy did not change male hormones across clinical studies, at any dose tested.", "soy2021", "strong"),
            compare("Vegetarian staples", [
                "Paneer, curd and milk",
                "Dals, chana and rajma",
                "Soya chunks",
            ], "Vegan staples", [
                "Tofu and soya chunks",
                "Dals, chana, rajma and sprouts",
                "Peanuts; aim for the upper end of your protein range",
            ]),
        ],
    },
    {
        "slug": "meal-timing",
        "part": "C",
        "title": "When to eat around training",
        "summary": "What matters about meal timing, and what does not.",
        "minutes": 3,
        "sources": ["kerksick2017", "issnprotein"],
        "blocks": [
            lead("Total daily food matters most. Timing is fine-tuning: spread protein through the day and do not train on an empty tank."),
            scale("What matters most", [
                ("1", "Total calories", "Sets whether you gain, lose or hold weight."),
                ("2", "Total protein", "Drives muscle repair across the day."),
                ("3", "Protein spread", "20 to 40 g every 3 to 4 hours."),
                ("4", "Meals around training", "Helps how you feel and recover."),
                ("5", "Exact minutes", "Barely matters for most people."),
            ], "kerksick2017"),
            steps("Around a session", [
                ("2 to 3 h before", "A normal meal: roti or rice, dal or paneer, vegetables."),
                ("30 to 60 min before", "If hungry: a banana or a small bowl of poha."),
                ("Within a few hours after", "A protein-rich meal; no need to rush a shake."),
            ]),
            stats([("20 to 40", "g", "protein per meal, every 3 to 4 hours", "issnprotein")]),
            evidence("When daily protein and energy are met, the exact timing after a session matters little for most people.", "kerksick2017", "moderate"),
        ],
    },
    # ================================================================ Part D: Train for your goal
    {
        "slug": "build-muscle",
        "part": "D",
        "title": "Building muscle",
        "summary": "How many sets per muscle, how heavy, and how close to failure to grow.",
        "minutes": 4,
        "sources": ["schoenfeld2017v", "schoenfeld2017l", "acsm2026"],
        "blocks": [
            lead("Muscle grows from enough hard sets per muscle each week, repeated for months. Load can vary; effort and consistency cannot."),
            bars("Weekly sets per muscle and growth", "sets a week", [
                ("Under 5 sets", 4, "least growth"),
                ("5 to 9 sets", 7, "more"),
                ("10 or more sets", 10, "most"),
            ], "schoenfeld2017v"),
            stats([
                ("10+", "sets", "per muscle a week gave the most growth", "schoenfeld2017v"),
                ("Light or heavy", "", "loads both build muscle when sets end close to failure", "schoenfeld2017l"),
            ]),
            week("Example: 4-day upper and lower", [
                ("Mon", "Upper", "strength"),
                ("Tue", "Lower", "strength"),
                ("Wed", "Walk", "cardio"),
                ("Thu", "Upper", "strength"),
                ("Fri", "Lower", "strength"),
                ("Sat", "Mobility", "mobility"),
                ("Sun", "Rest", "rest"),
            ]),
            compare("Grows muscle", [
                "Sets ending 1 to 3 reps from failure",
                "Adding reps or weight over time",
                "Training each muscle twice a week",
            ], "Wastes effort", [
                "Easy sets far from failure",
                "Changing exercises every week",
                "Endless sets with poor form",
            ]),
            evidence("Low and high loads built similar muscle when sets went close to failure; heavier loads built more maximal strength.", "schoenfeld2017l", "strong"),
        ],
    },
    {
        "slug": "get-stronger",
        "part": "D",
        "title": "Getting stronger and powerlifting",
        "summary": "Heavy, practised lifts: squat, bench and deadlift, and how strength is built.",
        "minutes": 4,
        "sources": ["schoenfeld2017l", "grgic2018", "zourdos2016", "acsm2026"],
        "blocks": [
            lead("Strength is a skill as well as muscle. Lift heavy, practise the same lifts often, and rest long enough to lift well."),
            stats([
                ("Heavy", "loads", "build more maximal strength than light loads", "schoenfeld2017l"),
                ("2+", "min rest", "between heavy sets helps strength", "grgic2018"),
            ]),
            table(["Lift", "What it trains", "Key cue"], [
                ["Squat", "Legs, hips, trunk", "Brace, knees track over toes"],
                ["Bench press", "Chest, shoulders, triceps", "Shoulder blades pinned, feet planted"],
                ["Deadlift", "Back, hips, grip", "Bar close, back flat, push the floor away"],
                ["Overhead press", "Shoulders, triceps", "Glutes tight, bar over mid-foot"],
            ]),
            scale("Effort for strength work, reps in reserve (Levlofit rule)", [
                ("RIR 4+", "Technique", "Warm-up and practice sets."),
                ("RIR 2 to 3", "Most work sets", "Bar speed stays good."),
                ("RIR 0 to 1", "Rarely", "Tests and the last set of a block."),
            ], "zourdos2016"),
            steps("A strength block", [
                ("Weeks 1 to 3", "Build: add 2.5 to 5 kg when every rep is clean."),
                ("Week 4", "A lighter week to recover."),
                ("Then", "Retest, or start the next block a little heavier."),
            ]),
            rule("Powerlifting meets need a coach for technique and peaking. Levlofit's Strength path builds the base."),
        ],
    },
    {
        "slug": "physique",
        "part": "D",
        "title": "Building an aesthetic physique",
        "summary": "Proportions, which muscles shape the look, and pairing training with body-fat changes.",
        "minutes": 3,
        "sources": ["schoenfeld2017v", "helms2014", "acsm2026"],
        "blocks": [
            lead("An aesthetic look is muscle in the right places plus low enough body fat to see it. Build first, then lean out."),
            table(["Area", "Why it matters", "Key moves"], [
                ["Side delts", "Width, V-taper", "Lateral raise, overhead press"],
                ["Upper back, lats", "Width and posture", "Pull-up, lat pulldown, rows"],
                ["Upper chest", "A fuller chest", "Incline press"],
                ["Arms", "Proportion", "Curls, pushdowns, dips"],
                ["Legs", "Balance with the upper body", "Squat, lunge, Romanian deadlift"],
            ]),
            cycle("The physique year", ["Build muscle", "Lean out", "Maintain", "Build again"]),
            stats([
                ("10+", "sets", "per muscle a week for lagging areas", "schoenfeld2017v"),
                ("0.5 to 1", "% a week", "loss pace when leaning out", "helms2014"),
            ]),
            compare("Helps the look", [
                "Extra sets for lagging muscles",
                "Patience: months, not weeks",
                "Photos and tape every 2 to 4 weeks",
            ], "Hurts it", [
                "Only training mirror muscles",
                "Skipping legs",
                "Cutting before you have built muscle",
            ]),
        ],
    },
    {
        "slug": "calisthenics",
        "part": "D",
        "title": "Calisthenics",
        "summary": "Bodyweight strength: progressions from push-ups to pull-ups, dips and holds.",
        "minutes": 4,
        "sources": ["kotarsky2018"],
        "blocks": [
            lead("Your body is the barbell. You progress by making the move harder: more leverage, fewer points of support, more range."),
            table(["Skill", "Start", "Next", "Goal"], [
                ["Push", "Incline push-up", "Full push-up", "Archer, then one-arm push-up"],
                ["Pull", "Inverted row", "Negative pull-up", "Strict pull-ups, then weighted"],
                ["Squat", "Box squat", "Split squat", "Pistol squat"],
                ["Hold", "Plank", "Hollow hold", "L-sit"],
                ["Dip", "Bench dip", "Negative dip", "Parallel bar dips"],
            ]),
            steps("How to move up a step", [
                ("Hit the target", "3 sets of 8 to 12 clean reps, or 3 holds of 30 s."),
                ("Step up", "Move to the next variation, even if reps drop to 3 to 5."),
                ("Build again", "Climb back to the target, then step up again."),
            ]),
            stats([("Similar", "", "strength and muscle gains from progressive push-ups as from bench press", "kotarsky2018")]),
            evidence("A controlled trial found progressive push-ups matched the bench press for strength and muscle thickness gains.", "kotarsky2018", "moderate"),
            cycle("Your first pull-up", ["Inverted rows", "Band-assisted pull-ups", "Slow negatives", "First strict pull-up"]),
        ],
    },
    {
        "slug": "running",
        "part": "D",
        "title": "Running",
        "summary": "Easy miles, safe weekly increases, and the 80/20 way to run faster.",
        "minutes": 4,
        "sources": ["seiler2010", "nielsen2014"],
        "blocks": [
            lead("Most of your running should feel easy. You get faster by running more, gradually, with a little hard work on top."),
            plate("How endurance athletes mix intensity", [
                ("Easy, can talk in sentences", 80, "about 80%"),
                ("Hard, intervals or tempo", 20, "about 20%"),
            ], "seiler2010"),
            band("Weekly distance increase, new runners", "% more than last week", [
                (0, 10, "Safer", "good"),
                (10, 30, "Watch for niggles", "warn"),
                (30, 50, "Higher injury risk", "bad"),
            ], "nielsen2014"),
            steps("From zero to 5 km", [
                ("Weeks 1 to 2", "Run 1 min, walk 2 min, 8 rounds, 3 days a week."),
                ("Weeks 3 to 5", "Run 3 to 5 min, walk 1 to 2 min."),
                ("Weeks 6 to 8", "Run 10 to 20 min without stopping."),
                ("Week 9 on", "Run 5 km easy, then add one faster session a week."),
            ]),
            scale("The talk test (Levlofit tip)", [
                ("Easy", "Full sentences", "Most runs."),
                ("Steady", "Short phrases", "Tempo runs."),
                ("Hard", "A few words", "Intervals only."),
            ], "seiler2010"),
            evidence("Novice runners who raised weekly distance by more than 30% over two weeks had more overuse injuries than those who added under 10%.", "nielsen2014", "moderate"),
        ],
    },
    {
        "slug": "hyrox",
        "part": "D",
        "title": "HYROX and functional fitness",
        "summary": "The race format, the eight stations, and how to train running and strength together.",
        "minutes": 4,
        "sources": ["hyrox", "wilson2012"],
        "blocks": [
            lead("HYROX is 8 km of running split by 8 workout stations. It rewards a strong engine and strength that holds up while tired."),
            table(["Station, after each 1 km run", "Standard"], [
                ["1. SkiErg", "1000 m"],
                ["2. Sled push", "50 m"],
                ["3. Sled pull", "50 m"],
                ["4. Burpee broad jumps", "80 m"],
                ["5. Rowing", "1000 m"],
                ["6. Farmers carry", "200 m"],
                ["7. Sandbag lunges", "100 m"],
                ["8. Wall balls", "100 reps"],
            ], "hyrox"),
            week("Example HYROX week", [
                ("Mon", "Strength", "strength"),
                ("Tue", "Easy run", "cardio"),
                ("Wed", "Stations", "strength"),
                ("Thu", "Rest", "rest"),
                ("Fri", "Intervals", "cardio"),
                ("Sat", "Race sim", "cardio"),
                ("Sun", "Mobility", "mobility"),
            ]),
            compare("Race smart", [
                "Run the first km easier than you want",
                "Practise wall balls and lunges when tired",
                "Pace the sleds; walk them if needed",
            ], "Common mistakes", [
                "Sprinting the first run",
                "Only running, no station practice",
                "Skipping strength work",
            ]),
            evidence("Running and lifting in one plan works; keeping hard runs and leg sessions apart limits interference with strength.", "wilson2012", "moderate"),
        ],
    },
    {
        "slug": "mobility",
        "part": "D",
        "title": "Mobility and yoga",
        "summary": "How to gain range of motion, when to stretch, and what yoga adds.",
        "minutes": 3,
        "sources": ["afonso2021", "behm2016"],
        "blocks": [
            lead("Range of motion improves with regular practice. Stretching works, and so does strength training through a full range."),
            stats([("Same", "", "range of motion gains from full-range strength training as from stretching", "afonso2021")]),
            compare("Builds mobility", [
                "Full-range lifts: deep squats, RDLs, full push-ups",
                "Holding stretches 30 to 60 s, most days",
                "Yoga 2 to 3 times a week",
            ], "Does little", [
                "Stretching only once a week",
                "Forcing into pain",
                "Bouncing in a stretch",
            ]),
            steps("10-minute daily routine", [
                ("Hips", "Deep squat hold, 60 s."),
                ("Hamstrings", "Standing forward fold, 60 s."),
                ("Upper back", "Thread the needle, 5 each side."),
                ("Shoulders", "Wall slides, 10."),
                ("Ankles", "Knee-to-wall, 10 each side."),
            ]),
            evidence("Static stretches under 60 s before training barely affect strength; long holds right before heavy lifting can reduce force a little.", "behm2016", "strong"),
            table(["Practice", "Best for"], [
                ["Yoga", "Mobility, balance, calm"],
                ["Yoga flow in Levlofit", "Sphinx, butterfly, frog and twists"],
                ["Full-range lifting", "Strength and range together"],
            ]),
        ],
    },
    {
        "slug": "kettlebells",
        "part": "D",
        "title": "Kettlebell training",
        "summary": "Swings, goblet squats and carries: big results from one bell.",
        "minutes": 3,
        "sources": ["lake2012", "meigh2019"],
        "blocks": [
            lead("One kettlebell trains strength, power and conditioning. The swing is the centre of it all."),
            table(["Move", "Trains", "Start with"], [
                ["Swing", "Hips, back, power, heart", "3 x 10"],
                ["Goblet squat", "Legs, trunk", "3 x 8"],
                ["Press", "Shoulders", "3 x 5 each arm"],
                ["Row", "Back, grip", "3 x 8 each arm"],
                ["Farmers carry", "Grip, trunk", "3 x 30 m"],
            ]),
            steps("The swing", [
                ("Hinge", "Hips back, flat back, bell between the forearms."),
                ("Snap", "Drive the hips forward hard, glutes tight."),
                ("Float", "Arms only guide; the bell rises to chest height."),
                ("Return", "Let it fall, then hinge again."),
            ]),
            stats([("6", "weeks", "of swings improved maximal and explosive strength", "lake2012")]),
            evidence("Reviews find kettlebell training improves strength and fitness, but most studies are small.", "meigh2019", "moderate"),
        ],
    },
    {
        "slug": "general-fitness",
        "part": "D",
        "title": "General fitness and heart health",
        "summary": "The mix of cardio, strength and movement that keeps you healthy for life.",
        "minutes": 3,
        "sources": ["who2020", "mandsager2018"],
        "blocks": [
            lead("For lifelong health, do some of everything: lift twice a week, move your heart most days, and sit less."),
            week("A balanced week", [
                ("Mon", "Full body", "strength"),
                ("Tue", "Brisk walk", "cardio"),
                ("Wed", "Cycle or swim", "cardio"),
                ("Thu", "Full body", "strength"),
                ("Fri", "Walk", "cardio"),
                ("Sat", "Sport or yoga", "mobility"),
                ("Sun", "Rest", "rest"),
            ]),
            stats([
                ("150 to 300", "min", "of moderate cardio a week", "who2020"),
                ("2", "days", "of strength training a week", "who2020"),
                ("About 5x", "", "higher risk of death with the lowest fitness versus the highest", "mandsager2018"),
            ]),
            compare("Builds heart fitness", [
                "Brisk walking, cycling, swimming",
                "Sports and games",
                "Stairs instead of the lift",
            ], "Easy to forget", [
                "Long sitting without breaks",
                "Only lifting, no cardio",
            ]),
            evidence("In 122,007 adults, low cardiorespiratory fitness carried a mortality risk as large as smoking or diabetes, with no upper limit of benefit.", "mandsager2018", "strong"),
        ],
    },
    # ================================================================ Part E: Staying with it
    {
        "slug": "soreness-pain-injury",
        "part": "E",
        "title": "Soreness, pain and injuries",
        "summary": "Normal soreness versus pain that needs care, and how training prevents injury.",
        "minutes": 3,
        "sources": ["lauersen2014"],
        "blocks": [
            lead("Soreness after a new workout is normal. Sharp, joint or worsening pain is not. Strength training is one of the best ways to prevent injuries."),
            compare("Normal soreness", [
                "Dull ache in the muscle, 1 to 3 days after",
                "Both sides feel the same",
                "Eases as you warm up",
            ], "Pain to respect", [
                "Sharp or stabbing, in a joint",
                "Swelling, or a joint giving way",
                "Gets worse during the session",
                "Lasts more than a week",
            ]),
            band("Pain during exercise, a common physio guide", "pain out of 10", [
                (0, 3, "OK to train", "good"),
                (3, 5, "Reduce load or range", "warn"),
                (5, 10, "Stop, see a physio or doctor", "bad"),
            ], None),
            stats([("Under 1/3", "", "of sports injuries remained with strength training", "lauersen2014")]),
            steps("Coming back from a niggle", [
                ("Calm it", "Swap to pain-free moves for a few days; keep moving."),
                ("Reload", "Return at about half the weight; add a little each session."),
                ("Rebuild", "Back to full once it stays pain-free the next day."),
            ]),
            evidence("Across 25 trials, strength training cut sports injuries to under a third, while stretching alone did not prevent injury.", "lauersen2014", "strong"),
        ],
    },
    {
        "slug": "plateaus-deloads",
        "part": "E",
        "title": "Plateaus and lighter weeks",
        "summary": "Why progress stalls, how to break through, and when to take a deload week.",
        "minutes": 3,
        "sources": ["bell2023"],
        "blocks": [
            lead("Every lifter stalls. Usually the fix is recovery, food or a small change in the plan, not a whole new program."),
            flow("Stuck for 3 weeks or more?", [
                ("Are you sleeping under 7 hours, or eating in a deficit?", "Fix sleep and food first; progress slows when recovery is short.", "Go to the next question."),
                ("Have you trained hard for many weeks without a lighter week?", "Take a deload week.", "Go to the next question."),
                ("Same exercises and reps for months?", "Change the rep range or swap one exercise per muscle.", "Add one set per muscle a week."),
            ], source="bell2023"),
            steps("A deload week", [
                ("Same lifts", "Keep the exercises."),
                ("Less work", "Levlofit rule: cut sets by about half, or use lighter weights."),
                ("Easy effort", "Stop sets well before failure."),
                ("Come back", "Return to normal training the week after."),
            ]),
            cycle("A training block", ["Build for several weeks", "Deload", "Start a little stronger"]),
            evidence("Coaches agree deloads lower fatigue. A deload can be planned ahead or taken when you feel run down.", "bell2023", "consensus"),
        ],
    },
    {
        "slug": "busy-weeks",
        "part": "E",
        "title": "Missed sessions, travel and busy weeks",
        "summary": "How little training keeps your progress, and what to do when life gets in the way.",
        "minutes": 3,
        "sources": ["bickel2011"],
        "blocks": [
            lead("Missing a week does not erase months of work. A little training keeps most of what you built."),
            stats([("1/3", "", "of the usual training dose kept muscle size in young adults over 32 weeks", "bickel2011")]),
            flow("Missed sessions?", [
                ("Missed one session?", "Carry on with the next one. Do not double up.", "Go to the next question."),
                ("Missed a week or more?", "Levlofit rule: restart at about 80% of your last weights for one week.", "Carry on as planned."),
            ]),
            steps("20-minute hotel room workout", [
                ("Squats", "3 x 15 to 20."),
                ("Push-ups", "3 sets close to failure."),
                ("Backpack rows", "3 x 12 each arm, bag filled with books."),
                ("Lunges", "3 x 10 each leg."),
                ("Plank", "3 x 30 to 45 s."),
            ]),
            compare("Busy-week rules", [
                "Keep 1 or 2 short full-body sessions",
                "Walk more: calls on foot, stairs",
                "Protect sleep",
            ], "Avoid", [
                "All-or-nothing thinking",
                "Making up missed sessions in one day",
            ]),
            evidence("In a 32-week trial, one-third of the training dose kept muscle size in young adults; older adults needed more to keep size, though their strength held well.", "bickel2011", "moderate"),
        ],
    },
    {
        "slug": "home-training",
        "part": "E",
        "title": "Training at home",
        "summary": "Building strength with bodyweight, bands and dumbbells when there is no gym.",
        "minutes": 3,
        "sources": ["lopes2019", "schoenfeld2017l", "acsm2026"],
        "blocks": [
            lead("You do not need a gym to get strong. Muscles respond to effort, not to where the weight came from."),
            table(["Gym move", "At home"], [
                ["Barbell squat", "Goblet squat, Bulgarian split squat"],
                ["Bench press", "Push-up, dumbbell floor press"],
                ["Lat pulldown", "Band pulldown, door-frame row"],
                ["Romanian deadlift", "Single-leg dumbbell RDL"],
                ["Leg curl", "Sliding towel curl"],
            ]),
            stats([
                ("Same", "", "strength gains with elastic bands as with weights", "lopes2019"),
                ("Light loads", "", "build muscle too when sets end close to failure", "schoenfeld2017l"),
            ]),
            steps("Making light weights hard", [
                ("Slow down", "3 seconds down on every rep."),
                ("Go one-sided", "Single-leg and single-arm moves put more of the weight on each leg or arm."),
                ("Pause", "Hold 2 s at the hardest point."),
                ("More reps", "Take sets close to failure."),
            ]),
            evidence("Eight trials found bands and conventional weights gave similar strength gains.", "lopes2019", "moderate"),
        ],
    },
    {
        "slug": "women",
        "part": "E",
        "title": "Training as a woman",
        "summary": "Lifting, the menstrual cycle and pregnancy: what the evidence says.",
        "minutes": 4,
        "sources": ["mcnulty2020", "mottola2018"],
        "blocks": [
            lead("Women respond to training the same way men do. Lifting builds strength and shape, not bulk, unless that is the goal."),
            compare("Myths", [
                "You must train differently in each cycle phase",
                "Avoid exercise when pregnant",
            ], "Evidence", [
                "Cycle effects on performance are small and individual",
                "Exercise is safe and helpful in most pregnancies",
            ]),
            stats([
                ("Trivial", "", "average effect of cycle phase on performance", "mcnulty2020"),
                ("150", "min a week", "of moderate activity during a healthy pregnancy", "mottola2018"),
            ]),
            steps("Training with your cycle", [
                ("Track", "Note energy and mood in Habits."),
                ("Adjust", "On low days lower the load a little; on good days push."),
                ("Keep going", "No phase needs you to stop training."),
            ]),
            evidence("A meta-analysis of 78 studies found performance may be slightly lower in the early follicular phase, but effects were trivial and varied, so general phase-based rules are not supported.", "mcnulty2020", "moderate"),
            compare("Pregnant: usually fine", [
                "Get your doctor's go-ahead first",
                "Walking, cycling, swimming, light lifting",
                "Moderate effort: you can still talk",
            ], "Stop and seek care", [
                "Bleeding or fluid leaking",
                "Dizziness, chest pain or headache",
                "Painful contractions",
            ]),
        ],
    },
    {
        "slug": "over-40",
        "part": "E",
        "title": "Training after 40",
        "summary": "Why strength and balance matter more with age, and how to train safely.",
        "minutes": 3,
        "sources": ["who2020", "bickel2011"],
        "blocks": [
            lead("Muscle and balance fade with age unless you train them. It is never too late: older adults gain strength well."),
            stats([
                ("3+", "days a week", "of balance and strength work for adults 65 and over", "who2020"),
                ("More", "training", "is needed by older adults to keep muscle size", "bickel2011"),
            ]),
            week("Example week after 40", [
                ("Mon", "Strength", "strength"),
                ("Tue", "Walk", "cardio"),
                ("Wed", "Balance", "mobility"),
                ("Thu", "Strength", "strength"),
                ("Fri", "Walk", "cardio"),
                ("Sat", "Strength", "strength"),
                ("Sun", "Rest", "rest"),
            ]),
            steps("Smart changes", [
                ("Longer warm-up", "10 minutes, gradually heavier."),
                ("Moderate reps", "8 to 15 reps with good control."),
                ("Balance every week", "Single-leg stands, step-ups, heel-to-toe walking."),
                ("Recover", "Levlofit rule: 48 hours between hard sessions for the same muscles."),
            ]),
            evidence("WHO advises older adults to do varied balance and strength work on 3 or more days a week to prevent falls.", "who2020", "strong"),
        ],
    },
    {
        "slug": "mind-motivation",
        "part": "E",
        "title": "Mood, stress and motivation",
        "summary": "Exercise as medicine for the mind, and how to keep going on low days.",
        "minutes": 3,
        "sources": ["noetel2024", "lally2010", "who2020", "telemanas2024"],
        "blocks": [
            lead("Training lifts mood, eases stress and improves sleep. Motivation comes and goes; routines carry you through."),
            table(["Exercise", "Eased depression in trials"], [
                ["Walking or jogging", "Yes, among the best"],
                ["Yoga", "Yes"],
                ["Strength training", "Yes"],
                ["Mixed aerobic", "Yes"],
            ], "noetel2024"),
            stats([
                ("Harder", "", "sessions eased depression more than easy ones", "noetel2024"),
                ("66", "days", "median time for a new habit to feel automatic", "lally2010"),
            ]),
            steps("On a low day", [
                ("Shrink it", "Do just the warm-up. Often you will keep going."),
                ("Go outside", "A 10-minute walk counts."),
                ("Tick it", "Log it in Habits; the streak matters more than the size."),
            ]),
            evidence("A network meta-analysis of 218 trials found walking, jogging, yoga and strength training eased depression, with effects comparable to therapy. Exercise adds to medical care; it does not replace it.", "noetel2024", "moderate"),
            flow("When exercise is not enough", [
                ("Feeling low most days for two weeks or more?", "Talk to a doctor; exercise works best alongside care.", "Keep moving and keep logging."),
                ("Any thoughts of self-harm?", "Call Tele-MANAS on 14416 now, free and confidential.", "Reach out to someone you trust whenever it feels heavy."),
            ]),
        ],
    },
    {
        "slug": "how-levlofit-works",
        "part": "E",
        "title": "How Levlofit builds your plan",
        "summary": "Levels, level checks, the foundation phase and why goals unlock one at a time.",
        "minutes": 3,
        "sources": ["acsm2026"],
        "blocks": [
            lead("Levlofit is built level first. You train your main goal until the basics are solid, then new goals unlock."),
            scale("The Levlofit ladder", [
                ("0", "Starting out", "Learn the moves, build the habit."),
                ("1", "Foundation", "Basic strength and fitness in place."),
                ("2", "Building", "Steady progress on your main goal."),
                ("3", "Solid", "A good level for most people."),
                ("4", "Advanced", "Specialised training pays off."),
                ("5", "Expert", "Coach-led territory."),
            ], None),
            cycle("How you move up", ["Train the plan", "Log your sets", "Take the level check", "Unlock the next level"]),
            steps("What decides your plan", [
                ("Your answers", "Health check, body numbers, days, time and equipment."),
                ("Your level", "From the level check in Workout."),
                ("Rules, not AI", "Numbers come from cited rules; Levlofit AI explains them, never invents them."),
            ]),
            rule("Levlofit builds the basics before adding goals, so your training stays focused while you learn and recover."),
            compare("Change anytime in Protocol", [
                "Goals and main goal",
                "Training days and time",
                "Diet, allergies and budget",
            ], "Earned, not edited", [
                "Your level",
                "When new goals unlock",
            ]),
        ],
    },
]


def plain(block) -> str:
    """Flattens a block to text so Postgres full-text search can find it."""
    out = []

    def walk(v):
        if isinstance(v, str):
            out.append(v)
        elif isinstance(v, (int, float)):
            pass
        elif isinstance(v, dict):
            for k, x in v.items():
                if k not in ("t", "source", "kind", "tone"):
                    walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)

    walk(block)
    return " ".join(out)


def check_chapter(c):
    blocks = c["blocks"]
    share = sum(1 for b in blocks if b["t"] in VISUAL) / len(blocks)
    assert share >= 0.6, f"{c['slug']}: only {share:.0%} visual"
    assert c["sources"] and all(k in SRC for k in c["sources"]), f"{c['slug']}: bad sources"
    cited = {b.get("source") for b in blocks} | {i.get("source") for b in blocks for i in b.get("items", []) if isinstance(i, dict)}
    cited.discard(None)
    assert cited <= set(c["sources"]), f"{c['slug']}: cites {cited - set(c['sources'])} without listing it"
    for b in blocks:
        if b["t"] == "evidence":
            assert b.get("grade") in GRADES, f"{c['slug']}: evidence without a valid grade"
    return share


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def main():
    root = Path(__file__).resolve().parents[1]
    rows = []
    for i, c in enumerate(CHAPTERS, start=1):
        share = check_chapter(c)
        print(f"{i:02d} {c['slug']:<22} {len(c['blocks'])} blocks, {share:.0%} visual")
        body = " ".join(plain(b) for b in c["blocks"])
        sources = "array[" + ", ".join(q(SRC[k]) for k in c["sources"]) + "]::text[]"
        # Blocks keep source keys; the app resolves them against this map.
        blocks = json.dumps({"sources": {k: SRC[k] for k in c["sources"]}, "blocks": c["blocks"]}, ensure_ascii=False)
        rows.append(
            f"({i}, {q(c['slug'])}, {q(c['part'])}, {q(PARTS[c['part']])}, {q(c['title'])}, {q(c['summary'])}, {c['minutes']}, "
            f"{q(body)}, {sources}, {q(blocks)}::jsonb)"
        )
    sql = f"""-- Handbook v3: Parts A to E, {len(rows)} chapters. Generated by data/build_handbook.py; edit that file, not this one.
alter table public.handbook_chapters
  add column if not exists slug text unique,
  add column if not exists part_title text,
  add column if not exists summary text,
  add column if not exists minutes smallint,
  add column if not exists blocks jsonb not null default '{{}}';

delete from public.handbook_chapters;
insert into public.handbook_chapters (id, slug, part, part_title, title, summary, minutes, body_md, sources, blocks) values
{",\n".join(rows)};
"""
    out = root / "supabase" / "migrations" / "20261007400000_handbook_v3.sql"
    out.write_text(sql, encoding="utf-8")
    print(f"wrote {out.name}, {len(CHAPTERS)} chapters")


if __name__ == "__main__":
    main()

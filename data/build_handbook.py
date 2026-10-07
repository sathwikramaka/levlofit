"""Builds the Handbook migration from the chapter content below.

Every number here is checked against the source named next to it (web-verified 2026-09-29).
The curriculum PDF in Refrence/ is used as a reference for structure only, never as a source.

Content is a list of visual blocks, rendered natively by app/lib/handbook.dart. Rule: at least
60% of blocks in every chapter are true visuals (see VISUAL), so the Handbook teaches
by showing. The build fails if a chapter breaks that rule or cites a source it does not list.

Run: python data/build_handbook.py  -> supabase/migrations/20261003300000_handbook_v2.sql
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
}

PARTS = {"A": "Foundations", "B": "Getting better"}

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
        "sources": ["who2020", "acsm2026"],
        "blocks": [
            lead("Training is a signal. You stress the body a little more than it is used to, it recovers, and it rebuilds to handle that stress next time."),
            cycle("The adaptation loop", ["Train", "Tire", "Recover", "Adapt", "Do a little more"]),
            steps("Four rules behind every plan", [
                ("Specific", "You get better at what you practise. Running builds running, lifting builds strength."),
                ("Progressive", "Add a little over time: a rep, a set, a kilo or a minute."),
                ("Recovered", "Adaptation happens between sessions, not during them."),
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
                ("Less", "sitting", "and more movement in its place benefits health at any fitness level", "who2020"),
            ]),
            evidence("The ACSM 2026 review of 137 systematic reviews found the biggest gains come from going from no resistance training to any resistance training. Details matter less than doing it regularly.", "acsm2026", "strong"),
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
                ["Muscle size", "30 to 100% of max, near failure", "10 or more sets per muscle a week", "Each muscle 2 times a week"],
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
                ("40 to 50", "% less volume", "during a deload week", "bell2023"),
            ]),
            evidence("Expert coaches agree a deload is a planned lighter period to shed fatigue and come back ready. It is not a week off.", "bell2023", "consensus"),
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
                ("Pulses, eggs or meat", 85, "85 g"),
                ("Nuts and seeds", 35, "35 g"),
                ("Oils and fats", 27, "27 g"),
            ], "icmr2024"),
            bars("Protein per kg of body weight, per day", "g per kg", [
                ("Inactive adult, Indian RDA", 0.83, "0.83 g"),
                ("Training adult, lower end", 1.4, "1.4 g"),
                ("Training adult, upper end", 2.0, "2.0 g"),
            ], "issnprotein"),
            stats([
                ("20 to 40", "g", "protein per meal, spread every 3 to 4 hours", "issnprotein"),
                ("30", "% or less", "of daily energy from fat", "icmr2024"),
                ("0.83", "g per kg", "is the Indian RDA for a healthy, inactive adult", "icmr2020"),
            ]),
            table(["Food, per 100 g raw", "Protein", "Energy"], [
                ["Soya bean, white", "37.8 g", "377 kcal"],
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
                "Body weight back to normal by the next morning",
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
            compare("Recovering well", [
                "Weights feel normal or lighter",
                "You look forward to training",
                "Sleep is steady",
            ], "Too much fatigue", [
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
                ("9", "mg per kg", "of caffeine and above brings more side effects, with no extra benefit", "issncaffeine"),
            ]),
            bars("Caffeine for a 70 kg person", "mg", [
                ("Effective, low end (3 mg/kg)", 210, "210 mg"),
                ("Effective, high end (6 mg/kg)", 420, "420 mg"),
                ("More side effects (9 mg/kg)", 630, "630 mg"),
            ], "issncaffeine"),
            evidence("Creatine has been studied for up to 5 years at doses up to 30 g a day in healthy people and was safe and well tolerated. Protein powder is simply protein: a serving counts the same as protein from food.", "issncreatine", "strong"),
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
                ("60", "seconds plus", "gives a small edge for muscle growth", "singer2024"),
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
                "A heavier day after a salty meal",
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
    sql = f"""-- Handbook v2: Part A, Foundations; Part B, Getting better. Generated by data/build_handbook.py; edit that file, not this one.
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
    out = root / "supabase" / "migrations" / "20261003300000_handbook_v2.sql"
    out.write_text(sql, encoding="utf-8")
    print(f"wrote {out.name}, {len(CHAPTERS)} chapters")


if __name__ == "__main__":
    main()

"""Levlofit Handbook v4 DRAFT builder: the v3 chapters arranged and extended into one book.

Status: DRAFT FOR REVIEW. It never writes into supabase/migrations/. The production candidate stays data/build_handbook.py
and supabase/migrations/20261007400000_handbook_v3.sql, unchanged. This module imports the v3 content and applies the
book edits listed in docs/HANDBOOK_BOOK_PLAN.md:
  - an introduction (welcome), a part opener at the start of each of the five parts, and a closing chapter with a
    sample 12-week journey (putting-it-together);
  - new chapters: welcome, cardio-intensity, technique, under-eating, putting-it-together;
  - chapters reordered so concepts are taught before they are used; ids renumbered in reading order; slugs unchanged;
  - "Key points" and "Up next" blocks at the end of every chapter;
  - heat guidance (water), pregnancy and after-birth guidance (women), age scope (welcome, over-40), worked examples
    (calories, food-basics), and the session/deload wording made consistent.
New text that states a fact is either tied to a source already read in the evidence audit or written as a labelled
Levlofit rule; medical warning signs are left for qualified review (see data/handbook_v4/claims_register.csv).

Usage: python -I data/handbook_v4/build_handbook_v4.py   -> writes data/handbook_v4/handbook_v4_draft.sql only.
"""
import copy
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
_spec = importlib.util.spec_from_file_location("handbook_v3", ROOT / "data" / "build_handbook.py")
v3 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(v3)          # loads content only; v3.main() is not called, nothing is written

SRC = dict(v3.SRC)
PARTS = dict(v3.PARTS)
PARTS["E"] = "Staying with it, for life"
GRADES = v3.GRADES | {"unverified"}   # v4: an evidence note whose cited source has not been read yet
lead, text, rule, evidence, stats, steps, compare = v3.lead, v3.text, v3.rule, v3.evidence, v3.stats, v3.steps, v3.compare
bars, scale, week, plate, cycle, table, flow, band = v3.bars, v3.scale, v3.week, v3.plate, v3.cycle, v3.table, v3.flow, v3.band


# New block types (rendered by app/lib/handbook.dart; older app builds show nothing for them).
def part(title, body): return {"t": "part", "title": title, "text": body}
def keypoints(items): return {"t": "keypoints", "title": "Key points", "items": items}
def upnext(items): return {"t": "next", "title": "Up next", "items": [{"ref": r, "title": TITLE[r], "why": w} for r, w in items]}


VISUAL = v3.VISUAL | {"keypoints", "next"}


def plain(block) -> str:
    """Search text for a block: as v3, but chapter references (ref) are not text."""
    b = copy.deepcopy(block)
    for i in b.get("items", []) if isinstance(b.get("items"), list) else []:
        if isinstance(i, dict):
            i.pop("ref", None)
    return v3.plain(b)


CH = {c["slug"]: copy.deepcopy(c) for c in v3.CHAPTERS}


REWORDS = []   # (slug, old text, new text): v4 rewordings of v3 claims; carry_over.py keeps their review gates
REMOVED = []   # (slug, rendered v3 claim text, reason): v3 claims removed by a recorded decision


def reword(slug, old, new):
    edit_text(slug, old, new)
    REWORDS.append((slug, old, new))


def edit_text(slug, old, new):
    """Replace one exact string inside a chapter's blocks (fails loudly if it is not there exactly once)."""
    s = json.dumps(CH[slug]["blocks"], ensure_ascii=False)
    assert s.count(json.dumps(old, ensure_ascii=False)[1:-1]) == 1, (slug, old)
    CH[slug]["blocks"] = json.loads(s.replace(json.dumps(old, ensure_ascii=False)[1:-1], json.dumps(new, ensure_ascii=False)[1:-1]))


# ------------------------------------------------------------------ new chapters

CH["welcome"] = {
    "slug": "welcome",
    "part": "A",
    "title": "Welcome to the Handbook",
    "summary": "What this book covers, how its five parts fit together, and how to read its evidence notes and rules.",
    "minutes": 4,
    "sources": ["who2020"],
    "blocks": [
        lead("This book explains the why behind your Levlofit plan. Read it once from start to finish, then come back to any chapter when a question comes up."),
        table(["Part", "What you will learn"], [
            ["A. Foundations", "Starting safely, how your plan is built, how training works, how hard to push, technique, warming up, sets and reps, rest and sleep"],
            ["B. Getting better", "One goal at a time, measuring progress honestly, plateaus and lighter weeks, daily steps and habits"],
            ["C. Food and body", "The Indian plate and protein, water and heat, carbs and fats, vegetarian eating, meal timing, body numbers, calories, losing and gaining weight, eating too little, supplements"],
            ["D. Train for your goal", "One chapter for each goal: general fitness, muscle, strength, physique, calisthenics, mobility, kettlebells, running and HYROX"],
            ["E. Staying with it, for life", "Pain and injuries, busy weeks, training at home, training as a woman and after 40, mood, and a closing chapter that puts it all together"],
        ]),
        steps("How to read this book", [
            ("The first line", "Each chapter opens with its main idea in one or two sentences."),
            ("Evidence notes", "Graded by how Levlofit weighs the research it cites: strong means several reviews or large trials agree; moderate means fewer or smaller studies, or mixed results; consensus means expert agreement rather than trial results."),
            ("Levlofit rule", "A number Levlofit uses where research gives no exact figure. Treat it as a sensible starting point, not a research finding."),
            ("Levlofit tip", "Practical advice from Levlofit, not a research finding. Use it if it helps."),
            ("Sources", "Numbered markers point to the full list at the end of each chapter."),
            ("Key points and Up next", "Every chapter ends with a short summary and the chapter to read next."),
        ]),
        table(["Word", "Meaning in this book"], [
            ["Session", "One training appointment, from warm-up to the last set"],
            ["Set and rep", "A rep is one lift; a set is a group of reps done without rest"],
            ["RIR", "Reps in reserve: how many more good reps you could have done"],
            ["Deload", "A planned lighter week to shed fatigue"],
            ["Maintenance", "Eating about as much energy as you burn"],
            ["Level", "Your stage, 0 to 5, in each goal; levels are earned with a level check"],
            ["Protocol", "The app screen where you change your goals, training days and diet"],
            ["Workout", "The app tab with your sessions and level checks"],
        ]),
        compare("This book is", [
            "For healthy adults aged 18 and over; Levlofit plans cover ages 18 to 80",
            "Built on cited guidelines and research, with every number named to its source",
            "A companion to your plan in the app",
        ], "This book is not", [
            "Medical advice, or a replacement for your doctor, physiotherapist or dietitian",
            "Written for children or teenagers, who have their own activity guidelines",
            "A plan for pregnancy or a medical condition without your doctor's input",
        ]),
        evidence("WHO gives separate physical activity recommendations for children and adolescents aged 5 to 17, so this adult book does not apply to them.", "who2020", "strong"),
        rule("Start with the next chapter, Safe to start. If any of its questions apply to you, see a doctor before you train."),
    ],
}

CH["cardio-intensity"] = {
    "slug": "cardio-intensity",
    "part": "A",
    "title": "Easy, moderate and hard cardio",
    "summary": "How to judge cardio effort on a 0 to 10 scale, and how moderate and vigorous minutes add up.",
    "minutes": 3,
    "sources": ["who2020"],
    "blocks": [
        lead("Cardio guidelines count minutes of moderate or vigorous activity. You can judge both without a heart-rate monitor by rating your effort from 0 to 10, relative to your own fitness."),
        scale("Effort out of 10, relative to your fitness", [
            ("2 to 4", "Light", "Everyday movement such as slow walking."),
            ("5 to 6", "Moderate", "Counts toward 150 to 300 minutes a week."),
            ("7 to 8", "Vigorous", "Counts toward 75 to 150 minutes a week."),
        ], "who2020"),
        bars("Three ways to meet the weekly minimum", "minutes", [
            ("All moderate", 150, "150 min"),
            ("All vigorous", 75, "75 min"),
            ("Mixed: 90 moderate plus 30 vigorous", 120, "120 min"),
        ], None),
        steps("Worked example: a mixed week", [
            ("Moderate", "Brisk walk, 30 minutes on Monday, Wednesday and Friday: 90 moderate minutes."),
            ("Vigorous", "Jog, 15 minutes on Tuesday and Saturday: 30 vigorous minutes."),
            ("Add up", "One vigorous minute counts as two moderate ones, so 90 + 2 x 30 = 150. The minimum is met."),
        ]),
        evidence("WHO rates light activity at 2 to 4, moderate at 5 or 6 and vigorous at 7 or 8 on a 0 to 10 scale of perceived exertion, relative to each person's capacity.", "who2020", "consensus"),
        rule("Running uses a talk test for the same idea; see the Running chapter. Lifting uses a different scale, reps in reserve, in the next chapter."),
    ],
}

CH["technique"] = {
    "slug": "technique",
    "part": "A",
    "title": "Learning a lift",
    "summary": "The six movement patterns, how to learn a new exercise, and when to add weight.",
    "minutes": 3,
    "sources": ["zourdos2016"],
    "blocks": [
        lead("Good technique means repeating the same movement, under control, through a range you own. Learn each lift light, and add weight only when every rep looks and feels the same."),
        table(["Pattern", "Example", "Main muscles"], [
            ["Squat", "Goblet squat", "Thighs and hips"],
            ["Hinge", "Romanian deadlift", "Hamstrings, hips and back"],
            ["Push", "Push-up, bench press", "Chest, shoulders and triceps"],
            ["Pull", "Row, pull-up", "Back and biceps"],
            ["Single leg", "Split squat, step-up", "Legs and balance"],
            ["Carry", "Farmers carry", "Grip and trunk"],
        ]),
        steps("Learning a new lift: Levlofit rules", [
            ("Start light", "Bodyweight, a light dumbbell or an empty bar."),
            ("Same setup", "Place your feet, hands and grip the same way on every rep."),
            ("Control the way down", "Lower the weight under control instead of dropping into the bottom."),
            ("Use the range you own", "Go as deep as you can while keeping your position, without pain."),
            ("Check it", "Film one set from the side and compare it with the exercise demo."),
            ("Then add weight", "Only when every rep looks the same, keeping 2 to 3 reps in reserve while you learn."),
        ]),
        compare("Ready for more weight", [
            "Every rep has the same speed and shape",
            "You finish the set with reps in reserve",
            "No pain in any joint, during or the next day",
        ], "Fix before adding weight", [
            "Reps change shape or speed as the set goes on",
            "You reach failure earlier than planned",
            "Joint pain during or after the lift; see Soreness, pain and injuries",
        ]),
        cycle("The practice loop", ["Learn it light", "Repeat it often", "Film and check", "Add a little"]),
        rule("These are Levlofit coaching rules, not research findings; technique coaching is hard to test in trials. A qualified coach can check your form in person."),
    ],
}

CH["under-eating"] = {
    "slug": "under-eating",
    "part": "C",
    "title": "Eating too little",
    "summary": "Why Levlofit never sets calories below your resting burn, and the signs that dieting has gone too far.",
    "minutes": 3,
    "sources": ["helms2014", "telemanas2024"],
    "blocks": [
        lead("Eating too little for too long costs muscle, energy and health. Levlofit never sets your calories below your resting burn, but you are the first to notice when eating has become a struggle."),
        stats([("BMR", "", "is the floor: Levlofit never sets your calorie target below your resting burn"),
               ("0", "kcal", "deficit when your BMI is below the healthy range: Levlofit keeps you at maintenance instead")]),
        compare("Signs to slow down the diet", [
            "Weight falling faster than your planned pace for two weeks or more",
            "Strength dropping for several weeks in a row",
            "Constant hunger, poor sleep or low energy",
        ], "Signs to talk to a doctor", [
            "Periods stopping or becoming irregular",
            "Fainting or dizziness",
            "Feeling unable to stop restricting food, bingeing, making yourself sick, or exercising to make up for eating",
            "Thoughts about food, weight or your body taking over most of the day",
        ]),
        flow("Is dieting still right for you?", [
            ("Is your BMI below the healthy range?", "Do not diet. Levlofit keeps you at maintenance and builds strength instead.", "Go to the next question."),
            ("Does any sign in the doctor list apply to you?", "Pause the fat-loss phase and talk to a doctor. If you feel overwhelmed, call Tele-MANAS on 14416, free and confidential.", "Carry on at the planned pace and review every 2 to 3 weeks."),
        ]),
        evidence("In lean athletes, low energy availability is linked to lower testosterone in men and is the proposed cause of missed periods, called athletic amenorrhea, in women.", "helms2014", "moderate"),
        rule("This chapter cannot diagnose anything. Eating disorders are medical conditions that need care from a doctor or specialist."),
    ],
}

CH["putting-it-together"] = {
    "slug": "putting-it-together",
    "part": "E",
    "title": "Putting it together: your first 12 weeks",
    "summary": "The book's main lessons in ten principles, and a sample 12-week journey that uses them.",
    "minutes": 5,
    "sources": ["who2020", "bell2023"],
    "blocks": [
        lead("Everything in this book comes down to a few habits repeated for months. This chapter gathers them into ten principles and shows how they fit into a first 12 weeks."),
        steps("Ten principles from this book", [
            ("Start safely", "Answer the questions in Safe to start before you train hard."),
            ("Push hard enough", "End most working sets with 1 to 3 reps in reserve."),
            ("Progress slowly", "Add a rep, a set, a kilo or a minute at a time."),
            ("Own the technique", "Learn each lift light; add weight only when every rep looks the same."),
            ("Move most days", "150 to 300 minutes of moderate cardio and 2 strength days a week."),
            ("Recover", "Sleep 7 or more hours, and take a deload when fatigue builds."),
            ("Eat for your goal", "Build the plate first, then reach your protein target."),
            ("One goal at a time", "Build your main goal before adding others."),
            ("Read trends", "Judge weight, tape and strength over weeks, not days."),
            ("Respect pain", "Train around soreness; stop for sharp, joint or worsening pain."),
        ]),
        table(["Weeks", "Training", "Food and recovery", "Check"], [
            ["1 to 2", "Learn the moves: 2 to 3 full-body sessions, light weights, 2 to 3 reps in reserve; walk most days", "Build the plate; find your protein foods; set a sleep routine", "Starting weight, waist and photos; first training logs"],
            ["3 to 6", "Double progression on the main lifts at 2 to 3 reps in reserve; build cardio toward 150 minutes", "Reach your protein target most days", "Weekly weight trend; tape at week 4"],
            ["7 to 8", "Keep progressing; add a set where you recover well", "Change calories only after 2 to 3 weeks of trend", "Take a level check if your plan offers one"],
            ["9", "Deload: about half the sets, lighter effort", "Same food", "Note how you feel"],
            ["10 to 12", "Build again, a little heavier; retest a lift or a 5 km walk-run", "Review your phase: lose, gain or maintain", "Photos and tape; choose the next block"],
        ]),
        compare("Signs it is working", [
            "Weights or reps going up",
            "Weight and waist trends at the planned pace",
            "Sleep steady and you look forward to sessions",
        ], "Signs to change something", [
            "Stuck for 3 weeks or more: see Plateaus and lighter weeks",
            "Pain that changes how you move: see Soreness, pain and injuries",
            "Dreading every session: see Mood, stress and motivation",
        ]),
        cycle("After week 12", ["Review the block", "Choose the next goal or level", "Plan the next block", "Repeat"]),
        rule("This 12-week journey is an example, not a prescription. Your plan in Levlofit is built from your answers, level and goals; when they differ, follow your plan and ask Levlofit AI why."),
    ],
}

# ------------------------------------------------------------------ edits to existing chapters

# Water: heat guidance, and the daily water target moved here from Habits (where it did not belong).
CH["water"]["title"] = "Water, sweat and heat"
CH["water"]["summary"] = "How much to drink, how to check your sweat loss, and how to train safely in Indian heat."
water_bars = next(b for b in CH["habits"]["blocks"] if b["t"] == "bars")
CH["habits"]["blocks"].remove(water_bars)
CH["habits"]["sources"] = [s for s in CH["habits"]["sources"] if s != "efsa2010"]
CH["water"]["blocks"].insert(1, water_bars)
CH["water"]["sources"] = CH["water"]["sources"] + ["efsa2010"]
CH["water"]["blocks"].append(compare("Training in heat", [
    "Train in the cooler hours, early morning or evening",
    "Lower the pace or the load on very hot, humid days",
    "Drink before, during and after long sessions",
], "Stop, get into shade and cool down", [
    "Dizziness, nausea or a pounding headache",
    "Confusion, or skin that feels hot while sweating stops",
    "Get medical help at once if these do not ease quickly",
]))

# Women: pregnancy guidance from WHO 2020, and the after-birth gap stated plainly.
CH["women"]["summary"] = "Lifting, the menstrual cycle, pregnancy and after birth: what the evidence says."
CH["women"]["blocks"].insert(len(CH["women"]["blocks"]), evidence(
    "WHO advises pregnant and postpartum women without contraindications to stay active throughout pregnancy and after birth, with at least 150 minutes of moderate aerobic activity a week and a mix of aerobic and muscle-strengthening work. Women who were active before pregnancy can usually continue.",
    "who2020", "strong"))
CH["women"]["blocks"].append(rule("After giving birth: Levlofit does not yet have an after-birth setting. Ask your doctor or midwife when and how to restart, especially after a caesarean or a difficult birth."))
if "who2020" not in CH["women"]["sources"]:
    CH["women"]["sources"] = CH["women"]["sources"] + ["who2020"]

# Over 40: the plan's age range.
CH["over-40"]["blocks"].append(rule("Levlofit builds plans for ages 18 to 80. Over 65, or living with a long-term condition? Read Safe to start again and check with your doctor before hard training."))

# Worked examples.
CH["calories"]["blocks"].insert(4, steps("Worked example", [
    ("The person", "A 30-year-old man, 70 kg and 175 cm, training 3 days a week."),
    ("BMR", "10 x 70 + 6.25 x 175 - 5 x 30 + 5 = about 1,650 kcal a day."),
    ("Activity", "Light activity: 1,650 x 1.375 = about 2,270 kcal a day at maintenance."),
    ("Goal", "Fat loss, about 15% below: about 1,930 kcal a day, well above the BMR floor."),
]))
CH["food-basics"]["blocks"].insert(3, steps("Worked example: protein for a 60 kg adult", [
    ("Daily target", "1.4 to 2.0 g per kg: 84 to 120 g of protein a day."),
    ("Spread it", "Four meals of 20 to 30 g each."),
    ("On the plate", "For example dal and curd at lunch, paneer or eggs at dinner, milk or chana as a snack."),
]))

# One word for one thing: "session" for a training appointment ("workout" stays only in HYROX's official wording).
edit_text("busy-weeks", "20-minute hotel room workout", "20-minute hotel room session")
edit_text("soreness-pain-injury", "Soreness after a new workout is normal.", "Soreness after a new session is normal.")

# Frequency vs weekly sets (resolved from ACSM 2026, already read in full): muscle growth did not depend on how many days
# a week a muscle was trained once weekly volume was equal; "at least twice weekly" is ACSM's general advice for all
# adults, kept in How training works and Sets, reps and progress. Building muscle now says the same thing.
edit_text("build-muscle", "Training each muscle twice a week", "Reaching your weekly sets, split across the week however suits you")

# Decision 2 (PROVISIONAL, pending evidence review; docs/handbook_v4_review/DECISIONS.md): option C, cautious wording.
# The cited source (Wilson 2012) has not been read; ACSM 2026 reports insufficient data on cardio and weights in the
# same session. The claims stay flagged source_access / source_needed and content_decision.
reword("one-step-at-a-time", "Lots of running would compete with your strength work",
       "Lots of running may compete with your strength work")
reword("one-step-at-a-time", "on strength and size from frequent, long running sessions",
       "with strength and size gains from frequent, long running sessions; the evidence is mixed")
_st = next(b for b in CH["one-step-at-a-time"]["blocks"] if b["t"] == "stats" and b["items"][0]["unit"] == "interference")
_st["items"][0]["value"] = "Possible"          # was "More"
REWORDS.append(("one-step-at-a-time", "More · interference", "Possible · interference"))   # rendered form, for gate carry
reword("one-step-at-a-time",
       "Combining endurance and strength training costs some strength, size and especially power gains, and the cost grows with how often and how long the endurance sessions are.",
       "Some studies suggest that frequent or long endurance sessions may reduce strength, size and especially power gains from lifting; the evidence is mixed and the cited review is still being checked.")
reword("hyrox", "Running and lifting in one plan works; keeping hard runs and leg sessions apart limits interference with strength.",
       "Running and lifting can share one plan. Keeping hard runs and leg sessions apart may limit any interference with strength; the evidence is mixed.")
# Decision 3 (PROVISIONAL, pending evidence review): option B. ICMR 2024 supports getting all essential amino acids
# from combined plant foods; no read source shows muscle gain on vegan diets directly. The "upper end" advice has no
# source: kept as a labelled Levlofit rule, still flagged source_needed.
reword("veg-protein",
       "You can build muscle on a vegetarian or vegan diet. It takes planning: protein-dense foods at every meal and a mix of sources.",
       "Vegetarian and vegan diets can support muscle gain when protein is planned carefully: protein-dense foods at every meal and a mix of sources. Direct evidence in vegan diets is limited.")
reword("veg-protein", "Peanuts; aim for the upper end of your protein range",
       "Peanuts; Levlofit rule, not a research finding: aim for the upper end of your protein range")
# Decision 4 (PROVISIONAL, pending source and clinical review): option C, then the owner decision of 2026-10-18:
# the 630 mg (9 mg/kg) example is removed from the v3 source itself (bar and stat), until a source and a clinical
# justification exist. A caution is added without any numeric daily limit (no source read).
_i = next(i for i, b in enumerate(CH["supplements"]["blocks"]) if b["t"] == "bars" and b["title"] == "Caffeine for a 70 kg person")  # edit_text rebuilds blocks
CH["supplements"]["blocks"].insert(_i + 1, steps("Caffeine caution", [
    ("Count your whole day", "Coffee, tea, colas, energy drinks and pre-workouts all add up; plan the dose before training around the rest of your day."),
    ("Pregnant or on hormonal contraception?", "Your body may clear caffeine more slowly; if you are pregnant, ask your doctor before using caffeine for training."),
    ("High blood pressure or a heart condition?", "Talk to your doctor first; in some people more caffeine is linked to higher blood pressure."),
    ("Sleep", "Avoid caffeine in the hours before bed; it can delay sleep and shorten it."),
]))

# Owner decision 2026-10-18 (unsupported scientific claims removed, practical advice labelled as Levlofit tips or
# rules) is applied in data/build_handbook.py, so v3 and this draft carry the same wording.
# Decision 5 (owner chose option B, 2026-10-14; wording pending review): align rest wording with ACSM 2026 (read).
# ACSM: "Strength was not affected by ... short (<1 min) versus long (>1 min) between-set rest intervals"; hypertrophy:
# insufficient data. Timer durations are Levlofit rules (the app timer is unchanged: 120 s compound lifts, 90 s others).
# Grgic 2018 and Grgic 2017 remain unread; the muscle-growth bar stays flagged until Grgic 2017 is read.
_rest = CH["rest-between-sets"]
_rb = next(b for b in _rest["blocks"] if b["t"] == "bars" and b["title"] == "Rest to aim for")
_rb["source"] = None
_rb["items"] = [
    {"label": "Big lifts (Levlofit rule)", "value": 2, "note": "about 2 min"},
    {"label": "Muscle building (evidence under review)", "value": 1.5, "note": "over 1 min"},
    {"label": "Other exercises (Levlofit rule)", "value": 1.5, "note": "about 90 s"},
]
REWORDS += [("rest-between-sets", "Big lifts for strength · 2 · 2 min or more", "Big lifts (Levlofit rule) · 2 · about 2 min"),
            ("rest-between-sets", "Muscle building · 1.5 · over 1 min", "Muscle building (evidence under review) · 1.5 · over 1 min"),
            ("rest-between-sets", "Light accessory work · 1 · about 1 min", "Other exercises (Levlofit rule) · 1.5 · about 90 s")]
_rs = next(b for b in _rest["blocks"] if b["t"] == "stats" and b["items"][0]["unit"] == "minutes or more")
_rs["items"][0] = {"value": "Similar", "unit": "",
                   "label": "strength outcomes were reported when rests under 1 minute and over 1 minute were compared in the reviews summarised by ACSM 2026",
                   "source": "acsm2026"}
REWORDS.append(("rest-between-sets", "2 · minutes or more · of rest maximises strength gains",
                "Similar · strength outcomes were reported when rests under 1 minute and over 1 minute were compared in the reviews summarised by ACSM 2026"))
_re = next(b for b in _rest["blocks"] if b["t"] == "evidence" and b["text"].startswith("Strength improves with short rests too"))
_old_ev = _re["text"]
_re["text"] = ("Similar strength outcomes were reported when rests under 1 minute and over 1 minute were compared in the reviews "
               "summarised by ACSM 2026. For muscle growth, ACSM found the data insufficient. Rest long enough to repeat good reps.")
_re["source"] = "acsm2026"   # grade left as "moderate" for now: flagged grade_confirm in the register (63% is ACSM's rating, not ours)
REWORDS.append(("rest-between-sets", _old_ev, _re["text"]))
_rest["sources"] = _rest["sources"] + ["acsm2026"]
_gs = next(b for b in CH["get-stronger"]["blocks"] if b["t"] == "stats" and any(i["unit"] == "min rest" for i in b["items"]))
_gi = next(i for i in _gs["items"] if i["unit"] == "min rest")
_gi.update(value="About 2", label="between heavy sets: a Levlofit rule (reviews comparing rests under and over 1 minute reported similar strength outcomes)", source=None)
REWORDS.append(("get-stronger", "2+ · min rest · between heavy sets helps strength",
                "About 2 · min rest · between heavy sets: a Levlofit rule (reviews comparing rests under and over 1 minute reported similar strength outcomes)"))
for _slug, _needle in (("one-step-at-a-time", "Some studies suggest"), ("hyrox", "Running and lifting can share")):
    _b = next(b for b in CH[_slug]["blocks"] if b["t"] == "evidence" and b["text"].startswith(_needle))
    _b["grade"] = "unverified"   # was strong (one-step) / moderate (hyrox); cited source not read

# ------------------------------------------------------------------ evidence round 5 (2026-10-16): match the sources
# Nielsen 2014 (abstract): exploratory cohort, distance-related injuries only, not statistically significant (P = .07).
reword("running",
       "Novice runners who raised weekly distance by more than 30% over two weeks had more overuse injuries than those who added under 10%.",
       "In novice runners, raising weekly distance by more than 30% over two weeks went with more distance-related overuse injuries than adding under 10%, though overall injury rates did not differ; an early, uncertain finding.")
reword("running", "Higher injury risk", "Possibly higher injury risk")
reword("running", "Safer", "Gradual")   # the study did not show the under-10% group was safer overall
# Kotarsky 2018 (abstract): progressive push-ups improved upper-body strength in a small 4-week trial; equivalence
# with the bench press for muscle thickness is not stated in the abstract.
reword("calisthenics", "A controlled trial found progressive push-ups matched the bench press for strength and muscle thickness gains.",
       "In a small 4-week controlled trial, progressive push-ups improved upper-body strength.")
_cs = next(b for b in CH["calisthenics"]["blocks"] if b["t"] == "stats" and b["items"][0]["value"] == "Similar")
_cs["items"][0].update(value="Real", label="upper-body strength gains from progressive push-ups in a small trial")
REWORDS.append(("calisthenics", "Similar · strength and muscle gains from progressive push-ups as from bench press",
                "Real · upper-body strength gains from progressive push-ups in a small trial"))   # rendered form, for gate carry

# ------------------------------------------------------------------ evidence round 6 (2026-10-16): open full texts
# Each rewording says what an open-access full text (or, where marked, an abstract) states; audit_round6.py records it.
reword("sleep-recovery", "You train in the gym and improve while you rest. Sleep is part of the plan, not time off from it.",
       "Sleep is part of training: in studies with athletes, sleeping longer and short naps improved performance.")
reword("carbs-fibre-fats", "Add fibre slowly over a week or two and drink water with it, so your gut can adjust.",
       "A big jump in fibre can bring bloating: in one trial, bloating became more common on high-fibre diets. "
       "Levlofit tip: add fibre over a week or two and drink water with it.")
# Konrad 2024: hold time, volume and frequency did not significantly change range-of-motion gains.
reword("mobility", "Holding stretches 30 to 60 s, most days", "Regular static stretching; hold time and frequency mattered little in studies")
reword("mobility", "Stretching only once a week", "Holding stretches 60 s or longer right before heavy lifting")
reword("kettlebells", "One kettlebell trains strength, power and conditioning. The swing is the centre of it all.",
       "One kettlebell can build strength and power: six weeks of twice-weekly swings improved both in a trial. The swing is the centre of it all.")
reword("women", "Women respond to training the same way men do. Lifting builds strength and shape, not bulk, unless that is the goal.",
       "Women build muscle much as men do: across studies, muscle grew by a similar percentage in women and men.")
for _slug, _keys in {"sleep-recovery": ["cunha2023"], "carbs-fibre-fats": ["zhang2020"], "mobility": ["konrad2024"], "women": ["refalo2025"],
                     "calories": ["manore2017"], "warm-up": ["wilson2025"], "busy-weeks": ["coetsee2015"]}.items():
    CH[_slug]["sources"] = list(dict.fromkeys(CH[_slug]["sources"] + _keys))

# ------------------------------------------------------------------ reading order and parts

ORDER = [
    ("A", ["welcome", "safety-first", "how-levlofit-works", "how-training-works", "cardio-intensity", "effort-and-rir",
           "technique", "warm-up", "sets-reps-progress", "rest-between-sets", "sleep-recovery"]),
    ("B", ["one-step-at-a-time", "tracking-progress", "plateaus-deloads", "daily-steps", "habits"]),
    ("C", ["food-basics", "water", "carbs-fibre-fats", "veg-protein", "meal-timing", "body-measures", "calories",
           "fat-loss", "muscle-gain", "under-eating", "supplements"]),
    ("D", ["general-fitness", "build-muscle", "get-stronger", "physique", "calisthenics", "mobility", "kettlebells",
           "running", "hyrox"]),
    ("E", ["soreness-pain-injury", "busy-weeks", "home-training", "women", "over-40", "mind-motivation",
           "putting-it-together"]),
]
PART_INTRO = {
    "A": "Start safely, see how Levlofit builds your plan, and learn the training basics every later chapter uses: how adaptation works, how hard to push in cardio and lifting, technique, warming up, sets and reps, rest and sleep.",
    "B": "Progress comes from doing the basics for months. This part covers building one goal at a time, measuring honestly, getting past plateaus with lighter weeks, moving more every day and building habits that last.",
    "C": "Food decides much of what training can do. This part starts with the Indian plate and protein, then covers water and heat, carbs and fats, vegetarian eating, meal timing, body numbers, calories, losing and gaining weight, the warning signs of eating too little, and supplements.",
    "D": "Each chapter applies Part A to one goal. Start with General fitness if you are unsure, then read the chapter for your main goal.",
    "E": "Setbacks, busy weeks, training at home, training as a woman and after 40, and looking after your mood. The book closes by putting every lesson together in a sample 12-week journey.",
}
TITLE = {c["slug"]: c["title"] for c in CH.values()}

KEY = {
    "welcome": ["The book has five parts: Foundations, Getting better, Food and body, Train for your goal, and Staying with it.",
                "Evidence notes are graded strong, moderate or consensus; Levlofit rules are starting points, not findings.",
                "It is written for adults; it does not replace your doctor."],
    "safety-first": ["Most adults can start today; some should see a doctor first.",
                     "Chest pain, fainting, dizziness or an irregular heartbeat mean stop and get help.",
                     "Some activity is better than none: start low and build slowly."],
    "how-levlofit-works": ["Levels run from 0 to 5 in each goal and are earned with level checks.",
                           "Your answers, your level and cited rules decide your plan; Levlofit AI explains, it does not invent numbers.",
                           "Goals, days and diet can change anytime in Protocol; levels are earned."],
    "how-training-works": ["Training is a signal: stress, recover, adapt, then do a little more.",
                           "Adults need 150 to 300 minutes of moderate cardio, or 75 to 150 vigorous, and 2 strength days a week.",
                           "Hard sets for all major muscles at least twice a week matter more than fine details."],
    "cardio-intensity": ["Rate cardio effort 0 to 10: 5 or 6 is moderate, 7 or 8 is vigorous.",
                         "One vigorous minute counts like two moderate minutes toward the weekly target.",
                         "Mix both to reach at least 150 moderate-equivalent minutes a week."],
    "effort-and-rir": ["Reps in reserve (RIR) is how many more good reps you could have done.",
                       "Most working sets should end 1 to 3 reps short of failure.",
                       "Beginners misjudge RIR at first: leave an extra rep while learning."],
    "technique": ["Six patterns cover most training: squat, hinge, push, pull, single leg and carry.",
                  "Learn each lift light with the same setup and a controlled way down.",
                  "Add weight only when every rep looks the same and nothing hurts."],
    "warm-up": ["Raise, mobilise, rehearse: about 10 minutes before you lift.",
                "Dynamic movement helps; long static holds of 60 seconds or more belong after training.",
                "Finish the warm-up with lighter sets of your first exercise."],
    "sets-reps-progress": ["Match the dose to the goal: heavy for strength, enough hard sets for muscle.",
                           "Double progression: add reps until the top of the range, then add a little weight.",
                           "A deload is a planned lighter week; 4 to 8 weeks between them is common practice."],
    "rest-between-sets": ["Levlofit's timer gives about 2 minutes on big lifts and 90 seconds on other exercises; adjust so you can repeat good reps.",
                          "Similar strength outcomes were reported when rests under and over 1 minute were compared; for muscle growth the evidence is not settled.",
                          "Rest long enough to repeat good reps; the timer helps."],
    "sleep-recovery": ["Adults 18 to 60 need 7 or more hours of sleep regularly.",
                       "Alternate hard and easy days so you recover between hard sessions.",
                       "Falling performance and motivation for over a week are signs of too much fatigue."],
    "one-step-at-a-time": ["Build your main goal and the basics before stacking goals.",
                           "Add a second goal once the main goal reaches Level 2 and you recover well.",
                           "Frequent, long endurance sessions may cost some strength and power; the evidence is mixed."],
    "tracking-progress": ["Use the scale for trends, the tape every 2 to 4 weeks and photos every 4 weeks.",
                          "Weigh at the same time and in the same conditions.",
                          "A heavy day after salty food is water, not fat."],
    "plateaus-deloads": ["Check sleep and food first when progress stalls for 3 weeks.",
                         "A deload keeps the same lifts with less work and easier effort.",
                         "Build for several weeks, deload, then start a little stronger."],
    "daily-steps": ["Walking more is one of the simplest health wins.",
                    "The benefit levels off around 8,000 to 10,000 steps under 60, and 6,000 to 8,000 from 60.",
                    "Walk after meals, take calls standing and use the stairs."],
    "habits": ["New habits took a median of 66 days to feel automatic, with a wide range.",
               "Anchor the habit, start tiny and track it.",
               "Missing one day barely matters; try not to miss twice."],
    "food-basics": ["Build the plate first, then fix protein.",
                    "Training adults: 1.4 to 2.0 g of protein per kg a day, 20 to 40 g per meal.",
                    "Dals, paneer, eggs and chicken are strong Indian protein sources."],
    "water": ["Losing more than 2% of body weight in sweat starts to hurt performance.",
              "Weigh before and after a session to learn your own sweat loss.",
              "In heat, train in cooler hours, slow down, and stop and cool down if you feel unwell."],
    "carbs-fibre-fats": ["Choose whole grains, pulses, fruit and vegetables most days.",
                         "Aim for 25 g or more of fibre a day, and add it slowly.",
                         "Keep total fat at 30% of energy or less, saturated fat at 10% or less and trans fat at 1% or less."],
    "veg-protein": ["Vegetarian and vegan diets can support muscle gain when protein is planned carefully; direct evidence in vegan diets is limited.",
                    "Soya chunks, dals, peanuts and paneer are dense sources.",
                    "Mix pulses and grains through the day."],
    "meal-timing": ["Total calories and protein matter far more than timing.",
                    "Spread 20 to 40 g of protein every 3 to 4 hours.",
                    "Eat a normal meal 2 to 3 hours before training."],
    "body-measures": ["Levlofit uses Indian BMI cut-offs and your waist-to-height ratio.",
                      "Measure your waist midway between the lowest rib and the hip bone.",
                      "BMI screens; it cannot tell muscle from fat."],
    "calories": ["BMR from Mifflin-St Jeor, times an activity multiplier, gives maintenance.",
                 "Fat loss eats about 15% below maintenance, muscle gain about 10% above.",
                 "Change calories only after 2 to 3 weeks of weight trend."],
    "fat-loss": ["Lose about 0.5 to 1% of body weight a week to keep muscle.",
                 "Keep lifting and eat about 2.0 g of protein per kg while dieting.",
                 "A flat week is often water; check 3 weeks of trend before changing anything."],
    "muscle-gain": ["A small surplus, about 10% above maintenance, adds muscle with less fat.",
                    "Protein beyond about 1.6 g per kg gave no extra average muscle gain.",
                    "A big surplus mostly adds fat."],
    "under-eating": ["Levlofit never sets calories below your BMR, and keeps underweight users at maintenance.",
                     "Slow the diet if weight falls faster than planned or strength keeps dropping.",
                     "Missed periods, fainting or a loss of control around food mean talk to a doctor."],
    "supplements": ["Creatine monohydrate, 3 to 5 g a day, is worth it for strength and muscle.",
                    "Caffeine at 3 to 6 mg per kg helps performance; count your whole day's caffeine, avoid it late, and ask your doctor first if pregnant or with high blood pressure or a heart condition.",
                    "Protein powder is simply protein for days when meals fall short."],
    "general-fitness": ["Lift twice a week, move your heart most days and sit less.",
                        "150 to 300 minutes of moderate cardio a week is the target.",
                        "Low fitness carries a large health risk, and higher fitness showed no upper limit of benefit."],
    "build-muscle": ["10 or more hard sets per muscle a week gave the most growth.",
                     "Light and heavy loads both build muscle when sets end close to failure.",
                     "Add reps or weight over time, with most sets ending close to failure."],
    "get-stronger": ["Heavy loads build more maximal strength than light loads.",
                     "Rest about 2 minutes between heavy sets (a Levlofit rule).",
                     "Build for 3 weeks, take a lighter week, then retest."],
    "physique": ["Build muscle first, then lean out.",
                 "Add sets for lagging areas, and keep training legs.",
                 "Judge progress with photos and tape every 2 to 4 weeks."],
    "calisthenics": ["Progress bodyweight moves with leverage, support and range.",
                     "Hit 3 sets of 8 to 12 clean reps, then step up to a harder variation.",
                     "Progressive push-ups built upper-body strength in a small controlled trial."],
    "mobility": ["Full-range strength training improved range of motion as much as stretching.",
                 "Short stretches before training barely affect strength.",
                 "Stretch regularly; across studies, how long and how often mattered little."],
    "kettlebells": ["The swing is a hip hinge: snap the hips, let the arms guide.",
                    "One bell trains strength, power and conditioning.",
                    "Reviews find benefits, but most studies are small."],
    "running": ["Run most of your weekly distance easy, with a little hard work on top.",
                "New runners: increase weekly distance gradually; big jumps raised overuse injuries.",
                "Use run-walk intervals to build up to 5 km."],
    "hyrox": ["HYROX is 8 x 1 km of running, each followed by a workout station.",
              "Train running and strength together; keeping hard runs and leg sessions apart may limit interference.",
              "Practise the stations while tired, and pace the first kilometre."],
    "soreness-pain-injury": ["Dull, even soreness after a new session is normal.",
                             "Sharp, joint, swelling or worsening pain needs care.",
                             "Strength training is one of the best ways to prevent injuries."],
    "busy-weeks": ["Missing a week does not erase months of work.",
                   "Do not double up; restart a little lighter after a long break.",
                   "One or two short full-body sessions keep most of your progress."],
    "home-training": ["Bands and bodyweight can build strength like gym weights.",
                      "Make light loads hard: slow down, go one-sided, pause and take sets close to failure.",
                      "Most gym moves have a home version."],
    "women": ["Women build muscle much as men do: similar percentage gains from the same training.",
              "Menstrual cycle effects on performance are small and individual.",
              "Pregnancy: usually stay active with your doctor's go-ahead; after birth, restart with your doctor's or midwife's advice."],
    "over-40": ["Strength and balance fade with age unless you train them; it is never too late.",
                "Older adults: varied balance and strength work on 3 or more days a week.",
                "Warm up longer and leave 48 hours between hard sessions for the same muscles."],
    "mind-motivation": ["Walking, jogging, yoga and strength training all eased depression in trials.",
                        "On a low day, shrink the session rather than skip it.",
                        "Feeling low for two weeks or more: talk to a doctor. Thoughts of self-harm: call Tele-MANAS on 14416."],
    "putting-it-together": ["Ten principles carry the whole book: safety, effort, progression, technique, movement, recovery, food, focus, trends and pain.",
                            "A first 12 weeks: learn, progress, deload at week 9, then build and review.",
                            "Your own plan comes first; this journey is an example."],
}

NEXT = {
    "welcome": [("safety-first", "Before anything else, check that it is safe for you to start.")],
    "safety-first": [("how-levlofit-works", "With safety covered, see how your plan is built from your answers.")],
    "how-levlofit-works": [("how-training-works", "The plan follows a few rules of how the body adapts; here they are.")],
    "how-training-works": [("cardio-intensity", "The cardio targets count moderate and vigorous minutes; learn to judge them.")],
    "cardio-intensity": [("effort-and-rir", "Lifting has its own effort scale: reps in reserve.")],
    "effort-and-rir": [("technique", "Effort only counts with good form; learn how to learn a lift.")],
    "technique": [("warm-up", "Every session starts by preparing for the first lift.")],
    "warm-up": [("sets-reps-progress", "Warmed up, decide how many sets and reps, and how to progress.")],
    "sets-reps-progress": [("rest-between-sets", "Between those sets, how long should you rest?")],
    "rest-between-sets": [("sleep-recovery", "The biggest rest of all happens at night.")],
    "sleep-recovery": [("one-step-at-a-time", "Part B: with the foundations in place, start building your main goal.")],
    "one-step-at-a-time": [("tracking-progress", "To know if the goal is moving, measure it honestly.")],
    "tracking-progress": [("plateaus-deloads", "When the measurements stop moving, here is what to do.")],
    "plateaus-deloads": [("daily-steps", "Progress also comes from the hours outside training.")],
    "daily-steps": [("habits", "Steps and sessions only add up if they become habits.")],
    "habits": [("food-basics", "Part C: food decides much of what training can do.")],
    "food-basics": [("water", "After food, the next basic is water, especially in Indian heat.")],
    "water": [("carbs-fibre-fats", "Back to the plate: which carbs and fats to choose.")],
    "carbs-fibre-fats": [("veg-protein", "Protein without meat takes planning; here is how.")],
    "veg-protein": [("meal-timing", "Once you know what to eat, see how much timing matters.")],
    "meal-timing": [("body-measures", "Before setting a calorie target, read your body numbers.")],
    "body-measures": [("calories", "Your numbers and activity set your calorie target.")],
    "calories": [("fat-loss", "Eating below maintenance: how to lose fat and keep muscle."),
                 ("muscle-gain", "Or eating above it: how to gain muscle, not just weight.")],
    "fat-loss": [("muscle-gain", "The opposite phase: gaining muscle with a small surplus.")],
    "muscle-gain": [("under-eating", "Whatever the phase, know the signs of eating too little.")],
    "under-eating": [("supplements", "Last in this part: the few supplements worth considering.")],
    "supplements": [("general-fitness", "Part D: apply everything to your goal, starting with general fitness.")],
    "general-fitness": [("build-muscle", "For more muscle, read on."), ("running", "For endurance, jump to Running.")],
    "build-muscle": [("get-stronger", "Muscle and strength overlap; strength adds heavy, practised lifts.")],
    "get-stronger": [("physique", "Muscle in the right places shapes the look.")],
    "physique": [("calisthenics", "No barbell? Your body can be the weight.")],
    "calisthenics": [("mobility", "Strength through full range also builds mobility.")],
    "mobility": [("kettlebells", "One more tool for strength and conditioning: the kettlebell.")],
    "kettlebells": [("running", "From power to endurance: running.")],
    "running": [("hyrox", "Running and strength together: HYROX.")],
    "hyrox": [("soreness-pain-injury", "Part E: staying with it, starting with aches, pain and injuries.")],
    "soreness-pain-injury": [("busy-weeks", "Life also interrupts training; here is how to keep progress.")],
    "busy-weeks": [("home-training", "When you cannot reach a gym, train at home.")],
    "home-training": [("women", "Training through life's stages, starting with training as a woman.")],
    "women": [("over-40", "Training changes a little with age, too.")],
    "over-40": [("mind-motivation", "Body and mind: how training helps mood and how to keep going.")],
    "mind-motivation": [("putting-it-together", "Finally, put the whole book together.")],
    "putting-it-together": [("how-levlofit-works", "Revisit how your plan is built as your level grows."),
                            ("plateaus-deloads", "Come back here when progress stalls."),
                            ("busy-weeks", "And here when life gets busy.")],
}

CHAPTERS = []
for p, slugs in ORDER:
    for n, slug in enumerate(slugs):
        c = CH[slug]
        c["part"] = p
        if n == 0:
            c["blocks"].insert(0, part(f"Part {p}. {PARTS[p]}", PART_INTRO[p]))
        c["blocks"].append(keypoints(KEY[slug]))
        c["blocks"].append(upnext(NEXT[slug]))
        CHAPTERS.append(c)


def check_book():
    slugs = [c["slug"] for c in CHAPTERS]
    assert len(slugs) == len(set(slugs)), "duplicate slug"
    missing = {c["slug"] for c in v3.CHAPTERS} - set(slugs)
    assert not missing, f"v3 chapters missing from the book: {missing}"
    assert set(slugs) == set(CH), f"chapters not placed in ORDER: {set(CH) - set(slugs)}"
    for c in CHAPTERS:
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
            if b["t"] == "next":
                assert all(i["ref"] in TITLE for i in b["items"]), f"{c['slug']}: Up next points to an unknown chapter"
        assert blocks[-1]["t"] == "next" and blocks[-2]["t"] == "keypoints", f"{c['slug']}: missing ending"
    starts = [c["slug"] for c in CHAPTERS if c["blocks"][0]["t"] == "part"]
    assert starts == [s[0] for _, s in ORDER], "each part must open with a part block"


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def main():
    check_book()
    rows = []
    for i, c in enumerate(CHAPTERS, start=1):
        body = " ".join(plain(b) for b in c["blocks"])
        sources = "array[" + ", ".join(q(SRC[k]) for k in c["sources"]) + "]::text[]"
        blocks = json.dumps({"sources": {k: SRC[k] for k in c["sources"]}, "blocks": c["blocks"]}, ensure_ascii=False)
        rows.append(
            f"({i}, {q(c['slug'])}, {q(c['part'])}, {q(PARTS[c['part']])}, {q(c['title'])}, {q(c['summary'])}, {c['minutes']}, "
            f"{q(body)}, {sources}, {q(blocks)}::jsonb)"
        )
    sql = f"""-- DRAFT FOR REVIEW, NOT A MIGRATION. Handbook v4 (one book), {len(rows)} chapters, generated by
-- data/handbook_v4/build_handbook_v4.py. Do not copy into supabase/migrations/ until the content review is done.
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
    out = HERE / "handbook_v4_draft.sql"
    out.write_text(sql, encoding="utf-8", newline="\n")
    print(f"wrote {out.relative_to(ROOT)}: {len(rows)} chapters (draft; supabase/migrations untouched)")


if __name__ == "__main__":
    main()

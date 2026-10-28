// Training sessions with real moves: which exercises a goal's session uses, how much of each, and the screens
// that show them as animated GIFs. Doses follow the Handbook chapter "Sets, reps and progress" (ACSM 2026):
// 2 to 3 sets per lift, a rep range such as 8 to 12, ending sets with 1 to 3 reps in reserve.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'exercise_guide.dart';
import 'exercises.dart';
import 'icons.dart';
import 'main.dart';
import 'progression.dart';
import 'reminders.dart';
import 'theme.dart';
import 'week_schedule.dart' show Json, WeekPlan, addOnMinutes;

enum Tier { none, home, gym }

/// What the user trains with: gym, home dumbbells, or nothing.
Tier tierFor(String? equipment, List<dynamic>? items) => switch (equipment) {
      'gym' => Tier.gym,
      'home' => Tier.home,
      'custom' => (kitFor(equipment, items) ?? const {}).any((k) => k == Kit.dumbbells || k == Kit.kettlebell) ? Tier.home : Tier.none,
      _ => Tier.none,
    };

/// Single pieces of kit the sessions care about, read from the user's own kit list.
enum Kit { dumbbells, kettlebell, pullUpBar, dipBars, bands, bench, barbell }

/// The kit a user listed. Null when it is unknown (gym, the home preset, or no answer): sessions then stay exactly
/// as they were. 'none' means no kit at all. Custom items are matched case-insensitively ("Pull-up bar", "dumbbells").
Set<Kit>? kitFor(String? equipment, List<dynamic>? items) => switch (equipment) {
      'none' => <Kit>{},
      'custom' => {for (final i in items ?? const []) ?_kitWord('$i'.toLowerCase())},
      _ => null,
    };

/// [kitFor] from a profile row.
Set<Kit>? kitOf(Map<String, dynamic> profile) => kitFor(profile['equipment'] as String?, profile['equipment_items'] as List?);

Kit? _kitWord(String s) => s.contains('dumbbell')
    ? Kit.dumbbells
    : s.contains('kettlebell')
        ? Kit.kettlebell
        : RegExp(r'pull[- ]?up|chin[- ]?up').hasMatch(s)
            ? Kit.pullUpBar
            : s.contains('dip')
                ? Kit.dipBars
                : s.contains('band')
                    ? Kit.bands
                    : s.contains('bench')
                        ? Kit.bench
                        : s.contains('barbell')
                            ? Kit.barbell
                            : null;

/// Moves that need one piece of kit, and the swap used when the user's kit list does not include it. Every swap is a
/// move these sessions already use, so it has a working animation, and it trains the same pattern.
const kitSwaps = {
  'lBDjFxJ': (Kit.pullUpBar, 'bZGHsAZ'), // pull-up -> inverted row (a sturdy table or low bar)
  '9WTm7dq': (Kit.dipBars, 'B1EVP9F'), // dip -> incline push-up
  'SpYC0Kp': (Kit.bench, 'I4hDWkc'), // dumbbell bench press -> push-up
  'I3tsCnC': (Kit.pullUpBar, 'iny3m5y'), // hanging leg raise -> dead bug (core, without a bar)
};

/// [ids] with each move the user cannot do swapped out, keeping order and dropping any repeat a swap creates.
List<String> fitKit(List<String> ids, Set<Kit>? kit) {
  if (kit == null) return ids;
  final out = <String>[];
  for (final id in ids) {
    final swap = kitSwaps[id];
    final use = swap == null || kit.contains(swap.$1) ? id : swap.$2;
    if (!out.contains(use)) out.add(use);
  }
  return out;
}

// ExerciseDB ids (public.exercises), all with working animations. Two sessions, A and B, alternate within a week.
const _strength = {
  Tier.gym: [
    ['qXTaZnJ', 'EIeI8Vf', 'fUBheHs', 'wQ2c4XD', 'iny3m5y'], // squat, bench, seated row, RDL, dead bug
    ['ila4NZS', 'znQUdHY', 'RVwzP10', 'RRWFUcw', 'qPEzJjA'], // deadlift, shoulder press, pulldown, lunge, carry
  ],
  Tier.home: [
    ['yn8yg1r', 'SpYC0Kp', 'BJ0Hz5L', 'rR0LJzx', 'iny3m5y'], // goblet squat, DB bench, DB row, DB RDL, dead bug
    ['aXtJhlg', 'A6wtbuL', 'I4hDWkc', 'qPEzJjA', 'RKjH6Lt'], // step-up, overhead press, push-up, carry, side bridge
  ],
  Tier.none: [
    ['QChZi3x', 'I4hDWkc', 'bZGHsAZ', 'u0cNiij', 'iny3m5y'], // squat, push-up, inverted row, glute bridge, dead bug
    ['9E25EOx', 'B1EVP9F', 'wd4ds3s', 'IZVHb27', 'RKjH6Lt'], // split squat, incline push-up, row, lunge, side bridge
  ],
};
const _skillBasics = ['bZGHsAZ', 'B1EVP9F', '9RT8oQW', 'QChZi3x', 'iny3m5y']; // levels 0 and 1
const _skillBuilt = ['lBDjFxJ', 'I4hDWkc', '9WTm7dq', '9E25EOx', 'I3tsCnC']; // pull-up, push-up, dip, split squat, leg raise
const _endurance = ['ealLwvX', 'DFGXwZr', 'oLrKqDH', 'bJYHBIN', '0mB6wHO']; // drills, run, calf raise, stretch
const _hybridKit = ['UHJlbu3', 'IZVHb27', 'dK9394r', 'qPEzJjA', 'oLrKqDH']; // swing, lunge, burpee, carry, run
const _hybridBody = ['LIlE5Tn', 'IZVHb27', 'dK9394r', 'RJgzwny', 'oLrKqDH']; // jump squat, lunge, burpee, climber, run
const _mobility = ['DFGXwZr', '0mB6wHO', '99rWm7w', 'DeDThfG', 'f38OEuO', 'JbC2iaV'];
// Yoga: catalogue poses (seven asanas and a rocking frog stretch), ordered as a floor flow (backbends, hip openers, then twists to finish).
const _yoga = ['DIVyqrU', '01qpYSe', 'bWlZvXh', 'HIgYKAB', '2Dk4xQV', 'K5xgdvI', '2jl9K55', '6sYyrRX'];
const _poseNames = {
  'DIVyqrU': 'Sphinx pose (Salamba Bhujangasana)',
  '01qpYSe': 'Upward-facing dog (Urdhva Mukha Svanasana)',
  'bWlZvXh': 'Butterfly pose (Baddha Konasana)',
  'HIgYKAB': 'Seated wide-angle fold (Upavistha Konasana)',
  '2Dk4xQV': 'Rocking frog stretch', // the catalogue row (looked up 2026-10-16); not Mandukasana
  'K5xgdvI': 'Reclining big toe pose (Supta Padangusthasana), use a strap or towel',
  '2jl9K55': 'Seated twist (Ardha Matsyendrasana)',
  '6sYyrRX': 'Reclining twist (Supta Matsyendrasana)',
};

const _stretches = {'DFGXwZr', '0mB6wHO', '99rWm7w', 'DeDThfG', 'f38OEuO', 'JbC2iaV'};
const _drills = {'ealLwvX'};
const _carries = {'qPEzJjA'};
const _core = {'iny3m5y', 'RKjH6Lt', 'I3tsCnC'};
const _run = 'oLrKqDH';
// Multi-joint lifts get the longer rest.
const _compounds = {'qXTaZnJ', 'EIeI8Vf', 'fUBheHs', 'wQ2c4XD', 'ila4NZS', 'znQUdHY', 'RVwzP10', 'yn8yg1r', 'SpYC0Kp', 'BJ0Hz5L', 'rR0LJzx', 'A6wtbuL', 'lBDjFxJ', '9WTm7dq'};

/// Rest after a set, in seconds: 2 min or more maximises strength on big lifts (Grgic 2018);
/// over 60 s gives a small edge for muscle growth (Singer 2024), so 90 s for the rest.
int restFor(String id) => _compounds.contains(id) ? 120 : 90;

// ---- injury check ---------------------------------------------------------------------------------------------
// The user's injury note is free text (profiles.injuries, up to 300 characters). The check reads five body areas
// from it and compares them with the joints each named move clearly loads. It is a conservative screen, not
// medical advice and not reviewed by a physiotherapist:
//   set aside   moves that put body weight or a heavy load straight through that area (jumping and landing,
//               push-ups on the wrists, overhead pressing and hanging, loaded hip hinges); they leave the session.
//   take care   moves that load the area less directly; they stay, with a note to use a pain-free range or skip.
// Moves not listed below, and injury notes that name no known area, are reported as not checked, never as safe.

enum BodyArea { knee, ankle, wrist, shoulder, lowerBack }

String areaName(BodyArea a) => a == BodyArea.lowerBack ? 'lower back' : a.name;

const _k = BodyArea.knee, _a = BodyArea.ankle, _w = BodyArea.wrist, _s = BodyArea.shoulder, _b = BodyArea.lowerBack;

/// Named moves (names as in the session lists above) -> (label, set aside for, take care with).
const moveLoads = <String, (String, Set<BodyArea>, Set<BodyArea>)>{
  'LIlE5Tn': ('Jump squat', {_k, _a}, {}),
  'dK9394r': ('Burpee', {_k, _a, _w}, {_s}),
  'RJgzwny': ('Mountain climber', {_w}, {_s}),
  'I4hDWkc': ('Push-up', {_w}, {_s}),
  'B1EVP9F': ('Incline push-up', {}, {_w, _s}),
  'znQUdHY': ('Shoulder press', {_s}, {_w}),
  'A6wtbuL': ('Overhead press', {_s}, {_w}),
  '9WTm7dq': ('Dip', {_s}, {_w}),
  'lBDjFxJ': ('Pull-up', {_s}, {}),
  'ila4NZS': ('Deadlift', {_b}, {}),
  'wQ2c4XD': ('Romanian deadlift', {_b}, {}),
  'rR0LJzx': ('Dumbbell Romanian deadlift', {_b}, {}),
  'UHJlbu3': ('Kettlebell swing', {_b}, {}),
  'qXTaZnJ': ('Squat', {}, {_k, _b}),
  'yn8yg1r': ('Goblet squat', {}, {_k}),
  'QChZi3x': ('Squat', {}, {_k}),
  'RRWFUcw': ('Lunge', {}, {_k, _a}),
  'IZVHb27': ('Lunge', {}, {_k, _a}),
  '9E25EOx': ('Split squat', {}, {_k}),
  'aXtJhlg': ('Step-up', {}, {_k, _a}),
  'oLrKqDH': ('Run', {}, {_k, _a}),
  'bJYHBIN': ('Calf raise', {}, {_a}),
  'qPEzJjA': ('Loaded carry', {}, {_b, _w}),
  'EIeI8Vf': ('Bench press', {}, {_s, _w}),
  'SpYC0Kp': ('Dumbbell bench press', {}, {_s, _w}),
  'RVwzP10': ('Pulldown', {}, {_s}),
  // Identified in the catalogue on 2026-10-16 (exercise_guide.dart); loads mirror the closest move above.
  // Hands behind on the floor take body weight with the wrists bent back and the shoulders extended: both set aside.
  '9RT8oQW': ('Bench dip on the floor', {_s, _w}, {}),
  'ealLwvX': ('High knees', {}, {_k, _a}),
  // Leaning back from a hold loads grip and shoulders less than a pull-up, but still loads them.
  'wd4ds3s': ('Standing row', {}, {_w, _s}),
  // 2026-10-17: the rest of the prescribed moves. Hanging from a bar loads the shoulders like a pull-up; the others
  // load an area only lightly, so they keep a care note and never leave the session.
  'I3tsCnC': ('Hanging leg raise', {_s}, {_b}),
  'bZGHsAZ': ('Inverted row', {}, {_s, _w}),
  'BJ0Hz5L': ('Dumbbell row', {}, {_b}),
  'RKjH6Lt': ('Side bridge', {}, {_s}),
  '01qpYSe': ('Upward-facing dog', {}, {_w, _b}),
  'DIVyqrU': ('Sphinx pose', {}, {_b}),
  '2Dk4xQV': ('Rocking frog stretch', {}, {_k}),
  'DFGXwZr': ("World's greatest stretch", {}, {_k}),
  'f38OEuO': ('Kneeling lat stretch', {}, {_k, _s}),
  'JbC2iaV': ('Spine stretch', {}, {_b}),
  'HIgYKAB': ('Seated wide-angle fold', {}, {_b}),
  '2jl9K55': ('Seated twist', {}, {_b}),
  '6sYyrRX': ('Reclining twist', {}, {_b}),
  // Checked and not loading any of the five areas directly:
  '0mB6wHO': ("Runner's stretch", {}, {}),
  '99rWm7w': ('Hamstring stretch', {}, {}),
  'DeDThfG': ('Seated glute stretch', {}, {}),
  'bWlZvXh': ('Butterfly pose', {}, {}),
  'K5xgdvI': ('Reclining big toe pose', {}, {}),
  'fUBheHs': ('Seated row', {}, {}),
  'u0cNiij': ('Glute bridge', {}, {}),
  'iny3m5y': ('Dead bug', {}, {}),
};

final _areaWords = <BodyArea, RegExp>{
  BodyArea.knee: RegExp(r'\bknees?\b|\bacl\b|\bmcl\b|menisc|patell'),
  BodyArea.ankle: RegExp(r'\bankles?\b|achilles'),
  BodyArea.wrist: RegExp(r'\bwrists?\b|carpal'),
  BodyArea.shoulder: RegExp(r'\bshoulders?\b|rotator|\bcuff\b'),
  BodyArea.lowerBack: RegExp(r'(?<!upper )\bback\b|backache|\bdisc\b|herniat|sciatica|lumbar|\bspine\b|spinal'),
};
// Body parts the check does not cover; a note naming one is reported as only partly checked.
final _otherWords = RegExp(r'\bhips?\b|\bnecks?\b|\belbows?\b|upper back|\bfoot\b|\bfeet\b|\btoes?\b|hamstring|groin|\bcalf\b|\bcalves\b|'
    r'quad|\bchest\b|\bribs?\b|\bhands?\b|\bfingers?\b|\bthumb|\bhead\b|\bjaw\b|\bgluteal|\bshin|\bheel|plantar|\btendon|\bligament|\bfracture|\bsurgery|\bthigh');
final _noInjury = RegExp(r'^(no|none|nil|na|n/a|nothing|no injur(y|ies)|no pain|not really|-+|\.+)\.?$');

/// What the free-text note names: the areas the check covers, and whether it also says something it cannot map.
/// Null when there is no note. A negated area ("no knee pain") still counts, so the check errs toward caution.
({Set<BodyArea> areas, bool unmatched})? readInjury(String? text) {
  final t = (text ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty || _noInjury.hasMatch(t)) return null;
  final areas = {for (final e in _areaWords.entries) if (e.value.hasMatch(t)) e.key};
  return (areas: areas, unmatched: areas.isEmpty || _otherWords.hasMatch(t));
}

typedef InjuryCheck = ({
  List<String> ids, // the session after setting moves aside
  List<String> setAside,
  Map<String, Set<BodyArea>> care, // kept moves that load a reported area less directly
  List<String> notAssessed, // kept moves this check has no information about
  ({Set<BodyArea> areas, bool unmatched})? note,
});

/// Applies the injury note to a session. With no note the session is returned unchanged.
InjuryCheck checkInjury(List<String> ids, String? injury) {
  final note = readInjury(injury);
  if (note == null) return (ids: ids, setAside: const [], care: const {}, notAssessed: const [], note: null);
  final setAside = <String>[], kept = <String>[], care = <String, Set<BodyArea>>{}, notAssessed = <String>[];
  for (final id in ids) {
    final load = moveLoads[id];
    if (load == null) {
      kept.add(id);
      notAssessed.add(id);
    } else if (load.$2.intersection(note.areas).isNotEmpty) {
      setAside.add(id);
    } else {
      kept.add(id);
      final c = load.$3.intersection(note.areas);
      if (c.isNotEmpty) care[id] = c;
    }
  }
  return (ids: kept, setAside: setAside, care: care, notAssessed: notAssessed, note: note);
}

/// The lines the session shows about the injury check; empty when there is no note.
List<String> injuryNotice(InjuryCheck c) {
  final note = c.note;
  if (note == null) return const [];
  final areas = note.areas.map(areaName).join(', ');
  return [
    if (note.areas.isEmpty)
      'Your injury note does not name a body part Levlofit can check (knee, ankle, wrist, shoulder or lower back), so these moves were not checked against it.'
    else
      'You noted an injury (read as: $areas). This is a simple screen, not medical advice.',
    if (note.areas.isNotEmpty && note.unmatched) 'Part of your note names something Levlofit cannot check, so not every risk is covered.',
    if (c.setAside.isNotEmpty) 'Set aside today: ${c.setAside.map((id) => moveLoads[id]!.$1).join(', ')}.',
    if (note.areas.isNotEmpty && c.notAssessed.isNotEmpty)
      '${c.notAssessed.length} ${c.notAssessed.length == 1 ? 'move was' : 'moves were'} not checked against your injury.',
    'Stop any move that hurts, and see a physiotherapist or doctor for pain that persists.',
  ];
}

/// The note on a kept move that loads a reported area.
String careNote(Set<BodyArea> areas) => 'Loads your ${areas.map(areaName).join(' and ')}: use a pain-free range, or skip it.';

/// Exercise ids for one session of [kind] at [level]. [index] is which session of that goal this is in the week.
/// [kit] (from [kitFor]) swaps out moves that need kit the user does not have; null keeps the lists unchanged.
List<String> sessionIds(String kind, Tier tier, int level, int index, {String? goal, Set<Kit>? kit}) => fitKit(
      switch (kind) {
        _ when goal == 'yoga' => _yoga,
        'skill' => level <= 1 ? _skillBasics : _skillBuilt,
        'endurance' => _endurance,
        'hybrid' => tier == Tier.none ? _hybridBody : _hybridKit,
        'mobility' => _mobility,
        _ => _strength[tier]![index % 2],
      },
      kit,
    );

/// Lifts log reps and kilograms per set; everything else is just ticked.
bool isLift(String id) => setsFor(id, 1) > 0 && !_carries.contains(id) && !_core.contains(id);

typedef SetLog = ({int reps, double? kg});

/// The coach's next step for a lift, from last session's sets, by double progression (Handbook,
/// "Sets, reps and progress", ACSM 2026): stay at a weight until every set reaches 12 reps, then add the
/// smallest weight step you have and work back up from 8.
String nextStep(List<SetLog> last) {
  if (last.isEmpty) return 'First time: pick a weight you can lift 8 to 12 times with 1 to 3 reps left.';
  final kg = last.first.kg;
  final at = kg == null || kg == 0 ? 'bodyweight' : '${kg % 1 == 0 ? kg.toInt() : kg} kg';
  final reps = last.map((x) => x.reps).join(', ');
  if (last.every((x) => x.reps >= 12)) return 'Last time $reps at $at. Every set hit 12: add the smallest weight step today and aim for 8 or more.';
  return 'Last time $reps at $at. Same weight today; beat at least one of those numbers.';
}

/// Sets to tick on the session screen; 0 when the move is done once (run, stretch, drill).
int setsFor(String id, int level, {bool lighter = false}) {
  final sets = _stretches.contains(id) || _poseNames.containsKey(id) || _drills.contains(id) || id == _run ? 0 : (level <= 1 ? 2 : 3);
  // A lighter day the person confirmed with Levlofit AI (batch 3b): one set fewer, never below one.
  return lighter && sets > 1 ? sets - 1 : sets;
}

/// Sets the session asks for: every move that loaded, so a missing move never leaves the session unfinishable.
int totalSets(List<String> ids, List<String> missing, int level) =>
    ids.where((id) => !missing.contains(id)).fold(0, (s, id) => s + setsFor(id, level));

/// Rough minutes for a session as prescribed: 5 min warm-up, about 40 s of work per set plus the rest shown after
/// it, 1 min per hold or drill. A Levlofit planning estimate, not a measured time. Null when the session has a run
/// block, whose length the session does not set.
int? estimateMinutes(List<String> ids, int level) {
  if (ids.contains(_run)) return null;
  return ((300 + ids.fold(0, (s, id) => s + _moveSeconds(id, level))) / 60).round();
}

/// The notice when the estimate runs past the person's session length (5 min of slack), else null.
String? overTimeNotice(int? estimate, int? sessionMinutes) => estimate == null || sessionMinutes == null || estimate <= sessionMinutes + 5
    ? null
    : 'With the rests shown, this session takes about $estimate min, longer than your $sessionMinutes-minute setting.';

/// A session fitted to the person's session length: the moves to show, the ones left out (in session order) and the
/// estimate for what is shown.
typedef TimeFit = ({List<String> ids, List<String> leftOut, int? estimate});

/// Never trims a session below this many moves (a full-body session keeps a lower-body, a push and a pull).
const minMovesWhenShortened = 3;

/// Fits [ids] to [sessionMinutes]. Levlofit rule, COACH REVIEW PENDING together with the estimate's assumptions
/// (PROGRESS batch BA): when the estimate runs past the setting (the over-time notice), leave out the
/// lowest-priority moves, last listed first (core, carries and accessory work come last in every session), until it
/// fits. Main multi-joint lifts (the ones with the longer rest) are never left out, a session keeps at least
/// [minMovesWhenShortened] moves, and no set or dose changes. Unchanged when it already fits, when there is no
/// setting, or when the session cannot be estimated (a run block). It may still run over when only protected moves
/// are left; the over-time notice then still shows.
TimeFit fitToTime(List<String> ids, int level, int? sessionMinutes) {
  var estimate = estimateMinutes(ids, level);
  bool over() => overTimeNotice(estimate, sessionMinutes) != null;
  if (!over()) return (ids: ids, leftOut: const [], estimate: estimate);
  final keep = [...ids];
  final leftOut = <String>[];
  for (var i = keep.length - 1; i >= 0 && over() && keep.length > minMovesWhenShortened; i--) {
    if (_compounds.contains(keep[i])) continue;
    leftOut.insert(0, keep.removeAt(i));
    estimate = estimateMinutes(keep, level);
  }
  return (ids: keep, leftOut: leftOut, estimate: estimate);
}

/// The line above a shortened session. [names] are the left-out moves' names, in session order.
String shortenedNotice(List<String> names, int? estimate, int sessionMinutes) =>
    'Shortened to fit your $sessionMinutes-minute setting: ${names.join(', ')} ${names.length == 1 ? 'is' : 'are'} left out today'
    '${estimate == null ? '' : ' (about $estimate min now)'}. The main lifts stay as planned.';

// ---- add-on blocks ---------------------------------------------------------------------------------------------
// The plan engine turns lower-priority goals (and the strength days missing for the WHO minimum) into 20-minute
// add-on blocks. A block is real moves from that goal's own session, at that goal's level, with the person's kit.
// Levlofit rules, COACH REVIEW PENDING together with the session estimate (PROGRESS batch BA): first-listed moves
// first (main lifts lead every session list), as many as the 20 minutes hold; an endurance block is the warm-up drill
// and an easy run filling the time; moves already in the day's main session are not repeated.

/// One add-on block. [minutes] is its estimate when it follows a warmed-up session (no warm-up of its own).
typedef AddOnBlock = ({String name, String goal, String kind, int level, List<String> ids, int minutes});

/// Seconds a move takes as prescribed: about 40 s of work per set plus the rest after it; 1 min per hold or drill.
int _moveSeconds(String id, int level) {
  final sets = setsFor(id, level);
  return sets == 0 ? 60 : sets * (40 + restFor(id));
}

/// Minutes for a block of [ids] at [level]; a block with the easy run always takes the whole add-on time.
int blockMinutes(List<String> ids, int level) =>
    ids.contains(_run) ? addOnMinutes : (ids.fold(0, (s, id) => s + _moveSeconds(id, level)) / 60).round();

/// The block for the session [spec] (a plan goal, or the extra-strength session), never repeating [exclude]. The
/// week's other session variant fills in when the first one is already in the day. Empty (0 min) only when every
/// move of the goal is already in the day.
AddOnBlock addOnBlock(Json spec, Tier tier, {Set<Kit>? kit, List<String> exclude = const [], int index = 0}) {
  final kind = spec['kind'] as String? ?? 'strength';
  final goal = spec['goal'] as String? ?? kind;
  final level = spec['startLevel'] as int? ?? 0;
  final candidates = <String>{
    for (var i = 0; i < 2; i++)
      for (final id in sessionIds(kind, tier, level, index + i, goal: goal, kit: kit))
        if (!exclude.contains(id)) id,
  }.toList();
  final ids = <String>[];
  if (kind == 'endurance' && candidates.contains(_run)) {
    ids.addAll([if (candidates.contains('ealLwvX')) 'ealLwvX', _run]);
  } else {
    var seconds = 0;
    for (final id in candidates.where((id) => id != _run)) {
      final s = _moveSeconds(id, level);
      if (ids.isNotEmpty && seconds + s > addOnMinutes * 60) continue;
      ids.add(id);
      seconds += s;
    }
  }
  return (name: (spec['name'] ?? goal) as String, goal: goal, kind: kind, level: level, ids: ids, minutes: ids.isEmpty ? 0 : blockMinutes(ids, level));
}

/// The block's header line on the session screen.
String blockSummary(AddOnBlock b) => b.ids.isEmpty
    ? 'Add-on: ${b.name}. Every move is already covered by today\'s session.'
    : b.ids.contains(_run)
        ? 'Add-on: ${b.name}  ·  about ${b.minutes} min: the drill, then an easy run for the rest of the time'
        : 'Add-on: ${b.name}  ·  about ${b.minutes} min';

/// A day fitted to the person's session length: the main session's fit, the blocks as kept, the block moves left out
/// (in block order) and the estimate for everything shown.
typedef DayFit = ({TimeFit main, List<AddOnBlock> blocks, List<String> blockLeftOut, int? estimate});

/// Fits a day: the main session and its add-on blocks against [sessionMinutes] (5 min of slack, as [overTimeNotice]).
/// The main session first gives up its accessories under [fitToTime] (budget: the setting less the blocks' minutes);
/// then blocks lose moves, last block and last move first, keeping one move each. Main lifts and doses never change.
/// A run session cannot be estimated, so nothing is trimmed then. Still over afterwards: the over-time notice shows.
DayFit fitDay(List<String> ids, int level, List<AddOnBlock> blocks, int? sessionMinutes) {
  int blocksTotal(List<AddOnBlock> bs) => bs.fold(0, (s, b) => s + b.minutes);
  final main = fitToTime(ids, level, sessionMinutes == null || blocks.isEmpty ? sessionMinutes : sessionMinutes - blocksTotal(blocks));
  final kept = [...blocks];
  final leftOut = <String>[];
  int? total() => main.estimate == null ? null : main.estimate! + blocksTotal(kept);
  for (var i = kept.length - 1; i >= 0 && overTimeNotice(total(), sessionMinutes) != null; i--) {
    var b = kept[i];
    while (b.ids.length > 1 && !b.ids.contains(_run) && overTimeNotice(total(), sessionMinutes) != null) {
      final ids = b.ids.sublist(0, b.ids.length - 1);
      leftOut.insert(0, b.ids.last);
      b = (name: b.name, goal: b.goal, kind: b.kind, level: b.level, ids: ids, minutes: blockMinutes(ids, b.level));
      kept[i] = b;
    }
  }
  return (main: main, blocks: kept, blockLeftOut: leftOut, estimate: total());
}

/// The planning estimate of a goal's main session, for placing add-on blocks in the week (no injury check: it can
/// only make a session shorter).
int? Function(Json session, int nth) sessionEstimator(Tier tier, Set<Kit>? kit) => (s, nth) {
      final level = s['startLevel'] as int? ?? 0;
      return estimateMinutes(sessionIds(s['kind'] as String? ?? 'strength', tier, level, nth, goal: s['goal'] as String?, kit: kit), level);
    };

/// The add-on blocks of [day] with their moves. [mainIds] is that day's main session (empty on a rest day), whose
/// moves the blocks do not repeat; each block also avoids the moves of the blocks before it.
List<AddOnBlock> blocksFor(WeekPlan week, int day, Tier tier, Set<Kit>? kit, List<String> mainIds) {
  final taken = [...mainIds];
  final out = <AddOnBlock>[];
  for (final (i, a) in week.addOns.indexed) {
    if (a.day != day) continue;
    // A goal's second block in the week starts from its other session variant, as its sessions alternate.
    final nth = week.addOns.take(i).where((x) => x.name == a.name && x.session['goal'] == a.session['goal']).length;
    final b = addOnBlock(a.session, tier, kit: kit, exclude: taken, index: nth);
    taken.addAll(b.ids);
    out.add((name: a.name, goal: b.goal, kind: b.kind, level: b.level, ids: b.ids, minutes: b.minutes)); // named as the week lists it
  }
  return out;
}

/// The line above a session the person made lighter with Levlofit AI.
const lighterNotice = 'Lighter day: one set fewer on each move, and finish every set with 3 or more reps in reserve.';

/// One warm-up step: what to do, how much, and how.
typedef WarmUpStep = ({String move, String dose, String how});

/// The warm-up before the main moves (owner request 2026-10-29), about the 5 minutes [estimateMinutes] already counts:
/// easy pulse-raising work, joint movement, then lighter ramp-up sets of the first lift. Not part of the session's sets
/// and never ticked. Short holds only: the Handbook's warming-up chapter keeps static stretches under 60 s (Behm 2016).
/// Adapted to the session kind, the equipment ([gym]), the level, a lighter day or medical hold, and an injury note.
List<WarmUpStep> warmUpFor({required String kind, required int level, bool gym = false, String? injury, bool light = false}) {
  final hurt = (injury ?? '').toLowerCase();
  bool has(List<String> words) => words.any(hurt.contains);
  final knee = has(['knee', 'ankle', 'hip']), upper = has(['shoulder', 'wrist', 'elbow']), back = has(['back', 'spine', 'disc']);
  final pulse = (
    move: 'Easy cardio',
    dose: '${light ? 3 : 2}–3 minutes',
    how: gym
        ? 'Walk briskly, or use a bike, rower or treadmill at an easy pace, until you feel warm and breathe a little faster.'
        : 'Brisk walking or marching on the spot at an easy pace, until you feel warm and breathe a little faster.',
  );
  final joints = [
    (move: 'Arm circles', dose: '10 forward, 10 back', how: 'Arms out to the sides, small circles growing bigger. Keep it pain-free.'),
    (move: 'Hip circles', dose: '5 each way', how: 'Hands on hips, feet apart, draw slow circles with your hips.'),
    if (back)
      (move: 'Cat-cow', dose: '6 slow reps', how: 'On hands and knees, gently round then arch your back within a comfortable range.')
    else
      (move: 'Hip hinge', dose: '8 slow reps', how: 'Hands on hips, push your hips back with a flat back, then stand tall.'),
    if (knee)
      (move: 'Glute bridge', dose: '10 slow reps', how: 'Lying on your back, knees bent, lift your hips and lower slowly. Skips deep knee bending.')
    else
      (move: 'Bodyweight squat', dose: '${level <= 1 ? 6 : 10} slow reps', how: 'To a comfortable depth, heels down, chest up.'),
    if (upper)
      (move: 'Shoulder blade squeezes', dose: '10 reps', how: 'Arms by your sides, squeeze your shoulder blades together and relax. No weight on your hands.')
    else
      (move: 'Wall push-up', dose: '8 slow reps', how: 'Hands on a wall at shoulder height, lower your chest towards it and push back.'),
  ];
  final specific = switch (kind) {
    'endurance' => (move: 'Very easy jog', dose: '3–5 minutes', how: 'Slower than your main run; you should be able to talk in full sentences.'),
    'mobility' => (move: 'Slow breathing', dose: '5 breaths', how: 'Breathe in through the nose and out slowly before the first pose.'),
    _ => (
        move: 'Ramp-up sets',
        dose: light ? '1 light set of 5 reps' : '1–2 light sets of 5 reps',
        how: 'Before your first main move, do it with about half the weight (or an easier version) to rehearse the movement. '
            'These are not counted in your sets.',
      ),
  };
  return [pulse, ...joints, specific];
}

/// The cooldown after the main moves: easy movement, then short, gentle stretches (holds of 30 s or less, as the
/// Handbook's warming-up chapter advises against long holds before strength work; Behm 2016). Not counted in sets.
List<WarmUpStep> cooldownFor({required String kind}) => [
      (
        move: kind == 'endurance' ? 'Easy walk' : 'Easy walk or slow marching',
        dose: '2–3 minutes',
        how: 'Let your breathing settle before you stop.',
      ),
      (move: 'Gentle stretches', dose: '20–30 seconds each', how: 'Thighs, hips and chest or shoulders: ease into a comfortable stretch, no bouncing, no pain.'),
    ];

/// The line above every session while the plan is on a medical hold (plan-engine 3.2, ACSM pre-participation screen).
const medicalHoldNotice = 'Light training only until a doctor clears you: one set fewer on each move, 3 or more reps in reserve, '
    'and no added weight. Stop and get help for chest pain, dizziness or feeling unwell.';

/// How much of a move, in words. Lifting doses: Handbook "Sets, reps and progress" (ACSM 2026).
/// Stretch holds stay under the 60 s that can blunt strength for a while (Behm 2016).
String doseFor(String id, int level, {bool lighter = false}) {
  final sets = setsFor(id, level, lighter: lighter);
  if (id == _run) return 'Main block at an easy pace you can talk at';
  if (id == '2Dk4xQV') return 'Rock slowly back and forth for 5 slow breaths, within a comfortable stretch';
  if (_poseNames.containsKey(id)) return 'Hold for 5 slow breaths, each side if one-sided';
  if (_stretches.contains(id)) return 'Hold 30 s or less, each side';
  if (_drills.contains(id)) return 'Warm-up, until you feel loose';
  if (_carries.contains(id)) return '$sets walks, stop before grip or posture fades';
  final setWord = sets == 1 ? 'set' : 'sets';
  if (_core.contains(id)) return '$sets $setWord, slow and controlled';
  return lighter ? '$sets $setWord × 8–12 reps, 3 or more left in the tank' : '$sets $setWord × 8–12 reps, 1–3 left in the tank';
}

final _cache = <String, Map<String, dynamic>>{};

/// A session's moves as loaded: [found] in session order, and [missing] ids that have no catalogue row.
typedef Moves = ({List<Map<String, dynamic>> found, List<String> missing});

/// Splits [ids] by whether [rows] has them. Missing ids are reported, never dropped silently.
Moves resolveMoves(List<String> ids, Map<String, Map<String, dynamic>> rows) =>
    (found: [for (final i in ids) ?rows[i]], missing: [for (final i in ids) if (!rows.containsKey(i)) i]);

/// Loads name and GIF for [ids], keeping their order; cached for the app session. In licensed mode (release builds)
/// the rows come from Levlofit's own guide, with no catalogue read and no animation.
Future<Moves> loadMoves(List<String> ids) async {
  if (!exerciseDbContent) {
    return resolveMoves(ids, {for (final i in ids) if (moveGuide[i] case final g?) i: {'id': i, 'name': g.name}});
  }
  final unknown = ids.where((i) => !_cache.containsKey(i)).toList();
  if (unknown.isNotEmpty) {
    try {
      final rows = await supabase.from('exercises').select('id, name, gif_url, target_muscles').inFilter('id', unknown);
      for (final r in rows) {
        _cache[r['id'] as String] = r;
      }
    } catch (e) {
      debugPrint('session: catalogue read failed, using the moves guide: $e');
    }
  }
  // A move the catalogue did not return still has Levlofit's guide entry: keep it in the session under its guide
  // name (ExerciseGif finds its animation by id), instead of leaving it out. Not cached, so a later read can fill it.
  final moves = resolveMoves(ids, {
    ..._cache,
    for (final i in ids)
      if (!_cache.containsKey(i) && moveGuide[i] != null) i: {'id': i, 'name': moveGuide[i]!.name},
  });
  if (moves.missing.isNotEmpty) debugPrint('session: exercise ids not in the catalogue: ${moves.missing.join(', ')}');
  return moves;
}

/// What the user sees when moves could not be loaded.
String missingMovesText(int n) => n == 1
    ? '1 move could not be loaded, so it is left out of this session.'
    : '$n moves could not be loaded, so they are left out of this session.';

String moveName(Map<String, dynamic> m) => _poseNames[m['id']] ?? moveGuide[m['id']]?.name ?? (m['name'] as String).split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// A horizontal strip of animated moves with names and doses. Tapping a move opens its detail.
class MoveStrip extends StatelessWidget {
  const MoveStrip({super.key, required this.ids, required this.level, this.tile = 128, this.injury, this.lighter = false});
  final bool lighter; // a lighter day or a medical hold: the preview shows the dose the session will ask for
  final List<String> ids;
  final int level;
  final double tile;
  final String? injury; // the user's injury note; moves it sets aside are left out and counted

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final check = checkInjury(ids, injury);
    final shown = check.ids;
    return SizedBox(
      height: tile + 54,
      child: FutureBuilder(
        future: loadMoves(shown),
        builder: (context, snap) {
          final moves = snap.data?.found;
          final missingCount = snap.data?.missing.length ?? 0;
          final notes = [
            if (missingCount > 0) missingMovesText(missingCount),
            if (check.setAside.isNotEmpty) '${check.setAside.length} set aside for your injury.',
          ];
          final missing = notes.length;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: moves == null ? shown.length : moves.length + (missing > 0 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (moves != null && i == moves.length) {
                // Moves left out (no catalogue row, or set aside for an injury): say so instead of showing a shorter
                // session without explanation.
                return SizedBox(
                  width: tile,
                  child: Container(
                    height: tile,
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.outline)),
                    child: Text(notes.join(' '), textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  ),
                );
              }
              final m = moves?[i];
              return SizedBox(
                width: tile,
                child: Pressable(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: m == null ? null : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: m['id'] as String))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: tile,
                        height: tile,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.outline)),
                        child: ExerciseGif(m?['gif_url'] as String?, id: m?['id'] as String? ?? (moves == null ? shown[i] : null)),
                      ),
                      const SizedBox(height: 8),
                      Text(m == null ? ' ' : moveName(m), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge),
                      // Flexible: with large system text the second dose line gives way instead of overflowing the strip.
                      Flexible(
                        child: Text(
                          m == null ? ' ' : doseFor(m['id'] as String, level, lighter: lighter),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(fontSize: 11, height: 1.3, color: c.onSurfaceVariant),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// One session, move by move: animation, dose, and a box per set to tick. Finishing logs the day.
class SessionScreen extends StatefulWidget {
  const SessionScreen(
      {super.key, required this.title, required this.ids, required this.level, this.onFinish, this.done = false, this.injury, this.sessionMinutes, this.blocks = const [], this.moves, this.lighter = false, this.medicalHold = false, this.kind = 'strength', this.gym = false});
  final String kind; // the goal's session kind, for the warm-up
  final bool gym; // gym equipment, for the warm-up's cardio options
  final String title;
  final List<String> ids;
  final int level;
  final List<AddOnBlock> blocks; // add-on blocks after the main session, each at its own goal's level
  final Future<Moves> Function(List<String> ids)? moves; // tests only; the app loads from the catalogue
  final Future<bool> Function()? onFinish; // logs today's session and says whether it saved; null when not today's
  final bool done;
  final String? injury; // the user's injury note (profiles.injuries); null keeps the session as planned
  final int? sessionMinutes; // the person's session length, for the over-time notice
  final bool lighter; // a lighter day the person confirmed with Levlofit AI: one set fewer, more reps in reserve
  final bool medicalHold; // plan.medicalHold: a health-screen flag, so every session uses the lighter dose, no added load

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool get _light => widget.lighter || widget.medicalHold;
  // The injury check runs over the whole day; each part (main session, each block) keeps its own moves that passed.
  late final _check = checkInjury([...widget.ids, for (final b in widget.blocks) ...b.ids], widget.injury);
  late final List<AddOnBlock> _blocks = [
    for (final b in widget.blocks)
      if ([for (final id in b.ids) if (_check.ids.contains(id)) id] case final ids)
        (name: b.name, goal: b.goal, kind: b.kind, level: b.level, ids: ids, minutes: ids.isEmpty ? 0 : blockMinutes(ids, b.level)),
  ];
  late final _fit = fitDay([for (final id in widget.ids) if (_check.ids.contains(id)) id], widget.level, _blocks, widget.sessionMinutes);
  late final _levels = {for (final b in _blocks) for (final id in b.ids) id: b.level};
  int _levelOf(String id) => _levels[id] ?? widget.level;
  bool _full = false; // the person chose the full session over the shortened one
  List<String> get _ids => _full ? _check.ids : [..._fit.main.ids, for (final b in _fit.blocks) ...b.ids]; // the moves shown and counted
  List<String> get _leftOut => [..._fit.main.leftOut, ..._fit.blockLeftOut];
  late final _moves = (widget.moves ?? loadMoves)(_check.ids);

  /// The estimate for [shown] moves: the main session's (with its warm-up) plus each block's.
  int? _estimateOf(List<String> shown) {
    final main = estimateMinutes([for (final id in shown) if (!_levels.containsKey(id)) id], widget.level);
    return main == null ? null : main + _blocks.fold(0, (s, b) => s + blockMinutes([for (final id in b.ids) if (shown.contains(id)) id], b.level));
  }
  List<String> _missing = const []; // ids with no catalogue row; their sets do not count
  final _ticked = <String, int>{};
  final _today = <String, List<SetLog>>{}; // sets logged in this session, by move
  Map<String, List<SetLog>> _last = {}; // the previous session's sets, by move
  List<Advice> _advice = const []; // notes from earlier sessions: pain, a long break, effort, a lighter week
  bool _saving = false;
  bool _savingSet = false; // one set save at a time, so a double tap cannot store the same set twice
  late bool _done = widget.done;
  // Rest timer: counts down from [_restTotal] after a set is ticked.
  Timer? _rest;
  DateTime? _restEnds;
  int _restTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadLast();
    _loadAdvice();
    _moves.then((m) {
      if (mounted && m.missing.isNotEmpty) setState(() => _missing = m.missing);
    }, onError: (_) {});
  }

  /// Earlier sessions (effort and pain answers) for today's coaching notes. Notes are only advice, so a failed read
  /// simply shows none.
  Future<void> _loadAdvice() async {
    try {
      final from = DateTime.now().subtract(const Duration(days: 120)).toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('workout_logs')
          .select('performed_on, rpe, notes')
          .eq('user_id', supabase.auth.currentUser!.id)
          .gte('performed_on', from)
          .order('performed_on', ascending: false)
          .limit(200);
      final history = [
        for (final r in rows)
          (day: DateTime.parse(r['performed_on'] as String), rpe: r['rpe'] as int?, pain: painFromNotes(r['notes'] as String?)),
      ];
      if (mounted) setState(() => _advice = sessionAdvice(history, DateTime.now()));
    } catch (_) {
      // No notes without history.
    }
  }

  /// The most recent earlier session for each lift, so every move can show the next step.
  Future<void> _loadLast() async {
    final lifts = _check.ids.where(isLift).toList();
    if (lifts.isEmpty) return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('set_logs')
          .select('exercise_id, performed_on, set_no, reps, kg')
          .eq('user_id', supabase.auth.currentUser!.id)
          .inFilter('exercise_id', lifts)
          .lt('performed_on', today)
          .order('performed_on', ascending: false)
          .order('set_no', ascending: true)
          .limit(300);
      final last = <String, List<SetLog>>{};
      final day = <String, String>{};
      for (final r in rows) {
        final id = r['exercise_id'] as String;
        day.putIfAbsent(id, () => r['performed_on'] as String);
        if (day[id] != r['performed_on']) continue;
        (last[id] ??= []).add((reps: r['reps'] as int, kg: (r['kg'] as num?)?.toDouble()));
      }
      if (mounted) setState(() => _last = last);
    } catch (_) {
      // Without history the session still works; the hint says it is the first time.
    }
  }

  /// A lift's set: ask for reps and load (prefilled from last time), save it, then tick it.
  Future<void> _logSet(String id, int setNo) async {
    if (_savingSet) return;
    final prev = _today[id]?.lastOrNull ?? _last[id]?.elementAtOrNull(setNo - 1) ?? _last[id]?.lastOrNull;
    var reps = prev?.reps ?? 10;
    final kg = TextEditingController(text: prev?.kg == null ? '' : '${prev!.kg! % 1 == 0 ? prev.kg!.toInt() : prev.kg}');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SET $setNo', style: monoLabel(sheet)),
                const SizedBox(height: 12),
                Row(children: [
                  Text('Reps', style: Theme.of(sheet).textTheme.titleMedium),
                  const Spacer(),
                  IconButton.outlined(onPressed: reps > 1 ? () => setSheet(() => reps--) : null, icon: const Icon(LvIcons.minus, size: 18)),
                  SizedBox(width: 56, child: Text('$reps', textAlign: TextAlign.center, style: monoNumber(sheet, size: 28))),
                  IconButton.outlined(onPressed: reps < 100 ? () => setSheet(() => reps++) : null, icon: const Icon(LvIcons.plus, size: 18)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: kg,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d?)?$'))],
                  decoration: const InputDecoration(labelText: 'Weight, leave empty for bodyweight', suffixText: 'kg'),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Log set'))),
              ]),
            ),
          ),
        ),
      ),
    );
    final load = double.tryParse(kg.text);
    kg.dispose();
    if (saved != true || _savingSet) return;
    _savingSet = true;
    try {
      // The phone's own date, the same one the history read and undo use (the column default is the server's UTC
      // date, which is yesterday in India before 05:30).
      await supabase.from('set_logs').insert({
        'performed_on': DateTime.now().toIso8601String().substring(0, 10),
        'exercise_id': id,
        'set_no': setNo,
        'reps': reps,
        'kg': load,
      });
      if (!mounted) return;
      setState(() {
        (_today[id] ??= []).add((reps: reps, kg: load));
        _ticked[id] = setNo;
      });
      if (_doneSets < _totalSets) _startRest(restFor(id));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the set. Check your connection.')));
    } finally {
      _savingSet = false;
    }
  }

  /// Unticks back to [setNo] and removes those sets from today's log.
  Future<void> _undoSet(String id, int setNo) async {
    setState(() {
      _ticked[id] = setNo - 1;
      _today[id] = [...?_today[id]].take(setNo - 1).toList();
    });
    if (!isLift(id)) return;
    try {
      await supabase
          .from('set_logs')
          .delete()
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('exercise_id', id)
          .eq('performed_on', DateTime.now().toIso8601String().substring(0, 10))
          .gte('set_no', setNo);
    } catch (_) {}
  }

  int get _restLeft => _restEnds == null ? 0 : _restEnds!.difference(DateTime.now()).inMilliseconds.clamp(0, 1 << 30) ~/ 1000;

  void _startRest(int seconds) {
    _rest?.cancel();
    setState(() {
      _restTotal = seconds;
      _restEnds = DateTime.now().add(Duration(seconds: seconds));
    });
    _rest = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_restLeft <= 0) {
        _stopRest();
        HapticFeedback.heavyImpact();
        Reminders.chime();
      } else {
        setState(() {});
      }
    });
  }

  void _stopRest() {
    _rest?.cancel();
    if (mounted) setState(() => _restEnds = null);
  }

  void _adjustRest(int by) => setState(() {
        _restEnds = _restEnds!.add(Duration(seconds: by));
        _restTotal = (_restTotal + by).clamp(1, 600);
      });

  /// After a logged session: how hard was it (1 to 10) and was there pain. Optional; saved on today's workout_logs
  /// row (rpe, and notes as "pain: ..."), and used for the next sessions' coaching notes.
  Future<void> _askHowItWent() async {
    final answer = await showModalBottomSheet<({int? rpe, Pain? pain})>(context: context, builder: (_) => const HowItWentSheet());
    if (answer == null || (answer.rpe == null && answer.pain == null)) return;
    try {
      await supabase
          .from('workout_logs')
          .update({'rpe': ?answer.rpe, if (answer.pain != null) 'notes': painNote(answer.pain!)})
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('performed_on', DateTime.now().toIso8601String().substring(0, 10));
      if (answer.pain == Pain.stopped && mounted) {
        await showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Look after that pain'),
            content: const Text('Rest the painful area and skip any move that hurts next time. If the pain is still there in a few days, '
                'or it is sharp, swelling or getting worse, see a physiotherapist or doctor.'),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
          ),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your session is logged, but how it went could not be saved.')));
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    super.dispose();
  }

  int get _totalSets => _ids.where((id) => !_missing.contains(id)).fold(0, (s, id) => s + setsFor(id, _levelOf(id), lighter: _light));
  int get _doneSets => _ids.fold(0, (s, id) => s + (_ticked[id] ?? 0)); // a left-out move's sets stop counting

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      // The logging side reports its own errors; only a confirmed save marks the session done.
      if (!await widget.onFinish!()) return;
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _done = true);
      if (mounted) await _askHowItWent();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection and try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: t.titleMedium),
        actions: [
          IconButton(tooltip: 'Timer', icon: const Icon(LvIcons.timer, size: 22), onPressed: () => showTimerSheet(context)),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: motion(context, 400),
            curve: spring,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 3),
          ),
        ),
      ),
      body: FutureBuilder(
        future: _moves,
        builder: (context, snap) {
          if (snap.hasError) return const Padding(padding: EdgeInsets.all(24), child: ErrorLine('Could not load this session. Check your connection.'));
          final loaded = snap.data?.found;
          if (loaded == null) return const Center(child: CircularProgressIndicator());
          final missing = snap.data!.missing;
          final moves = [for (final m in loaded) if (_ids.contains(m['id'])) m];
          final leftOutNames = [for (final m in loaded) if (_leftOut.contains(m['id'])) moveName(m)];
          // The first shown move of each block gets the block's header; a block with none shown gets it at the end.
          final headers = <String, AddOnBlock>{};
          final emptyBlocks = <(AddOnBlock, bool)>[]; // with whether it was planned empty (covered by the session)
          for (final (i, b) in _blocks.indexed) {
            final first = moves.where((m) => b.ids.contains(m['id'])).firstOrNull;
            if (first == null) {
              emptyBlocks.add((b, widget.blocks[i].ids.isEmpty));
            } else {
              headers[first['id'] as String] = b;
            }
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: staggered([
                  Text('${moves.length} MOVES  ·  $_doneSets OF $_totalSets SETS', style: monoLabel(context)),
                  const SizedBox(height: 14),
                  if (_advice.isNotEmpty) ...[
                    _CoachNotes(advice: _advice),
                    const SizedBox(height: 12),
                  ],
                  if (leftOutNames.isNotEmpty) ...[
                    Text(
                      _full
                          ? 'Full session: about ${_estimateOf([for (final id in _check.ids) if (!missing.contains(id)) id])} min with the rests shown.'
                          : shortenedNotice(leftOutNames, _fit.estimate, widget.sessionMinutes!),
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _full = !_full),
                        child: Text(_full ? 'Shorten to fit ${widget.sessionMinutes} min' : 'Show full session'),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (overTimeNotice(_estimateOf([for (final id in _ids) if (!missing.contains(id)) id]), widget.sessionMinutes)
                      case final note? when !_full || leftOutNames.isEmpty) ...[
                    Text(note, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: 12),
                  ],
                  if (widget.medicalHold) ...[
                    _InjuryNotice(label: 'SEE A DOCTOR FIRST', lines: const [medicalHoldNotice]),
                    const SizedBox(height: 12),
                  ] else if (widget.lighter) ...[
                    Text(lighterNotice, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: 12),
                  ],
                  if (_check.note != null) ...[
                    _InjuryNotice(lines: injuryNotice(_check)),
                    const SizedBox(height: 12),
                  ],
                  _WarmUp(steps: warmUpFor(kind: widget.kind, level: widget.level, gym: widget.gym, injury: widget.injury, light: _light)),
                  const SizedBox(height: 12),
                  Text('MAIN SESSION', style: monoLabel(context)),
                  const SizedBox(height: 10),
                  for (final (i, m) in moves.indexed) ...[
                    if (headers[m['id']] case final b?) ...[
                      const SizedBox(height: 8),
                      Text(blockSummary(b).toUpperCase(), style: monoLabel(context)),
                      const SizedBox(height: 10),
                    ],
                    _MoveCard(
                      number: i + 1,
                      move: m,
                      level: _levelOf(m['id'] as String),
                      lighter: _light,
                      ticked: _ticked[m['id']] ?? 0,
                      // No "add weight" hints while a doctor has not cleared harder training.
                      hint: !widget.medicalHold && isLift(m['id'] as String) ? liftHint(_last[m['id']] ?? const [], _advice) : null,
                      care: _check.care[m['id']] == null ? null : careNote(_check.care[m['id']]!),
                      onSet: (s) {
                        HapticFeedback.selectionClick();
                        final id = m['id'] as String;
                        final done = _ticked[id] ?? 0;
                        if (s <= done) {
                          _undoSet(id, s);
                          return;
                        }
                        // Sets fill in order; lifts ask for reps and load first.
                        if (isLift(id)) {
                          _logSet(id, done + 1);
                          return;
                        }
                        setState(() => _ticked[id] = done + 1);
                        // Rest after each set except the very last one of the session.
                        if (_doneSets < _totalSets) _startRest(restFor(id));
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final (b, planned) in emptyBlocks) ...[
                    Text(planned
                            ? blockSummary(b)
                            : 'Add-on: ${b.name}. Its moves could not be loaded or are set aside today.',
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: 12),
                  ],
                  if (missing.isNotEmpty) ...[
                    ErrorLine('${missingMovesText(missing.length)} Your other moves and sets still count.'),
                    const SizedBox(height: 12),
                  ],
                  _WarmUp(steps: cooldownFor(kind: widget.kind), title: 'COOLDOWN  ·  ABOUT 5 MIN', note: 'After your last set. Not counted in your sets.'),
                  const SizedBox(height: 12),
                  Text('Warm up first, stop any move that hurts, and rest long enough to repeat good reps. $exerciseMediaCredit.',
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ]),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: 600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: motion(context, 300),
              switchInCurve: spring,
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, alignment: Alignment.bottomCenter, child: child)),
              child: _restEnds == null
                  ? const SizedBox(width: double.infinity, key: ValueKey('no-rest'))
                  : Padding(
                      key: const ValueKey('rest'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RestBar(left: _restLeft, total: _restTotal, onAdjust: _adjustRest, onSkip: _stopRest),
                    ),
            ),
            if (widget.onFinish != null)
              SizedBox(
                height: 56,
                child: AnimatedSwitcher(
                  duration: motion(context, 300),
                  child: _done
                      ? Container(
                          key: const ValueKey('done'),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.secondary, borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LvIcons.checkCircle, color: c.primary),
                            const SizedBox(width: 8),
                            Text('Session logged', style: t.titleMedium?.copyWith(color: c.onSecondary)),
                          ]),
                        )
                      : FilledButton(
                          key: const ValueKey('finish'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: _saving ? null : _finish,
                          child: Text(_doneSets == 0 ? 'Mark session done' : 'Finish and log session'),
                        ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Notes from earlier sessions at the top of today's (pain, a long break, a very hard session, a lighter week).
class _CoachNotes extends StatelessWidget {
  const _CoachNotes({required this.advice});
  final List<Advice> advice;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FROM YOUR LAST SESSIONS', style: monoLabel(context).copyWith(color: c.tertiary)),
        const SizedBox(height: 6),
        for (final a in advice) Padding(padding: const EdgeInsets.only(top: 4), child: Text(a.text, style: t.bodySmall)),
      ]),
    );
  }
}

/// Effort (1 to 10) and pain after a session. Both optional; "Skip" saves nothing.
class HowItWentSheet extends StatefulWidget {
  const HowItWentSheet({super.key});

  @override
  State<HowItWentSheet> createState() => HowItWentSheetState();
}

class HowItWentSheetState extends State<HowItWentSheet> {
  int? _rpe;
  Pain? _pain;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Scrolls when the sheet is short (small phones, landscape): a bottom sheet is capped at part of the screen.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How did it go?', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Optional. It shapes the notes for your next sessions.', style: t.bodySmall),
          const SizedBox(height: 16),
          Text('How hard was it, from 1 (very easy) to 10 (as hard as possible)?', style: t.bodyMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 1; i <= 10; i++)
              ChoiceChip(label: Text('$i'), selected: _rpe == i, onSelected: (on) => setState(() => _rpe = on ? i : null)),
          ]),
          const SizedBox(height: 16),
          Text('Any pain?', style: t.bodyMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (p, label) in const [(Pain.none, 'None'), (Pain.mild, 'Some soreness'), (Pain.stopped, 'Pain made me stop')])
              ChoiceChip(label: Text(label), selected: _pain == p, onSelected: (on) => setState(() => _pain = on ? p : null)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
            const Spacer(),
            FilledButton(
              onPressed: _rpe == null && _pain == null ? null : () => Navigator.pop(context, (rpe: _rpe, pain: _pain)),
              child: const Text('Save'),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// The injury check's notes at the top of a session.
/// The warm-up section above the main moves: about 5 minutes, nothing to tick.
class _WarmUp extends StatelessWidget {
  const _WarmUp({required this.steps, this.title = 'WARM-UP  ·  ABOUT 5 MIN', this.note = 'Not counted in your sets. Stop any move that hurts.'});
  final List<WarmUpStep> steps;
  final String title, note;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: monoLabel(context)),
        const SizedBox(height: 4),
        Text(note, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ${s.move}  ·  ${s.dose}', style: t.titleSmall),
              Text(s.how, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ]),
          ),
      ]),
    );
  }
}

class _InjuryNotice extends StatelessWidget {
  const _InjuryNotice({required this.lines, this.label = 'INJURY CHECK'});
  final List<String> lines;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c.error.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: monoLabel(context).copyWith(color: c.error)),
        const SizedBox(height: 6),
        for (final l in lines) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l, style: t.bodySmall)),
      ]),
    );
  }
}

class _MoveCard extends StatelessWidget {
  const _MoveCard({required this.number, required this.move, required this.level, required this.ticked, required this.hint, required this.onSet, this.care, this.lighter = false});
  final bool lighter;
  final String? care; // injury caution for this move, from the injury check
  final int number;
  final Map<String, dynamic> move;
  final int level, ticked;
  final String? hint; // the coach's next step for a lift
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final id = move['id'] as String;
    final sets = setsFor(id, level, lighter: lighter);
    final complete = sets > 0 && ticked >= sets;
    return AnimatedContainer(
      duration: motion(context, 260),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: complete ? c.primary : c.outline, width: complete ? 1.5 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: id))),
          child: Container(
            width: 104,
            height: 104,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ExerciseGif(move['gif_url'] as String?, id: id),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$number'.padLeft(2, '0'), style: monoLabel(context).copyWith(color: c.tertiary)),
            const SizedBox(height: 2),
            Text(moveName(move), style: t.titleMedium),
            const SizedBox(height: 2),
            Text(doseFor(id, level, lighter: lighter), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!, style: t.bodySmall?.copyWith(color: c.tertiary, fontWeight: FontWeight.w600)),
            ],
            if (care != null) ...[
              const SizedBox(height: 6),
              Text(care!, style: t.bodySmall?.copyWith(color: c.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 10),
            if (sets > 0)
              Wrap(spacing: 8, children: [
                for (var s = 1; s <= sets; s++)
                  Semantics(
                    button: true,
                    label: 'Set $s ${s <= ticked ? 'done' : 'not done'}',
                    child: GestureDetector(
                      onTap: () => onSet(s),
                      child: AnimatedContainer(
                        duration: motion(context, 220),
                        curve: spring,
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s <= ticked ? c.primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: s <= ticked ? c.primary : c.outline, width: 1.5),
                        ),
                        child: s <= ticked ? Icon(LvIcons.check, size: 16, color: c.onPrimary) : Text('$s', style: monoNumber(context, size: 13)),
                      ),
                    ),
                  ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// The rest countdown that slides up after each set: time left, a draining bar, nudges and skip.
class _RestBar extends StatelessWidget {
  const _RestBar({required this.left, required this.total, required this.onAdjust, required this.onSkip});
  final int left, total;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const onInk = cloud;
    return Material(
      color: Theme.of(context).brightness == Brightness.dark ? c.surfaceContainerHighest : graphite,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: total == 0 ? 0 : left / total, minHeight: 3, backgroundColor: Colors.transparent),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('REST', style: monoLabel(context).copyWith(color: onInk.withValues(alpha: 0.6), fontSize: 10)),
              Text(_clock(left), style: monoNumber(context, size: 26).copyWith(color: onInk)),
            ]),
            const Spacer(),
            TextButton(onPressed: () => onAdjust(-15), style: TextButton.styleFrom(foregroundColor: onInk), child: const Text('-15s')),
            TextButton(onPressed: () => onAdjust(15), style: TextButton.styleFrom(foregroundColor: onInk), child: const Text('+15s')),
            FilledButton(onPressed: onSkip, style: FilledButton.styleFrom(minimumSize: const Size(64, 40)), child: const Text('Skip')),
          ]),
        ),
      ]),
    );
  }
}

/// A free timer for anything in a session: countdown presets or a stopwatch.
Future<void> showTimerSheet(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (_) => const SafeArea(child: _TimerSheet()));

class _TimerSheet extends StatefulWidget {
  const _TimerSheet();

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  bool _stopwatch = false;
  int _preset = 90;
  DateTime? _started; // running since
  Duration _banked = Duration.zero; // time already counted before a pause
  Timer? _tick;

  Duration get _elapsed => _banked + (_started == null ? Duration.zero : DateTime.now().difference(_started!));
  int get _shown => _stopwatch ? _elapsed.inSeconds : (_preset - _elapsed.inSeconds).clamp(0, _preset);

  void _toggle() {
    HapticFeedback.selectionClick();
    if (_started != null) {
      _tick?.cancel();
      setState(() {
        _banked = _elapsed;
        _started = null;
      });
      return;
    }
    setState(() => _started = DateTime.now());
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (!_stopwatch && _shown == 0) {
        _tick?.cancel();
        setState(() {
          _started = null;
          _banked = Duration.zero;
        });
        HapticFeedback.heavyImpact();
        Reminders.chime();
      } else {
        setState(() {});
      }
    });
  }

  void _reset() {
    _tick?.cancel();
    setState(() {
      _started = null;
      _banked = Duration.zero;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _started != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Timer')), ButtonSegment(value: true, label: Text('Stopwatch'))],
          selected: {_stopwatch},
          showSelectedIcon: false,
          onSelectionChanged: running
              ? null
              : (v) => setState(() {
                    _stopwatch = v.first;
                    _banked = Duration.zero;
                  }),
        ),
        const SizedBox(height: 20),
        Text(_clock(_shown), style: monoNumber(context, size: 64)),
        const SizedBox(height: 12),
        if (!_stopwatch)
          Wrap(spacing: 8, children: [
            for (final p in const [30, 60, 90, 120, 180])
              ChoiceChip(
                label: Text(p < 60 ? '${p}s' : _clock(p)),
                selected: _preset == p,
                onSelected: running
                    ? null
                    : (_) => setState(() {
                          _preset = p;
                          _banked = Duration.zero;
                        }),
              ),
          ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _reset, child: const Text('Reset'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: _toggle, child: Text(running ? 'Pause' : 'Start'))),
        ]),
      ]),
    );
  }
}

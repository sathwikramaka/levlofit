// Session-to-session coaching: what the last sessions say about today. Pure functions, no database or UI.
//
// Inputs are what the app already stores: workout_logs rows (date, effort 1-10 in `rpe`, and a pain answer kept in
// `notes` as "pain: none|mild|stopped") and each lift's sets from set_logs.
//
// The thresholds below are Levlofit coaching rules, chosen to be conservative. They are NOT verified against a source
// and need review by a qualified coach or physiotherapist before they are presented as evidence-based (see
// docs/PROGRESS.md, requirement 3). The double-progression rule itself (nextStep) follows the Handbook chapter
// "Sets, reps and progress".

import 'session.dart' show SetLog, nextStep;

/// How the session felt for pain, asked when it is finished.
enum Pain { none, mild, stopped }

/// The workout_logs.notes value for a pain answer, and back. Unknown or empty notes read as no answer.
String painNote(Pain p) => 'pain: ${p.name}';
Pain? painFromNotes(String? notes) {
  final m = RegExp(r'pain: (none|mild|stopped)').firstMatch(notes ?? '');
  return m == null ? null : Pain.values.byName(m.group(1)!);
}

typedef SessionLog = ({DateTime day, int? rpe, Pain? pain});

/// One coaching note for today, most important first.
enum AdviceKind { pain, returning, hardLast, deload }

typedef Advice = ({AdviceKind kind, String text});

/// A break longer than this many days means starting lighter than last time.
const longBreakDays = 14;

/// An effort of this or more (out of 10) last time means holding the weight, not adding.
const veryHardRpe = 9;

/// After this many weeks in a row with training, suggest a lighter week; sooner if recent sessions felt hard.
const deloadAfterWeeks = 8;
const deloadAfterWeeksIfHard = 6;
const hardAverageRpe = 8.0;

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monday(DateTime d) => _date(d).subtract(Duration(days: d.weekday - 1));

/// Weeks in a row, ending with this week or last week, that each have at least one session.
int trainingWeeksInARow(List<SessionLog> history, DateTime today) {
  final weeks = {for (final s in history) _monday(s.day)};
  var week = _monday(today);
  if (!weeks.contains(week)) week = week.subtract(const Duration(days: 7));
  var n = 0;
  while (weeks.contains(week)) {
    n++;
    week = week.subtract(const Duration(days: 7));
  }
  return n;
}

/// Notes for today's session from earlier sessions (any order; today's own log is ignored).
List<Advice> sessionAdvice(List<SessionLog> history, DateTime today) {
  final day = _date(today);
  final past = history.where((s) => _date(s.day).isBefore(day)).toList()..sort((a, b) => b.day.compareTo(a.day));
  if (past.isEmpty) return const [];
  final last = past.first;
  final gap = day.difference(_date(last.day)).inDays;
  final out = <Advice>[];
  if (last.pain == Pain.stopped) {
    out.add((
      kind: AdviceKind.pain,
      text: 'Last time pain made you stop. Skip any move that hurts today, and see a physiotherapist or doctor if the pain is still there.',
    ));
  }
  if (gap > longBreakDays) {
    out.add((kind: AdviceKind.returning, text: 'Your last session was $gap days ago. Start lighter than last time and build back up over the next sessions.'));
  } else if ((last.rpe ?? 0) >= veryHardRpe) {
    out.add((kind: AdviceKind.hardLast, text: 'Your last session felt very hard (${last.rpe} out of 10). Keep the same weights today rather than adding.'));
  }
  final weeks = trainingWeeksInARow(past, day);
  final recent = past.take(3).map((s) => s.rpe).whereType<int>().toList();
  final hard = recent.length == 3 && recent.reduce((a, b) => a + b) / 3 >= hardAverageRpe;
  if (gap <= longBreakDays && (weeks >= deloadAfterWeeks || (weeks >= deloadAfterWeeksIfHard && hard))) {
    out.add((
      kind: AdviceKind.deload,
      text: 'You have trained $weeks weeks in a row${hard ? ' and recent sessions felt hard' : ''}. Consider a lighter week: fewer sets, same moves.',
    ));
  }
  return out;
}

/// The hint for one lift, from its last sets and today's notes. A long break, a very hard last session or pain
/// replace the usual "add weight" step with a hold or a lighter start.
String liftHint(List<SetLog> last, List<Advice> advice) {
  final step = nextStep(last);
  if (last.isEmpty) return step;
  final kinds = {for (final a in advice) a.kind};
  final kg = last.first.kg;
  final at = kg == null || kg == 0 ? 'bodyweight' : '${kg % 1 == 0 ? kg.toInt() : kg} kg';
  if (kinds.contains(AdviceKind.pain)) return 'Last time: $at. Pain stopped you last session, so do not add weight; skip this move if it hurts.';
  if (kinds.contains(AdviceKind.returning)) return 'Last time: $at, before your break. Start lighter and build back up.';
  if (kinds.contains(AdviceKind.hardLast) && step.contains('add the smallest weight step')) {
    return 'Last time: $at, and the session felt very hard. Keep $at today.';
  }
  return step;
}

/// A lift's best set on its first and latest logged day (heaviest load, then most reps), for the Progress page.
typedef LiftProgress = ({String id, DateTime from, SetLog first, DateTime to, SetLog latest});

/// Lifts logged on at least two different days, from set_logs rows (exercise_id, performed_on, reps, kg), most
/// improved first. Compares best sets only, so one weak set on a tired day does not read as going backwards.
List<LiftProgress> liftProgress(List<Map<String, dynamic>> rows) {
  final byLift = <String, Map<DateTime, SetLog>>{};
  bool better(SetLog a, SetLog b) => (a.kg ?? 0) != (b.kg ?? 0) ? (a.kg ?? 0) > (b.kg ?? 0) : a.reps > b.reps;
  for (final r in rows) {
    final day = DateTime.parse(r['performed_on'] as String);
    final s = (reps: r['reps'] as int, kg: (r['kg'] as num?)?.toDouble());
    final days = byLift.putIfAbsent(r['exercise_id'] as String, () => {});
    final best = days[day];
    if (best == null || better(s, best)) days[day] = s;
  }
  final out = <LiftProgress>[
    for (final MapEntry(key: id, value: days) in byLift.entries)
      if (days.length >= 2)
        () {
          final sorted = days.keys.toList()..sort();
          return (id: id, from: sorted.first, first: days[sorted.first]!, to: sorted.last, latest: days[sorted.last]!);
        }(),
  ];
  double gain(LiftProgress p) => p.first.kg != null && p.first.kg! > 0 && p.latest.kg != null
      ? (p.latest.kg! - p.first.kg!) / p.first.kg!
      : (p.latest.reps - p.first.reps) / p.first.reps;
  return out..sort((a, b) => gain(b).compareTo(gain(a)));
}

/// "40 kg x 8" or "12 reps" for a set without load.
String setLabel(SetLog s) => s.kg == null || s.kg == 0 ? '${s.reps} reps' : '${s.kg!.toStringAsFixed(s.kg! % 1 == 0 ? 0 : 1)} kg x ${s.reps}';

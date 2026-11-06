// Weekly report (roadmap Stage 4, brief 6.2): last full Monday-to-Sunday week from what was actually logged.
// Deterministic rules only; nothing is estimated or filled in. Missing data is listed, never guessed. One week is too
// short for a weight trend, so weight is shown as a plain difference of averages and never drives the advice.
import 'package:flutter/material.dart';

import 'theme.dart';

typedef Weigh = ({DateTime day, double kg});

/// One day's logged food (food_diary.dart diaryTotals); [unknown] entries had no food values and added nothing.
typedef DayFood = ({double kcal, double protein, int unknown});

/// Average logged intake on the days with food logged, beside the plan's targets.
typedef Intake = ({int days, int kcal, int protein, num? kcalTarget, num? proteinTarget, int unknown});

/// Lifts trained this week compared with the same lift's last session before the week (best set, as liftProgress).
typedef StrengthTrend = ({int up, int same, int down});

typedef WeekReport = ({
  DateTime monday,
  int planned,
  int done,
  int? foodDays, // null: could not be read (never shown as zero)
  Intake? intake, // only with [minFoodDays] logged days
  StrengthTrend? strength, // null without a lift that has an earlier session to compare with
  int? checkinDays,
  double? weightChangeKg, // this week's average minus the week before's, only with 2+ weigh-ins in each
  int weighIns,
  String observation,
  String nextStep,
  List<String> missing,
});

/// Weigh-ins needed in each of the two weeks before a weight difference is shown.
const minWeighInsPerWeek = 2;

/// Days with food logged before averages are shown: fewer says more about logging than about eating.
const minFoodDays = 3;

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

/// The report for the full week starting [monday] (a Monday, local date).
WeekReport weeklyReport({
  required DateTime monday,
  required int plannedPerWeek,
  required Set<DateTime> trained,
  required Map<DateTime, DayFood>? food, // per logged day; null when the food log could not be read
  required Set<DateTime>? checkinDays,
  required List<Weigh> weights,
  num? kcalTarget,
  num? proteinTarget,
  List<Map<String, dynamic>> sets = const [], // set_logs rows: exercise_id, performed_on, reps, kg
}) {
  final start = _d(monday);
  bool inWeek(DateTime d, DateTime from) => !_d(d).isBefore(from) && _d(d).isBefore(from.add(const Duration(days: 7)));
  int count(Set<DateTime> days) => days.where((d) => inWeek(d, start)).map(_d).toSet().length;

  final planned = plannedPerWeek.clamp(1, 7);
  final done = count(trained);
  final foodWeek = food == null ? null : {for (final e in food.entries) if (inWeek(e.key, start)) _d(e.key): e.value};
  final foodCount = foodWeek?.length;
  Intake? intake;
  if (foodWeek != null && foodWeek.length >= minFoodDays) {
    final n = foodWeek.length;
    intake = (
      days: n,
      kcal: (foodWeek.values.fold(0.0, (s, f) => s + f.kcal) / n).round(),
      protein: (foodWeek.values.fold(0.0, (s, f) => s + f.protein) / n).round(),
      kcalTarget: kcalTarget,
      proteinTarget: proteinTarget,
      unknown: foodWeek.values.fold(0, (s, f) => s + f.unknown),
    );
  }
  final strength = strengthTrend(sets, start);
  final checkins = checkinDays == null ? null : count(checkinDays);
  final thisWeek = weights.where((w) => inWeek(w.day, start)).toList();
  final lastWeek = weights.where((w) => inWeek(w.day, start.subtract(const Duration(days: 7)))).toList();
  double avg(List<Weigh> ws) => ws.fold(0.0, (s, w) => s + w.kg) / ws.length;
  final weightChange = thisWeek.length >= minWeighInsPerWeek && lastWeek.length >= minWeighInsPerWeek
      ? ((avg(thisWeek) - avg(lastWeek)) * 10).round() / 10
      : null;

  final missing = [
    if (foodCount == null)
      'Your food log could not be loaded.'
    else if (foodCount == 0)
      'No meals logged, so food is not part of this report.'
    else if (intake == null)
      'Food is compared with your targets from $minFoodDays logged days; this week had $foodCount.',
    if (weightChange == null) 'Weight needs $minWeighInsPerWeek weigh-ins in this week and the week before to compare.',
    if (checkins == null) 'Check-ins could not be loaded.' else if (checkins == 0) 'No daily check-ins.',
  ];

  final (String observation, String next) = switch (done) {
    0 => ('No training was logged this week.', 'Pick one day this week for a short session. Twenty minutes still counts.'),
    _ when done >= planned => (
        done == planned ? (planned == 1 ? 'You logged your planned session.' : 'You logged all of your $planned planned sessions.') : 'You logged $done sessions; $planned were planned.',
        (foodCount ?? 0) < minFoodDays
            ? 'Try logging food on three days this week to see how meals compare with your targets.'
            : 'Keep the same plan. Progress shows over several weeks, not one.',
      ),
    _ when done * 2 < planned => (
        'You logged $done of $planned planned sessions.',
        'If $planned days a week is hard to fit, you can lower training days in Protocol. A plan you can keep beats a bigger one.',
      ),
    _ => ('You logged $done of $planned planned sessions.', 'Choose fixed days for your sessions this week and set a workout reminder.'),
  };

  return (
    monday: start,
    planned: planned,
    done: done,
    foodDays: foodCount,
    intake: intake,
    strength: strength,
    checkinDays: checkins,
    weightChangeKg: weightChange,
    weighIns: thisWeek.length,
    observation: observation,
    nextStep: next,
    missing: missing,
  );
}

/// Each lift trained in the week starting [monday]: its best set that week against its best set on the last day it was
/// trained before the week. Heavier wins; at the same weight, more reps. Lifts new this week are not counted.
StrengthTrend? strengthTrend(List<Map<String, dynamic>> sets, DateTime monday) {
  final start = _d(monday), end = start.add(const Duration(days: 7));
  bool better(({int reps, double kg}) a, ({int reps, double kg}) b) => a.kg != b.kg ? a.kg > b.kg : a.reps > b.reps;
  final byLift = <String, Map<DateTime, ({int reps, double kg})>>{};
  for (final r in sets) {
    final day = _d(DateTime.parse(r['performed_on'] as String));
    if (!day.isBefore(end)) continue;
    final s = (reps: r['reps'] as int, kg: ((r['kg'] as num?) ?? 0).toDouble());
    final days = byLift.putIfAbsent(r['exercise_id'] as String, () => {});
    final best = days[day];
    if (best == null || better(s, best)) days[day] = s;
  }
  var up = 0, same = 0, down = 0;
  for (final days in byLift.values) {
    final inWeek = [for (final e in days.entries) if (!e.key.isBefore(start)) e.value];
    final before = days.keys.where((d) => d.isBefore(start)).toList()..sort();
    if (inWeek.isEmpty || before.isEmpty) continue;
    final now = inWeek.reduce((a, b) => better(a, b) ? a : b), last = days[before.last]!;
    if (better(now, last)) {
      up++;
    } else if (better(last, now)) {
      down++;
    } else {
      same++;
    }
  }
  return up + same + down == 0 ? null : (up: up, same: same, down: down);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({super.key, required this.report});
  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final r = report;
    final sun = r.monday.add(const Duration(days: 6));
    final w = r.weightChangeKg;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant))),
            Text(value, style: monoNumber(context, size: 15)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(cardRadius), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('LAST WEEK  ·  ${r.monday.day} ${_months[r.monday.month - 1].toUpperCase()} TO ${sun.day} ${_months[sun.month - 1].toUpperCase()}', style: monoLabel(context)),
        const SizedBox(height: 8),
        Text(r.observation, style: t.titleMedium),
        const SizedBox(height: 10),
        row('Training sessions', '${r.done} / ${r.planned}'),
        row('Days with food logged', r.foodDays == null ? '–' : '${r.foodDays} / 7'),
        if (r.intake case final i?) ...[
          row('Calories, daily average', i.kcalTarget == null ? '${i.kcal} kcal' : '${i.kcal} / ${i.kcalTarget!.round()} kcal'),
          row('Protein, daily average', i.proteinTarget == null ? '${i.protein} g' : '${i.protein} / ${i.proteinTarget!.round()} g'),
          Text(
              'Average of the ${i.days} days you logged food. Meals you did not log are not counted, so a missed meal reads low.'
              '${i.unknown > 0 ? ' ${i.unknown} logged item${i.unknown == 1 ? '' : 's'} had no food values and added nothing.' : ''}',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
        row('Daily check-ins', r.checkinDays == null ? '–' : '${r.checkinDays} / 7'),
        if (r.strength case final st?) row('Lifts vs your last session', '${st.up} up · ${st.same} same · ${st.down} down'),
        if (w != null) row('Weight, average vs week before', '${w > 0 ? '+' : ''}${w.toStringAsFixed(1)} kg'),
        if (w != null)
          Text('One week of weight moves with water and food; the 6-week trend above is the one to judge by.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 10),
        Text('NEXT STEP', style: monoLabel(context)),
        const SizedBox(height: 4),
        Text(r.nextStep, style: t.bodyMedium),
        if (r.missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final m in r.missing) Text(m, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

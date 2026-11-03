// Weekly report (roadmap Stage 4, brief 6.2): last full Monday-to-Sunday week from what was actually logged.
// Deterministic rules only; nothing is estimated or filled in. Missing data is listed, never guessed. One week is too
// short for a weight trend, so weight is shown as a plain difference of averages and never drives the advice.
import 'package:flutter/material.dart';

import 'theme.dart';

typedef Weigh = ({DateTime day, double kg});

typedef WeekReport = ({
  DateTime monday,
  int planned,
  int done,
  int? foodDays, // null: could not be read (never shown as zero)
  int? checkinDays,
  double? weightChangeKg, // this week's average minus the week before's, only with 2+ weigh-ins in each
  int weighIns,
  String observation,
  String nextStep,
  List<String> missing,
});

/// Weigh-ins needed in each of the two weeks before a weight difference is shown.
const minWeighInsPerWeek = 2;

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

/// The report for the full week starting [monday] (a Monday, local date).
WeekReport weeklyReport({
  required DateTime monday,
  required int plannedPerWeek,
  required Set<DateTime> trained,
  required Set<DateTime>? foodDays,
  required Set<DateTime>? checkinDays,
  required List<Weigh> weights,
}) {
  final start = _d(monday);
  bool inWeek(DateTime d, DateTime from) => !_d(d).isBefore(from) && _d(d).isBefore(from.add(const Duration(days: 7)));
  int count(Set<DateTime> days) => days.where((d) => inWeek(d, start)).map(_d).toSet().length;

  final planned = plannedPerWeek.clamp(1, 7);
  final done = count(trained);
  final food = foodDays == null ? null : count(foodDays);
  final checkins = checkinDays == null ? null : count(checkinDays);
  final thisWeek = weights.where((w) => inWeek(w.day, start)).toList();
  final lastWeek = weights.where((w) => inWeek(w.day, start.subtract(const Duration(days: 7)))).toList();
  double avg(List<Weigh> ws) => ws.fold(0.0, (s, w) => s + w.kg) / ws.length;
  final weightChange = thisWeek.length >= minWeighInsPerWeek && lastWeek.length >= minWeighInsPerWeek
      ? ((avg(thisWeek) - avg(lastWeek)) * 10).round() / 10
      : null;

  final missing = [
    if (food == null) 'Your food log could not be loaded.' else if (food == 0) 'No meals logged, so food is not part of this report.',
    if (weightChange == null) 'Weight needs $minWeighInsPerWeek weigh-ins in this week and the week before to compare.',
    if (checkins == null) 'Check-ins could not be loaded.' else if (checkins == 0) 'No daily check-ins.',
  ];

  final (String observation, String next) = switch (done) {
    0 => ('No training was logged this week.', 'Pick one day this week for a short session. Twenty minutes still counts.'),
    _ when done >= planned => (
        done == planned ? 'You logged all of your $planned planned sessions.' : 'You logged $done sessions; $planned were planned.',
        (food ?? 0) < 3
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
    foodDays: food,
    checkinDays: checkins,
    weightChangeKg: weightChange,
    weighIns: thisWeek.length,
    observation: observation,
    nextStep: next,
    missing: missing,
  );
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
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('LAST WEEK  ·  ${r.monday.day} ${_months[r.monday.month - 1].toUpperCase()} TO ${sun.day} ${_months[sun.month - 1].toUpperCase()}', style: monoLabel(context)),
        const SizedBox(height: 8),
        Text(r.observation, style: t.titleMedium),
        const SizedBox(height: 10),
        row('Training sessions', '${r.done} / ${r.planned}'),
        row('Days with food logged', r.foodDays == null ? '–' : '${r.foodDays} / 7'),
        row('Daily check-ins', r.checkinDays == null ? '–' : '${r.checkinDays} / 7'),
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

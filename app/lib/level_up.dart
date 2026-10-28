// Level up: XP, a level, four ratings and an optional 66-day challenge, all worked out from what the person logged
// (sessions, active minutes, water, the daily goal). Nothing here is stored except the challenge start date.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'main.dart' show prefs;
import 'theme.dart';

/// 66 days: the median time to automaticity in Lally et al., Eur J Soc Psychol 2010;40:998 (range 18 to 254 days).
const challengeDays = 66;
const challengeSource = 'Lally et al., European Journal of Social Psychology, 2010';
const challengeStartKey = 'challenge_start';

/// Days of history the dashboard loads for this card (a full challenge).
const levelUpWindow = challengeDays;

DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

/// Points per thing done. Levlofit's own scale: a session is worth most, a complete day next, water least.
const xpSession = 50, xpCompleteDay = 20, xpWaterDay = 10, xpPer10Minutes = 1;

int xpFor({required int sessions, required int completeDays, required int waterDays, required int activeMinutes}) =>
    sessions * xpSession + completeDays * xpCompleteDay + waterDays * xpWaterDay + (activeMinutes ~/ 10) * xpPer10Minutes;

/// Level from XP: level n starts at 50 x (n - 1)^2 XP, so early levels come quickly and later ones take longer.
int levelFor(int xp) => 1 + math.sqrt(math.max(0, xp) / 50).floor();
int xpForLevel(int level) => 50 * (level - 1) * (level - 1);

/// Progress through the current level, 0 to 1.
double levelProgress(int xp) {
  final l = levelFor(xp);
  final from = xpForLevel(l), to = xpForLevel(l + 1);
  return ((xp - from) / (to - from)).clamp(0.0, 1.0);
}

typedef Ratings = ({int training, int movement, int hydration, int consistency});

int overall(Ratings r) => ((r.training + r.movement + r.hydration + r.consistency) / 4).round();

/// Ratings out of 100 over the last 28 days. Training: sessions against the plan; movement: active minutes against
/// WHO's 150 a week; hydration: days at the water target; consistency: days the daily goal was complete.
Ratings ratingsFor({
  required DateTime today,
  required Set<DateTime> trained,
  required Map<DateTime, int> minutes,
  required int sessionsPerWeek,
  required bool Function(DateTime) waterMet,
  required bool Function(DateTime) dayComplete,
}) {
  final days = [for (var i = 0; i < 28; i++) _d(today).subtract(Duration(days: i))];
  int pct(num part, num whole) => whole <= 0 ? 0 : (100 * part / whole).clamp(0, 100).round();
  return (
    training: pct(days.where(trained.contains).length, sessionsPerWeek * 4),
    movement: pct(days.fold<int>(0, (s, d) => s + (minutes[d] ?? 0)), 150 * 4),
    hydration: pct(days.where(waterMet).length, 28),
    consistency: pct(days.where(dayComplete).length, 28),
  );
}

/// Where a challenge started on [start] stands on [today]: the day number (1 to 66, past 66 when over) and the
/// complete days so far. Missed days do not reset it: in Lally 2010 one missed day did not set habits back.
({int day, int complete, bool over}) challengeStatus(DateTime start, DateTime today, bool Function(DateTime) dayComplete) {
  final s = _d(start), t = _d(today);
  final day = t.difference(s).inDays + 1;
  final last = day > challengeDays ? s.add(const Duration(days: challengeDays - 1)) : t;
  var complete = 0;
  for (var d = s; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    if (dayComplete(d)) complete++;
  }
  return (day: day, complete: complete, over: day > challengeDays);
}

DateTime? readChallengeStart() {
  try {
    final v = prefs.getString(challengeStartKey);
    return v == null ? null : DateTime.tryParse(v);
  } catch (_) {
    return null;
  }
}

class LevelUpCard extends StatefulWidget {
  const LevelUpCard({super.key, required this.xp, required this.ratings, required this.dayComplete, this.today});
  final int xp;
  final Ratings ratings;
  final bool Function(DateTime) dayComplete;
  final DateTime? today; // tests

  @override
  State<LevelUpCard> createState() => _LevelUpCardState();
}

class _LevelUpCardState extends State<LevelUpCard> {
  late DateTime? _start = readChallengeStart();

  Future<void> _begin() async {
    final now = _d(widget.today ?? DateTime.now());
    setState(() => _start = now);
    await prefs.setString(challengeStartKey, now.toIso8601String().substring(0, 10));
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final level = levelFor(widget.xp);
    final r = widget.ratings;
    final start = _start;
    final status = start == null ? null : challengeStatus(start, widget.today ?? DateTime.now(), widget.dayComplete);

    Widget stat(String label, int v) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 96, child: Text(label, style: t.bodyMedium)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: v / 100, minHeight: 6, backgroundColor: c.surfaceContainerHighest),
              ),
            ),
            SizedBox(width: 40, child: Text('$v', textAlign: TextAlign.end, style: monoNumber(context, size: 13))),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(24), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // XP rank, not a curriculum level: goal Levels 0 to 5 are earned only through level checks (audit F16).
        Text('YOUR RANK', style: monoLabel(context)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Rank $level', style: t.headlineSmall),
          const Spacer(),
          Text('${widget.xp} XP', style: monoNumber(context, size: 15)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: levelProgress(widget.xp), minHeight: 8, backgroundColor: c.surfaceContainerHighest),
        ),
        const SizedBox(height: 4),
        Text('${xpForLevel(level + 1) - widget.xp} XP to rank ${level + 1}. Sessions, complete days, water and active minutes all count; your goal levels move only with level checks.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          Text('YOUR RATING', style: monoLabel(context)),
          const Spacer(),
          Text('${overall(r)}', style: monoNumber(context, size: 22).copyWith(color: c.primary)),
        ]),
        const SizedBox(height: 10),
        stat('Training', r.training),
        stat('Movement', r.movement),
        stat('Hydration', r.hydration),
        stat('Consistency', r.consistency),
        Text('Last 28 days, out of 100.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 16),
        Text('66-DAY CHALLENGE', style: monoLabel(context)),
        const SizedBox(height: 8),
        if (status == null) ...[
          Text('New habits take about 66 days to feel automatic. Complete your daily goal each day and watch the run fill up.',
              style: t.bodyMedium),
          const SizedBox(height: 10),
          FilledButton(onPressed: _begin, child: const Text('Start the 66 days')),
        ] else ...[
          Text(
            status.over
                ? 'Finished: ${status.complete} of $challengeDays days complete.'
                : 'Day ${status.day} of $challengeDays  ·  ${status.complete} complete',
            style: t.titleMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: math.min(status.day, challengeDays) / challengeDays,
              minHeight: 8,
              backgroundColor: c.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Text('A missed day does not reset the run. Just pick it up again tomorrow.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          if (status.over) ...[const SizedBox(height: 10), OutlinedButton(onPressed: _begin, child: const Text('Start another 66 days'))],
        ],
        const SizedBox(height: 8),
        Text('Source for 66 days: $challengeSource.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ]),
    );
  }
}

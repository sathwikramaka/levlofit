import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/session.dart';

// Session length estimate vs the person's session minutes.
void main() {
  test('lifts: warm-up plus work and rest per set; holds count a minute', () {
    // Squat (compound, 120 s rest) and dead bug (90 s) at level 2: 3 sets each.
    expect(estimateMinutes(['qXTaZnJ', 'iny3m5y'], 2), ((300 + 3 * 160 + 3 * 130) / 60).round());
    // Level 1: 2 sets. Stretch: 1 min.
    expect(estimateMinutes(['qXTaZnJ', 'DFGXwZr'], 1), ((300 + 2 * 160 + 60) / 60).round());
  });

  test('a run block has no set length, so no estimate', () {
    expect(estimateMinutes(['oLrKqDH', 'bJYHBIN'], 2), isNull);
  });

  test('notice only when the estimate runs more than 5 min past the setting', () {
    expect(overTimeNotice(45, 30), 'With the rests shown, this session takes about 45 min, longer than your 30-minute setting.');
    expect(overTimeNotice(35, 30), isNull);
    expect(overTimeNotice(null, 30), isNull);
    expect(overTimeNotice(45, null), isNull);
  });

  test('every prescribed strength session at level 2 fits a 60-minute setting', () {
    for (final tier in Tier.values) {
      for (var i = 0; i < 4; i++) {
        final ids = sessionIds('strength', tier, 2, i);
        final est = estimateMinutes(ids, 2);
        expect(est == null || est <= 65, isTrue, reason: '$tier $i: $est min');
      }
    }
  });

  // Every session the app can prescribe: kinds x tiers x levels 0-5 x both strength days, plus yoga.
  final sessions = [
    for (final kind in ['strength', 'skill', 'endurance', 'hybrid', 'mobility', 'yoga'])
      for (final tier in Tier.values)
        for (var level = 0; level <= 5; level++)
          for (var i = 0; i < 2; i++) (kind: kind, tier: tier, level: level, ids: sessionIds(kind == 'yoga' ? 'mobility' : kind, tier, level, i, goal: kind == 'yoga' ? 'yoga' : null)),
  ];

  test('estimate is null exactly when the session has a run block, else at least the 5 min warm-up', () {
    for (final s in sessions) {
      final est = estimateMinutes(s.ids, s.level);
      expect(est == null, s.ids.contains('oLrKqDH'), reason: '$s');
      if (est != null) expect(est, greaterThanOrEqualTo(5), reason: '$s');
    }
  });

  test('estimate matches the stated formula for every prescribable session', () {
    for (final s in sessions.where((s) => !s.ids.contains('oLrKqDH'))) {
      final seconds = 300 + s.ids.fold(0, (t, id) => t + (setsFor(id, s.level) == 0 ? 60 : setsFor(id, s.level) * (40 + restFor(id))));
      expect(estimateMinutes(s.ids, s.level), (seconds / 60).round(), reason: '$s');
    }
  });

  test('a higher level never estimates shorter for the same moves; same input, same answer', () {
    for (final s in sessions.where((s) => !s.ids.contains('oLrKqDH'))) {
      for (var l = 0; l < 5; l++) {
        expect(estimateMinutes(s.ids, l + 1)!, greaterThanOrEqualTo(estimateMinutes(s.ids, l)!), reason: '$s level $l');
      }
      expect(estimateMinutes(s.ids, s.level), estimateMinutes([...s.ids], s.level));
    }
  });

  test('the estimate only informs: it never changes the moves or sets prescribed', () {
    for (final s in sessions) {
      final before = [for (final id in s.ids) (id, setsFor(id, s.level), doseFor(id, s.level))];
      estimateMinutes(s.ids, s.level);
      overTimeNotice(estimateMinutes(s.ids, s.level), 20);
      expect([for (final id in s.ids) (id, setsFor(id, s.level), doseFor(id, s.level))], before);
    }
  });
}

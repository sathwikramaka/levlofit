import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/session.dart';

// Fitting a session to the person's session length (fitToTime). Levlofit rule pending coach review.
void main() {
  const settings = [20, 30, 45, 60, 75, 90]; // the values profiles.session_minutes allows
  final sessions = [
    for (final kind in ['strength', 'skill', 'endurance', 'hybrid', 'mobility', 'yoga'])
      for (final tier in Tier.values)
        for (var level = 0; level <= 5; level++)
          for (var i = 0; i < 2; i++) (kind: kind, tier: tier, level: level, ids: sessionIds(kind == 'yoga' ? 'mobility' : kind, tier, level, i, goal: kind == 'yoga' ? 'yoga' : null)),
  ];
  // The main multi-joint lifts: the moves with the longer rest.
  bool protected(String id) => restFor(id) == 120;

  test('a session that fits, has no setting, or has a run block is returned unchanged', () {
    for (final s in sessions) {
      for (final m in [null, ...settings]) {
        final est = estimateMinutes(s.ids, s.level);
        if (overTimeNotice(est, m) != null) continue;
        final fit = fitToTime(s.ids, s.level, m);
        expect(fit.ids, s.ids, reason: '$s $m');
        expect(fit.leftOut, isEmpty, reason: '$s $m');
        expect(fit.estimate, est, reason: '$s $m');
      }
    }
  });

  test('shortening keeps order, only removes moves, never a main lift, never below 3 moves', () {
    var shortened = 0;
    for (final s in sessions) {
      for (final m in settings) {
        final fit = fitToTime(s.ids, s.level, m);
        if (fit.leftOut.isEmpty) continue;
        shortened++;
        expect([for (final id in s.ids) if (fit.ids.contains(id)) id], fit.ids, reason: 'order kept: $s $m');
        expect({...fit.ids, ...fit.leftOut}, {...s.ids}, reason: 'nothing added or lost: $s $m');
        expect(fit.ids.length + fit.leftOut.length, s.ids.length, reason: '$s $m');
        expect(fit.leftOut.where(protected), isEmpty, reason: 'main lift left out: $s $m');
        expect(fit.ids.length, greaterThanOrEqualTo(minMovesWhenShortened), reason: '$s $m');
        expect(fit.estimate, estimateMinutes(fit.ids, s.level), reason: 'estimate is for the shown moves: $s $m');
        expect(fit.estimate!, lessThan(estimateMinutes(s.ids, s.level)!), reason: '$s $m');
      }
    }
    expect(shortened, greaterThan(0), reason: 'some prescribable session must need shortening at 20 or 30 min');
  });

  test('it stops as soon as the session fits, and keeps going only while protected moves remain the problem', () {
    for (final s in sessions) {
      for (final m in settings) {
        final fit = fitToTime(s.ids, s.level, m);
        if (fit.leftOut.isEmpty) continue;
        // Putting back the last move it left out would run over again: no more was removed than needed.
        final putBack = [for (final id in s.ids) if (fit.ids.contains(id) || id == fit.leftOut.first) id];
        expect(overTimeNotice(estimateMinutes(putBack, s.level), m), isNotNull, reason: '$s $m');
        // If it still runs over, nothing else could be removed under the rules.
        if (overTimeNotice(fit.estimate, m) != null) {
          final removable = fit.ids.where((id) => !protected(id));
          expect(removable.isEmpty || fit.ids.length == minMovesWhenShortened, isTrue, reason: '$s $m');
        }
      }
    }
  });

  test('the lowest-priority moves go first: a later move is never kept while an earlier unprotected one goes', () {
    for (final s in sessions) {
      for (final m in settings) {
        final fit = fitToTime(s.ids, s.level, m);
        for (final out in fit.leftOut) {
          final at = s.ids.indexOf(out);
          final keptLater = s.ids.skip(at + 1).where((id) => fit.ids.contains(id) && !protected(id));
          expect(keptLater, isEmpty, reason: '$s $m: kept a later unprotected move while leaving out $out');
        }
      }
    }
  });

  test('sets and doses never change, and the same input gives the same answer', () {
    for (final s in sessions) {
      final before = [for (final id in s.ids) (id, setsFor(id, s.level), doseFor(id, s.level))];
      final a = fitToTime(s.ids, s.level, 20), b = fitToTime([...s.ids], s.level, 20);
      expect(a.ids, b.ids);
      expect(a.leftOut, b.leftOut);
      expect([for (final id in s.ids) (id, setsFor(id, s.level), doseFor(id, s.level))], before);
      expect(s.ids, before.map((x) => x.$1).toList(), reason: 'input list not modified');
    }
  });

  test('worked example: gym strength A at level 2 in a 30-minute setting', () {
    final ids = sessionIds('strength', Tier.gym, 2, 0); // squat, bench, seated row, RDL, dead bug
    expect(estimateMinutes(ids, 2), 44);
    final fit = fitToTime(ids, 2, 30);
    expect(fit.leftOut, ['iny3m5y']); // only the dead bug may go; the four main lifts stay
    expect(fit.estimate, 37);
    expect(overTimeNotice(fit.estimate, 30), isNotNull, reason: 'still over: the over-time notice keeps showing');
  });

  test('worked example: bodyweight strength A at level 2 (38 min) fits 30 min without the dead bug, 20 min without two moves', () {
    final ids = sessionIds('strength', Tier.none, 2, 0); // squat, push-up, inverted row, glute bridge, dead bug
    expect(estimateMinutes(ids, 2), 38);
    final at30 = fitToTime(ids, 2, 30);
    expect(at30.leftOut, ['iny3m5y']);
    expect(at30.estimate, 31);
    final at20 = fitToTime(ids, 2, 20);
    expect(at20.leftOut, ['u0cNiij', 'iny3m5y']);
    expect(at20.ids, ['QChZi3x', 'I4hDWkc', 'bZGHsAZ']);
    expect(at20.estimate, 25);
    expect(overTimeNotice(at20.estimate, 20), isNull);
  });

  test('shortened notice wording', () {
    expect(shortenedNotice(['Dead Bug'], 37, 30), 'Shortened to fit your 30-minute setting: Dead Bug is left out today (about 37 min now). The main lifts stay as planned.');
    expect(shortenedNotice(['Glute Bridge', 'Dead Bug'], 25, 30), contains('Glute Bridge, Dead Bug are left out today'));
  });
}

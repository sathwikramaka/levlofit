import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/progression.dart';

// Session-to-session coaching rules (progression.dart). These test the software behaviour of Levlofit's rules; they
// say nothing about whether the thresholds are right for a given person (that needs qualified review).

final today = DateTime(2026, 10, 13); // a Tuesday
SessionLog s(int daysAgo, {int? rpe, Pain? pain}) => (day: today.subtract(Duration(days: daysAgo)), rpe: rpe, pain: pain);
Set<AdviceKind> kinds(List<Advice> a) => {for (final x in a) x.kind};

void main() {
  group('pain answers stored in notes', () {
    test('round trip, and anything else reads as no answer', () {
      for (final p in Pain.values) {
        expect(painFromNotes(painNote(p)), p);
      }
      expect(painFromNotes(null), isNull);
      expect(painFromNotes('felt great'), isNull);
      expect(painFromNotes('pain: severe'), isNull);
    });
  });

  group('session advice', () {
    test('no history, or only today, gives no advice', () {
      expect(sessionAdvice(const [], today), isEmpty);
      expect(sessionAdvice([s(0, rpe: 10, pain: Pain.stopped)], today), isEmpty);
    });

    test('a normal recent session gives no advice', () {
      expect(sessionAdvice([s(2, rpe: 7, pain: Pain.none)], today), isEmpty);
    });

    test('pain that stopped the last session comes first and names a professional', () {
      final a = sessionAdvice([s(2, rpe: 6, pain: Pain.stopped)], today);
      expect(a.first.kind, AdviceKind.pain);
      expect(a.first.text, contains('physiotherapist or doctor'));
      expect(kinds(sessionAdvice([s(2, pain: Pain.mild)], today)), isNot(contains(AdviceKind.pain)));
    });

    test('a break longer than 14 days means a lighter start; exactly 14 days does not', () {
      expect(kinds(sessionAdvice([s(15)], today)), {AdviceKind.returning});
      expect(sessionAdvice([s(15)], today).single.text, contains('15 days ago'));
      expect(kinds(sessionAdvice([s(14)], today)), isEmpty);
    });

    test('a very hard last session (9 or 10) means holding the weights; 8 does not', () {
      expect(kinds(sessionAdvice([s(2, rpe: 9)], today)), {AdviceKind.hardLast});
      expect(kinds(sessionAdvice([s(2, rpe: 8)], today)), isEmpty);
      expect(kinds(sessionAdvice([s(20, rpe: 10)], today)), {AdviceKind.returning}, reason: 'a long break wins over effort');
    });

    test('weeks in a row count back from this week or last week, and stop at an empty week', () {
      final steady = [for (var w = 0; w < 9; w++) s(1 + 7 * w)];
      expect(trainingWeeksInARow(steady, today), 9);
      expect(trainingWeeksInARow([s(1), s(8), s(22)], today), 2, reason: 'the week three weeks back is empty in between');
      expect(trainingWeeksInARow(const [], today), 0);
    });

    test('a lighter week after 8 weeks in a row, or after 6 when the last three sessions averaged 8 or more', () {
      final eight = [for (var w = 0; w < 8; w++) s(1 + 7 * w, rpe: 6)];
      expect(kinds(sessionAdvice(eight, today)), {AdviceKind.deload});
      final sixHard = [for (var w = 0; w < 6; w++) s(1 + 7 * w, rpe: 8)];
      expect(kinds(sessionAdvice(sixHard, today)), {AdviceKind.deload});
      expect(sessionAdvice(sixHard, today).single.text, contains('felt hard'));
      final sixEasy = [for (var w = 0; w < 6; w++) s(1 + 7 * w, rpe: 6)];
      expect(sessionAdvice(sixEasy, today), isEmpty);
      final sixUnknown = [for (var w = 0; w < 6; w++) s(1 + 7 * w)];
      expect(sessionAdvice(sixUnknown, today), isEmpty, reason: 'missing effort answers never count as hard');
    });
  });

  group('lift hints', () {
    const top = [(reps: 12, kg: 20.0), (reps: 12, kg: 20.0)];
    const mid = [(reps: 10, kg: 20.0), (reps: 9, kg: 20.0)];

    test('without notes the usual double-progression step is unchanged', () {
      expect(liftHint(top, const []), contains('add the smallest weight step'));
      expect(liftHint(mid, const []), contains('Same weight today'));
      expect(liftHint(const [], const []), startsWith('First time'));
    });

    test('a very hard last session turns "add weight" into "keep 20 kg"', () {
      final hard = sessionAdvice([s(2, rpe: 9)], today);
      expect(liftHint(top, hard), 'Last time: 20 kg, and the session felt very hard. Keep 20 kg today.');
      expect(liftHint(mid, hard), contains('Same weight today'), reason: 'a hold step stays a hold step');
    });

    test('pain or a long break never suggests adding weight', () {
      for (final a in [sessionAdvice([s(2, pain: Pain.stopped)], today), sessionAdvice([s(30)], today)]) {
        final hint = liftHint(top, a);
        expect(hint, isNot(contains('add the smallest weight step')));
        expect(hint, contains('20 kg'));
      }
      expect(liftHint(const [(reps: 12, kg: null)], sessionAdvice([s(30)], today)), contains('bodyweight'));
    });
  });
}

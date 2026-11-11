// Found on a phone (2026-11-07): logging a set with a weight typed threw a red error screen, because the field's
// controller was destroyed while the sheet was still animating closed with the field on screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/session.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('personal bests: heaviest ever, or most reps at a weight lifted before; never on the first log', () {
    const before = [(reps: 10, kg: 40.0), (reps: 8, kg: 45.0), (reps: 6, kg: null)];
    expect(personalBest(before, (reps: 3, kg: 47.5)), 'heaviest');
    expect(personalBest(before, (reps: 9, kg: 45.0)), 'reps');
    expect(personalBest(before, (reps: 8, kg: 45.0)), isNull, reason: 'a tie is not a best');
    expect(personalBest(before, (reps: 12, kg: 42.5)), isNull, reason: 'a new weight below the heaviest has nothing to compare');
    expect(personalBest(before, (reps: 7, kg: null)), 'reps', reason: 'bodyweight counts as one weight');
    expect(personalBest(const [], (reps: 10, kg: 40.0)), isNull);
  });

  test('a finished session counts the minutes it took, not the plan', () {
    final start = DateTime(2026, 11, 11, 18);
    expect(sessionMinutesSpent(start, start.add(const Duration(minutes: 37, seconds: 20))), 37);
    expect(sessionMinutesSpent(start, start.add(const Duration(seconds: 10))), 1);
    expect(sessionMinutesSpent(start, start.add(const Duration(hours: 9))), 240);
  });

  test('reopening a session keeps the sets from today; earlier sets stay as last time', () {
    Map<String, dynamic> row(String on, int no, int reps, double? kg) => {'exercise_id': 'a', 'performed_on': on, 'set_no': no, 'reps': reps, 'kg': kg};
    final s = splitSetLogs([row('2026-11-07', 1, 10, 40), row('2026-11-07', 2, 9, 40), row('2026-11-05', 1, 8, 35), row('2026-11-05', 2, 8, 35), row('2026-11-01', 1, 6, 30)], '2026-11-07');
    expect(s.today['a'], [(reps: 10, kg: 40.0), (reps: 9, kg: 40.0)]);
    expect(s.last['a'], [(reps: 8, kg: 35.0), (reps: 8, kg: 35.0)], reason: 'only the most recent earlier day');
    expect(splitSetLogs([row('2026-11-05', 1, 8, 35)], '2026-11-07').today, isEmpty);
  });

  testWidgets('logging a set with a weight typed closes its sheet without an error', (tester) async {
    tester.view.physicalSize = const Size(390, 1800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ids = sessionIds('strength', Tier.home, 1, 0);
    final rows = {for (final id in ids) id: {'id': id, 'name': 'move $id', 'gif_url': 'https://media.invalid/$id.gif', 'target_muscles': <String>[]}};
    await tester.pumpWidget(MaterialApp(home: SessionScreen(title: 'Strength', ids: ids, level: 1, moves: (x) async => resolveMoves(x, rows))));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('1').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '40');
    tester.view.viewInsets = const FakeViewPadding(bottom: 1000); // the keyboard is up
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Log set'));
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero; // it closes while the sheet animates away, which rebuilds the field
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/checkin.dart';

void main() {
  test('summary lists only what was answered, in neutral words', () {
    expect(checkInSummary(null), '');
    expect(checkInSummary({'workout': null, 'energy': null}), '');
    expect(checkInSummary({'workout': 'skipped', 'energy': 2, 'soreness': 0}), 'Training: skipped  ·  Energy 2/5  ·  Soreness: none');
    expect(checkInSummary({'food': 'partly', 'sleep': 5}), 'Food plan: partly  ·  Sleep 5/5');
  });

  test('empty check-in: nulls and blank notes only', () {
    expect(checkInEmpty({'workout': null, 'note': '  '}), isTrue);
    expect(checkInEmpty({'workout': null, 'soreness': 0}), isFalse); // "no soreness" is an answer
  });

  Future<Map<String, CheckIn>> pumpCard(WidgetTester tester, {CheckIn? existing, bool failSave = false}) async {
    final rows = <String, CheckIn>{'2026-11-03': ?existing};
    final CheckInStore store = (
      load: (day) async => rows[day],
      save: (day, a) async {
        if (failSave) throw Exception('offline');
        rows[day] = a;
      },
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CheckInCard(store: store, now: () => DateTime(2026, 11, 3, 21)))));
    await tester.pumpAndSettle();
    return rows;
  }

  testWidgets('new day: prompt, answer two questions, saved for today and shown on the card', (tester) async {
    final rows = await pumpCard(tester);
    expect(find.textContaining('How did today go?'), findsOneWidget);
    await tester.tap(find.byType(CheckInCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trained'));
    await tester.tap(find.text('A little'));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(rows['2026-11-03']!['workout'], 'done');
    expect(rows['2026-11-03']!['soreness'], 1);
    expect(rows['2026-11-03']!['energy'], isNull);
    expect(find.text('Training: trained  ·  Soreness: a little'), findsOneWidget);
  });

  testWidgets('edit: earlier answers are preselected and can be cleared', (tester) async {
    final rows = await pumpCard(tester, existing: {'workout': 'rest', 'energy': 3});
    await tester.tap(find.byType(CheckInCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest day')); // unselect
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(rows['2026-11-03']!['workout'], isNull);
    expect(rows['2026-11-03']!['energy'], 3);
  });

  testWidgets('save fails offline: sheet stays open with the error, nothing lost', (tester) async {
    await pumpCard(tester, failSave: true);
    await tester.tap(find.byType(CheckInCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Followed it'));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text('How did today go?'), findsOneWidget);
  });

  testWidgets('very sore shows the conservative care note', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byType(CheckInCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Very sore'));
    await tester.pump();
    expect(find.textContaining('physiotherapist or doctor'), findsOneWidget);
  });
}

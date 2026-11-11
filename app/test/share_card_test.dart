import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/share_card.dart';
import 'package:levlo/weekly_report.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  WeekReport week({int done = 3, int planned = 4}) => weeklyReport(
        monday: DateTime(2026, 11, 2),
        plannedPerWeek: planned,
        trained: {for (var i = 0; i < done; i++) DateTime(2026, 11, 2 + i)},
        food: const {},
        checkinDays: {DateTime(2026, 11, 3)},
        weights: const [],
      );

  test('the week card shares sessions, streak and check-ins, never food or weight', () {
    final card = weekShareCard(week(), streakWeeks: 5);
    expect(card.big, '3 of 4 sessions');
    expect(card.kicker, 'MY WEEK  ·  2 NOV TO 8 NOV');
    expect(card.facts.map((f) => f.$2), ['WEEKS STREAK', 'CHECK-INS']);
    expect([card.big, card.line, ...card.facts.expand((f) => [f.$1, f.$2])].join(' '), isNot(matches(RegExp('kcal|kg|weight|calor', caseSensitive: false))));
    expect(weekShareCard(week(done: 4), streakWeeks: 1).line, 'Every planned session done.');
  });

  testWidgets('the card fits a small phone sheet with long text', (tester) async {
    tester.view.physicalSize = const Size(320, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ShareCard(kicker: 'LEVEL UP', big: 'Level 12 and some more long words', line: 'Strength  ·  ' * 6, facts: const [('12', 'A'), ('3 / 7', 'B'), ('99', 'C')]),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

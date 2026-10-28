import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/level_up.dart';
import 'package:levlo/main.dart';
import 'package:levlo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('XP and levels: early levels quick, later ones slower, progress within a level', () {
    expect(xpFor(sessions: 2, completeDays: 3, waterDays: 4, activeMinutes: 95), 2 * 50 + 3 * 20 + 4 * 10 + 9);
    expect(levelFor(0), 1);
    expect(levelFor(49), 1);
    expect(levelFor(50), 2);
    expect(levelFor(199), 2);
    expect(levelFor(200), 3);
    expect(levelProgress(125), closeTo(0.5, 0.001)); // level 2 runs 50 to 200
    expect(levelFor(-5), 1);
  });

  test('ratings over 28 days, capped at 100', () {
    final today = DateTime(2026, 10, 27);
    final days = [for (var i = 0; i < 28; i++) today.subtract(Duration(days: i))];
    final r = ratingsFor(
      today: today,
      trained: days.take(6).toSet(), // 6 of 12 planned
      minutes: {for (final d in days) d: 40}, // 1,120 of 600
      sessionsPerWeek: 3,
      waterMet: (d) => d.day.isEven,
      dayComplete: (d) => false,
    );
    expect(r.training, 50);
    expect(r.movement, 100);
    expect(r.hydration, inInclusiveRange(40, 60));
    expect(r.consistency, 0);
    expect(overall(r), ((50 + 100 + r.hydration + 0) / 4).round());
  });

  test('66-day challenge: day count, complete days, missed days do not reset, ends after 66', () {
    final start = DateTime(2026, 9, 1);
    final s = challengeStatus(start, DateTime(2026, 9, 10), (d) => d.day != 5);
    expect(s.day, 10);
    expect(s.complete, 9);
    expect(s.over, isFalse);
    final done = challengeStatus(start, start.add(const Duration(days: 80)), (d) => true);
    expect(done.over, isTrue);
    expect(done.complete, challengeDays);
  });

  testWidgets('card: start the challenge, then it shows day 1, at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final today = DateTime(2026, 10, 27);
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: LevelUpCard(
            xp: 230,
            ratings: (training: 70, movement: 80, hydration: 50, consistency: 40),
            dayComplete: (_) => false,
            today: today,
          ),
        ),
      ),
    ));
    // XP shows as a rank, never as a Level, so it cannot be mistaken for a goal level (audit F16).
    expect(find.text('Rank 3'), findsOneWidget);
    expect(find.text('YOUR RANK'), findsOneWidget);
    expect(find.textContaining('Level'), findsNothing);
    expect(find.text('60'), findsOneWidget); // overall rating
    await tester.tap(find.text('Start the 66 days'));
    await tester.pump();
    expect(find.text('Day 1 of 66  ·  0 complete'), findsOneWidget);
    expect(prefs.getString(challengeStartKey), '2026-10-27');
    expect(tester.takeException(), isNull);
  });
}

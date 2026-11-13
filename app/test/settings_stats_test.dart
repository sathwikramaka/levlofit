import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart' show ActivityHeatmap, minutesByDay, weightChange;
import 'package:levlo/main.dart' show prefs;
import 'package:levlo/workout_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Settings and stats added on 2026-11-12 after the owner's reference screenshots.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('weight over 30 days: latest minus the last weigh-in on or before the cut; none without one', () {
    final now = DateTime(2026, 11, 12);
    final w = [(day: DateTime(2026, 10, 1), kg: 80.0), (day: DateTime(2026, 10, 12), kg: 79.0), (day: DateTime(2026, 11, 10), kg: 78.2)];
    expect(weightChange(w, now, 30), closeTo(-0.8, 1e-9));
    expect(weightChange(w.sublist(2), now, 30), isNull);
    expect(weightChange([(day: DateTime(2026, 11, 1), kg: 80.0), (day: DateTime(2026, 11, 10), kg: 79.0)], now, 30), isNull);
  });

  test('activity: minutes add up per day, a session without minutes still counts, levels by time', () {
    final m = minutesByDay([
      {'performed_on': '2026-11-10', 'duration_min': 30},
      {'performed_on': '2026-11-10', 'duration_min': 20},
      {'performed_on': '2026-11-11', 'duration_min': null},
    ]);
    expect(m[DateTime(2026, 11, 10)], 50);
    expect(m[DateTime(2026, 11, 11)], 1);
    expect([0, 10, 25, 45, 75].map(ActivityHeatmap.level), [0, 1, 2, 3, 4]);
  });

  testWidgets('the 12-month heatmap draws at phone width', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: ActivityHeatmap(minutes: {DateTime(2026, 11, 10): 45}, today: DateTime(2026, 11, 12)))),
    ));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('1 day '), findsOneWidget);
  });

  testWidgets('the heatmap starts the week the account was created', (tester) async {
    final today = DateTime(2026, 11, 12); // a Thursday
    expect(ActivityHeatmap.startFor(today, DateTime(2026, 10, 29)), DateTime(2026, 10, 26), reason: 'the Monday of the join week');
    expect(ActivityHeatmap.startFor(today, null), DateTime(2025, 11, 10), reason: 'no join date: 52 weeks back');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: ActivityHeatmap(minutes: {DateTime(2026, 9, 1): 30, DateTime(2026, 11, 10): 45}, today: today, since: DateTime(2026, 10, 29)))),
    ));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('1 day '), findsOneWidget, reason: 'training before the account existed is not counted');
  });

  test('workout choices: defaults, then saved and read back', () async {
    expect(loadWorkoutPrefs(), defaultWorkoutPrefs);
    await saveWorkoutPrefs((awake: false, rest: 120, sounds: false, flash: true, animations: Animations.small));
    expect(loadWorkoutPrefs(), (awake: false, rest: 120, sounds: false, flash: true, animations: Animations.small));
    expect(restLabel(null), 'By move');
    expect(restLabel(90), '90 s');
    expect(restLabel(180), '3 min');
  });


}

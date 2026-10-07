import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/coach_chat.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/theme.dart';

// A synthetic plan shaped like generated_plans.plan (engine 2.0). No real user data.
final _plan = <String, dynamic>{
  'trainingDaysPerWeek': 4,
  'goals': [
    {'goal': 'strength', 'name': 'Strength', 'startLevel': 1, 'sessionsPerWeek': 3, 'experience': 'beginner'},
    {'goal': 'running', 'name': 'Running', 'startLevel': 0, 'sessionsPerWeek': 1, 'experience': 'none'},
  ],
  'nutrition': {
    'energyKcal': 2350,
    'proteinG': 150,
    'proteinPerKg': 2.0,
    'maxSoyaChunksDryG': 50,
    'excludedFoodTags': ['beef', 'pork'],
    'supplements': <Map<String, dynamic>>[],
  },
  'bmi': {'value': 22.4, 'category': 'normal'},
  'review': [
    {'level': 'change', 'title': 'Cutting became maintenance', 'why': 'BMI under 18.', 'source': 'Misra 2009'},
    {'level': 'info', 'title': 'Waist to height', 'why': 'Healthy.', 'source': 'NICE 2022'},
  ],
  'sources': ['WHO 2020', 'ISSN 2017'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final name in ['light', 'dark']) {
    testWidgets('dashboard lays out at phone size without errors ($name)', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final today = DateTime.now();
      await tester.pumpWidget(MaterialApp(
        theme: name == 'light' ? lightTheme : darkTheme,
        home: Scaffold(body: dashboardBentoForTest(_plan, logged: {DateTime(today.year, today.month, today.day)})),
      ));
      await tester.pump(const Duration(seconds: 2)); // let the reveals and rings finish

      expect(tester.takeException(), isNull);
      expect(find.text('Done today'), findsOneWidget); // today is logged, so the workout card shows the done state
      expect(find.text('TRAIN'), findsOneWidget);
      // The list builds lazily: scroll each section in and check nothing throws on the way.
      for (final label in ['THIS WEEK', 'FUEL', 'BODY  ·  BMI']) {
        await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(label), findsWidgets, reason: label);
        expect(tester.takeException(), isNull, reason: 'while showing $label');
      }
    });
  }

  for (final empty in [true, false]) {
    testWidgets('progress lays out (${empty ? 'empty' : 'with data'})', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      String ago(int d) => now.subtract(Duration(days: d)).toIso8601String().substring(0, 10);
      final logs = empty ? <Map<String, dynamic>>[] : [{'performed_on': ago(9), 'duration_min': 45}, {'performed_on': ago(2), 'duration_min': null}];
      final body = empty
          ? <Map<String, dynamic>>[]
          : [
              {'measured_on': ago(30), 'weight_kg': 72.4, 'waist_cm': 84.0, 'body_fat_pct': null},
              {'measured_on': ago(15), 'weight_kg': 71.8, 'waist_cm': null, 'body_fat_pct': 18.5},
              {'measured_on': ago(1), 'weight_kg': 71, 'waist_cm': 82.5, 'body_fat_pct': null},
            ];
      await tester.pumpWidget(MaterialApp(theme: darkTheme, home: progressBodyForTest({..._plan, 'weightGoal': 'cut'}, logs, body)));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      for (final label in ['BODY WEIGHT', 'MEASUREMENTS', 'PHOTOS', 'TRAINING, LAST 12 WEEKS']) {
        await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: 'while showing $label');
      }
    });
  }

  test('weight trend and verdict', () {
    final start = DateTime(2026, 9, 1);
    // 80 kg losing 0.6 kg a week: about -0.75 % a week, inside the cut range.
    final pts = [for (var w = 0; w <= 4; w++) (day: start.add(Duration(days: 7 * w)), kg: 80 - 0.6 * w)];
    final pct = weeklyTrendPct(pts)!;
    expect(pct, closeTo(-0.6 / 78.8 * 100, 0.01));
    expect(verdict('cut', pct).title, 'On track');
    expect(verdict('bulk', pct).title, 'Slower than planned');
    expect(verdict('maintain', pct).title, 'Drifting down');
    expect(weeklyTrendPct(pts.take(2).toList()), isNull); // too few weigh-ins
    expect(verdict('cut', null).title, 'Not enough data yet');
  });

  testWidgets('chat screen lays out at phone size and renders markdown', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: darkTheme, home: const CoachScreen()));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Message Levlofit AI'), findsOneWidget);
    expect(find.text('Why is my plan built this way?'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: const Scaffold(body: Markdown('''## Plan
Eat **150 g** protein.
- dal
- paneer
1. Warm up
2. Lift''')),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.textContaining('paneer'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });

  for (final tab in ['workout', 'hydration', 'habits', 'foods', 'settings']) {
    testWidgets('$tab tab lays out at phone size', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final plan = {
        ..._plan,
        'phase': {'id': 'foundation', 'title': 'Foundation phase', 'why': 'Basics first.', 'source': 'Curriculum'},
        'roadmap': {
          'intro': 'Start with the basics.',
          'steps': [
            {'title': 'Learn the patterns', 'focus': 'Squat, hinge, push, pull.', 'moveOnWhen': 'Clean reps on all four.'},
            {'title': 'Add running', 'focus': 'Easy runs.', 'moveOnWhen': 'Strength reaches Level 2.'},
          ],
        },
        'goals': [
          {'goal': 'strength', 'name': 'Strength', 'startLevel': 1, 'sessionsPerWeek': 3, 'experience': 'beginner', 'kind': 'strength', 'status': 'active'},
          {'goal': 'running', 'name': 'Running', 'startLevel': 0, 'sessionsPerWeek': 0, 'experience': 'none', 'kind': 'endurance', 'status': 'queued', 'unlockWhen': 'Strength reaches Level 2'},
        ],
      };
      final report = FlutterError.onError;
      FlutterError.onError = (d) {
        debugPrint('LAYOUT: ${d.toString()}');
        report?.call(d);
      };
      addTearDown(() => FlutterError.onError = report);
      await tester.pumpWidget(MaterialApp(theme: darkTheme, home: tabForTest(tab, plan)));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      // Scroll to the end and back, checking nothing overflows on the way.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}

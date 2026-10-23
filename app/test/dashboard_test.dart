import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/coach_chat.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/dashboard_layout.dart';
import 'package:levlo/reminders.dart';
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

  for (final w in [390.0, 360.0]) {
  for (final name in ['light', 'dark']) {
    testWidgets('dashboard lays out at phone size without errors ($name, ${w.toInt()} dp)', (tester) async {
      tester.view.physicalSize = Size(w, 844) * 3;
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
  }

  testWidgets('week strip: a goal name stays on one line on a narrow phone', (tester) async {
    // On a 411 dp phone "Strength" broke as "Strengt / h" (2026-10-17); 360 dp is narrower still.
    tester.view.physicalSize = const Size(360, 780) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: darkTheme, home: Scaffold(body: dashboardBentoForTest(_plan))));
    await tester.pump(const Duration(seconds: 2));
    await tester.scrollUntilVisible(find.text('THIS WEEK'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(seconds: 1));
    final labels = find.text('Strength');
    expect(labels, findsWidgets);
    for (final e in labels.evaluate()) {
      expect(e.size!.height, lessThan(20), reason: 'one 10 pt line is 12 px high; two lines would be 24');
    }
    expect(tester.takeException(), isNull);
  });

  for (final w in [390.0, 360.0]) {
  for (final empty in [true, false]) {
    testWidgets('progress lays out (${empty ? 'empty' : 'with data'}, ${w.toInt()} dp)', (tester) async {
      tester.view.physicalSize = Size(w, 844) * 3;
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

  for (final w in [390.0, 360.0]) {
  for (final tab in ['workout', 'hydration', 'habits', 'foods', 'reminders', 'settings']) {
    testWidgets('$tab tab lays out at phone size (${w.toInt()} dp)', (tester) async {
      tester.view.physicalSize = Size(w, 844) * 3;
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

  testWidgets('a tab opened from another page shows a back arrow that returns there', (tester) async {
    var backs = 0;
    await tester.pumpWidget(MaterialApp(home: tabForTest('settings', _plan, onBack: () => backs++)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    expect(backs, 1);
  });

  testWidgets('a tab opened from the menu keeps the menu button', (tester) async {
    await tester.pumpWidget(MaterialApp(home: tabForTest('settings', _plan)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('hidden dashboard cards are not built; the customise button is there', (tester) async {
    tester.view.physicalSize = const Size(390, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final hide = {'rings', 'week', 'fuel'};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: dashboardBentoForTest(_plan, layout: [for (final c in defaultLayout) (id: c.id, visible: !hide.contains(c.id))]))));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.text('FUEL'), findsNothing);
    expect(find.text('DAILY GOAL'), findsOneWidget);
    expect(find.text('Customise dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily goal celebrates once when the chosen tasks are done', (tester) async {
    tester.view.physicalSize = const Size(390, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final streaks = <int>[];
    Widget app() => MaterialApp(
          home: Scaffold(body: dashboardBentoForTest(_plan, logged: {DateTime(now.year, now.month, now.day)}, dailyTasks: {'train'}, onCelebrated: streaks.add)),
        );
    await tester.pumpWidget(app()); // 'train' is done: today is logged
    await tester.pump(const Duration(seconds: 2));
    // One celebration; the streak depends on the calendar (a planned rest day yesterday also counts).
    expect(streaks, hasLength(1));
    expect(streaks.single, greaterThanOrEqualTo(1));
    expect(find.text('Daily goal done'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8)); // the banner leaves on its own
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 2));
    expect(streaks, hasLength(1)); // a rebuild does not celebrate again
  });

  testWidgets('reminders: exact timing off shows the explanation and a button; on shows no button', (tester) async {
    addTearDown(() => Reminders.timingOverride = null);
    Reminders.timingOverride = () async => ReminderTiming.inexact;
    await tester.pumpWidget(MaterialApp(home: tabForTest('reminders', _plan)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Exact timing: off'), findsOneWidget);
    expect(find.textContaining('may arrive a few minutes late'), findsOneWidget);
    // Tapping asks Android once; if the settings page cannot open (as here, in a test) nothing breaks.
    await tester.tap(find.text('Allow exact timing'));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    Reminders.timingOverride = () async => ReminderTiming.exact;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: tabForTest('reminders', _plan)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Exact timing: on'), findsOneWidget);
    expect(find.text('Allow exact timing'), findsNothing);
  });

  testWidgets('reminders: no timing row where timing is unknown (web, iOS, or the platform cannot be asked)', (tester) async {
    addTearDown(() => Reminders.timingOverride = null);
    Reminders.timingOverride = () async => null;
    await tester.pumpWidget(MaterialApp(home: tabForTest('reminders', _plan)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Exact timing'), findsNothing);
  });
}

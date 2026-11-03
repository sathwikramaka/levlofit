import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/weekly_report.dart';

void main() {
  final mon = DateTime(2026, 10, 26); // a Monday
  DateTime day(int i) => mon.add(Duration(days: i));
  WeekReport report({int planned = 3, Set<DateTime>? trained, Set<DateTime>? food, Set<DateTime>? checkins, List<Weigh> weights = const []}) =>
      weeklyReport(monday: mon, plannedPerWeek: planned, trained: trained ?? {}, foodDays: food ?? {}, checkinDays: checkins ?? {}, weights: weights);

  test('counts only days inside the week, once each', () {
    final r = report(trained: {day(0), day(0).add(const Duration(hours: 9)), day(2), day(7), day(-1)}, food: {day(1)}, checkins: {day(6)});
    expect(r.done, 2);
    expect(r.foodDays, 1);
    expect(r.checkinDays, 1);
  });

  test('a failed read is reported as unknown, never as zero', () {
    final r = weeklyReport(monday: mon, plannedPerWeek: 3, trained: {}, foodDays: null, checkinDays: null, weights: const []);
    expect(r.foodDays, isNull);
    expect(r.missing, containsAll(['Your food log could not be loaded.', 'Check-ins could not be loaded.']));
  });

  test('nothing logged: neutral observation and a small next step; every gap listed', () {
    final r = report();
    expect(r.observation, 'No training was logged this week.');
    expect(r.nextStep, contains('Twenty minutes'));
    expect(r.missing, hasLength(3));
  });

  test('all planned sessions done; food logging nudged when under 3 days', () {
    expect(report(trained: {day(0), day(2), day(4)}).observation, 'You logged all of your 3 planned sessions.');
    expect(report(trained: {day(0), day(2), day(4)}).nextStep, contains('logging food'));
    expect(report(trained: {day(0), day(2), day(4)}, food: {day(0), day(1), day(2)}).nextStep, contains('Keep the same plan'));
    expect(report(trained: {day(0), day(1), day(2), day(4)}).observation, 'You logged 4 sessions; 3 were planned.');
  });

  test('under half the plan: offers fewer days, never blames', () {
    final r = report(planned: 5, trained: {day(1), day(3)});
    expect(r.observation, 'You logged 2 of 5 planned sessions.');
    expect(r.nextStep, contains('lower training days'));
    expect(report(planned: 3, trained: {day(1), day(3)}).nextStep, contains('fixed days'));
  });

  test('weight difference only with 2+ weigh-ins in both weeks; rounded to 0.1 kg', () {
    final prev = [(day: day(-6), kg: 80.0), (day: day(-3), kg: 80.4)];
    expect(report(weights: [...prev, (day: day(1), kg: 79.9)]).weightChangeKg, isNull);
    final r = report(weights: [...prev, (day: day(1), kg: 79.9), (day: day(5), kg: 79.75)]);
    expect(r.weightChangeKg, -0.4);
    expect(r.missing.where((m) => m.startsWith('Weight')), isEmpty);
  });

  testWidgets('card lays out at phone width and shows the trend caveat with weight', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = report(trained: {day(0)}, weights: [(day: day(-6), kg: 70), (day: day(-2), kg: 70), (day: day(1), kg: 70.5), (day: day(3), kg: 70.5)]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: WeeklyReportCard(report: r)))));
    expect(tester.takeException(), isNull);
    expect(find.text('LAST WEEK  ·  26 OCT TO 1 NOV'), findsOneWidget);
    expect(find.text('+0.5 kg'), findsOneWidget);
    expect(find.textContaining('6-week trend'), findsOneWidget);
  });
}

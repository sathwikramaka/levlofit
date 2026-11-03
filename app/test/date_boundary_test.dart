import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/checkin.dart';
import 'package:levlo/progression.dart';
import 'package:levlo/weekly_report.dart';

// Date-boundary behaviour (stabilisation stage 2). The app keys every log by the phone's local calendar day, so these
// tests use local DateTimes at the edges of a day and a week. India has no daylight saving; DateTime arithmetic below
// works on calendar days, not 24-hour spans.
void main() {
  Future<String?> savedDay(WidgetTester tester, DateTime now) async {
    String? day;
    final CheckInStore store = (load: (_) async => null, save: (d, _) async => day = d);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CheckInCard(key: UniqueKey(), store: store, now: () => now))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckInCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trained'));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    return day;
  }

  testWidgets('check-in at 23:59 belongs to that day; at 00:00 to the next', (tester) async {
    expect(await savedDay(tester, DateTime(2026, 11, 3, 23, 59, 59)), '2026-11-03');
    expect(await savedDay(tester, DateTime(2026, 11, 4, 0, 0)), '2026-11-04');
  });

  testWidgets('app left open past midnight: the next check-in goes to the new day, not yesterday', (tester) async {
    var clock = DateTime(2026, 11, 3, 23, 50);
    final saved = <String, CheckIn>{};
    final CheckInStore store = (load: (d) async => saved[d], save: (d, a) async => saved[d] = a);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CheckInCard(store: store, now: () => clock))));
    await tester.pumpAndSettle();
    Future<void> checkIn(String answer) async {
      await tester.tap(find.byType(CheckInCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text(answer));
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    await checkIn('Trained');
    clock = DateTime(2026, 11, 4, 0, 10);
    await checkIn('Rest day');
    expect(saved['2026-11-03']!['workout'], 'done');
    expect(saved['2026-11-04']!['workout'], 'rest'); // and yesterday's answers were not carried over
    expect(saved['2026-11-04']!['energy'], isNull);
  });

  testWidgets('month and year ends roll over correctly', (tester) async {
    expect(await savedDay(tester, DateTime(2026, 12, 31, 23, 30)), '2026-12-31');
    expect(await savedDay(tester, DateTime(2027, 1, 1, 0, 5)), '2027-01-01');
  });

  test('weekly report: Sunday 23:59 is in the week, Monday 00:00 is the next week', () {
    final mon = DateTime(2026, 10, 26);
    final r = weeklyReport(
      monday: mon, plannedPerWeek: 3, food: const {}, checkinDays: {}, weights: const [],
      trained: {DateTime(2026, 11, 1, 23, 59), DateTime(2026, 11, 2, 0, 0), DateTime(2026, 10, 25, 23, 59)},
    );
    expect(r.done, 1);
  });

  test('a week across a month end and a year end is 7 calendar days', () {
    final r = weeklyReport(
      monday: DateTime(2026, 12, 28), plannedPerWeek: 7, food: const {}, checkinDays: {}, weights: const [],
      trained: {for (var i = 0; i < 9; i++) DateTime(2026, 12, 28 + i)}, // 28 Dec to 5 Jan
    );
    expect(r.done, 7); // 28 Dec - 3 Jan
  });

  test('welcome back counts calendar days, not hours', () {
    // Last session late on 6 Nov, opened early on 20 Nov: 14 calendar days even though under 14 x 24 hours.
    expect(welcomeBack(logged: {DateTime(2026, 11, 6, 22)}, planSince: DateTime(2026, 9, 1), today: DateTime(2026, 11, 20, 6)), (days: 14));
  });

  test('fewer-days weeks are Monday to Sunday in local time, whatever the hour today', () {
    final logged = {DateTime(2026, 10, 12, 23, 59), DateTime(2026, 10, 19, 0, 1), DateTime(2026, 10, 26, 12)};
    final late = fewerDaysOffer(planned: 3, logged: logged, planSince: DateTime(2026, 10, 1), today: DateTime(2026, 11, 2, 23, 59));
    final early = fewerDaysOffer(planned: 3, logged: logged, planSince: DateTime(2026, 10, 1), today: DateTime(2026, 11, 2, 0, 0));
    expect(late!.perWeek, [1, 1, 1]);
    expect(early!.perWeek, [1, 1, 1]);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/progression.dart';

void main() {
  final today = DateTime(2026, 11, 4); // Wednesday; full weeks start 12, 19 and 26 Oct
  final since = DateTime(2026, 10, 1);
  Set<DateTime> on(List<int> octDays) => {for (final d in octDays) DateTime(2026, 10, d)};

  test('three short weeks: offers the rounded-up average, below the plan', () {
    final o = fewerDaysOffer(planned: 5, logged: on([13, 15, 20, 22, 24, 27, 29]), planSince: since, today: today);
    expect(o!.perWeek, [2, 3, 2]);
    expect(o.suggested, 3);
  });

  test('one week on plan: no offer', () {
    expect(fewerDaysOffer(planned: 3, logged: on([13, 20, 21, 22, 27]), planSince: since, today: today), isNull);
  });

  test('no sessions at all is a break, not a schedule problem', () {
    expect(fewerDaysOffer(planned: 4, logged: {}, planSince: since, today: today), isNull);
  });

  test('a plan younger than three full weeks: no offer', () {
    expect(fewerDaysOffer(planned: 4, logged: on([20, 27]), planSince: DateTime(2026, 10, 14), today: today), isNull);
    expect(fewerDaysOffer(planned: 4, logged: on([20, 27]), planSince: DateTime(2026, 10, 12, 18), today: today), isNotNull);
  });

  test('never below 1 day and never at the plan; a 1-day plan is never cut', () {
    expect(fewerDaysOffer(planned: 3, logged: on([13]), planSince: since, today: today)!.suggested, 1);
    expect(fewerDaysOffer(planned: 3, logged: on([13, 14, 20, 21, 27, 28]), planSince: since, today: today)!.suggested, 2); // steady 2 of 3
    expect(fewerDaysOffer(planned: 1, logged: {}, planSince: since, today: today), isNull);
  });

  test('this week and sessions before the window do not count', () {
    expect(fewerDaysOffer(planned: 3, logged: on([1, 2, 3, 5, 13]).union({DateTime(2026, 11, 2), DateTime(2026, 11, 3)}), planSince: since, today: today)!.perWeek, [1, 0, 0]);
  });
}

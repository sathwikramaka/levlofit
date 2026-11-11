import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart';

void main() {
  final monday = DateTime(2026, 11, 9);
  Set<DateTime> weeksMet(List<int> weeksBack, {int days = 3}) => {
        for (final w in weeksBack)
          for (var d = 0; d < days; d++) monday.subtract(Duration(days: 7 * w - d)),
      };

  test('weeks in a row on plan, counting back from last week', () {
    expect(weekStreak(weeksMet([1, 2, 3]), monday, 3), (weeks: 3, forgiven: false));
    expect(weekStreak(weeksMet([0, 1]), monday, 3).weeks, 2, reason: 'this week joins once met');
  });

  test('one short week a month is let off; a second one inside four weeks ends the streak', () {
    expect(weekStreak(weeksMet([1, 3, 4]), monday, 3), (weeks: 3, forgiven: true), reason: 'week 2 let off');
    expect(weekStreak(weeksMet([1, 4]), monday, 3), (weeks: 1, forgiven: false), reason: 'weeks 2 and 3 both short: the streak ends, no pass used');
    expect(weekStreak(weeksMet([1, 2, 3, 4, 6, 7]), monday, 3).weeks, 6, reason: 'weeks 5 short, the pass is free again');
    expect(weekStreak(<DateTime>{}, monday, 3), (weeks: 0, forgiven: false));
  });
}

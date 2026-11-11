import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/home_widget.dart';

void main() {
  test('home widget lines: the session and length, done, or a rest day; the week and any streak', () {
    expect(widgetLines(session: 'Strength', done: false, minutes: 45, doneThisWeek: 1, perWeek: 4, streakWeeks: 3),
        (today: 'Strength  ·  45 min', week: '1 of 4 sessions this week  ·  3-week streak'));
    expect(widgetLines(session: 'Strength', done: true, minutes: 45, doneThisWeek: 2, perWeek: 4, streakWeeks: 0).today, 'Strength, done');
    expect(widgetLines(session: null, done: false, doneThisWeek: 0, perWeek: 3, streakWeeks: 0),
        (today: 'Rest day', week: '0 of 3 sessions this week'));
  });
}

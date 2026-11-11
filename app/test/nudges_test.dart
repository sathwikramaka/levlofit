import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/reminders.dart';

void main() {
  const on = (enabled: true, workout: null, waterEveryH: null, weighInWeekday: null, waterWindow: null);

  test('nudges: Sunday recap, morning check-in and four meals, each once a day, inside the reminder id range', () {
    final s = slotsFor(on, const {}, extras: (recap: true, coach: true, meals: true));
    final recap = s.singleWhere((x) => x.title == recapTitle);
    expect((recap.weekday, recap.hour), (7, 19));
    expect(s.where((x) => x.title == coachTitle).single.weekday, isNull, reason: 'every day');
    expect(s.where((x) => mealTitles.contains(x.title)).length, 4);
    expect(s.every((x) => isReminderId(x.id)), isTrue);
    expect(s.map((x) => x.id).toSet().length, s.length, reason: 'ids are unique');
  });

  test('nudges stay off with no extras, and the master switch silences them', () {
    expect(slotsFor(on, const {}), isEmpty);
    expect(slotsFor(remindersOff, const {}, extras: (recap: true, coach: true, meals: true)), isEmpty);
  });

  test('a tapped reminder is recognised by the title in its payload', () {
    const slot = (id: 400, weekday: 7, hour: 19, minute: 0, title: recapTitle, body: 'b');
    expect(payloadTitle(slotKey(slot, ReminderTiming.exact, 'Asia/Kolkata')), recapTitle);
    expect(payloadTitle('lvtest|alarmClock|7|30'), isNull);
    expect(payloadTitle(null), isNull);
  });
}

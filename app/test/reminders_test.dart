import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/reminders.dart';

void main() {
  test('reminder slots follow the settings', () {
    const sessions = {1: 'Strength', 3: 'Strength', 5: 'Running'};
    final all = slotsFor((enabled: true, workout: const TimeOfDay(hour: 18, minute: 30), waterEveryH: 3, weighInWeekday: 7), sessions);
    // 3 training days, water at 9, 12, 15, 18, 21, one weigh-in.
    expect(all.where((s) => s.id >= 100 && s.id < 200).map((s) => s.weekday), [1, 3, 5]);
    expect(all.where((s) => s.id >= 200 && s.id < 300).map((s) => s.hour), [9, 12, 15, 18, 21]);
    expect(all.singleWhere((s) => s.id == 300).weekday, 7);
    expect(all.firstWhere((s) => s.weekday == 5).body, contains('Running'));
    expect(all.map((s) => s.id).toSet().length, all.length); // ids never collide
    expect(slotsFor((enabled: false, workout: const TimeOfDay(hour: 7, minute: 0), waterEveryH: 1, weighInWeekday: 1), sessions), isEmpty);
    expect(slotsFor((enabled: true, workout: null, waterEveryH: null, weighInWeekday: null), sessions), isEmpty);
  });

  const on = (enabled: true, workout: TimeOfDay(hour: 18, minute: 0), waterEveryH: 2, weighInWeekday: 1);
  CustomReminder own(String name, Set<int> days, {bool enabled = true}) => (id: name, name: name, at: const TimeOfDay(hour: 7, minute: 30), weekdays: days, enabled: enabled);

  test('custom reminders: one slot per chosen day, or one daily slot', () {
    final slots = slotsFor(on, const {}, custom: [own('Creatine', {}), own('Stretch', {5, 1, 3}), own('Off', {2}, enabled: false)]);
    final custom = slots.where((s) => s.id >= 1000).toList();
    expect([for (final s in custom) (s.title, s.weekday)], [('Creatine', null), ('Stretch', 1), ('Stretch', 3), ('Stretch', 5)]);
    expect(custom.every((s) => s.hour == 7 && s.minute == 30), isTrue);
    // All seven days is the same as every day.
    expect(slotsFor(on, const {}, custom: [own('All', {1, 2, 3, 4, 5, 6, 7})]).where((s) => s.id >= 1000).single.weekday, isNull);
  });

  test('custom reminder ids never collide with each other or the built-in ones', () {
    final twenty = [for (var i = 0; i < 25; i++) own('r$i', {1, 2, 3, 4, 5, 6})];
    final slots = slotsFor(on, const {1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'E', 6: 'F', 7: 'G'}, custom: twenty);
    expect(slots.map((s) => s.id).toSet().length, slots.length);
    expect(slots.where((s) => s.id >= 1000).length, maxCustomReminders * 6); // capped at 20 reminders
    expect(slots.where((s) => s.id >= 1000).every((s) => s.id < 1000 + 8 * maxCustomReminders), isTrue);
  });

  test('the master switch silences custom reminders too', () {
    expect(slotsFor((enabled: false, workout: null, waterEveryH: null, weighInWeekday: null), const {}, custom: [own('x', {})]), isEmpty);
  });

  test('day labels and the database row round-trip', () {
    expect(describeDays({}), 'Every day');
    expect(describeDays({1, 2, 3, 4, 5, 6, 7}), 'Every day');
    expect(describeDays({5, 4, 3, 2, 1}), 'Weekdays');
    expect(describeDays({6, 7}), 'Weekends');
    expect(describeDays({5, 1, 3}), 'Mon, Wed, Fri');
    final row = customToRow((id: null, name: '  Creatine ', at: const TimeOfDay(hour: 8, minute: 5), weekdays: {3, 1}, enabled: false));
    expect(row, {'name': 'Creatine', 'remind_at': '08:05', 'weekdays': [1, 3], 'enabled': false});
    expect(customToRow(own('x', {1, 2, 3, 4, 5, 6, 7}))['weekdays'], isEmpty);
    final back = customFromRow({...row, 'id': 'abc', 'remind_at': '08:05:00'});
    expect((back.id, back.name, back.at, back.enabled), ('abc', 'Creatine', const TimeOfDay(hour: 8, minute: 5), false));
    expect(back.weekdays, {1, 3});
  });

  Future<Object?> openEditor(WidgetTester tester, CustomReminder? initial) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    Object? result = 'not closed';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showModalBottomSheet<Object>(context: context, isScrollControlled: true, builder: (_) => CustomReminderEditor(initial: initial)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('editor needs a name and returns the reminder with its days', (tester) async {
    Object? result;
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showModalBottomSheet<Object>(context: context, isScrollControlled: true, builder: (_) => const CustomReminderEditor()),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
    expect(find.text('Delete'), findsNothing); // nothing to delete yet
    await tester.enterText(find.byType(TextField), 'Creatine');
    await tester.tap(find.text('Mon'));
    await tester.tap(find.text('Fri'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat: Mon, Fri'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final r = result as CustomReminder;
    expect((r.id, r.name, r.enabled), (null, 'Creatine', true));
    expect(r.weekdays, {1, 5});
  });

  testWidgets('editor deletes only after confirming', (tester) async {
    await openEditor(tester, own('Stretch', {2}));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this reminder?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(find.text('Edit reminder'), findsOneWidget); // still open, nothing deleted
  });

  // ---- diff-based scheduling (planReminderChanges) ----
  const zone = 'Asia/Kolkata';
  final daily = slotsFor(on, const {1: 'Strength'}, custom: [own('Creatine', {})]);
  Map<int, String?> pendingFor(List<Slot> slots, ReminderTiming t) => {for (final s in slots) s.id: slotKey(s, t, zone)};

  test('unchanged reminders are neither cancelled nor rescheduled', () {
    final plan = planReminderChanges(daily, pendingFor(daily, ReminderTiming.exact), ReminderTiming.exact, zone);
    expect(plan.cancel, isEmpty);
    expect(plan.schedule, isEmpty);
  });

  test('a changed time reschedules only that reminder, without cancelling it first', () {
    final pending = pendingFor(daily, ReminderTiming.exact);
    final moved = slotsFor(on, const {1: 'Strength'}, custom: [(id: 'Creatine', name: 'Creatine', at: const TimeOfDay(hour: 7, minute: 45), weekdays: <int>{}, enabled: true)]);
    final plan = planReminderChanges(moved, pending, ReminderTiming.exact, zone);
    expect(plan.cancel, isEmpty); // replacing an id keeps any notification of it on screen
    expect(plan.schedule.map((s) => (s.id, s.hour, s.minute)), [(1000, 7, 45)]);
  });

  test('a removed reminder is cancelled; the test notification and foreign ids are never touched', () {
    final pending = {...pendingFor(daily, ReminderTiming.exact), 1: null, 7: 'someone else', 99: null};
    final withoutCustom = slotsFor(on, const {1: 'Strength'});
    final plan = planReminderChanges(withoutCustom, pending, ReminderTiming.exact, zone);
    expect(plan.cancel, [1000]);
    expect(plan.schedule, isEmpty);
  });

  test('switching reminders off cancels only Levlofit reminder ids', () {
    final pending = {...pendingFor(daily, ReminderTiming.exact), 1: null};
    final plan = planReminderChanges(slotsFor((enabled: false, workout: null, waterEveryH: null, weighInWeekday: null), const {}), pending, ReminderTiming.exact, zone);
    expect(plan.cancel, [for (final s in daily) s.id]..sort());
    expect(plan.cancel, isNot(contains(1)));
    expect(plan.schedule, isEmpty);
  });

  test('clearing on sign-out or account deletion (remindersOff) cancels every Levlofit reminder and nothing else', () {
    final custom = slotsFor(defaultPrefs, const {1: 'Strength'}, custom: [own('Stretch', {})]);
    final pending = {...pendingFor(custom, ReminderTiming.exact), 1: null, alarmClockTestId: null, 42: 'someone else'};
    final plan = planReminderChanges(slotsFor(remindersOff, const {1: 'Strength'}, custom: [own('Stretch', {})]), pending, ReminderTiming.exact, zone);
    expect(plan.cancel, [for (final s in custom) s.id]..sort());
    expect(plan.cancel, containsAll([101, 1000])); // a built-in and a custom reminder
    expect(plan.cancel.where((id) => id < 100), isEmpty, reason: 'test notification, timing test alarm and foreign ids stay');
    expect(plan.schedule, isEmpty);
  });

  test('when the own reminders could not be read (keepCustom), their alarms stay; built-in changes still apply', () {
    final withCustom = slotsFor(defaultPrefs, const {1: 'Strength'}, custom: [own('Stretch', {}), own('Creatine', {1, 3})]);
    final pending = pendingFor(withCustom, ReminderTiming.exact);
    final builtInOnly = slotsFor(defaultPrefs, const {1: 'Strength'});
    final plan = planReminderChanges(builtInOnly, pending, ReminderTiming.exact, zone, keepCustom: true);
    expect(plan.cancel, isEmpty, reason: 'no custom alarm is cancelled because a read failed');
    expect(plan.schedule, isEmpty);
    // Without the flag the same input would cancel them all (the bug this guards against).
    expect(planReminderChanges(builtInOnly, pending, ReminderTiming.exact, zone).cancel.where(isCustomReminderId), isNotEmpty);
    // A removed built-in reminder is still cancelled with keepCustom.
    final noWater = slotsFor((enabled: true, workout: defaultPrefs.workout, waterEveryH: null, weighInWeekday: 1), const {1: 'Strength'});
    final p2 = planReminderChanges(noWater, pending, ReminderTiming.exact, zone, keepCustom: true);
    expect(p2.cancel, isNotEmpty);
    expect(p2.cancel.every((id) => !isCustomReminderId(id)), isTrue);
  });

  test('a change of timing (permission granted or revoked) re-registers every reminder in the new mode', () {
    final plan = planReminderChanges(daily, pendingFor(daily, ReminderTiming.exact), ReminderTiming.inexact, zone);
    expect(plan.cancel, isEmpty);
    expect(plan.schedule.length, daily.length);
    final back = planReminderChanges(daily, pendingFor(daily, ReminderTiming.inexact), ReminderTiming.exact, zone);
    expect(back.schedule.length, daily.length);
  });

  test('alarms from the old version (no payload) and a timezone change are re-registered', () {
    expect(planReminderChanges(daily, {for (final s in daily) s.id: null}, ReminderTiming.exact, zone).schedule.length, daily.length);
    expect(planReminderChanges(daily, pendingFor(daily, ReminderTiming.exact), ReminderTiming.exact, 'Europe/London').schedule.length, daily.length);
  });

  test('the first apply after launch re-registers everything (force-stop recovery) but still cancels nothing wanted', () {
    final pending = {...pendingFor(daily, ReminderTiming.exact), 1: null};
    final plan = planReminderChanges(daily, pending, ReminderTiming.exact, zone, refreshAll: true);
    expect(plan.cancel, isEmpty);
    expect(plan.schedule.length, daily.length);
  });

  test('a missing alarm is scheduled', () {
    final pending = pendingFor(daily, ReminderTiming.exact)..remove(daily.first.id);
    expect(planReminderChanges(daily, pending, ReminderTiming.exact, zone).schedule.map((s) => s.id), [daily.first.id]);
  });

  test('timestamps for the database are UTC with a Z', () {
    final ist = DateTime.parse('2026-10-15T13:47:23+05:30');
    expect(utcNow(ist), '2026-10-15T08:17:23.000Z');
    expect(utcNow(), endsWith('Z'));
  });
}

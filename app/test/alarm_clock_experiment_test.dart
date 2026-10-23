import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/reminders.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// The alarm-clock timing experiment: one standalone test alarm, kept apart from saved reminders.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tzdata.initializeTimeZones(); // the app does this in Reminders._init
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  final scheduled = <(Slot, tz.TZDateTime)>[];
  final cancelled = <int>[];
  setUp(() {
    scheduled.clear();
    cancelled.clear();
    Reminders.alarmClockScheduleOverride = (s, at) async => scheduled.add((s, at));
    Reminders.alarmClockCancelOverride = (id) async => cancelled.add(id);
  });
  tearDown(() {
    Reminders.alarmClockScheduleOverride = null;
    Reminders.alarmClockCancelOverride = null;
  });

  const prefsOn = (enabled: true, workout: TimeOfDay(hour: 18, minute: 0), waterEveryH: 2, weighInWeekday: 1);
  final custom = <CustomReminder>[(id: 'a', name: 'Creatine', at: const TimeOfDay(hour: 8, minute: 0), weekdays: <int>{}, enabled: true)];

  test('the test alarm is one-off and outside the reminder range', () {
    final s = alarmClockTestSlot(const TimeOfDay(hour: 16, minute: 45));
    expect((s.id, s.weekday, s.hour, s.minute), (alarmClockTestId, null, 16, 45));
    expect(isReminderId(alarmClockTestId), isFalse);
    expect(s.title, 'Levlofit timing test');
  });

  test('normal reminders never use the test id, and their plan never cancels or reschedules the test alarm', () {
    final slots = slotsFor(prefsOn, const {1: 'S'}, custom: custom);
    expect(slots.map((s) => s.id), isNot(contains(alarmClockTestId)));
    const zone = 'Asia/Kolkata';
    final pending = {for (final s in slots) s.id: slotKey(s, ReminderTiming.exact, zone), alarmClockTestId: 'lvtest|alarmClock|16|45'};
    for (final refreshAll in [false, true]) {
      final plan = planReminderChanges(slots, pending, ReminderTiming.exact, zone, refreshAll: refreshAll);
      expect(plan.cancel, isNot(contains(alarmClockTestId)));
      expect(plan.schedule.map((s) => s.id), isNot(contains(alarmClockTestId)));
    }
    // Turning reminders off cancels reminders only, not the test alarm.
    final off = planReminderChanges(const [], pending, ReminderTiming.exact, zone);
    expect(off.cancel, isNot(contains(alarmClockTestId)));
    expect(off.cancel.length, slots.length);
  });

  test('scheduling twice replaces the same alarm (no duplicate); an edit moves it', () async {
    await Reminders.scheduleAlarmClockTest(const TimeOfDay(hour: 16, minute: 45));
    await Reminders.scheduleAlarmClockTest(const TimeOfDay(hour: 17, minute: 5));
    expect(scheduled.map((e) => e.$1.id).toSet(), {alarmClockTestId});
    expect((scheduled.last.$2.hour, scheduled.last.$2.minute), (17, 5));
  });

  test('cancel touches the test alarm only', () async {
    await Reminders.cancelAlarmClockTest();
    expect(cancelled, [alarmClockTestId]);
  });

  test('a refusal from Android is reported, not thrown', () async {
    Reminders.alarmClockScheduleOverride = (s, at) async => throw PlatformException(code: 'exact_alarms_not_permitted');
    String? message;
    final when = await Reminders.scheduleAlarmClockTest(const TimeOfDay(hour: 9, minute: 0), onError: (m) => message = m);
    expect(when, isNull);
    expect(message, contains('Alarms & reminders'));
  });

  testWidgets('Reminders screen (test build): schedule and cancel the test alarm; your own reminders stay', (tester) async {
    tester.view.physicalSize = const Size(390, 2200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: tabForTest('reminders', const {'trainingDaysPerWeek': 3, 'goals': []})));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('TIMING EXPERIMENT'), findsOneWidget);
    expect(find.text('YOUR OWN'), findsOneWidget);
    await tester.tap(find.text('Schedule test alarm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(scheduled, hasLength(1));
    expect(scheduled.single.$1.id, alarmClockTestId);
    expect(find.textContaining('alarm-clock mode'), findsOneWidget);
    await tester.tap(find.text('Cancel test alarm'));
    await tester.pumpAndSettle();
    expect(cancelled, [alarmClockTestId]);
    expect(find.text('Test alarm cancelled.'), findsOneWidget);
  });
}

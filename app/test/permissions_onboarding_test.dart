import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/main.dart';
import 'package:levlo/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Permission onboarding and reminder timing. The platform checks are replaced through Reminders' test overrides,
// so no real permission is read or requested.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tzdata.initializeTimeZones();
  });

  var requests = 0;
  setUp(() async {
    requests = 0;
    await prefs.clear();
    Reminders.requestOverride = () async {
      requests++;
      return false;
    };
  });
  tearDown(() {
    Reminders.notificationsOverride = null;
    Reminders.timingOverride = null;
    Reminders.requestOverride = null;
  });

  Future<void> show(WidgetTester tester, {void Function()? onDone}) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: PermissionsScreen(onDone: onDone ?? () {})));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('notifications: asked only when tapped, and shown as on once allowed', (tester) async {
    var allowed = false;
    Reminders.notificationsOverride = () async => allowed;
    Reminders.requestOverride = () async {
      requests++;
      allowed = true;
      return true;
    };
    await show(tester);
    expect(requests, 0); // nothing is requested just by opening the screen
    await tester.tap(find.text('Allow notifications'));
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 1);
    expect(find.text('Allow notifications'), findsNothing);
    expect(find.text('On'), findsWidgets);
  });

  testWidgets('notifications denied: one request, no second prompt, and a way to turn them on later', (tester) async {
    Reminders.notificationsOverride = () async => false;
    await show(tester);
    await tester.tap(find.text('Allow notifications'));
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 1);
    expect(find.text('Allow notifications'), findsNothing);
    expect(find.textContaining('turn them on later in Reminders'), findsOneWidget);
  });

  testWidgets('already allowed (or below Android 13): no button, shown as on', (tester) async {
    Reminders.notificationsOverride = () async => true;
    await show(tester);
    expect(find.text('Allow notifications'), findsNothing);
    expect(requests, 0);
  });

  testWidgets('exact timing off: explained as a system setting with a button to Alarms & reminders', (tester) async {
    Reminders.notificationsOverride = () async => true;
    Reminders.timingOverride = () async => ReminderTiming.inexact;
    await show(tester);
    expect(find.text('Reminders on time'), findsOneWidget);
    expect(find.textContaining('system setting, not a pop-up'), findsOneWidget);
    expect(find.text('Open Alarms & reminders'), findsOneWidget);
  });

  testWidgets('exact timing re-read on return to the app', (tester) async {
    var timing = ReminderTiming.inexact;
    Reminders.notificationsOverride = () async => true;
    Reminders.timingOverride = () async => timing;
    await show(tester);
    expect(find.text('Open Alarms & reminders'), findsOneWidget);
    timing = ReminderTiming.exact; // the user switched Levlofit on in Alarms & reminders
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Open Alarms & reminders'), findsNothing);
  });

  testWidgets('exact timing not applicable (web, iOS) or allowed (below Android 12): no button', (tester) async {
    Reminders.notificationsOverride = () async => true;
    Reminders.timingOverride = () async => null;
    await show(tester);
    expect(find.text('Reminders on time'), findsNothing);
    Reminders.timingOverride = () async => ReminderTiming.exact;
    await tester.pumpWidget(const SizedBox()); // a fresh screen, as on a new launch
    await show(tester);
    expect(find.text('Reminders on time'), findsOneWidget);
    expect(find.text('Open Alarms & reminders'), findsNothing);
  });

  testWidgets('nothing blocks the app: Continue works with everything denied', (tester) async {
    Reminders.notificationsOverride = () async => false;
    Reminders.timingOverride = () async => ReminderTiming.inexact;
    var done = 0;
    await show(tester, onDone: () => done++);
    await tester.scrollUntilVisible(find.text('Continue'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(seconds: 1));
    expect(done, 1);
    expect(prefs.getBool('permissions_seen'), isTrue);
    expect(requests, 0);
  });

  test('saving reminders asks for notifications at most once, ever', () async {
    await Reminders.requestPermissionOnce();
    await Reminders.requestPermissionOnce();
    await Reminders.requestPermissionOnce();
    expect(requests, 1);
  });

  testWidgets('Reminders screen: a failed settings read shows an error and Retry, never editable defaults', (tester) async {
    Reminders.notificationsOverride = () async => true;
    Reminders.timingOverride = () async => ReminderTiming.exact;
    // No server in tests: the settings read fails, as it would offline.
    await tester.pumpWidget(MaterialApp(home: tabForTest('reminders', const {'trainingDaysPerWeek': 3, 'goals': []})));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Your reminder settings could not be loaded'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Every 2 h'), findsNothing, reason: 'no default chip that one tap would save over the real settings');
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Reminders screen: notifications off shows a turn-on row; Settings links to reminders', (tester) async {
    Reminders.notificationsOverride = () async => false;
    Reminders.timingOverride = () async => ReminderTiming.exact;
    await tester.pumpWidget(MaterialApp(home: tabForTest('reminders', const {'trainingDaysPerWeek': 3, 'goals': []})));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Notifications: off'), findsOneWidget);
    await tester.tap(find.text('Turn on notifications'));
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 1);
    await tester.pumpWidget(MaterialApp(home: tabForTest('settings', const {'trainingDaysPerWeek': 3, 'goals': []})));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Notifications and reminders'), findsOneWidget);
  });

  group('next occurrence (timezone and daylight saving)', () {
    Slot slot({int? weekday, int hour = 18, int minute = 0}) => (id: 100, weekday: weekday, hour: hour, minute: minute, title: 't', body: 'b');

    test('later today, or tomorrow once the time has passed (India)', () {
      final kolkata = tz.getLocation('Asia/Kolkata');
      expect(Reminders.nextOccurrence(slot(), tz.TZDateTime(kolkata, 2026, 10, 15, 17, 59)), tz.TZDateTime(kolkata, 2026, 10, 15, 18));
      expect(Reminders.nextOccurrence(slot(), tz.TZDateTime(kolkata, 2026, 10, 15, 18)), tz.TZDateTime(kolkata, 2026, 10, 16, 18));
    });

    test('weekly reminders land on their weekday', () {
      final kolkata = tz.getLocation('Asia/Kolkata');
      final next = Reminders.nextOccurrence(slot(weekday: DateTime.friday), tz.TZDateTime(kolkata, 2026, 10, 15, 19)); // a Thursday
      expect((next.weekday, next.day, next.hour), (DateTime.friday, 16, 18));
      final sameDay = Reminders.nextOccurrence(slot(weekday: DateTime.thursday), tz.TZDateTime(kolkata, 2026, 10, 15, 19));
      expect(sameDay.day, 22); // today's has passed: next week
    });

    test('daylight saving keeps the wall-clock time', () {
      final ny = tz.getLocation('America/New_York');
      // US clocks go back on 1 Nov 2026 and forward on 8 Mar 2026: 18:00 stays 18:00.
      final autumn = Reminders.nextOccurrence(slot(), tz.TZDateTime(ny, 2026, 10, 31, 19));
      expect((autumn.day, autumn.hour, autumn.minute), (1, 18, 0));
      expect(autumn.difference(tz.TZDateTime(ny, 2026, 10, 31, 18)), const Duration(hours: 25));
      final spring = Reminders.nextOccurrence(slot(), tz.TZDateTime(ny, 2026, 3, 7, 19));
      expect((spring.day, spring.hour), (8, 18));
      expect(spring.difference(tz.TZDateTime(ny, 2026, 3, 7, 18)), const Duration(hours: 23));
    });
  });

  group('exact and inexact scheduling plans', () {
    const zone = 'Asia/Kolkata';
    final slots = slotsFor((enabled: true, workout: const TimeOfDay(hour: 18, minute: 0), waterEveryH: 3, weighInWeekday: 1), const {1: 'S', 3: 'S'});

    test('every slot id is unique, so one reminder never posts twice', () {
      expect(slots.map((s) => s.id).toSet().length, slots.length);
    });

    test('alarms recorded as exact are re-registered as inexact when access is lost, and back again', () {
      final exact = {for (final s in slots) s.id: slotKey(s, ReminderTiming.exact, zone)};
      expect(planReminderChanges(slots, exact, ReminderTiming.inexact, zone).schedule.length, slots.length);
      final inexact = {for (final s in slots) s.id: slotKey(s, ReminderTiming.inexact, zone)};
      expect(planReminderChanges(slots, inexact, ReminderTiming.exact, zone).schedule.length, slots.length);
      expect(planReminderChanges(slots, exact, ReminderTiming.exact, zone).schedule, isEmpty);
    });
  });
}

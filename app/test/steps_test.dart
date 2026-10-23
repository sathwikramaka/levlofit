import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/coach_chat.dart';
import 'package:levlo/main.dart' show prefs;
import 'package:levlo/steps.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Phone steps: daily totals from Health Connect, on this phone only, shared with the coach only with consent.
// Platform behaviour is faked here; grant, deny and revoke on a real phone are not verified by these tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  setUp(() async {
    await prefs.clear();
    latestSteps = null;
  });

  final today = DateTime(2026, 10, 16, 18, 30);

  group('aggregation', () {
    test('7 days oldest first; a day without data is null, never zero', () {
      final d = lastDays({'2026-10-16': 4200, '2026-10-14': 9000}, today);
      expect(d.length, 7);
      expect(d.first.day, DateTime(2026, 10, 10));
      expect(d.last.day, DateTime(2026, 10, 16));
      expect(d.last.steps, 4200);
      expect(d[4].steps, 9000);
      expect(d[5].steps, isNull);
    });

    test('implausible totals (negative or above 100,000) are left out as errors, not shown', () {
      final d = lastDays({'2026-10-16': -5, '2026-10-15': 250000, '2026-10-14': 100000}, today);
      expect(d.last.steps, isNull);
      expect(d[5].steps, isNull);
      expect(d[4].steps, 100000);
    });

    test('day keys cross month ends correctly', () {
      final d = lastDays({'2026-09-30': 10}, DateTime(2026, 10, 3));
      expect(d.map((x) => isoDate(x.day)), ['2026-09-27', '2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03']);
      expect(d[3].steps, 10);
    });

    test('the average uses complete days with data only (today is partial)', () {
      final d = lastDays({'2026-10-16': 100, '2026-10-15': 8000, '2026-10-13': 6000}, today);
      expect(dailyAverage(d, today), 7000);
      expect(dailyAverage(lastDays({'2026-10-16': 100}, today), today), isNull);
    });

    test('freshness: a read older than 30 minutes is labelled as possibly out of date', () {
      expect(stepsStale(today, today.add(const Duration(minutes: 30))), isFalse);
      expect(stepsStale(today, today.add(const Duration(minutes: 31))), isTrue);
    });
  });

  group('sharing with the coach', () {
    final days = lastDays({'2026-10-16': 4200}, today);

    test('nothing without consent', () {
      expect(coachStepsPayload(days, today, today, consent: false), isNull);
    });

    test('nothing when the totals are more than a day old or missing', () {
      expect(coachStepsPayload(days, today, today.add(const Duration(hours: 25)), consent: true), isNull);
      expect(coachStepsPayload(null, null, today, consent: true), isNull);
    });

    test('with consent: 7 dated totals, missing days stay null, read time in UTC', () {
      final p = coachStepsPayload(days, today, today, consent: true)!;
      expect((p['days'] as List).length, 7);
      expect((p['days'] as List).last, {'date': '2026-10-16', 'steps': 4200});
      expect((p['days'] as List).first, {'date': '2026-10-10', 'steps': null});
      expect(p['readAt'], today.toUtc().toIso8601String());
    });

    test('sharing is off by default and switches off when steps are disconnected', () async {
      expect(stepsShareWithCoach(), isFalse);
      await setStepsConnected(true);
      await setStepsShareWithCoach(true);
      expect(stepsShareWithCoach(), isTrue);
      await setStepsConnected(false);
      expect(stepsShareWithCoach(), isFalse);
    });
  });

  // A fake Health Connect.
  ({StepsApi api, List<String> calls}) fake({
    StepsAvailability availability = StepsAvailability.available,
    bool granted = false,
    bool grantOnRequest = true,
    Map<String, int> totals = const {'2026-10-16': 4200, '2026-10-15': 8000},
    bool readFails = false,
  }) {
    final calls = <String>[];
    var g = granted;
    final StepsApi api = (
      availability: () async {
        calls.add('availability');
        return availability;
      },
      hasPermission: () async {
        calls.add('hasPermission');
        return g;
      },
      requestPermission: () async {
        calls.add('requestPermission');
        g = grantOnRequest;
        return g;
      },
      readDaily: (first, days) async {
        calls.add('readDaily ${isoDate(first)} $days');
        if (readFails) throw PlatformException(code: 'read');
        return totals;
      },
      openSettings: () async => calls.add('openSettings'),
    );
    return (api: api, calls: calls);
  }

  Future<void> show(WidgetTester tester, StepsApi api) async {
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [StepsCard(api: api, now: () => today)]))));
    await tester.pumpAndSettle();
  }

  testWidgets('a build without the Health Connect bridge says so and asks for nothing', (tester) async {
    // The real channel, answered as a build without the bridge answers: MissingPluginException.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final asked = <String>[];
    messenger.setMockMethodCallHandler(healthConnectChannel, (call) async {
      asked.add(call.method);
      throw MissingPluginException();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(healthConnectChannel, null));
    await show(tester, healthConnectSteps);
    expect(asked, ['availability']);
    expect(find.text('Step counting is not available in this version of the app.'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
  });

  testWidgets('Health Connect not installed: an install link, no permission request', (tester) async {
    final f = fake(availability: StepsAvailability.notInstalled);
    await show(tester, f.api);
    expect(find.textContaining('not on this phone'), findsOneWidget);
    expect(f.calls, isNot(contains('requestPermission')));
  });

  testWidgets('connect: the explanation comes first; Not now requests nothing', (tester) async {
    final f = fake();
    await show(tester, f.api);
    expect(f.calls, ['availability'], reason: 'not connected: no permission check, no read');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Health Connect?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(f.calls, ['availability']);
  });

  testWidgets('connect and grant: today, the average, the 7 days; sharing stays off until switched on', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(f.calls, contains('readDaily 2026-10-10 7'));
    expect(find.text('4200 steps today'), findsOneWidget);
    expect(find.text('About 8000 a day over the days recorded.'), findsOneWidget);
    expect(stepsConnected(), isTrue);
    expect(stepsShareWithCoach(), isFalse);
    expect(latestSteps!.days.last.steps, 4200);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(stepsShareWithCoach(), isTrue);
  });

  testWidgets('connect and deny: nothing is read, and the card says so', (tester) async {
    final f = fake(grantOnRequest: false);
    await show(tester, f.api);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not have access'), findsOneWidget);
    expect(f.calls.where((c) => c.startsWith('readDaily')), isEmpty);
    expect(stepsConnected(), isFalse);
  });

  testWidgets('revoked in Health Connect after connecting: no read, the card says so and offers to disconnect', (tester) async {
    await setStepsConnected(true);
    final f = fake(granted: false);
    await show(tester, f.api);
    expect(f.calls.where((c) => c.startsWith('readDaily')), isEmpty);
    expect(find.textContaining('does not have access'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
  });

  testWidgets('disconnect: stops reading, forgets the totals and turns sharing off', (tester) async {
    await setStepsConnected(true);
    await setStepsShareWithCoach(true);
    final f = fake(granted: true);
    await show(tester, f.api);
    expect(find.text('4200 steps today'), findsOneWidget);
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Connect'), findsOneWidget);
    expect(stepsShareWithCoach(), isFalse);
    expect(latestSteps, isNull);
  });

  testWidgets('coach messages carry the step totals only with consent', (tester) async {
    final sent = <Map<String, dynamic>>[];
    final CoachApi api = (
      boot: () async => ('Asha', <dynamic>[]),
      messages: (id) async => <dynamic>[],
      send: (body) async {
        sent.add(body);
        return {'reply': 'ok', 'threadId': 't1', 'title': null, 'userMessageId': 1, 'assistantMessageId': 2};
      },
      deleteThread: (id) async {},
    );
    latestSteps = (days: lastDays({isoDate(DateTime.now()): 3000}, DateTime.now()), readAt: DateTime.now());
    await setStepsConnected(true);
    Future<void> say(String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CoachScreen(api: api)));
    await tester.pump(const Duration(seconds: 1));
    await say('Am I walking enough?');
    expect(sent.single.containsKey('activity'), isFalse, reason: 'sharing is off');
    await setStepsShareWithCoach(true);
    await say('And today?');
    expect((sent.last['activity'] as Map)['days'], hasLength(7));
  });

  test('another account on this phone: totals and both choices are forgotten', () async {
    await setStepsConnected(true);
    await setStepsShareWithCoach(true);
    latestSteps = (days: lastDays({'2026-10-16': 1}, today), readAt: today);
    await forgetSteps();
    expect(latestSteps, isNull);
    expect(stepsConnected(), isFalse);
    expect(stepsShareWithCoach(), isFalse);
  });

  testWidgets('revoked in Health Connect: totals read earlier are no longer shared', (tester) async {
    await setStepsConnected(true);
    latestSteps = (days: lastDays({'2026-10-16': 1}, today), readAt: today);
    await show(tester, fake(granted: false).api);
    expect(latestSteps, isNull);
  });

  testWidgets('returning to the app (for example from Health Connect settings) checks access again', (tester) async {
    await setStepsConnected(true);
    final f = fake(granted: true);
    await show(tester, f.api);
    final before = f.calls.where((c) => c == 'hasPermission').length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(f.calls.where((c) => c == 'hasPermission').length, before + 1);
  });

  testWidgets('a failed read shows an error with a retry, never zero steps', (tester) async {
    await setStepsConnected(true);
    final f = fake(granted: true, readFails: true);
    await show(tester, f.api);
    expect(find.text('Could not read your steps just now.'), findsOneWidget);
    expect(find.textContaining('steps today'), findsNothing);
  });

  testWidgets('no steps today yet is said in words, not as 0', (tester) async {
    await setStepsConnected(true);
    final f = fake(granted: true, totals: const {'2026-10-15': 8000});
    await show(tester, f.api);
    expect(find.text('No steps recorded today yet'), findsOneWidget);
  });

  testWidgets('left on screen, the card says the totals may be out of date once they are 30 minutes old', (tester) async {
    // Found on the phone check 2026-10-18: nothing re-rendered the card, so the line could never appear by itself.
    await setStepsConnected(true);
    final f = fake(granted: true);
    var clock = today;
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [StepsCard(api: f.api, now: () => clock)]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('may be out of date'), findsNothing);
    clock = today.add(const Duration(minutes: 29));
    await tester.pump(const Duration(minutes: 29));
    expect(find.textContaining('may be out of date'), findsNothing);
    clock = today.add(const Duration(minutes: 31));
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('Read at 18:30; may be out of date.'), findsOneWidget);
    expect(f.calls.where((c) => c.startsWith('readDaily')).length, 1, reason: 'no new read happened');
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('may be out of date'), findsNothing, reason: 'a fresh read clears it');
  });
}

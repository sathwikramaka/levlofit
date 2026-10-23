import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/coach_chat.dart';
import 'package:levlo/coach_memory.dart';
import 'package:levlo/session.dart';
import 'package:levlo/swaps.dart';

// Coach action "swap today's exercise" (batch 3a): nothing changes until the person taps Swap. Synthetic data only.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('applySwaps replaces confirmed moves in order and never repeats a move', () {
    expect(applySwaps(['a', 'b', 'c'], const {}), ['a', 'b', 'c']);
    expect(applySwaps(['a', 'b', 'c'], {'b': 'x'}), ['a', 'x', 'c']);
    expect(applySwaps(['a', 'b', 'c'], {'a': 'c'}), ['c', 'b'], reason: 'a swap to a move already in the session drops the repeat');
  });

  test('swapFromJson reads a proposal and refuses malformed ones', () {
    final p = swapFromJson({'id': 41, 'day': '2026-10-24', 'from': {'id': 'yn8yg1r', 'name': 'Goblet squat'}, 'to': {'id': '9E25EOx', 'name': 'Split squat'}});
    expect(p, (id: 41, day: '2026-10-24', fromId: 'yn8yg1r', fromName: 'Goblet squat', toId: '9E25EOx', toName: 'Split squat'));
    for (final bad in [null, 'x', {'id': '41'}, {'id': 41, 'day': '2026-10-24', 'from': 'a', 'to': {'id': 'b'}}]) {
      expect(swapFromJson(bad), isNull);
    }
  });

  const proposal = (id: 41, day: '2026-10-24', fromId: 'yn8yg1r', fromName: 'Goblet squat', toId: '9E25EOx', toName: 'Split squat');

  ({SwapApi api, List<String> calls}) fake({String? refuse}) {
    final calls = <String>[];
    return (
      api: (
        confirm: (id) async {
          calls.add('confirm $id');
          return refuse;
        },
        dismiss: (id) async => calls.add('dismiss $id'),
        confirmChange: (id) async {
          calls.add('confirmChange $id');
          return refuse;
        },
        dismissChange: (id) async => calls.add('dismissChange $id'),
        logMeal: (m) async => calls.add('logMeal ${m.meal} ${m.items.map((i) => '${i.code}:${i.grams}').join(',')}'),
      ),
      calls: calls,
    );
  }

  Future<void> card(WidgetTester tester, SwapApi api) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: SwapCard(proposal: proposal, api: api))));

  testWidgets('card: shows the swap and writes nothing until a button is tapped; Swap confirms', (tester) async {
    final f = fake();
    await card(tester, f.api);
    expect(find.text('Goblet squat → Split squat'), findsOneWidget);
    expect(f.calls, isEmpty);
    await tester.tap(find.text('Swap'));
    await tester.pump();
    expect(f.calls, ['confirm 41']);
    expect(find.textContaining('Swapped.'), findsOneWidget);
    expect(find.text('Swap'), findsNothing, reason: 'answered once');
  });

  testWidgets('card: Not now dismisses the proposal and never confirms it', (tester) async {
    final f = fake();
    await card(tester, f.api);
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(f.calls, ['dismiss 41']);
    expect(find.text('Kept as planned.'), findsOneWidget);
  });

  testWidgets('card: a swap the server refuses says why and keeps the buttons', (tester) async {
    final f = fake(refuse: 'This swap no longer fits your equipment or injuries, so it was not made.');
    await card(tester, f.api);
    await tester.tap(find.text('Swap'));
    await tester.pump();
    expect(find.text('This swap no longer fits your equipment or injuries, so it was not made.'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);
    expect(find.textContaining('Swapped.'), findsNothing);
  });

  testWidgets('chat: today\'s moves go with the message, and a proposed swap shows the card unconfirmed', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    todaySession = (day: '2026-10-24', ids: ['yn8yg1r', 'SpYC0Kp'], restDays: ['2026-10-25']);
    addTearDown(() => todaySession = null);
    final sent = <Map<String, dynamic>>[];
    final f = fake();
    final CoachApi api = (
      boot: () async => ('Asha', <dynamic>[]),
      messages: (id) async => <dynamic>[],
      send: (body) async {
        sent.add(body);
        return {
          'reply': 'Split squats train the same muscles.',
          'threadId': 't1',
          'title': 'Swap',
          'userMessageId': 1,
          'assistantMessageId': 2,
          'suggestions': const [],
          'swap': {'id': 41, 'day': '2026-10-24', 'from': {'id': 'yn8yg1r', 'name': 'Goblet squat'}, 'to': {'id': '9E25EOx', 'name': 'Split squat'}},
        };
      },
      deleteThread: (id) async {},
    );
    final MemoryApi memory = (list: () async => <Fact>[], confirm: (id) async {}, save: (id, c, t, {required confirm}) async {}, remove: (id) async {}, removeAll: () async {});
    await tester.pumpWidget(MaterialApp(home: CoachScreen(api: api, memory: memory, swaps: f.api)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Can I swap the goblet squat?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sent.single['today'], {'day': '2026-10-24', 'ids': ['yn8yg1r', 'SpYC0Kp'], 'restDays': ['2026-10-25']});
    expect(find.text('SWAP TODAY\'S MOVE?'), findsOneWidget);
    expect(f.calls, isEmpty, reason: 'the reply alone changes nothing');
  });

  test('lighter day: one set fewer (never below one) and more reps in reserve', () {
    expect(setsFor('qXTaZnJ', 2), 3);
    expect(setsFor('qXTaZnJ', 2, lighter: true), 2);
    expect(setsFor('qXTaZnJ', 0, lighter: true), 1);
    expect(setsFor('DFGXwZr', 2, lighter: true), 0, reason: 'stretches stay holds');
    expect(doseFor('qXTaZnJ', 2, lighter: true), '2 sets × 8–12 reps, 3 or more left in the tank');
    expect(changeFromJson({'id': 7, 'kind': 'lighter', 'day': '2026-10-24'}), (id: 7, kind: 'lighter', day: '2026-10-24', toDay: null));
    expect(changeFromJson({'id': 7, 'kind': 'move', 'day': '2026-10-21', 'toDay': '2026-10-23'}), (id: 7, kind: 'move', day: '2026-10-21', toDay: '2026-10-23'));
    expect(changeFromJson({'id': 7, 'kind': 'move', 'day': '2026-10-24'}), isNull, reason: 'a move needs its day');
    expect(changeFromJson({'id': 7, 'kind': 'deload', 'day': '2026-10-24'}), isNull);
  });

  test('moved sessions: shown on the new day, today left as rest, others unchanged', () {
    const training = {1, 3, 5}; // Monday, Wednesday, Friday
    expect(sessionDayFor(3, training, const []), 3);
    expect(sessionDayFor(4, training, const []), isNull);
    expect(sessionDayFor(3, training, const [(3, 4)]), isNull, reason: 'Wednesday moved away');
    expect(sessionDayFor(4, training, const [(3, 4)]), 3, reason: "Thursday shows Wednesday's session");
    expect(sessionDayFor(5, training, const [(3, 4)]), 5);
    expect(weekdayName('2026-10-23'), 'Friday');
  });

  test('meal proposal: read only when every item is well formed', () {
    final ok = {'meal': 'lunch', 'items': [{'code': 'A001', 'name': 'Chapati', 'grams': 80}, {'code': 'C003', 'name': 'Chicken curry', 'grams': 250.5}]};
    final m = mealFromJson(ok)!;
    expect(m.meal, 'lunch');
    expect(m.items, [(code: 'A001', name: 'Chapati', grams: 80.0), (code: 'C003', name: 'Chicken curry', grams: 250.5)]);
    for (final bad in [
      null,
      {'meal': 'brunch', 'items': ok['items']},
      {'meal': 'lunch', 'items': []},
      {'meal': 'lunch', 'items': [{'code': 'A001', 'name': 'Chapati', 'grams': 5000}]},
      {'meal': 'lunch', 'items': [{'code': 'A001', 'grams': 80}]},
    ]) {
      expect(mealFromJson(bad), isNull, reason: '$bad');
    }
  });

  testWidgets('meal card: lists the foods; nothing is logged until Log it, and Not now logs nothing', (tester) async {
    final f = fake();
    const meal = (meal: 'lunch', items: [(code: 'A001', name: 'Chapati', grams: 80.0), (code: 'C003', name: 'Chicken curry', grams: 250.0)]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MealCard(proposal: meal, api: f.api))));
    expect(find.text('Lunch: Chapati 80 g, Chicken curry 250 g'), findsOneWidget);
    expect(f.calls, isEmpty);
    await tester.tap(find.text('Log it'));
    await tester.pump();
    expect(f.calls, ['logMeal lunch A001:80.0,C003:250.0']);
    expect(find.textContaining('Logged to today'), findsOneWidget);

    final g = fake();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MealCard(key: const ValueKey(3), proposal: meal, api: g.api))));
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(g.calls, isEmpty);
  });

  testWidgets('move card: says the day and writes nothing until Move is tapped', (tester) async {
    final f = fake();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LighterCard(proposal: (id: 9, kind: 'move', day: '2026-10-21', toDay: '2026-10-23'), api: f.api))));
    expect(find.text("MOVE TODAY'S SESSION?"), findsOneWidget);
    expect(find.textContaining('Train on Friday instead'), findsOneWidget);
    expect(f.calls, isEmpty);
    await tester.tap(find.text('Move'));
    await tester.pump();
    expect(f.calls, ['confirmChange 9']);
    expect(find.text('Moved to Friday.'), findsOneWidget);
  });

  testWidgets('lighter card: writes nothing until tapped; confirm and Not now call the server', (tester) async {
    final f = fake();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LighterCard(proposal: (id: 7, kind: 'lighter', day: '2026-10-24', toDay: null), api: f.api))));
    expect(find.text('MAKE TODAY LIGHTER?'), findsOneWidget);
    expect(f.calls, isEmpty);
    await tester.tap(find.text('Make it lighter'));
    await tester.pump();
    expect(f.calls, ['confirmChange 7']);
    expect(find.textContaining('session is lighter'), findsOneWidget);

    final g = fake();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LighterCard(key: const ValueKey(2), proposal: (id: 8, kind: 'lighter', day: '2026-10-24', toDay: null), api: g.api))));
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(g.calls, ['dismissChange 8']);
  });
}

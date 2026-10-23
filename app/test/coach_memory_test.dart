import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/coach_chat.dart';
import 'package:levlo/coach_memory.dart';

// Memory the person controls: the coach suggests, the person confirms, edits or deletes. Synthetic facts only.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // An in-memory coach_facts table for one user, recording every call.
  ({MemoryApi api, List<Fact> rows, List<String> calls}) fake(List<Fact> start, {bool failList = false}) {
    final rows = [...start];
    final calls = <String>[];
    void put(Fact f) => rows[rows.indexWhere((r) => r.id == f.id)] = f;
    Fact get(int id) => rows.firstWhere((r) => r.id == id);
    final MemoryApi api = (
      list: () async {
        calls.add('list');
        if (failList) throw Exception('offline');
        return [...rows];
      },
      confirm: (id) async {
        calls.add('confirm $id');
        final f = get(id);
        put((id: id, category: f.category, fact: f.fact, confirmed: true));
      },
      save: (id, category, fact, {required confirm}) async {
        calls.add('save $id $category "$fact" confirm=$confirm');
        final f = get(id);
        put((id: id, category: category, fact: fact, confirmed: confirm || f.confirmed));
      },
      remove: (id) async {
        calls.add('remove $id');
        rows.removeWhere((r) => r.id == id);
      },
      removeAll: () async {
        calls.add('removeAll');
        rows.clear();
      },
    );
    return (api: api, rows: rows, calls: calls);
  }

  const knee = (id: 7, category: 'injury', fact: 'left knee aches after squats', confirmed: false);
  const mornings = (id: 3, category: 'schedule', fact: 'trains before work', confirmed: true);

  Future<void> sheet(WidgetTester tester, MemoryApi api) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MemorySheet(api: api))));
    await tester.pumpAndSettle();
  }

  testWidgets('memory sheet: confirmed and waiting facts are shown apart, with what each means', (tester) async {
    final f = fake([mornings, knee]);
    await sheet(tester, f.api);
    expect(find.text('REMEMBERED'), findsOneWidget);
    expect(find.text('WAITING FOR YOUR OK'), findsOneWidget);
    expect(find.textContaining('Only you can see these'), findsOneWidget);
    expect(find.textContaining('Not used until you confirm'), findsOneWidget);
    expect(find.textContaining('confirmed facts go to our AI provider'), findsOneWidget);
    expect(find.textContaining('an injury fact only when you ask about training, movement or pain'), findsOneWidget);
    // Only the waiting fact offers "Remember this".
    expect(find.descendant(of: find.byKey(const ValueKey('fact-7')), matching: find.byTooltip('Remember this')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('fact-3')), matching: find.byTooltip('Remember this')), findsNothing);
  });

  testWidgets('memory sheet: approving a suggestion moves it to remembered', (tester) async {
    final f = fake([mornings, knee]);
    await sheet(tester, f.api);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('fact-7')), matching: find.byTooltip('Remember this')));
    await tester.pumpAndSettle();
    expect(f.calls, contains('confirm 7'));
    expect(find.text('WAITING FOR YOUR OK'), findsNothing);
    expect(f.rows.every((r) => r.confirmed), isTrue);
  });

  testWidgets('memory sheet: editing saves the new words and kind', (tester) async {
    final f = fake([mornings]);
    await sheet(tester, f.api);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('fact-3')), matching: find.byTooltip('Edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Fact'), 'trains before work, 30 minutes');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(f.calls, contains('save 3 schedule "trains before work, 30 minutes" confirm=true'));
    expect(find.text('trains before work, 30 minutes'), findsOneWidget);
  });

  testWidgets('memory sheet: an edit under 3 characters cannot be saved', (tester) async {
    final f = fake([mornings]);
    await sheet(tester, f.api);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Fact'), 'ab');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
  });

  testWidgets('memory sheet: deleting one fact and forgetting everything', (tester) async {
    final f = fake([mornings, knee]);
    await sheet(tester, f.api);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('fact-3')), matching: find.byTooltip('Forget this')));
    await tester.pumpAndSettle();
    expect(f.calls, contains('remove 3'));
    expect(find.text('trains before work'), findsNothing);
    await tester.tap(find.text('Forget everything'));
    await tester.pumpAndSettle();
    expect(f.calls, contains('removeAll'));
    expect(find.textContaining('Nothing yet'), findsOneWidget);
  });

  testWidgets('memory sheet: a failed load says so instead of showing an empty memory', (tester) async {
    final f = fake([mornings], failList: true);
    await sheet(tester, f.api);
    expect(find.text('Could not load your memory. Try again.'), findsOneWidget);
    expect(find.textContaining('Nothing yet'), findsNothing);
  });

  // ---- suggestion cards in the chat ----------------------------------------------------------------------

  Future<({List<String> calls})> chatWithSuggestion(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final f = fake([knee]);
    final CoachApi api = (
      boot: () async => ('Asha', <dynamic>[]),
      messages: (id) async => <dynamic>[],
      send: (body) async => {
            'reply': 'Noted. Swap deep squats for box squats this week.',
            'threadId': 't1',
            'title': 'Knee',
            'userMessageId': 1,
            'assistantMessageId': 2,
            'suggestions': [
              {'id': 7, 'category': 'injury', 'fact': 'left knee aches after squats'},
            ],
          },
      deleteThread: (id) async {},
    );
    await tester.pumpWidget(MaterialApp(home: CoachScreen(api: api, memory: f.api)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'My left knee aches after squats.');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return (calls: f.calls);
  }

  testWidgets('chat: a suggested fact is asked about, not saved, until the person taps Remember', (tester) async {
    final f = await chatWithSuggestion(tester);
    expect(find.text('REMEMBER THIS? · INJURY'), findsOneWidget);
    expect(find.textContaining('it is sent to our AI provider when you ask about training'), findsOneWidget, reason: 'an injury suggestion says where it goes');
    expect(f.calls.where((c) => c.startsWith('confirm')), isEmpty, reason: 'nothing is confirmed by the reply itself');
    await tester.tap(find.text('Remember'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(f.calls, contains('confirm 7'));
    expect(find.textContaining('Remembered.'), findsOneWidget);
  });

  testWidgets('chat: Not now deletes the suggestion', (tester) async {
    final f = await chatWithSuggestion(tester);
    await tester.tap(find.text('Not now'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(f.calls, contains('remove 7'));
    expect(f.calls.where((c) => c.startsWith('confirm')), isEmpty);
    expect(find.text('Not remembered.'), findsOneWidget);
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard_layout.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('merge keeps the saved order, drops unknown ids, adds new cards, forces required ones on', () {
    final l = mergeLayout([
      (id: 'body', visible: true),
      (id: 'gone', visible: true),
      (id: 'today', visible: false),
      (id: 'body', visible: false), // duplicate ignored
      (id: 'rings', visible: false),
    ]);
    expect(l.map((c) => c.id).take(3), ['body', 'today', 'rings']);
    expect(l.map((c) => c.id).toSet(), dashboardCards.keys.toSet());
    expect(l.firstWhere((c) => c.id == 'today').visible, isTrue);
    expect(l.firstWhere((c) => c.id == 'rings').visible, isFalse);
    expect(l.firstWhere((c) => c.id == 'week').visible, isTrue); // not in the saved layout: shown
    expect(mergeLayout(null).map((c) => c.id), dashboardCards.keys);
  });

  test('encode and decode round-trip; garbage falls back to the default', () {
    final l = mergeLayout([(id: 'week', visible: false)]);
    expect(decodeLayout(encodeLayout(l)), l);
    expect(decodeLayout('not json'), isNull);
    expect(decodeLayout('[{"id": 3}]'), isNull);
    expect(decodeLayout(null), isNull);
  });

  test('half cards pair up; a lone one takes a full line', () {
    List<CardPref> only(List<String> ids) => [for (final id in dashboardCards.keys) (id: id, visible: ids.contains(id))];
    expect(layoutRows(only(['today', 'hydration', 'habits', 'fuel', 'body'])), [['today'], ['hydration', 'habits'], ['fuel', 'body']]);
    expect(layoutRows(only(['today', 'hydration', 'fuel', 'body'])), [['today'], ['hydration', 'fuel'], ['body']]);
    expect(layoutRows([(id: 'hydration', visible: true), (id: 'today', visible: true), (id: 'habits', visible: true)]), [['hydration'], ['today'], ['habits']]);
  });

  Switch switchFor(WidgetTester tester, String label) =>
      tester.widget<Switch>(find.descendant(of: find.widgetWithText(ListTile, label), matching: find.byType(Switch)));

  testWidgets('customiser hides a card, cannot hide today, and resets', (tester) async {
    List<CardPref>? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardCustomiser(initial: defaultLayout, onChanged: (l) => saved = l))));
    expect(switchFor(tester, "Today's session").onChanged, isNull);
    await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Weekly rings'), matching: find.byType(Switch)));
    await tester.pump();
    expect(saved!.firstWhere((c) => c.id == 'rings').visible, isFalse);
    expect(switchFor(tester, 'Weekly rings').value, isFalse);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(saved, defaultLayout);
  });

  testWidgets('screen readers hear what each switch shows (labelled, not an unnamed switch)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardCustomiser(initial: defaultLayout, onChanged: (_) {}))));
    expect(find.bySemanticsLabel('Show Weekly rings'), findsOneWidget);
    expect(find.bySemanticsLabel("Show Today's session"), findsOneWidget);
    handle.dispose();
  });

  testWidgets('customiser reorders by dragging the handle', (tester) async {
    List<CardPref>? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardCustomiser(initial: defaultLayout, onChanged: (l) => saved = l))));
    final handle = find.descendant(of: find.widgetWithText(ListTile, 'Weekly rings'), matching: find.byIcon(Icons.drag_indicator));
    final g = await tester.startGesture(tester.getCenter(handle), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 14));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.indexWhere((c) => c.id == 'rings'), greaterThan(0));
    expect(saved!.map((c) => c.id).toSet(), dashboardCards.keys.toSet()); // nothing lost or doubled
    expect(saved!.length, dashboardCards.length);
  });
}

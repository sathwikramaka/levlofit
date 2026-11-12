import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart' show CoachFab;
import 'package:levlo/diet_view.dart';
import 'package:levlo/main.dart' show prefs;
import 'package:levlo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The plan-sheet views asked for on 2026-11-12: meal macro tables, the written-out session and the floating coach.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> phone(WidgetTester tester, Widget child, {double width = 320}) async {
    tester.view.physicalSize = Size(width, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [child]))));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('macro table: one row per item and a subtotal that adds them up, at 320 dp', (tester) async {
    await phone(
      tester,
      const MacroTable(totalLabel: 'Subtotal', rows: [
        (label: '1 bowl oats porridge with a long description that wraps', detail: '60 g dry', kcal: 233, protein: 10.2, carb: 39.6, fat: 4.2),
        (label: '1 banana', detail: null, kcal: 107, protein: 1.3, carb: 27, fat: 0.3),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('340'), findsOneWidget, reason: '233 + 107 kcal');
    expect(find.text('67'), findsOneWidget, reason: '39.6 + 27 g carbs');
    expect(find.text('4.5'), findsOneWidget, reason: '4.2 + 0.3 g fat');
  });

  testWidgets('session plan list: the warm-up, then each move numbered with its dose and rest', (tester) async {
    await phone(tester, const SessionPlanList(ids: ['qXTaZnJ', 'iny3m5y'], level: 2, kind: 'strength', gym: true));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('WARM-UP  ·  ABOUT 5 MIN'), findsOneWidget);
    expect(find.text('MAIN SESSION  ·  2 MOVES'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.textContaining('rest 2 min'), findsOneWidget, reason: 'a main lift rests 120 s');
    expect(find.textContaining('rest 90 s'), findsOneWidget);
  });

  testWidgets('floating coach: shows its name until first used, then the round spark only', (tester) async {
    await phone(tester, const Align(alignment: Alignment.centerRight, child: CoachFab()));
    expect(find.text('Ask Levlofit AI'), findsOneWidget);
    expect(find.bySemanticsLabel('Ask Levlofit AI'), findsOneWidget);
    await prefs.setBool('coach_fab_used', true);
    await phone(tester, const Align(alignment: Alignment.centerRight, child: CoachFab(key: ValueKey('again'))));
    expect(find.text('Ask Levlofit AI'), findsNothing);
    expect(find.bySemanticsLabel('Ask Levlofit AI'), findsOneWidget, reason: 'the round button keeps its spoken name');
  });
}

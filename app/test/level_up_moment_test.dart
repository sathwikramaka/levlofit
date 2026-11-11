import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/level_up.dart';
import 'package:levlo/theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a level-up names the level, the goal and what it trains, and fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 720) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: const LevelUpMoment(goalName: 'Muscle building', level: 2, title: 'Build volume', practice: ['Direct shoulder and arm work', 'Roughly 6 to 15 rep ranges']),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Muscle building  ·  Build volume'), findsOneWidget);
    expect(find.text('Direct shoulder and arm work'), findsOneWidget);
    expect(find.text('Share'), findsNothing, reason: 'no share button without a share action');
    expect(tester.takeException(), isNull);
  });
}

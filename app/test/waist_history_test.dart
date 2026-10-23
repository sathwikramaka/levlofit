import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/theme.dart';

// Progress shows waist-to-height next to waist history, from the profile height; nothing without a height or waist.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  const plan = {'trainingDaysPerWeek': 3, 'weightGoal': 'cut'};
  String ago(int d) => DateTime.now().subtract(Duration(days: d)).toIso8601String().substring(0, 10);
  final body = <Map<String, dynamic>>[
    {'measured_on': ago(30), 'weight_kg': 72.4, 'waist_cm': 89.0},
    {'measured_on': ago(1), 'weight_kg': 71.0, 'waist_cm': 82.5},
  ];

  Future<void> show(WidgetTester tester, List<Map<String, dynamic>> rows, {num? height}) async {
    tester.view.physicalSize = const Size(390, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: darkTheme, home: progressBodyForTest(plan, const [], rows, heightCm: height)));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('latest and first ratio, banded on the shown value', (tester) async {
    await show(tester, body, height: 175);
    // 82.5 / 175 = 0.471; 89 / 175 = 0.509
    expect(find.text('Waist to height 0.47, No increased risk (first 0.51). Under 0.50 is the aim.'), findsOneWidget);
  });

  testWidgets('one waist reading: no "first" value', (tester) async {
    await show(tester, [body.last], height: 160);
    expect(find.text('Waist to height 0.52, Increased risk. Under 0.50 is the aim.'), findsOneWidget);
  });

  testWidgets('no height or no waist: no ratio, no guess', (tester) async {
    await show(tester, body);
    expect(find.textContaining('Waist to height'), findsNothing);
    await show(tester, <Map<String, dynamic>>[{'measured_on': ago(1), 'weight_kg': 70.0}], height: 175);
    expect(find.textContaining('Waist to height'), findsNothing);
  });
}

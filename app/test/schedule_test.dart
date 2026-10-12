import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/theme.dart';

// Plans below are the real engine output for a running-only user at level 2
// (supabase/functions/_shared/plan-engine.ts generatePlan, reproduced in the Stage 0 audit).
// The engine adds strength work to reach the WHO minimum of two strength days; the week screen must show it.
Map<String, dynamic> _runningPlan({required int days, required int extraStrength, required int addOns}) => {
      'trainingDaysPerWeek': days,
      'extraStrengthSessions': extraStrength,
      'strengthAddOns': addOns,
      'goals': [
        {'goal': 'running', 'name': 'Running', 'kind': 'endurance', 'startLevel': 2, 'sessionsPerWeek': 4, 'addOnBlocksPerWeek': 0, 'experience': 'intermediate', 'status': 'active', 'unlockWhen': null},
      ],
      'nutrition': {'energyKcal': 2590, 'proteinG': 112, 'proteinPerKg': 1.6, 'maxSoyaChunksDryG': 50, 'excludedFoodTags': ['beef', 'pork'], 'supplements': <Map<String, dynamic>>[]},
      'bmi': {'value': 22.9, 'category': 'normal'},
      'review': <Map<String, dynamic>>[],
      'sources': <String>[],
    };

Future<void> _pumpWeek(WidgetTester tester, Map<String, dynamic> plan) async {
  // Tall enough that every day of the week is built, so off-screen rows are found too.
  tester.view.physicalSize = const Size(390, 6000) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: darkTheme, home: tabForTest('workout', plan)));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('every training day the engine counts has a session (no silent "Open session")', (tester) async {
    await _pumpWeek(tester, _runningPlan(days: 6, extraStrength: 2, addOns: 0));
    expect(find.text('Open session', skipOffstage: false), findsNothing, reason: 'extra strength sessions from the engine were dropped');
    expect(find.text('Rest and recover', skipOffstage: false), findsNWidgets(1), reason: '6 training days leave 1 rest day');
  });

  testWidgets('strength add-on blocks from the engine are shown in the week', (tester) async {
    await _pumpWeek(tester, _runningPlan(days: 4, extraStrength: 0, addOns: 2));
    expect(find.textContaining(RegExp('strength', caseSensitive: false), skipOffstage: false), findsWidgets,
        reason: 'the plan has 2 strength add-on blocks but the week never mentions strength');
  });
}

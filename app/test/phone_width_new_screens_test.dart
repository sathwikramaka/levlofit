import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/exercises.dart';
import 'package:levlo/food_diary.dart';
import 'package:levlo/session.dart';
import 'package:levlo/theme.dart';

// Phone width (375 x 812) for the screens added on 2026-10-15/16, with long names and every section open. Layout
// evidence only: the visual check in the local web build and the device pass are still open.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  const long = (
    code: 'X1',
    name: 'Bengal gram, dal, split and dehusked, boiled in plenty of water',
    nameHi: 'Chana dal',
    kcal: 355.0,
    protein: 21.55,
    fat: 5.31,
    carb: 46.7,
    fiber: 15.1,
    micros: {'iron_mg': 6.08, 'calcium_mg': 46.32, 'folate_ug': 182.0},
  );
  final DiaryApi diary = (
    load: (day) async => [for (final m in diaryMeals) (id: m, meal: m, foodCode: 'X1', grams: 1999.5)],
    foods: (codes) async => {'X1': long},
    search: (q) async => [long],
    add: (day, meal, code, grams) async {},
    remove: (id) async {},
    update: (id, meal, grams) async {},
  );

  testWidgets('food diary: full day, vitamins and minerals open, edit dialog', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: darkTheme, home: FoodDiaryScreen(api: diary, kcalTarget: 2400, proteinTarget: 120, today: DateTime(2026, 10, 16))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vitamins and minerals'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(long.name).last);
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipes: long names, log dialog', (tester) async {
    phone(tester);
    final RecipeApi api = (
      list: () async => [(id: 'r', name: 'Grandmother\'s Sunday chana dal with jeera rice and ghee', servings: 20, items: [(foodCode: 'X1', grams: 2000.0)])],
      save: (n, s, i) async {},
      remove: (id) async {},
      log: (d, m, i) async {},
    );
    await tester.pumpWidget(MaterialApp(theme: darkTheme, home: RecipesScreen(api: api, diary: diary, day: DateTime(2026, 10, 16))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Log a serving'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tape list in Progress, no waist-to-height ratio', (tester) async {
    phone(tester);
    String ago(int d) => DateTime.now().subtract(Duration(days: d)).toIso8601String().substring(0, 10);
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme,
      home: progressBodyForTest(const {'trainingDaysPerWeek': 3, 'weightGoal': 'cut'}, const [], <Map<String, dynamic>>[
        {'measured_on': ago(30), 'waist_cm': 101.5},
        {'measured_on': ago(1), 'waist_cm': 99.0},
      ]),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('99.0 cm'), findsOneWidget);
    expect(find.textContaining('Waist to height'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise library: Mobility group lists the yoga poses as stretches', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mobility').first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Upward-facing dog'), findsOneWidget);
    expect(find.textContaining('Stretches Rectus abdominis'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('over-time notice text fits the session screen wording', () {
    expect(overTimeNotice(estimateMinutes(sessionIds('strength', Tier.gym, 2, 0), 2), 20), contains('longer than your 20-minute setting'));
  });
}

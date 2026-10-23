import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/food_diary.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

// Food diary: totals come only from the food table's per-100 g values; inputs are bounded; failures are shown.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const rice = (code: 'A013', name: 'Rice, raw, brown', nameHi: null, kcal: 354.0, protein: 9.16, fat: 1.24, carb: 74.8, fiber: 4.43, micros: {'iron_mg': 1.02, 'calcium_mg': 10.93});
  const dal = (code: 'B001', name: 'Bengal gram, dal', nameHi: 'Chana dal', kcal: 355.0, protein: 21.55, fat: 5.31, carb: 46.7, fiber: 15.1, micros: {'iron_mg': 6.08, 'folate_ug': 182.0});
  final foods = <String, FoodRow>{'A013': rice, 'B001': dal};

  test('totals scale per-100 g values by the grams eaten', () {
    final t = diaryTotals([(id: '1', meal: 'lunch', foodCode: 'A013', grams: 150), (id: '2', meal: 'dinner', foodCode: 'B001', grams: 50)], foods);
    expect(t.kcal, closeTo(354 * 1.5 + 355 * 0.5, 1e-9));
    expect(t.protein, closeTo(9.16 * 1.5 + 21.55 * 0.5, 1e-9));
    expect(t.fiber, closeTo(4.43 * 1.5 + 15.1 * 0.5, 1e-9));
    expect(t.unknownFoods, 0);
  });

  test('an entry whose food is missing adds nothing and is reported, never guessed', () {
    final t = diaryTotals([(id: '1', meal: 'lunch', foodCode: 'GONE', grams: 200), (id: '2', meal: 'lunch', foodCode: 'A013', grams: 100)], foods);
    expect(t.kcal, closeTo(354, 1e-9));
    expect(t.unknownFoods, 1);
    expect(diaryTotals(const [], foods).kcal, 0);
  });

  test('vitamins and minerals: summed only where the food has a value; missing values are counted, not zero', () {
    final t = diaryTotals([(id: '1', meal: 'lunch', foodCode: 'A013', grams: 200), (id: '2', meal: 'dinner', foodCode: 'B001', grams: 50)], foods);
    expect(t.micros['iron_mg']!.amount, closeTo(1.02 * 2 + 6.08 * 0.5, 1e-9));
    expect(t.micros['iron_mg']!.missing, 0);
    expect(t.micros['folate_ug']!.amount, closeTo(91, 1e-9)); // dal only
    expect(t.micros['folate_ug']!.missing, 1); // rice has no folate value
    expect(t.micros['calcium_mg']!.missing, 1);
    expect(t.micros['vitamin_c_mg']!.missing, 2);
  });

  test('a food row reads the micronutrients it has and skips nulls', () {
    final f = foodFromRow({'code': 'X', 'name': 'T', 'kcal': 1, 'iron_mg': 2.5, 'folate_ug': null});
    expect(f.micros, {'iron_mg': 2.5});
  });

  test('grams: same bounds as the database, one decimal', () {
    expect(parseGrams('').error, isNotNull);
    expect(parseGrams('0').error, isNotNull);
    expect(parseGrams('2000.1').error, isNotNull);
    expect(parseGrams('abc').error, isNotNull);
    expect(parseGrams('2000').grams, 2000);
    expect(parseGrams(' 152.46 ').grams, 152.5);
  });

  test('a food row with missing nutrient fields reads as zero for that field only', () {
    final f = foodFromRow({'code': 'X', 'name': 'Test', 'name_hi': null, 'kcal': 100, 'protein_g': null, 'fat_g': 2, 'carb_g': null, 'fiber_g': null});
    expect((f.kcal, f.protein, f.fat, f.carb), (100.0, 0.0, 2.0, 0.0));
  });

  // A small in-memory diary.
  ({DiaryApi api, List<(DateTime, String, String, double)> added, List<String> removed, List<DateTime> loads, List<(String, String, double)> updated}) fake(
      {bool failLoad = false, bool failUpdate = false, Object? addError}) {
    final rows = <DiaryEntry>[];
    final added = <(DateTime, String, String, double)>[];
    final removed = <String>[];
    final loads = <DateTime>[];
    final updated = <(String, String, double)>[];
    final DiaryApi api = (
      load: (day) async {
        loads.add(day);
        if (failLoad) throw Exception('offline');
        return [...rows];
      },
      foods: (codes) async => {for (final c in codes) c: ?foods[c]},
      search: (q) async => [for (final f in foods.values) if (f.name.toLowerCase().contains(q.toLowerCase())) f],
      add: (day, meal, code, grams) async {
        if (addError != null) throw addError;
        added.add((day, meal, code, grams));
        rows.add((id: 'n${rows.length}', meal: meal, foodCode: code, grams: grams));
      },
      remove: (id) async {
        removed.add(id);
        rows.removeWhere((r) => r.id == id);
      },
      update: (id, meal, grams) async {
        if (failUpdate) throw Exception('offline');
        updated.add((id, meal, grams));
        final i = rows.indexWhere((r) => r.id == id);
        rows[i] = (id: id, meal: meal, foodCode: rows[i].foodCode, grams: grams);
      },
    );
    return (api: api, added: added, removed: removed, loads: loads, updated: updated);
  }

  Future<void> show(WidgetTester tester, DiaryApi api) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: FoodDiaryScreen(api: api, kcalTarget: 2000, proteinTarget: 100, today: DateTime(2026, 10, 15))));
    await tester.pumpAndSettle();
  }

  testWidgets('empty day: zero totals against the plan targets, every meal empty', (tester) async {
    await show(tester, fake().api);
    expect(find.text('0 of 2000 kcal'), findsOneWidget);
    expect(find.text('0.0 of 100 g protein'), findsOneWidget);
    expect(find.text('Nothing logged.'), findsNWidgets(4));
  });

  testWidgets('a failed load says so and offers a retry', (tester) async {
    final f = fake(failLoad: true);
    await show(tester, f.api);
    expect(find.textContaining('Could not load your diary'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(f.loads, hasLength(2));
  });

  testWidgets('add: search, pick, weigh, save; a bad weight is refused first', (tester) async {
    final f = fake();
    await show(tester, f.api);
    await tester.tap(find.widgetWithText(TextButton, 'Add').first); // breakfast
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice, raw, brown'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a weight above 0 g'), findsOneWidget);
    expect(f.added, isEmpty);
    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(f.added.single, (DateTime(2026, 10, 15), 'breakfast', 'A013', 150.0));
    expect(find.text('Rice, raw, brown'), findsOneWidget);
    expect(find.text('531 of 2000 kcal'), findsOneWidget); // 354 x 1.5
    await tester.tap(find.text('Vitamins and minerals'));
    await tester.pumpAndSettle();
    expect(find.text('1.5 mg'), findsOneWidget); // iron 1.02 x 1.5
    // zinc, magnesium, potassium, sodium, vitamin C, folate: rice has no value
    expect(find.text('No value for 1 entry; the total may be higher.'), findsNWidgets(6));
  });

  testWidgets('remove asks first; Keep leaves the entry', (tester) async {
    final f = fake();
    await f.api.add(DateTime(2026, 10, 15), 'lunch', 'B001', 100);
    f.added.clear();
    await show(tester, f.api);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(f.removed, isEmpty);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(f.removed, ['n0']);
    expect(find.text('Nothing logged.'), findsNWidgets(4));
  });

  testWidgets('edit: tap an entry, change weight and meal; a bad weight is refused; no change sends nothing', (tester) async {
    final f = fake();
    await f.api.add(DateTime(2026, 10, 15), 'lunch', 'A013', 100);
    await show(tester, f.api);
    await tester.tap(find.text('Rice, raw, brown'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(f.updated, isEmpty, reason: 'unchanged');
    await tester.tap(find.text('Rice, raw, brown'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a weight above 0 g'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dinner'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(f.updated.single, ('n0', 'dinner', 200.0));
    expect(find.text('708 of 2000 kcal'), findsOneWidget);
  });

  testWidgets('edit: a failed save says the entry is unchanged', (tester) async {
    final f = fake(failUpdate: true);
    await f.api.add(DateTime(2026, 10, 15), 'lunch', 'A013', 100);
    await show(tester, f.api);
    await tester.tap(find.text('Rice, raw, brown'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save that change. The entry is unchanged.'), findsOneWidget);
    expect(find.text('354 of 2000 kcal'), findsOneWidget);
  });

  testWidgets('days: no future dates; previous day loads that day', (tester) async {
    final f = fake();
    await show(tester, f.api);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(f.loads.last, DateTime(2026, 10, 14));
    expect(find.text('2026-10-14'), findsOneWidget);
  });

  test('diary range: today back to 730 days, the same window the database accepts', () {
    final today = DateTime(2026, 10, 15);
    expect(oldestDiaryDay(today), DateTime(2024, 10, 15));
    expect(diaryDayInRange(today, today), isTrue);
    expect(diaryDayInRange(DateTime(2024, 10, 15), today), isTrue);
    expect(diaryDayInRange(DateTime(2024, 10, 14), today), isFalse);
    expect(diaryDayInRange(DateTime(2026, 10, 16), today), isFalse);
    expect(oldestDiaryDay(DateTime(2028, 3, 1)), DateTime(2026, 3, 2)); // 730 days, not 2 years: 29 Feb 2028 counts
  });

  testWidgets('days: the previous-day button stops at the oldest diary day and says why', (tester) async {
    final f = fake();
    await show(tester, f.api);
    expect(find.textContaining('The diary keeps'), findsNothing);
    for (var i = 0; i < 730; i++) {
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('2024-10-15'), findsOneWidget);
    expect(f.loads.last, DateTime(2024, 10, 15));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull);
    expect(find.text('The diary keeps the last 2 years. Older days cannot be opened.'), findsOneWidget);
    expect(f.loads.where((d) => d.isBefore(DateTime(2024, 10, 15))), isEmpty);
  });

  testWidgets('add: a day the server refuses as out of range gets a clear message, not the generic one', (tester) async {
    final f = fake(addError: const PostgrestException(message: 'diary day out of range', code: '22008'));
    await show(tester, f.api);
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice, raw, brown'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('That day is outside the diary (today and the last 2 years). Nothing was added.'), findsOneWidget);
    expect(find.text('Could not save that entry. Nothing was added.'), findsNothing);
  });

  test('save errors: only the out-of-range day (22008) gets the diary-range message; anything else keeps the text given', () {
    const generic = 'Could not log that recipe. Nothing was added.';
    expect(diarySaveError(const PostgrestException(message: 'diary day out of range', code: '22008'), generic),
        'That day is outside the diary (today and the last 2 years). Nothing was added.');
    expect(diarySaveError(const PostgrestException(message: 'food log limit reached for this day', code: 'P0001'), generic), generic);
    expect(diarySaveError(Exception('offline'), generic), generic);
  });
}

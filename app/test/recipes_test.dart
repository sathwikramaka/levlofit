import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/food_diary.dart';

// Recipes: the user's own dishes from IFCT foods; logging adds scaled ingredients to the diary.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const rice = (code: 'A013', name: 'Rice, raw, brown', nameHi: null, kcal: 354.0, protein: 9.16, fat: 1.24, carb: 74.8, fiber: 4.43, micros: <String, double>{});
  const dal = (code: 'B001', name: 'Bengal gram, dal', nameHi: 'Chana dal', kcal: 355.0, protein: 21.55, fat: 5.31, carb: 46.7, fiber: 15.1, micros: <String, double>{});
  final foods = <String, FoodRow>{'A013': rice, 'B001': dal};
  final Recipe dalRice = (id: 'r1', name: 'Dal rice', servings: 2, items: [(foodCode: 'A013', grams: 150.0), (foodCode: 'B001', grams: 100.0)]);

  test('portion scales every ingredient by servings eaten over servings made, one decimal', () {
    expect(recipePortion(dalRice, 1), [(foodCode: 'A013', grams: 75.0), (foodCode: 'B001', grams: 50.0)]);
    expect(recipePortion(dalRice, 0.5), [(foodCode: 'A013', grams: 37.5), (foodCode: 'B001', grams: 25.0)]);
    final Recipe tiny = (id: 'r', name: 'x', servings: 20, items: [(foodCode: 'A013', grams: 1.0)]);
    expect(recipePortion(tiny, 0.5), isNull, reason: '0.025 g rounds to 0: refused, not logged as 0');
    final Recipe big = (id: 'r', name: 'x', servings: 1, items: [(foodCode: 'A013', grams: 1500.0)]);
    expect(recipePortion(big, 2), isNull, reason: '3000 g is over the diary limit');
  });

  test('a recipe row without items reads as empty, not an error', () {
    expect(recipeFromRow({'id': 'a', 'name': 'b', 'servings': 3}).items, isEmpty);
  });

  ({RecipeApi api, List<Recipe> saved, List<(DateTime, String, List<RecipeItem>)> logged, List<String> removed}) fakeRecipes(List<Recipe> start, {bool failLog = false}) {
    final store = [...start], saved = <Recipe>[], logged = <(DateTime, String, List<RecipeItem>)>[], removed = <String>[];
    final RecipeApi api = (
      list: () async => [...store],
      save: (name, servings, items) async {
        final Recipe r = (id: 'n${store.length}', name: name, servings: servings, items: items);
        saved.add(r);
        store.add(r);
      },
      remove: (id) async {
        removed.add(id);
        store.removeWhere((r) => r.id == id);
      },
      log: (day, meal, items) async {
        if (failLog) throw Exception('offline');
        logged.add((day, meal, items));
      },
    );
    return (api: api, saved: saved, logged: logged, removed: removed);
  }

  final DiaryApi diary = (
    load: (day) async => <DiaryEntry>[],
    foods: (codes) async => {for (final c in codes) c: ?foods[c]},
    search: (q) async => [for (final f in foods.values) if (f.name.toLowerCase().contains(q.toLowerCase())) f],
    add: (day, meal, code, grams) async {},
    remove: (id) async {},
    update: (id, meal, grams) async {},
  );

  Future<void> show(WidgetTester tester, RecipeApi api) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: RecipesScreen(api: api, diary: diary, day: DateTime(2026, 10, 15))));
    await tester.pumpAndSettle();
  }

  testWidgets('list shows kcal a serving from the food table', (tester) async {
    await show(tester, fakeRecipes([dalRice]).api);
    // (354 x 1.5 + 355) / 2 = 443
    expect(find.text('2 ingredients  ·  2 servings  ·  443 kcal a serving'), findsOneWidget);
  });

  testWidgets('empty list explains recipes', (tester) async {
    await show(tester, fakeRecipes([]).api);
    expect(find.textContaining('No recipes yet'), findsOneWidget);
  });

  testWidgets('log one serving to dinner adds the scaled ingredients to that day', (tester) async {
    final f = fakeRecipes([dalRice]);
    await show(tester, f.api);
    await tester.tap(find.byTooltip('Log a serving'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await tester.pumpAndSettle();
    final (day, meal, items) = f.logged.single;
    expect((day, meal), (DateTime(2026, 10, 15), 'dinner'));
    expect(items, [(foodCode: 'A013', grams: 75.0), (foodCode: 'B001', grams: 50.0)]);
    expect(find.text('Added 2 ingredients to Dinner.'), findsOneWidget);
  });

  testWidgets('a failed log says nothing was added', (tester) async {
    await show(tester, fakeRecipes([dalRice], failLog: true).api);
    await tester.tap(find.byTooltip('Log a serving'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await tester.pumpAndSettle();
    expect(find.text('Could not log that recipe. Nothing was added.'), findsOneWidget);
  });

  testWidgets('delete asks first', (tester) async {
    final f = fakeRecipes([dalRice]);
    await show(tester, f.api);
    await tester.tap(find.byTooltip('Delete recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(f.removed, isEmpty);
    await tester.tap(find.byTooltip('Delete recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(f.removed, ['r1']);
    expect(find.textContaining('No recipes yet'), findsOneWidget);
  });

  testWidgets('new recipe: refuses empty fields, then saves name, servings and ingredients', (tester) async {
    final f = fakeRecipes([]);
    await show(tester, f.api);
    await tester.tap(find.text('New recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Give the recipe a name'), findsOneWidget);
    expect(find.text('Add at least one ingredient'), findsOneWidget);
    expect(f.saved, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Dal');
    await tester.enterText(find.widgetWithText(TextField, 'Servings it makes'), '25');
    await tester.tap(find.text('Add ingredient'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search foods'), 'dal');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bengal gram, dal'));
    await tester.pumpAndSettle();
    expect(find.text('Raw weight in the whole recipe'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Raw weight in the whole recipe'), '200');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Enter 1 to 20 servings'), findsOneWidget);
    expect(f.saved, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Servings it makes'), '4');
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(f.saved.single.name, 'Dal');
    expect(f.saved.single.servings, 4);
    expect(f.saved.single.items, [(foodCode: 'B001', grams: 200.0)]);
    expect(find.text('1 ingredient  ·  4 servings  ·  178 kcal a serving'), findsOneWidget); // 355 x 2 / 4
  });
}

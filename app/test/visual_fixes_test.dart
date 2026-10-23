import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/exercises.dart';
import 'package:levlo/food_diary.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

// Fixes for the six findings of the 2026-10-16 local web check (PROGRESS batch BD).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const dal = (code: 'B001', name: 'Bengal gram, dal', nameHi: null, kcal: 355.0, protein: 21.55, fat: 5.31, carb: 46.7, fiber: 15.1, micros: <String, double>{});
  final DiaryApi diary = (
    load: (day) async => <DiaryEntry>[],
    foods: (codes) async => {'B001': dal},
    search: (q) async => [dal],
    add: (day, meal, code, grams) async {},
    remove: (id) async {},
    update: (id, meal, grams) async {},
  );
  final saved = <String>[];
  final RecipeApi recipes = (
    list: () async => <Recipe>[],
    save: (name, servings, items) async => saved.add(name),
    remove: (id) async {},
    log: (day, meal, items) async {},
  );

  Future<void> openEditor(WidgetTester tester, {Size size = const Size(390, 900)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: RecipesScreen(api: recipes, diary: diary, day: DateTime(2026, 10, 16))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New recipe'));
    await tester.pumpAndSettle();
  }

  testWidgets('1: the name error does not overlap the servings label', (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    final error = tester.getRect(find.text('Give the recipe a name'));
    final label = tester.getRect(find.text('Servings it makes'));
    expect(error.bottom, lessThanOrEqualTo(label.top), reason: 'error $error, label $label');
  });

  testWidgets('2: errors clear as soon as the field changes', (tester) async {
    await openEditor(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Servings it makes'), '25');
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Give the recipe a name'), findsOneWidget);
    expect(find.text('Enter 1 to 20 servings'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'D');
    await tester.pump();
    expect(find.text('Give the recipe a name'), findsNothing);
    expect(find.text('Enter 1 to 20 servings'), findsOneWidget, reason: 'only the edited field clears');
    await tester.enterText(find.widgetWithText(TextField, 'Servings it makes'), '4');
    await tester.pump();
    expect(find.text('Enter 1 to 20 servings'), findsNothing);
  });

  testWidgets('3: leaving with unsaved input asks first; Keep editing stays, Discard leaves', (tester) async {
    await openEditor(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Dal');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard this recipe?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Dal'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.text('New recipe'), findsOneWidget, reason: 'back on the Recipes list (its button)');
    expect(find.text('Save recipe'), findsNothing);
    expect(saved, isEmpty);
  });

  testWidgets('3: an untouched editor leaves without asking', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard this recipe?'), findsNothing);
    expect(find.text('Save recipe'), findsNothing);
  });

  testWidgets('4: recipe list and editor keep the diary width (640) on a wide screen', (tester) async {
    await openEditor(tester, size: const Size(1280, 900));
    expect(tester.getSize(find.byType(ListView)).width, 640);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ListView)).width, 640);
  });

  testWidgets('5: guide tags show the wording as written', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExerciseScreen(id: 'K5xgdvI', load: () async => throw Exception('offline'))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('A strap or towel'), findsOneWidget);
    expect(find.text('A Strap Or Towel'), findsNothing);
    expect(find.text('Hamstrings'), findsOneWidget);
  });

  test('6: a missing catalogue row is told apart from a failed request', () {
    expect(notInCatalogue(const PostgrestException(message: 'JSON object requested, multiple (or no) rows returned', code: 'PGRST116')), isTrue);
    expect(notInCatalogue(const PostgrestException(message: 'boom', code: '500')), isFalse);
    expect(notInCatalogue(Exception('offline')), isFalse);
    expect(notInCatalogue(null), isFalse);
  });

  testWidgets('6: the messages say which it was', (tester) async {
    Future<void> show(String id, Object error) async {
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: ExerciseScreen(id: id, load: () async => throw error)));
      await tester.pump(const Duration(seconds: 1));
    }

    const empty = PostgrestException(message: 'no rows', code: 'PGRST116');
    await show('K5xgdvI', empty);
    expect(find.text('The animation and steps for this move are not in the catalogue yet.'), findsOneWidget);
    await show('K5xgdvI', Exception('offline'));
    expect(find.text('The animation and steps could not load. Check your connection.'), findsOneWidget);
    await show('zzzzzzz', empty);
    expect(find.text('This exercise is not in the catalogue yet.'), findsOneWidget);
    await show('zzzzzzz', Exception('offline'));
    expect(find.text('Could not load this exercise. Check your connection.'), findsOneWidget);
  });
}

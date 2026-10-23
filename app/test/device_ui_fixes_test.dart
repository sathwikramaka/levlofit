import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/food_diary.dart';
import 'package:levlo/theme.dart';

// Fixes for the three minor findings of the OnePlus 13 device pass (PROGRESS batch BM), at the phone's width.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void phone(WidgetTester tester, {double width = 375}) {
    tester.view.physicalSize = Size(width, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// The text of each laid-out line of a paragraph.
  List<String> lines(WidgetTester tester, Finder f) {
    final p = tester.renderObject<RenderParagraph>(f);
    // Same text, style, scale and width as the paragraph on screen.
    final tp = TextPainter(text: p.text, textDirection: p.textDirection, textScaler: p.textScaler)..layout(maxWidth: p.constraints.maxWidth);
    final text = p.text.toPlainText();
    final out = <String>[];
    var i = 0;
    while (i < text.length) {
      final b = tp.getLineBoundary(TextPosition(offset: i));
      out.add(text.substring(b.start, b.end));
      i = b.end > i ? b.end : i + 1;
    }
    tp.dispose();
    return out;
  }

  const rice = (code: 'A013', name: 'Rice, raw, brown', nameHi: null, kcal: 354.0, protein: 9.16, fat: 1.24, carb: 74.8, fiber: 4.43, micros: <String, double>{});
  const dal = (code: 'B001', name: 'Bengal gram, dal', nameHi: null, kcal: 329.0, protein: 21.55, fat: 5.31, carb: 46.7, fiber: 15.1, micros: <String, double>{});
  final foods = <String, FoodRow>{'A013': rice, 'B001': dal};
  final entries = <DiaryEntry>[(id: '1', meal: 'lunch', foodCode: 'A013', grams: 150), (id: '2', meal: 'dinner', foodCode: 'B001', grams: 50)];
  DiaryApi api() => (
        load: (day) async => entries,
        foods: (codes) async => foods,
        search: (q) async => [rice, dal],
        add: (day, meal, code, grams) async {},
        remove: (id) async {},
        update: (id, meal, grams) async {},
      );

  test('1: macro line keeps each label, value and unit together', () {
    final s = macroLine(diaryTotals(entries, foods));
    for (final item in s.split('  ·  ')) {
      expect(item, isNot(contains(' ')), reason: 'only non-breaking spaces inside "$item"');
    }
    expect(s.replaceAll('\u00a0', ' '), 'Carbohydrate 135.5 g  ·  Fat 4.5 g  ·  Fibre 14.2 g');
  });

  // Widget tests draw with the square-glyph test font (Geist Mono and Inter are fetched at runtime, not bundled),
  // about 1.5 times wider than the app's fonts; widths are chosen so the text fits as it does on the phone.
  testWidgets('1: on phone widths the unit never starts a line of its own', (tester) async {
    for (final w in [360.0, 375.0, 412.0]) {
      phone(tester, width: w);
      await tester.pumpWidget(MaterialApp(theme: darkTheme, home: FoodDiaryScreen(api: api(), kcalTarget: 1740, proteinTarget: 93, today: DateTime(2026, 10, 15))));
      await tester.pumpAndSettle();
      final text = macroLine(diaryTotals(entries, foods));
      final ls = lines(tester, find.text(text));
      for (final l in ls) {
        expect(RegExp(r'^\s*g\b').hasMatch(l), isFalse, reason: 'width $w, lines $ls');
        expect(RegExp(r'\d\s*$').hasMatch(l), isFalse, reason: 'a value split from its unit at width $w: $ls');
      }
    }
  });

  testWidgets('2: after adding an ingredient the keyboard stays closed and no field has focus', (tester) async {
    phone(tester);
    final RecipeApi recipes = (list: () async => <Recipe>[], save: (n, s, i) async {}, remove: (id) async {}, log: (d, m, i) async {});
    await tester.pumpWidget(MaterialApp(home: RecipesScreen(api: recipes, diary: api(), day: DateTime(2026, 10, 15))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New recipe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Dal rice'); // Name focused, keyboard up
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('Add ingredient'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search foods'), 'dal');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bengal gram, dal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Bengal gram, dal'), findsOneWidget, reason: 'ingredient listed');
    expect(tester.testTextInput.isVisible, isFalse, reason: 'keyboard must not reopen on Name');
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused == null || focused.findAncestorWidgetOfExactType<EditableText>() == null && focused.widget is! EditableText, isTrue);
    expect(find.widgetWithText(TextField, 'Dal rice'), findsOneWidget, reason: 'name kept');
  });

  // 480 px with the test font is about 330 dp with Geist Mono: the one-line labels were cut off here before the fix.
  testWidgets('3: Progress stat labels are shown whole on narrow screens and the tiles share one height', (tester) async {
    for (final w in [480.0, 600.0]) {
      phone(tester, width: w);
      await tester.pumpWidget(MaterialApp(theme: darkTheme, home: progressBodyForTest(const {'trainingDaysPerWeek': 3, 'weightGoal': 'cut'}, const [], const [])));
      await tester.pump(const Duration(seconds: 2));
      for (final label in ['ADHERENCE %', 'SESSIONS', 'WEEK STREAK']) {
        expect(tester.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines, isFalse, reason: '$label at $w');
      }
      final heights = {
        for (final label in ['ADHERENCE %', 'SESSIONS', 'WEEK STREAK'])
          tester.getSize(find.ancestor(of: find.text(label), matching: find.byType(Material)).first).height,
      };
      expect(heights, hasLength(1), reason: 'equal tile heights at $w: $heights');
      expect(tester.takeException(), isNull);
    }
  });
}

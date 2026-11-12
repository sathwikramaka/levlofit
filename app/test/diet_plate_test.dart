import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/diet_plan.dart';
import 'package:levlo/diet_view.dart';
import 'package:levlo/theme.dart';

// The simpler Diet tab (2026-11-03): plate shares, Ate it diary rows, and the plate card at phone width.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  PlanItem item(String code, String name, double g, String unit, double kcal, [double protein = 0]) =>
      (code: code, name: name, grams: g, unit: unit, kcal: kcal, protein: protein, carb: 0, fat: 0, fiber: 0);
  final PlanMeal breakfast = (name: 'Breakfast', time: '8 am', items: [
    item('oats', 'Rolled oats', 40, 'dry', 152, 5.3),
    item('L002', 'Cow milk', 200, 'ml', 122, 6.3),
    item('E012', 'Banana', 120, 'raw', 107, 1.3),
    item('T012', 'Sunflower oil', 5, 'oil', 44),
  ]);
  final PlanMeal lunch = (name: 'Lunch', time: '1 pm', items: [
    item('dish:besan-chilla', 'Besan chilla', 60, 'dry', 232, 13.4),
    item('B010', 'Moong dal', 30, 'dry', 104, 7.2),
    item('C033', 'Spinach', 150, 'raw', 35, 4.3),
    item('supp:whey', 'Whey', 30, 'scoop', 120, 24),
  ]);

  test('plate shares: energy by part, oil left out, summing to one', () {
    final s = plateShares(breakfast);
    expect(s.keys, ['grain', 'protein', 'veg', 'fruit']);
    expect(s['grain'], closeTo(152 / 381, 1e-9));
    expect(s['fruit'], closeTo((122 + 107) / 381, 1e-9), reason: 'milk and fruit share a part');
    expect(s['veg'], 0);
    expect(s.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
    expect(plateShares((name: 'Empty', time: '', items: const [])).values, everyElement(0));
  });

  test('healthy plate check: by weight, milk, oil and shakes beside the plate', () {
    final p = plateCheck([breakfast, lunch]);
    // breakfast: oats 40 grain, banana 120 fruit; lunch: chilla 60 grain, dal 30 protein, spinach 150 veg.
    expect(p.vegFruit, closeTo(270 / 400, 1e-9));
    expect(p.grains, closeTo(100 / 400, 1e-9));
    expect(p.protein, closeTo(30 / 400, 1e-9));
    expect(plateCheck(const []).vegFruit, 0);
  });

  test('Ate it rows: planned rows, dishes as ingredients, shakes left out', () {
    final codes = plannerRowCodes([
      {'code': 'FDC173904'}, {'code': 'FDC174288'}, {'code': 'FDC174256'}, {'code': 'L002'},
    ]);
    expect(codes['oats'], 'FDC173904');
    expect(codes['B001'], 'FDC174288');
    expect(codes['L002'], 'L002', reason: 'no USDA row fetched: the planner code is its own row');
    expect(diaryItems(lunch, (c) => codes[c] ?? c), [('FDC174288', 60.0), ('FDC174256', 30.0), ('C033', 150.0)]);
    expect(diaryItems(breakfast, (c) => c).map((r) => r.$1), ['oats', 'L002', 'E012', 'T012'], reason: 'oil is logged too');
  });

  test('cereal servings read as bowls', () {
    expect(servingLabel(item('oats', 'Rolled oats', 40, 'dry', 152)), '1 bowl oats porridge (40 g dry)');
    expect(servingLabel(item('cornflakes', 'Corn flakes', 60, 'raw', 230)), '2 bowls corn flakes (30 g each)');
    expect(mealTitle(breakfast), 'Oats porridge + Milk + Banana');
  });

  testWidgets('plate card at phone width: servings, Swap and Ate it; a tap shows grams', (tester) async {
    tester.view.physicalSize = const Size(375, 1400) * 3; // phone width; tall enough for both cards with their tables
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var swapped = 0, ate = 0;
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(24), children: [
          PlateMealCard(
            meal: breakfast,
            tag: 'POST-WORKOUT  ·  FROM THE MESS',
            notes: const ['Take the closest items at the mess. Short on protein? Add an extra serving of dal, paneer, curd or soya chunks if served.'],
            onSwap: () => swapped++,
            onAte: () async => ate++,
          ),
          const PlateMealCard(meal: (name: 'Dinner', time: '8 pm', items: []), logged: true),
          const PlateKey(),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('1 bowl oats porridge (40 g dry)'), findsOneWidget);
    expect(find.text('IN YOUR DIARY'), findsOneWidget);
    expect(find.text('Ate it'), findsOneWidget, reason: 'only the card with onAte offers it');
    expect(find.textContaining('40 g dry rolled oats'), findsNothing);
    await tester.tap(find.text('Swap'));
    await tester.tap(find.text('Ate it'));
    await tester.pump();
    expect((swapped, ate), (1, 1));
    await tester.tap(find.text('Breakfast'));
    await tester.pump();
    expect(find.textContaining('40 g dry rolled oats'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plate colours come from the theme, light and dark, and stay distinct', (tester) async {
    for (final theme in [lightTheme, darkTheme]) {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(theme: theme, home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: PlateKey());
      })));
      final scheme = Theme.of(ctx).colorScheme;
      final colours = [for (final (k, _) in plateParts) plateColor(ctx, k)];
      expect(colours, [scheme.primary, scheme.secondary, scheme.onSurfaceVariant, scheme.surfaceContainerHighest]);
      expect(colours.toSet(), hasLength(4));
      expect(tester.takeException(), isNull);
    }
  });
}

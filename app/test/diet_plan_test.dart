import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';

// IFCT 2017 values per 100 g for the planner's foods (code, name, tags, kcal, protein, carb, fat, fibre).
const _rows = [
  ['A011', 'Rice flakes', <String>[], 354, 7.44, 76.75, 1.14, 3.46],
  ['A010', 'Ragi', <String>[], 321, 7.16, 66.82, 1.92, 11.18],
  ['A019', 'Wheat flour, atta', ['gluten', 'wheat'], 320, 10.57, 64.17, 1.53, 11.36],
  ['A015', 'Rice, raw, milled', <String>[], 356, 7.94, 78.24, 0.52, 2.81],
  ['A005', 'Jowar', <String>[], 334, 9.97, 67.68, 1.73, 10.22],
  ['A003', 'Bajra', <String>[], 348, 10.96, 61.78, 5.43, 11.49],
  ['B021', 'Red gram, dal', <String>[], 331, 21.70, 55.23, 1.56, 9.06],
  ['B010', 'Green gram, dal', <String>[], 326, 23.88, 52.59, 1.35, 9.37],
  ['B013', 'Lentil dal', <String>[], 322, 24.35, 52.53, 0.75, 10.43],
  ['B020', 'Rajmah, red', <String>[], 299, 19.91, 48.61, 1.77, 16.57],
  ['B002', 'Bengal gram, whole', <String>[], 287, 18.77, 39.56, 5.11, 25.22],
  ['X001', 'Soya chunks', ['soy'], 327, 51.46, 33.92, 1.22, 17.5],
  ['H012', 'Ground nut', ['peanut'], 520, 23.65, 17.27, 39.63, 10.38],
  ['L002', 'Milk, whole, Cow', ['dairy'], 73, 3.26, 4.94, 4.48, 0.0],
  ['M004', 'Egg, poultry, whole, boiled', ['egg'], 148, 13.43, 0.0, 10.54, 0.0],
  ['L003', 'Paneer', ['dairy'], 258, 18.86, 12.41, 14.78, 0.0],
  ['N003', 'Chicken, poultry, breast, skinless', ['poultry'], 168, 21.81, 0.0, 9.0, 0.0],
  ['S006', 'Rohu', ['fish'], 102, 19.71, 0.0, 2.39, 0.0],
  ['E012', 'Banana, ripe, robusta', <String>[], 105, 1.23, 23.63, 0.33, 1.94],
  ['E049', 'Papaya, ripe', <String>[], 24, 0.42, 4.61, 0.16, 2.83],
  ['E028', 'Guava, white flesh', <String>[], 32, 1.44, 5.13, 0.32, 8.59],
  ['E001', 'Apple, big', <String>[], 62, 0.29, 13.11, 0.64, 2.59],
  ['E047', 'Orange, pulp', <String>[], 37, 0.70, 7.92, 0.13, 1.29],
  ['D036', 'Cauliflower', <String>[], 23, 2.15, 2.03, 0.44, 3.71],
  ['D056', 'Ladies finger', <String>[], 27, 2.08, 3.62, 0.22, 4.08],
  ['C015', 'Cabbage, green', <String>[], 22, 1.36, 3.25, 0.12, 2.76],
  ['C033', 'Spinach', <String>[], 24, 2.14, 2.05, 0.64, 2.38],
  ['F002', 'Carrot, orange', <String>[], 33, 0.95, 5.55, 0.47, 4.18],
  ['D043', 'Cucumber, green, elongate', <String>[], 20, 0.71, 3.48, 0.16, 2.14],
  ['D076', 'Tomato, ripe, local', <String>[], 20, 0.90, 2.71, 0.47, 1.77],
  ['T012', 'Sunflower oil', <String>[], 900, 0.0, 0.0, 100.0, 0.0],
  // Dish-only ingredients (dishRecipes).
  ['A022', 'Wheat, semolina', ['gluten', 'wheat'], 334, 11.38, 68.43, 0.74, 9.72],
  ['A023', 'Wheat, vermicelli', ['gluten', 'wheat'], 333, 9.70, 70.39, 0.45, 9.28],
  ['B001', 'Bengal gram, dal', <String>[], 329, 21.55, 46.72, 5.31, 15.15],
  ['B003', 'Black gram, dal', <String>[], 324, 23.06, 51.00, 1.69, 11.93],
  ['B011', 'Green gram, whole', <String>[], 294, 22.53, 46.13, 1.14, 17.04],
];

final foodsForTest = withDishes({
  for (final r in _rows)
    r[0] as String: foodFromRow({'code': r[0], 'name': r[1], 'tags': r[2], 'kcal': r[3], 'protein_g': r[4], 'carb_g': r[5], 'fat_g': r[6], 'fiber_g': r[7]}),
});

void main() {
  test('every diet and budget lands near the plan targets, all week, and respects exclusions', () {
    const diets = {
      'non_vegetarian': {'beef', 'pork'},
      'eggitarian': {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish'},
      'vegetarian': {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg'},
      'vegan': {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'honey'},
    };
    for (final MapEntry(key: diet, value: excluded) in diets.entries) {
      for (final tier in [1, 2, 3]) {
        for (var day = 0; day < 7; day++) {
          final p = planDay(foods: foodsForTest, kcal: 2300, protein: 120, excluded: excluded, tier: tier, day: day);
          final label = '$diet tier $tier day $day';
          expect(p.kcal, closeTo(2300, 2300 * 0.12), reason: label);
          // Plant-only days at a high target may fall short; the Diet screen then points to the plan's supplement advice.
          expect(p.protein, greaterThan(120 * (diet == 'vegan' ? 0.7 : (diet == 'vegetarian' && tier == 1 ? 0.75 : 0.8))), reason: label);
          expect(p.meals.map((m) => m.name), containsAll(['Breakfast', 'Lunch', 'Dinner']), reason: label);
          for (final m in p.meals) {
            for (final i in m.items) {
              expect(foodsForTest[i.code]!.tags.any(excluded.contains), isFalse, reason: '$label ${i.name}');
              expect(i.grams, greaterThan(0), reason: label);
            }
          }
        }
      }
    }
  });

  test('soya stays under the plan cap, budget tier hides premium foods, oil follows ICMR', () {
    final p = planDay(foods: foodsForTest, kcal: 2600, protein: 160, excluded: {'beef', 'pork', 'dairy', 'egg', 'meat', 'poultry', 'fish'}, soyaCapG: 50, day: 2);
    final soya = p.meals.expand((m) => m.items).where((i) => i.code == 'X001').fold(0.0, (s, i) => s + i.grams);
    expect(soya, lessThanOrEqualTo(50));
    final low = planDay(foods: foodsForTest, kcal: 2200, protein: 110, excluded: {'beef', 'pork'}, tier: 1, day: 0);
    expect(low.meals.expand((m) => m.items).any((i) => ['L003', 'N003', 'S006', 'E001', 'E047'].contains(i.code)), isFalse);
    expect(oilGrams(2000), 27);
    expect(oilGrams(1200), 20);
    expect(oilGrams(3000), 30);
    expect(budgetTier('custom', 120), 1);
    expect(budgetTier('custom', 250), 2);
    expect(budgetTier('custom', 500), 3);
  });

  test('regional staples are preferred, never forced', () {
    int regionalCount(String? region, Set<String> staples) {
      var n = 0;
      for (var day = 0; day < 7; day++) {
        final p = planDay(foods: foodsForTest, kcal: 2300, protein: 120, excluded: {'beef', 'pork'}, day: day, region: region);
        expect(p.meals.expand((m) => m.items), isNotEmpty);
        n += p.meals.expand((m) => m.items).where((i) => staples.contains(i.code)).length;
      }
      return n;
    }

    for (final region in ['north', 'south', 'east', 'west']) {
      final staples = regionStaples[region]!;
      expect(regionalCount(region, staples), greaterThanOrEqualTo(regionalCount(null, staples)), reason: region);
    }
    expect(regionalCount('south', regionStaples['south']!), greaterThan(regionalCount(null, regionStaples['south']!)));
  });

  test('household servings: what goes on the plate, with exact grams kept', () {
    PlanItem item(String code, String name, double g, String unit) =>
        (code: code, name: name, grams: g, unit: unit, kcal: 0, protein: 0, carb: 0, fat: 0, fiber: 0);
    expect(servingLabel(item('A019', 'Wheat atta (roti)', 60, 'dry')), '2 rotis');
    expect(servingLabel(item('A019', 'Wheat atta (roti)', 45, 'dry')), '1½ rotis');
    expect(servingLabel(item('B010', 'Moong dal', 30, 'dry')), '1 katori moong dal');
    expect(servingLabel(item('A015', 'Rice', 100, 'raw')), '2 cups cooked rice');
    expect(servingLabel(item('L002', 'Cow milk', 200, 'ml')), '1 glass milk');
    expect(servingLabel(item('M004', 'Eggs, boiled', 100, 'egg')), '2 boiled eggs');
    expect(servingLabel(item('T012', 'Sunflower oil', 10, 'oil')), '2 tsp cooking oil');
    expect(servingLabel(item('E012', 'Banana', 60, 'raw')), '½ banana');
    expect(servingLabel(item('N003', 'Chicken breast', 150, 'raw')), 'Chicken curry (150 g boneless chicken)');
    expect(exactLabel(item('A019', 'Wheat atta (roti)', 60, 'dry')), '60 g dry wheat atta');
    final meal = (name: 'Lunch', time: '1 pm', items: [item('A019', 'Wheat atta (roti)', 60, 'dry'), item('B010', 'Moong dal', 30, 'dry'), item('T012', 'Sunflower oil', 10, 'oil')]);
    expect(mealSummary(meal), '2 rotis + 1 katori moong dal');
    final day = planDay(foods: foodsForTest, kcal: 2200, protein: 110, excluded: {'beef', 'pork'});
    expect(dayOilLabel(day), startsWith('Cooking oil for the whole day: '));
    // Breakfast is a breakfast dish (idli, poha, chilla...), never roti and sabzi, for every diet and region.
    for (final ex in [{'beef', 'pork'}, {'beef', 'pork', 'egg', 'meat', 'poultry', 'fish'}, {'beef', 'pork', 'egg', 'meat', 'poultry', 'fish', 'dairy'}]) {
      for (final region in [null, 'north', 'south', 'east', 'west']) {
        for (var d = 0; d < 7; d++) {
          final b = planDay(foods: foodsForTest, kcal: 2200, protein: 100, excluded: ex, day: d, region: region).meals.first;
          expect(b.items.first.code, startsWith('dish:'), reason: '$region day $d: ${mealSummary(b)}');
          expect(b.items.map((i) => i.code), isNot(anyOf(contains('A019'), contains('C033'), contains('D036'))));
        }
      }
    }
    for (final m in day.meals.take(3)) {
      expect(m.items.map((i) => i.code), isNot(contains('X001')), reason: 'no soya curry at ${m.name}');
    }
  });

  test('protein shake: food planned around it, added to the evening snack, checks against the full targets', () {
    const kcal = 2200.0, protein = 140.0;
    final food = planDay(foods: foodsForTest, kcal: kcal - 2 * scoopKcal, protein: protein - 2 * scoopProtein, excluded: {'beef', 'pork'});
    final d = addShake(food, 2, kcal: kcal, protein: protein, plant: false);
    final snack = d.meals.firstWhere((m) => m.name == 'Evening snack');
    expect(servingLabel(snack.items.first), '2 scoops whey in water');
    expect(exactLabel(snack.items.first), '60 g powder');
    expect(d.protein, closeTo(food.protein + 48, 1e-9));
    expect(d.kcal, closeTo(food.kcal + 240, 1e-9));
    expect(d.check.feasible, ((d.kcal - kcal) / kcal).abs() <= kcalTolerance && d.protein / protein >= minProteinShare);
    expect(identical(addShake(food, 0, kcal: kcal, protein: protein, plant: false), food), isTrue);
    expect(servingLabel(addShake(food, 1, kcal: kcal, protein: protein, plant: true).meals[2].items.first), '1 scoop plant protein in water');
  });
}

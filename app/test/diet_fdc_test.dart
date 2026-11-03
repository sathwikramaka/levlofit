import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';

// The planner on licensed data only: the USDA FoodData Central rows that 20261025200000_foods_usda_fdc.sql and
// 20261103100000_foods_fdc_breakfast.sql insert, with every IFCT row hidden (as in a release, food_sources.ifct2017.release_allowed = false).

/// The generated rows, read back from the migration.
List<Map<String, dynamic>> _fdcRows() {
  final sql = [
    for (final f in ['20261025200000_foods_usda_fdc.sql', '20261103100000_foods_fdc_breakfast.sql']) File('../supabase/migrations/$f').readAsStringSync(),
  ].join('\n');
  double? n(String v) => v == 'null' ? null : double.parse(v);
  return [
    for (final m in RegExp(r"^\('(FDC\d+)', '([^']*)', '[^']*', array\[([^\]]*)\]::text\[\], (\S+), (\S+), (\S+), (\S+), (\S+),", multiLine: true)
        .allMatches(sql))
      {
        'code': m[1],
        'name': m[2],
        'tags': [for (final t in m[3]!.split(',')) if (t.trim().isNotEmpty) t.trim().replaceAll("'", '')],
        'kcal': n(m[4]!),
        'protein_g': n(m[5]!),
        'fat_g': n(m[6]!),
        'carb_g': n(m[7]!),
        'fiber_g': n(m[8]!),
      },
  ];
}

void main() {
  final rows = _fdcRows();

  test('the planner map matches the generated USDA rows, one for one', () {
    expect(rows, hasLength(34));
    expect(plannerFdcCodes.values.toSet(), {for (final r in rows) r['code']});
    expect(plannerCodes, containsAll(plannerFdcCodes.values));
  });

  test('with IFCT hidden, the planner gets the USDA foods under its own codes and none of the four without a record', () {
    final foods = plannerFoods(rows);
    expect(foods.keys.where((k) => !k.startsWith('dish:')).toSet(), plannerFdcCodes.keys.toSet());
    expect(foods.keys.where((k) => k.startsWith('dish:')).toSet(),
        {'dish:moong-chilla', 'dish:upma', 'dish:besan-chilla', 'dish:thepla', 'dish:sprouts', 'dish:daliya'},
        reason: 'the dishes made wholly of USDA foods; poha, idli, dosa, ragi dosa and vermicelli still need IFCT');
    expect(foods['oats']!.kcal, 379, reason: 'rolled oats, FDC 173904');
    expect(foods['B011']!.kcal, foods['B010']!.kcal, reason: 'whole moong for sprouts is the same USDA record as moong');
    expect(foods.keys, isNot(containsAll(['A011', 'A010', 'L003', 'S006'])));
    expect(foods['B020']!.code, 'B020', reason: 'planner rules stay keyed by planner code');
    expect(foods['B020']!.kcal, 337, reason: 'kidney beans, FDC 173744');
    expect(foods['X001']!.carb, closeTo(16.42, 0.01), reason: 'available carbohydrate, not the by-difference total');
  });

  test('a USDA row wins over the IFCT row where both are visible (local development)', () {
    final foods = plannerFoods([
      ...rows,
      {'code': 'B020', 'name': 'Rajma (IFCT)', 'tags': <String>[], 'kcal': 299, 'protein_g': 19.91, 'carb_g': 48.61, 'fat_g': 1.77, 'fiber_g': 16.57},
      {'code': 'L003', 'name': 'Paneer', 'tags': ['dairy'], 'kcal': 258, 'protein_g': 18.86, 'carb_g': 3.0, 'fat_g': 14.8, 'fiber_g': 0.0},
    ]);
    expect(foods['B020']!.kcal, 337);
    expect(foods['L003']!.kcal, 258, reason: 'no USDA record: the IFCT row is the fallback where it is allowed');
  });

  test('breakfast cereals: a week offers them, and diet and gluten settings keep the wrong ones out', () {
    final foods = plannerFoods(rows);
    const cereals = {'oats', 'cornflakes', 'muesli', 'dish:daliya'};
    Set<String> breakfasts(Set<String> excluded, int tier) => {
          for (var day = 0; day < 7; day++)
            for (final it in planDay(foods: foods, kcal: 2000, protein: 90, excluded: excluded, tier: tier, day: day).meals.first.items) it.code,
        };
    expect(breakfasts({'beef', 'pork'}, 3).intersection(cereals), isNotEmpty, reason: 'a cereal breakfast appears in the week');
    expect(breakfasts({'beef', 'pork', 'dairy', 'egg', 'meat', 'poultry', 'fish', 'shellfish', 'honey'}, 3), isNot(anyOf(contains('cornflakes'), contains('muesli'))),
        reason: 'vegan: no corn flakes without milk, no muesli with milk solids');
    expect(breakfasts({'beef', 'pork', 'wheat', 'barley', 'rye', 'oats'}, 3).intersection(cereals), isEmpty, reason: 'gluten: no oats, corn flakes (malt), muesli or daliya');
    expect(breakfasts({'beef', 'pork'}, 1), isNot(anyOf(contains('cornflakes'), contains('muesli'))), reason: 'the lowest budget keeps to oats and daliya');
  });

  // Synthetic profiles with real plan-engine targets (as in diet_feasibility_test).
  const veg = {'beef', 'egg', 'fish', 'meat', 'pork', 'poultry', 'shellfish'};
  for (final (label, kcal, protein, tier, excluded) in [
    ('M25 maintain, non-veg, mid budget', 2300.0, 112.0, 2, {'beef', 'pork'}),
    ('M20 bulk, eggitarian, high budget', 2540.0, 104.0, 3, {'beef', 'fish', 'meat', 'pork', 'poultry', 'shellfish'}),
    ('M28 bulk, vegetarian, low budget', 2260.0, 96.0, 1, veg),
    ('F30 cut, vegetarian, sedentary, low budget', 1450.0, 110.0, 1, veg),
  ]) {
    test('$label: every day on USDA data is honest about meeting its targets and uses only allowed foods', () {
      final foods = plannerFoods(rows);
      for (var day = 0; day < 7; day++) {
        final d = planDay(foods: foods, kcal: kcal, protein: protein, excluded: excluded, tier: tier, day: day);
        final within = ((d.kcal - kcal) / kcal).abs() <= kcalTolerance && d.protein / protein >= minProteinShare;
        expect(d.check.feasible, within, reason: 'day $day: ${d.kcal.round()} kcal, ${d.protein.round()} g');
        for (final it in d.meals.expand((m) => m.items)) {
          expect(foods.containsKey(it.code), isTrue, reason: it.code);
          expect(foods[it.code]!.tags.any(excluded.contains), isFalse, reason: '${it.name} on day $day');
        }
      }
    });
  }
}

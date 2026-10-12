import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';

import 'diet_plan_test.dart' show foodsForTest;

// Targets are the real plan-engine output (supabase/functions/_shared/plan-engine.ts, generatePlan) for these
// synthetic profiles: 3 training days, light daily activity unless noted. Regenerate if the engine changes.
// Food values are the IFCT 2017 / USDA seed values (checked against the foods migrations).
// Contract: a day is either within the acceptance checks (±5% energy, at least 90% protein) and says so, or it says
// it is not, explains why, and offers only changes that respect the person's settings. Never a silent miss.
// These checks are software acceptance criteria, not medical recommendations.

typedef _Profile = ({String label, double kcal, double protein, int tier, Set<String> excluded, bool mustPass});

const _veg = {'beef', 'egg', 'fish', 'meat', 'pork', 'poultry', 'shellfish'};
const _vegan = {'beef', 'dairy', 'egg', 'fish', 'honey', 'meat', 'pork', 'poultry', 'shellfish'};
const _profiles = <_Profile>[
  (label: 'M25 maintain, non-veg, mid budget', kcal: 2300.0, protein: 112.0, tier: 2, excluded: {'beef', 'pork'}, mustPass: true),
  (label: 'F30 cut, vegetarian, sedentary, low budget', kcal: 1450.0, protein: 110.0, tier: 1, excluded: _veg, mustPass: false),
  (label: 'M35 cut, vegan, low budget', kcal: 2040.0, protein: 170.0, tier: 1, excluded: _vegan, mustPass: false),
  (label: 'M20 bulk, eggitarian, high budget', kcal: 2540.0, protein: 104.0, tier: 3, excluded: {'beef', 'fish', 'meat', 'pork', 'poultry', 'shellfish'}, mustPass: true),
  (label: 'F45 recomp, eggitarian, lactose-free, mid budget', kcal: 1760.0, protein: 140.0, tier: 2, excluded: {'beef', 'dairy', 'fish', 'meat', 'pork', 'poultry', 'shellfish'}, mustPass: false),
  (label: 'M28 bulk, vegetarian, low budget', kcal: 2260.0, protein: 96.0, tier: 1, excluded: _veg, mustPass: true),
];

// Planner foods above the low and mid budget tiers, from the catalogue's cost column.
const _aboveTier1 = {'L003', 'N003', 'S006', 'E001', 'E047'};

List<PlanItem> _items(DayPlan p) => p.meals.expand((m) => m.items).toList();

bool _withinChecks(DayPlan p, double kcal, double protein) =>
    ((p.kcal - kcal) / kcal).abs() <= kcalTolerance && p.protein / protein >= minProteinShare;

/// Words a suggestion must never contain for someone who excludes these food tags.
List<String> _forbiddenWords(Set<String> excluded) => [
      if (excluded.contains('dairy')) ...['milk', 'paneer', 'curd', 'whey'],
      if (excluded.contains('egg')) 'egg',
      if (excluded.contains('poultry')) 'chicken',
      if (excluded.contains('fish')) 'fish',
      if (excluded.contains('soy')) 'soya',
      if (excluded.contains('peanut')) 'peanut',
    ];

void main() {
  for (final p in _profiles) {
    group(p.label, () {
      final days = [
        for (var day = 0; day < 7; day++) planDay(foods: foodsForTest, kcal: p.kcal, protein: p.protein, excluded: p.excluded, tier: p.tier, day: day),
      ];

      test('the feasibility flag tells the truth on every day', () {
        for (final (day, d) in days.indexed) {
          expect(d.check.feasible, _withinChecks(d, p.kcal, p.protein), reason: 'day $day: ${d.kcal.round()} kcal, ${d.protein.round()} g');
        }
      });

      test('only allowed foods, within budget and soya limit', () {
        for (final (day, d) in days.indexed) {
          for (final i in _items(d)) {
            expect(foodsForTest[i.code]!.tags.any(p.excluded.contains), isFalse, reason: 'day $day ${i.name}');
            if (p.tier == 1) expect(_aboveTier1.contains(i.code), isFalse, reason: 'day $day ${i.name} is above budget');
          }
          final soya = _items(d).where((i) => i.code == 'X001').fold(0.0, (s, i) => s + i.grams);
          expect(soya, lessThanOrEqualTo(50), reason: 'day $day soya');
        }
      });

      test('energy lands within ±5% of the target on every day', () {
        for (final (day, d) in days.indexed) {
          expect((d.kcal - p.kcal).abs() / p.kcal, lessThanOrEqualTo(kcalTolerance), reason: 'day $day: ${d.kcal.round()} kcal');
        }
      });

      if (p.mustPass) {
        test('meets both checks on all 7 days', () {
          for (final (day, d) in days.indexed) {
            expect(d.check.feasible, isTrue, reason: 'day $day: ${d.kcal.round()} kcal, ${d.protein.round()} g, issues ${d.check.issues}');
          }
        });
      } else {
        test('a day that misses explains why, proves the limit, and suggests only allowed changes', () {
          for (final (day, d) in days.indexed) {
            if (d.check.feasible) continue;
            expect(d.check.issues, isNotEmpty, reason: 'day $day');
            expect(d.check.options.last, contains('not medical advice'), reason: 'day $day');
            if (d.check.proteinShare < minProteinShare) {
              // The exact ceiling for these foods within the energy limit is below the check, so no plan could pass.
              expect(d.check.proteinCeiling, lessThan(p.protein * minProteinShare), reason: 'day $day ceiling');
              // And the planner is not lazy: it gets within 5% of the target of that ceiling.
              expect(d.protein, greaterThanOrEqualTo(d.check.proteinCeiling - p.protein * 0.05), reason: 'day $day');
              expect(d.check.issues.first, startsWith('Protein:'));
            }
            final text = d.check.options.join(' ').toLowerCase();
            for (final w in _forbiddenWords(p.excluded)) {
              expect(text.contains(w), isFalse, reason: 'day $day suggests "$w"');
            }
          }
        });
      }

      test('the same inputs always give the same day', () {
        final again = planDay(foods: foodsForTest, kcal: p.kcal, protein: p.protein, excluded: p.excluded, tier: p.tier, day: 3);
        String key(DayPlan d) => _items(d).map((i) => '${i.code}:${i.grams}').join(',');
        expect(key(again), key(days[3]));
      });
    });
  }

  test('impossible: vegan without soy, peanut or gluten at 200 g protein is reported, never padded', () {
    final excluded = {..._vegan, 'soy', 'peanut', 'gluten', 'wheat', 'barley', 'rye'};
    final d = planDay(foods: foodsForTest, kcal: 2000, protein: 200, excluded: excluded, tier: 3);
    expect(d.check.feasible, isFalse);
    expect(d.check.proteinCeiling, lessThan(200 * minProteinShare));
    expect(d.check.issues.first, startsWith('Protein:'));
    for (final i in _items(d)) {
      expect(foodsForTest[i.code]!.tags.any(excluded.contains), isFalse, reason: i.name);
    }
    final text = d.check.options.join(' ').toLowerCase();
    for (final w in _forbiddenWords(excluded)) {
      expect(text.contains(w), isFalse, reason: 'suggests "$w"');
    }
  });

  test('no usable foods at all: an empty day is reported as infeasible', () {
    final d = planDay(foods: const {}, kcal: 2000, protein: 100, excluded: const {'beef', 'pork'});
    expect(d.meals, isEmpty);
    expect(d.check.feasible, isFalse);
    expect(d.check.issues.first, contains('None of the planner'));
  });

  test('protein powder is suggested only when the plan already includes it', () {
    final without = planDay(foods: foodsForTest, kcal: 2040, protein: 170, excluded: _vegan, tier: 1);
    final with_ = planDay(foods: foodsForTest, kcal: 2040, protein: 170, excluded: _vegan, tier: 1, proteinPowder: true);
    expect(without.check.options.join(' '), isNot(contains('protein powder')));
    expect(with_.check.options.first, contains('protein powder'));
  });

  test('a very high energy target with modest protein is either met or reported, never silently short', () {
    final d = planDay(foods: foodsForTest, kcal: 4500, protein: 90, excluded: const {'beef', 'pork'}, tier: 3);
    expect(d.check.feasible, _withinChecks(d, 4500, 90));
    if (!d.check.feasible) expect(d.check.issues.join(' '), contains('Energy:'));
  });
}

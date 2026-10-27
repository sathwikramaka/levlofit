import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';

import 'diet_plan_test.dart' show foodsForTest;

// Targets are the real plan-engine output (supabase/functions/_shared/plan-engine.ts, generatePlan) for these
// synthetic profiles: 3 training days, light daily activity unless noted. Regenerate if the engine changes.
// Food values are the IFCT 2017 / USDA seed values (checked against the foods migrations).
// Contract: a day is either within the acceptance checks (±5% energy, at least 90% protein) and says so, or it says
// it is not, explains why in terms scoped to Levlofit's planner, and offers only changes that respect the person's
// settings. These checks are software acceptance criteria, not medical recommendations.

typedef _Profile = ({String label, double kcal, double protein, int tier, Set<String> excluded, bool mustPass});

const _veg = {'beef', 'egg', 'fish', 'meat', 'pork', 'poultry', 'shellfish'};
const _vegan = {'beef', 'dairy', 'egg', 'fish', 'honey', 'meat', 'pork', 'poultry', 'shellfish'};
const _eggNoDairy = {'beef', 'dairy', 'fish', 'meat', 'pork', 'poultry', 'shellfish'};
const _profiles = <_Profile>[
  (label: 'M25 maintain, non-veg, mid budget', kcal: 2300.0, protein: 112.0, tier: 2, excluded: {'beef', 'pork'}, mustPass: true),
  // Misses: about 90 g protein fits 1450 kcal with whole rotis and chillas (portions in whole pieces since 2026-10-28).
  (label: 'F30 cut, vegetarian, sedentary, low budget', kcal: 1450.0, protein: 110.0, tier: 1, excluded: _veg, mustPass: false),
  (label: 'M35 cut, vegan, low budget', kcal: 2040.0, protein: 170.0, tier: 1, excluded: _vegan, mustPass: false),
  (label: 'M20 bulk, eggitarian, high budget', kcal: 2540.0, protein: 104.0, tier: 3, excluded: {'beef', 'fish', 'meat', 'pork', 'poultry', 'shellfish'}, mustPass: true),
  (label: 'F45 recomp, eggitarian, lactose-free, mid budget', kcal: 1760.0, protein: 140.0, tier: 2, excluded: _eggNoDairy, mustPass: true),
  (label: 'M28 bulk, vegetarian, low budget', kcal: 2260.0, protein: 96.0, tier: 1, excluded: _veg, mustPass: true),
];

// Planner foods above the low and mid budget tiers, from the catalogue's cost column.
const _aboveTier1 = {'L003', 'N003', 'S006', 'E001', 'E047'};
const _tier = {'L003': 2, 'N003': 2, 'S006': 2, 'E001': 2, 'E047': 2};

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

// ---- independent upper bound -------------------------------------------------------------------------------
// A separate copy of the planner's template rules (slot foods, floors, caps), deliberately not imported from the
// production code. For any multipliers lam, mu >= 0, Lagrangian duality gives a valid upper bound on the protein
// of every day that uses one food per slot, portions within [floor, cap], soya within its limit and energy within
// target +5%; the smallest bound over a grid of multipliers is used. Update this table if the templates change.
typedef _TSlot = (List<String> codes, double floor, double base, double max, bool fixed);
const _templates = <_TSlot>[
  (['dish:poha', 'dish:idli', 'dish:besan-chilla', 'dish:upma', 'dish:dosa', 'dish:moong-chilla', 'dish:thepla', 'dish:ragi-dosa', 'dish:vermicelli'], 20, 60, 150, false),
  (['M004', 'L003'], 0, 0, 150, false), (['L002'], 200, 200, 200, true), (['E012', 'E049', 'E028', 'E001'], 120, 120, 120, true),
  (['A015'], 20, 60, 150, false), (['A019', 'A005'], 20, 40, 120, false), (['B021', 'B010', 'B013', 'B020', 'B002'], 30, 40, 90, false), (['D036', 'D056', 'C015', 'F002', 'C033'], 150, 150, 150, true), (['D043'], 100, 100, 100, true),
  (['dish:sprouts', 'B002', 'H012'], 20, 30, 60, false), (['E028', 'E047', 'E012', 'E049'], 120, 120, 120, true), (['L002'], 0, 200, 200, true), (['M004', 'X001', 'L003', 'B013', 'B010', 'B021'], 0, 0, 100, false),
  (['A019', 'A005', 'A003'], 20, 60, 150, false), (['N003', 'S006', 'L003', 'M004', 'X001', 'B020', 'B013'], 25, 100, 220, false), (['C033', 'D076', 'C015', 'D036', 'D056'], 150, 150, 150, true),
];
const _foodCap = {'H012': 40.0, 'B002': 80.0, 'B021': 90.0, 'B010': 90.0, 'B013': 90.0, 'B020': 90.0, 'L003': 150.0, 'M004': 200.0, 'N003': 220.0, 'S006': 220.0};

double _oilKcalShown(double kcal) {
  final g = (27 * kcal / 2000).clamp(20.0, 30.0).roundToDouble();
  return 900 * ((g * 0.2).roundToDouble() + (g * 0.4).roundToDouble() * 2) / 100; // sunflower oil, 900 kcal/100 g
}

double dualBound({required double kcal, required int tier, required Set<String> excluded, double soyaCap = 50}) {
  final budget = kcal * (1 + kcalTolerance) - _oilKcalShown(kcal);
  final slots = <List<(String, double, double)>>[
    for (final (codes, floor, base, max, fixed) in _templates)
      [
        for (final c in codes)
          if ((_tier[c] ?? 1) <= tier && !foodsForTest[c]!.tags.any(excluded.contains))
            // Soya may be shown below a slot floor when its limit is split, so its lower end is 0 here.
            (c, c == 'X001' ? 0.0 : floor, c == 'X001' ? math.min(max, soyaCap) : (fixed ? base : math.min(max, _foodCap[c] ?? max))),
      ],
  ].where((s) => s.isNotEmpty).toList();
  var best = double.infinity;
  for (var li = 0; li <= 400; li++) {
    final lam = li * 0.0005;
    for (var mi = 0; mi <= 40; mi++) {
      final mu = mi * 0.05;
      var total = lam * budget + mu * soyaCap;
      for (final s in slots) {
        var m = double.negativeInfinity;
        for (final (c, lo, hi) in s) {
          final f = foodsForTest[c]!;
          final coef = (f.protein - lam * f.kcal - (c == 'X001' ? mu * 100 : 0)) / 100;
          m = math.max(m, coef * (coef > 0 ? hi : lo));
        }
        total += m;
      }
      best = math.min(best, total);
    }
  }
  return best;
}

void main() {
  for (final p in _profiles) {
    group(p.label, () {
      final days = [
        for (var day = 0; day < 7; day++) planDay(foods: foodsForTest, kcal: p.kcal, protein: p.protein, excluded: p.excluded, tier: p.tier, day: day),
      ];

      test('the feasibility flag tells the truth on every day', () {
        for (final (day, d) in days.indexed) {
          expect(d.check.feasible, _withinChecks(d, p.kcal, p.protein), reason: 'day $day: ${d.kcal.round()} kcal, ${d.protein.round()} g');
          expect(d.check.hitStepLimit, isFalse, reason: 'day $day stopped at the step limit');
        }
      });

      test('only allowed foods, within budget and soya limit; eggs in whole eggs', () {
        for (final (day, d) in days.indexed) {
          for (final i in _items(d)) {
            expect(foodsForTest[i.code]!.tags.any(p.excluded.contains), isFalse, reason: 'day $day ${i.name}');
            if (p.tier == 1) expect(_aboveTier1.contains(i.code), isFalse, reason: 'day $day ${i.name} is above budget');
            if (i.code == 'M004') {
              expect(i.grams % 50, 0, reason: 'day $day egg grams ${i.grams}');
              expect(amountLabel(i), startsWith('${(i.grams / 50).round()} egg'));
            }
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

      test('the template ceiling is below an independent upper bound and above every day that keeps to the energy limit', () {
        final ceiling = templateProteinCeiling(foods: foodsForTest, kcal: p.kcal, excluded: p.excluded, tier: p.tier);
        final bound = dualBound(kcal: p.kcal, tier: p.tier, excluded: p.excluded);
        // Production rounds each food's energy down (at most 1 kcal per slot), so allow 2 g of slack.
        expect(ceiling, lessThanOrEqualTo(bound + 2), reason: 'ceiling $ceiling vs independent bound $bound');
        for (final (day, d) in days.indexed) {
          if (d.kcal <= p.kcal * (1 + kcalTolerance)) expect(d.protein, lessThanOrEqualTo(ceiling + 1e-6), reason: 'day $day');
        }
      });

      if (p.mustPass) {
        test('meets both checks on all 7 days', () {
          for (final (day, d) in days.indexed) {
            expect(d.check.feasible, isTrue, reason: 'day $day: ${d.kcal.round()} kcal, ${d.protein.round()} g, issues ${d.check.issues}');
          }
        });
      } else {
        test('a day that misses: independent proof, scoped explanation, allowed suggestions only', () {
          // The dual bound treats portions as continuous; whole-piece portions (rotis, chillas) can sit below it, so
          // the proof of the miss is the exhaustive template search (proteinCeiling), checked against the bound above.
          for (final (day, d) in days.indexed) {
            expect(d.check.feasible, isFalse, reason: 'day $day');
            final text = d.check.issues.join(' ');
            expect(d.check.issues.first, startsWith('Protein:'));
            expect(text, contains('Levlofit\'s food list, meal templates, portion limits and your budget'));
            expect(text, contains('limits of the planner, not of nutrition'));
            expect(text, isNot(contains('no arrangement')));
            expect(text, isNot(contains('smallest')), reason: 'energy is in range, so no portion-size claim');
            expect(d.check.proteinCeiling, isNotNull);
            expect(d.check.proteinCeiling!, lessThan(p.protein * minProteinShare));
            // Not lazy: the day shown is within 8% of the target of the ceiling (the ceiling allows +5% energy).
            expect(d.protein, greaterThanOrEqualTo(d.check.proteinCeiling! - p.protein * 0.08), reason: 'day $day');
            expect(d.check.options.last, contains('not medical advice'));
            final options = d.check.options.join(' ').toLowerCase();
            for (final w in _forbiddenWords(p.excluded)) {
              expect(options.contains(w), isFalse, reason: 'day $day suggests "$w"');
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

  test('F45 regression: a template day meets the targets, so it is no longer reported as impossible', () {
    const kcal = 1760.0, protein = 140.0;
    // Independent evidence that the targets are reachable within the templates.
    expect(dualBound(kcal: kcal, tier: 2, excluded: _eggNoDairy), greaterThanOrEqualTo(protein * minProteinShare));
    for (var day = 0; day < 7; day++) {
      final d = planDay(foods: foodsForTest, kcal: kcal, protein: protein, excluded: _eggNoDairy, tier: 2, day: day);
      expect(d.check.feasible, isTrue, reason: 'day $day: ${d.check.issues}');
      // Recompute the day from the food table, independently of the planner's own totals.
      var k = 0.0, pr = 0.0;
      for (final i in _items(d)) {
        final f = foodsForTest[i.code] ?? (i.code == 'T012' ? foodsForTest['T012']! : null);
        k += f!.kcal * i.grams / 100;
        pr += f.protein * i.grams / 100;
        expect(f.tags.any(_eggNoDairy.contains), isFalse, reason: i.name);
      }
      expect((k - kcal).abs() / kcal, lessThanOrEqualTo(kcalTolerance), reason: 'day $day energy $k');
      expect(pr / protein, greaterThanOrEqualTo(minProteinShare), reason: 'day $day protein $pr');
    }
  });

  group('variety search falls back safely', () {
    // F45 settings with a smaller food list: the only dals are moong, masoor and kala chana. The weekday rotation
    // picks the lunch dal as pool[(day + slot 2 + meal 1) % 3] (the planner's rotation rule, mirrored here).
    // Variety attempts always keep that weekday dal, so a day showing another dal came from the full search.
    final foods = {...foodsForTest}..remove('B021')..remove('B020')..removeWhere((k, _) => k.startsWith('dish:')); // the pre-dish list
    const dalPool = ['B010', 'B013', 'B002'];
    String dalOf(DayPlan d) => d.meals.firstWhere((m) => m.name == 'Lunch').items.map((i) => i.code).firstWhere(dalPool.contains);

    test('when no varied day passes, the passing full-search day is returned', () {
      var fallbacks = 0;
      for (var day = 0; day < 7; day++) {
        final d = planDay(foods: foods, kcal: 1760, protein: 138, excluded: _eggNoDairy, tier: 2, day: day);
        expect(d.check.feasible, isTrue, reason: 'day $day: ${d.check.issues}');
        // Independently recomputed from the food table.
        var k = 0.0, pr = 0.0;
        for (final i in _items(d)) {
          final f = foodsForTest[i.code]!;
          k += f.kcal * i.grams / 100;
          pr += f.protein * i.grams / 100;
          expect(f.tags.any(_eggNoDairy.contains), isFalse, reason: 'day $day ${i.name}');
          expect(foods.containsKey(i.code), isTrue, reason: 'day $day uses ${i.name}, which is not in the food list');
        }
        expect((k - 1760).abs() / 1760, lessThanOrEqualTo(kcalTolerance), reason: 'day $day energy $k');
        expect(pr / 138, greaterThanOrEqualTo(minProteinShare), reason: 'day $day protein $pr');
        if (dalOf(d) != dalPool[(day + 3) % 3]) {
          fallbacks++;
          expect(d.check.proteinCeiling, isNotNull, reason: 'day $day: only the full search shows another dal');
        }
        final again = planDay(foods: foods, kcal: 1760, protein: 138, excluded: _eggNoDairy, tier: 2, day: day);
        expect(_items(again).map((i) => '${i.code}:${i.grams}').join(','), _items(d).map((i) => '${i.code}:${i.grams}').join(','));
      }
      expect(fallbacks, greaterThan(0), reason: 'this profile should exercise the fallback');
    });

    test('when no day passes at all, the miss is reported honestly', () {
      for (var day = 0; day < 7; day++) {
        final d = planDay(foods: foods, kcal: 1760, protein: 146, excluded: _eggNoDairy, tier: 2, day: day);
        expect(d.check.feasible, isFalse, reason: 'day $day');
        expect(d.check.issues.first, startsWith('Protein:'));
        expect(d.check.proteinCeiling!, lessThan(146 * minProteinShare));
        expect(d.check.proteinCeiling!, lessThanOrEqualTo(dualBound(kcal: 1760, tier: 2, excluded: _eggNoDairy) + 2));
        for (final i in _items(d)) {
          expect(foodsForTest[i.code]!.tags.any(_eggNoDairy.contains), isFalse, reason: 'day $day ${i.name}');
        }
      }
    });
  });

  test('impossible: vegan without soy, peanut or gluten at 200 g protein is reported, never padded', () {
    final excluded = {..._vegan, 'soy', 'peanut', 'gluten', 'wheat', 'barley', 'rye'};
    final d = planDay(foods: foodsForTest, kcal: 2000, protein: 200, excluded: excluded, tier: 3);
    expect(d.check.feasible, isFalse);
    expect(dualBound(kcal: 2000, tier: 3, excluded: excluded), lessThan(200 * minProteinShare));
    expect(d.check.proteinCeiling!, lessThan(200 * minProteinShare));
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

  test('F45 week varies across days while every day passes and respects every setting', () {
    const kcal = 1760.0, protein = 140.0;
    final week = planWeek((foods: foodsForTest, kcal: kcal, protein: protein, excluded: _eggNoDairy, custom: const [], tier: 2, soyaCapG: 50, proteinPowder: false, region: null));
    final distinct = <String>{}, dals = <String>{}, staples = <String>{};
    for (final (day, d) in week.indexed) {
      // Independently recomputed from the food table and checked against the acceptance criteria.
      var k = 0.0, pr = 0.0;
      for (final i in _items(d)) {
        final f = foodsForTest[i.code]!;
        k += f.kcal * i.grams / 100;
        pr += f.protein * i.grams / 100;
        expect(f.tags.any(_eggNoDairy.contains), isFalse, reason: 'day $day ${i.name}');
        expect(_aboveTier1.contains(i.code) && (_tier[i.code] ?? 1) > 2, isFalse);
        if (i.code == 'M004') expect(i.grams % 50, 0);
      }
      expect((k - kcal).abs() / kcal, lessThanOrEqualTo(kcalTolerance), reason: 'day $day energy $k');
      expect(pr / protein, greaterThanOrEqualTo(minProteinShare), reason: 'day $day protein $pr');
      expect(_items(d).where((i) => i.code == 'X001').fold(0.0, (s, i) => s + i.grams), lessThanOrEqualTo(50));
      distinct.add(_items(d).map((i) => '${i.code}:${i.grams}').join(','));
      final lunch = d.meals.firstWhere((m) => m.name == 'Lunch').items;
      dals.addAll(lunch.where((i) => const {'B021', 'B010', 'B013', 'B020', 'B002'}.contains(i.code)).map((i) => i.code));
      staples.addAll(_items(d).where((i) => const {'A011', 'A010', 'A019', 'A005', 'A003'}.contains(i.code) || i.code.startsWith('dish:')).map((i) => i.code));
    }
    expect(distinct.length, greaterThanOrEqualTo(5), reason: 'distinct days');
    expect(dals.length, greaterThanOrEqualTo(3), reason: 'dals across the week: $dals');
    expect(staples.length, greaterThanOrEqualTo(3), reason: 'staples across the week: $staples');
  });

  test('identical inputs give identical F45 weeks', () {
    String key(List<DayPlan> w) => w.map((d) => _items(d).map((i) => '${i.code}:${i.grams}').join(',')).join('|');
    WeekRequest r() => (foods: {...foodsForTest}, kcal: 1760.0, protein: 140.0, excluded: {..._eggNoDairy}, custom: const <String>[], tier: 2, soyaCapG: 50.0, proteinPowder: false, region: null);
    expect(key(planWeek(r())), key(planWeek(r())));
  });

  test('when no template day fits the energy limit, no protein figure is claimed', () {
    for (final target in [40.0, 200.0]) {
      final low = planDay(foods: foodsForTest, kcal: 700, protein: target, excluded: const {'beef', 'pork'}, tier: 3);
      expect(low.check.feasible, isFalse);
      expect(low.check.proteinCeiling, isNull, reason: 'protein $target');
      final text = low.check.issues.join(' ');
      expect(text, isNot(contains('about 0 g')));
      expect(text, contains('even the smallest portions'));
      // Short of protein too: the protein line says why it gives no figure instead of claiming a ceiling.
      if (low.check.proteinShare < minProteinShare) expect(text, contains('no protein figure'), reason: 'protein $target');
    }
    expect(planDay(foods: foodsForTest, kcal: 700, protein: 200, excluded: const {'beef', 'pork'}, tier: 3).check.proteinShare, lessThan(minProteinShare));
  });

  test('portion-size claims appear only when the templates themselves prove them', () {
    final low = planDay(foods: foodsForTest, kcal: 700, protein: 40, excluded: const {'beef', 'pork'}, tier: 3);
    expect(low.check.feasible, isFalse);
    expect(low.check.issues.join(' '), contains('even the smallest portions'));
    final high = planDay(foods: foodsForTest, kcal: 9000, protein: 90, excluded: const {'beef', 'pork'}, tier: 3);
    expect(high.check.feasible, isFalse);
    expect(high.check.issues.join(' '), contains('even the largest portions'));
  });

  test('protein powder is suggested only when the plan already includes it', () {
    final without = planDay(foods: foodsForTest, kcal: 2040, protein: 170, excluded: _vegan, tier: 1);
    final with_ = planDay(foods: foodsForTest, kcal: 2040, protein: 170, excluded: _vegan, tier: 1, proteinPowder: true);
    expect(without.check.options.join(' '), isNot(contains('protein powder')));
    expect(with_.check.options.first, contains('protein powder'));
  });

  group('cooking oil respects the person\'s own exclusion words', () {
    // Mustard oil, IFCT 2017 seed row T006 (supabase/migrations/20260929170000_foods_ifct2017.sql).
    final withMustard = {...foodsForTest, 'T006': foodFromRow({'code': 'T006', 'name': 'Mustard oil', 'tags': <String>[], 'kcal': 900, 'protein_g': 0.0, 'carb_g': 0.0, 'fat_g': 100.0, 'fiber_g': 0.0})};
    List<String> oils(DayPlan d) => _items(d).where((i) => i.unit == 'oil').map((i) => i.code).toSet().toList();

    test('excluding sunflower uses mustard oil, never sunflower', () {
      final d = planDay(foods: withMustard, kcal: 2300, protein: 112, excluded: const {'beef', 'pork'}, custom: const ['sunflower']);
      expect(oils(d), ['T006']);
    });

    test('excluding both oils leaves the day without oil instead of substituting one', () {
      final d = planDay(foods: withMustard, kcal: 2300, protein: 112, excluded: const {'beef', 'pork'}, custom: const ['oil']);
      expect(oils(d), isEmpty);
    });
  });

  test('a very high energy target with modest protein is either met or reported, never silently short', () {
    final d = planDay(foods: foodsForTest, kcal: 4500, protein: 90, excluded: const {'beef', 'pork'}, tier: 3);
    expect(d.check.feasible, _withinChecks(d, 4500, 90));
    if (!d.check.feasible) expect(d.check.issues.join(' '), contains('Energy:'));
  });

  // Coach plan item 5: property test over seeded random profiles (energy, protein, budget, diet, restrictions).
  test('properties: 40 random profiles x 2 days keep every rule, and the feasibility flag always tells the truth', () {
    var seed = 20261024;
    double rnd() => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
    int between(int lo, int hi) => lo + (rnd() * (hi - lo + 1)).floor();
    const diets = [<String>{}, _veg, _vegan, {'fish', 'meat', 'poultry', 'shellfish'}]; // non-veg, veg, vegan, eggitarian
    const restrictions = ['dairy', 'peanut', 'soy', 'tree_nut'];
    for (var i = 0; i < 40; i++) {
      final excluded = {'beef', 'pork', ...diets[between(0, diets.length - 1)], for (final r in restrictions) if (rnd() < 0.25) r};
      final kcal = between(1400, 3200).toDouble(), protein = between(60, 200).toDouble(), tier = between(1, 3);
      final at = 'case $i: ${kcal.round()} kcal, ${protein.round()} g, tier $tier, ${excluded.toList()..sort()}';
      for (final day in [0, 3]) {
        final d = planDay(foods: foodsForTest, kcal: kcal, protein: protein, excluded: excluded, tier: tier, day: day);
        expect(d.check.feasible, _withinChecks(d, kcal, protein), reason: '$at, day $day: flag disagrees with the numbers');
        expect(d.check.hitStepLimit, isFalse, reason: '$at, day $day');
        if (!d.check.feasible) expect(d.check.issues, isNotEmpty, reason: '$at, day $day: infeasible without saying why');
        final words = _forbiddenWords(excluded);
        for (final it in _items(d)) {
          expect(foodsForTest[it.code]!.tags.any(excluded.contains), isFalse, reason: '$at, day $day: ${it.name}');
          if (tier == 1) expect(_aboveTier1.contains(it.code), isFalse, reason: '$at, day $day: ${it.name} above budget');
        }
        for (final o in d.check.options) {
          for (final w in words) {
            expect(o.toLowerCase().contains(w), isFalse, reason: '$at, day $day: suggestion "$o" names $w');
          }
        }
        final soya = _items(d).where((it) => it.code == 'X001').fold(0.0, (s, it) => s + it.grams);
        expect(soya, lessThanOrEqualTo(excluded.contains('soy') ? 0 : 50), reason: '$at, day $day: soya ${soya}g');
      }
    }
  });
}

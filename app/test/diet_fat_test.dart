import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';

import 'diet_plan_test.dart' show foodsForTest;

// Total fat as a share of energy, reported as guidance only: WHO (2023) and ICMR-NIN (2024) give 30% or less for adults.
// These tests recompute the share independently, pin the threshold, check missing fat values are never treated as
// zero, and prove the guidance changes neither the plan nor its energy/protein pass flag.

typedef _Profile = ({String label, double kcal, double protein, int tier, Set<String> excluded, int passing});

const _veg = {'beef', 'egg', 'fish', 'meat', 'pork', 'poultry', 'shellfish'};
const _profiles = <_Profile>[
  (label: 'M25', kcal: 2300.0, protein: 112.0, tier: 2, excluded: {'beef', 'pork'}, passing: 7),
  (label: 'F30', kcal: 1450.0, protein: 110.0, tier: 1, excluded: _veg, passing: 0),
  (label: 'M35', kcal: 2040.0, protein: 170.0, tier: 1, excluded: {'beef', 'dairy', 'egg', 'fish', 'honey', 'meat', 'pork', 'poultry', 'shellfish'}, passing: 0),
  (label: 'M20', kcal: 2540.0, protein: 104.0, tier: 3, excluded: {'beef', 'fish', 'meat', 'pork', 'poultry', 'shellfish'}, passing: 7),
  (label: 'F45', kcal: 1760.0, protein: 140.0, tier: 2, excluded: {'beef', 'dairy', 'fish', 'meat', 'pork', 'poultry', 'shellfish'}, passing: 7),
  (label: 'M28', kcal: 2260.0, protein: 96.0, tier: 1, excluded: _veg, passing: 7),
];

List<DayPlan> _week(_Profile p, [Map<String, Food>? foods]) =>
    planWeek((foods: foods ?? foodsForTest, kcal: p.kcal, protein: p.protein, excluded: p.excluded, custom: const [], tier: p.tier, soyaCapG: 50, proteinPowder: false, region: null));

/// The fixture with one food's fat value missing (as a null fat_g from the food table would give).
Map<String, Food> _withoutFat(String code) {
  final f = foodsForTest[code]!;
  return {
    ...foodsForTest,
    code: foodFromRow({'code': f.code, 'name': f.name, 'tags': f.tags, 'kcal': f.kcal, 'protein_g': f.protein, 'carb_g': f.carb, 'fat_g': null, 'fiber_g': f.fiber}),
  };
}


void main() {
  group('fatGuidance threshold', () {
    test('30% exactly is within guidance; anything above it gets the message', () {
      expect(fatGuidance(0.30, const []), isEmpty);
      expect(fatGuidance(0.25, const []), isEmpty);
      final over = fatGuidance(0.3001, const []);
      expect(over, hasLength(1));
      expect(over.single, contains('above the 30% or less'));
      expect(over.single, contains('not a diagnosis'));
    });

    test('values just above 30% never read as 30%: exact messages at 30%, 30.01% and 30.49%', () {
      // 30% exactly: within guidance, no message; the share itself displays as 30.0%.
      expect(fatGuidance(0.30, const []), isEmpty);
      expect(fatShareText(0.30), 'about 30.0%');
      // 30.01% would round to 30.0%, so it reads "just over 30%".
      expect(fatShareText(0.3001), 'just over 30%');
      expect(
        fatGuidance(0.3001, const []).single,
        'Fat: just over 30% of this day\'s energy comes from fat, above the 30% or less that WHO (2023) and '
        'ICMR-NIN (2024) advise for adults. This is general guidance, not a diagnosis.',
      );
      // 30.49% rounds to 30.5% at one decimal, which already reads as over the limit.
      expect(fatShareText(0.3049), 'about 30.5%');
      expect(
        fatGuidance(0.3049, const []).single,
        'Fat: about 30.5% of this day\'s energy comes from fat, above the 30% or less that WHO (2023) and '
        'ICMR-NIN (2024) advise for adults. This is general guidance, not a diagnosis.',
      );
      expect(fatGuidance(0.41, const []).single, contains('about 41.0%'));
      // No over-limit message ever shows a number at or below 30.
      for (var bp = 3001; bp <= 3100; bp++) {
        final text = fatGuidance(bp / 10000, const []).single;
        final shown = RegExp(r'about (\d+\.\d)%').firstMatch(text);
        if (shown != null) expect(double.parse(shown.group(1)!), greaterThan(30.0), reason: 'share ${bp / 100}%');
      }
    });

    test('a missing fat value gives no percentage, names the food, and wins over the threshold', () {
      final g = fatGuidance(null, const ['Sunflower oil']);
      expect(g.single, contains('not shown'));
      expect(g.single, contains('Sunflower oil'));
      expect(RegExp(r'\d+%').hasMatch(g.single), isFalse);
      expect(fatGuidance(0.5, const ['Paneer']).single, contains('not shown'));
    });
  });

  group('foodFromRow fat state', () {
    test('a null or unreadable fat value is unknown, never a real zero', () {
      Food row(Object? fat) => foodFromRow({'code': 'X', 'name': 'x', 'tags': <String>[], 'kcal': 100, 'protein_g': 1, 'carb_g': 1, 'fat_g': fat, 'fiber_g': 0});
      expect(row(null).fatKnown, isFalse);
      expect(row('n/a').fatKnown, isFalse);
      expect(row(0).fatKnown, isTrue);
      expect(row('10.5').fat, 10.5);
      expect(row('10.5').fatKnown, isTrue);
      expect(foodsForTest.values.every((f) => f.fatKnown), isTrue, reason: 'every fixture food has a fat value');
    });
  });

  for (final p in _profiles) {
    test('${p.label}: fat share recomputed independently, guidance exactly above 30%, pass flags unchanged', () {
      final week = _week(p);
      for (final (day, d) in week.indexed) {
        var fat = 0.0, kcal = 0.0;
        for (final i in d.meals.expand((m) => m.items)) {
          fat += foodsForTest[i.code]!.fat * i.grams / 100;
          kcal += foodsForTest[i.code]!.kcal * i.grams / 100;
        }
        final share = 9 * fat / kcal;
        expect(d.check.fatEnergyShare, isNotNull, reason: 'day $day');
        expect(d.check.fatEnergyShare!, closeTo(share, 1e-9), reason: 'day $day');
        expect(d.check.guidance.isNotEmpty, share > maxFatEnergyShare, reason: 'day $day share $share');
        // The pass flag is still exactly the energy and protein check.
        final within = ((d.kcal - p.kcal) / p.kcal).abs() <= kcalTolerance && d.protein / p.protein >= minProteinShare;
        expect(d.check.feasible, within, reason: 'day $day');
      }
      expect(week.where((d) => d.check.feasible).length, p.passing, reason: 'passing days as before this change');
    });
  }

  test('F45: every day passes the energy and protein checks and still carries the fat guidance', () {
    final week = _week(_profiles[4]);
    expect(week.every((d) => d.check.feasible), isTrue);
    expect(week.every((d) => d.check.guidance.single.contains('of this day\'s energy comes from fat')), isTrue);
  });

  test('a missing fat value on a planned food hides the share on every day and names the food', () {
    final week = _week(_profiles[0], _withoutFat('T012')); // sunflower oil is on every day
    for (final (day, d) in week.indexed) {
      expect(d.check.fatEnergyShare, isNull, reason: 'day $day');
      expect(d.check.guidance.single, contains('Sunflower oil'), reason: 'day $day');
      expect(d.check.guidance.single, contains('not shown'), reason: 'day $day');
    }
  });

  test('a missing fat value on a food that is not planned does not hide the share', () {
    final week = _week(_profiles[1], _withoutFat('N003')); // chicken never appears in a vegetarian plan
    expect(week.every((d) => d.check.fatEnergyShare != null), isTrue);
  });

  test('fat data may swap in leaner foods, but only lowers fat and never fails a day', () {
    final noFat = {for (final e in foodsForTest.entries) e.key: _withoutFat(e.key)[e.key]!};
    double share(DayPlan d) {
      // The fat share of a day's foods with their real fat values.
      final fat = d.meals.expand((m) => m.items).fold(0.0, (s, i) => s + foodsForTest[i.code]!.fat * i.grams / 100);
      return d.kcal <= 0 ? 0 : 9 * fat / d.kcal;
    }

    for (final p in _profiles) {
      final a = _week(p), b = _week(p, noFat);
      for (var day = 0; day < 7; day++) {
        expect(b[day].check.fatEnergyShare, isNull, reason: '${p.label} day $day: unknown fat is never shown');
        if (b[day].check.feasible) expect(a[day].check.feasible, isTrue, reason: '${p.label} day $day pass flag');
        expect(share(a[day]), lessThanOrEqualTo(math.max(maxFatEnergyShare, share(b[day])) + 1e-9), reason: '${p.label} day $day fat');
      }
    }
  });

  test('the week cache key changes when only the fat-known state changes', () {
    WeekRequest req(Map<String, Food> foods) =>
        (foods: foods, kcal: 2300.0, protein: 112.0, excluded: const {'beef', 'pork'}, custom: const <String>[], tier: 2, soyaCapG: 50.0, proteinPowder: false, region: null);
    final f = foodsForTest['T012']!;
    Food oil(Object? fat) => foodFromRow({'code': f.code, 'name': f.name, 'tags': f.tags, 'kcal': f.kcal, 'protein_g': 0, 'carb_g': 0, 'fat_g': fat, 'fiber_g': 0});
    final known0 = {...foodsForTest, 'T012': oil(0)}, unknown = {...foodsForTest, 'T012': oil(null)};
    expect(known0['T012']!.fat, unknown['T012']!.fat, reason: 'same number, different knowledge');
    expect(weekKey(req(known0)), isNot(weekKey(req(unknown))));
    final cache = WeekCache();
    cache.put(weekKey(req(known0)), planWeek(req(known0)));
    expect(cache.get(weekKey(req(unknown))), isNull, reason: 'a week with known fat is never served for unknown fat');
  });

  test('egg and vegetarian weeks stay near 30% fat (planner swaps leaner foods; was up to 45%)', () {
    for (final excluded in [
      {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish'},
      {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg'},
    ]) {
      final week = planWeek((foods: foodsForTest, kcal: 2290.0, protein: 144.0, excluded: excluded, custom: const <String>[], tier: 2, soyaCapG: 50.0, proteinPowder: false, region: null));
      for (final d in week) {
        expect(d.check.fatEnergyShare, lessThanOrEqualTo(0.32), reason: excluded.contains('egg') ? 'vegetarian' : 'eggitarian');
        expect(d.check.proteinShare, greaterThanOrEqualTo(minProteinShare));
      }
      expect(week.every((d) => d.check.feasible), isTrue);
    }
  });
}

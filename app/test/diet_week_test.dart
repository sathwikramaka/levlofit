import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';

import 'diet_plan_test.dart' show foodsForTest;

// The Diet tab builds a whole week once per set of inputs (in a background isolate) and reads days from a cache.
// These tests pin down that the cached week is exactly what planDay gives, that the key changes whenever any
// input that changes the result changes (and only then), and that nothing about the nutrition checks changes.

const _eggNoDairy = {'beef', 'dairy', 'fish', 'meat', 'pork', 'poultry', 'shellfish'};
const _veg = {'beef', 'egg', 'fish', 'meat', 'pork', 'poultry', 'shellfish'};

WeekRequest _req({
  Map<String, Food>? foods,
  double kcal = 1760,
  double protein = 140,
  Set<String> excluded = _eggNoDairy,
  List<String> custom = const [],
  int tier = 2,
  double soyaCapG = 50,
  bool proteinPowder = false,
}) =>
    (foods: foods ?? foodsForTest, kcal: kcal, protein: protein, excluded: excluded, custom: custom, tier: tier, soyaCapG: soyaCapG, proteinPowder: proteinPowder, region: null, mealCodes: null, topUpScoop: false);

String _dayKey(DayPlan d) =>
    '${d.check.feasible}|${d.meals.map((m) => '${m.name}:${m.items.map((i) => '${i.code}=${i.grams}').join(',')}').join(';')}|${d.check.issues.join('/')}';

void main() {
  group('planWeek', () {
    test('gives exactly the seven planDay results, Monday first', () {
      final r = _req();
      final week = planWeek(r);
      expect(week.length, 7);
      for (var day = 0; day < 7; day++) {
        final single = planDay(foods: r.foods, kcal: r.kcal, protein: r.protein, excluded: r.excluded, tier: r.tier, day: day);
        expect(_dayKey(week[day]), _dayKey(single), reason: 'day $day');
      }
    });

    test('is deterministic', () {
      expect(planWeek(_req()).map(_dayKey).toList(), planWeek(_req()).map(_dayKey).toList());
    });

    test('in the background gives the same week as on the calling thread', () async {
      final r = _req(excluded: _veg, kcal: 1450, protein: 110, tier: 1);
      final background = await planWeekInBackground(r);
      expect(background.map(_dayKey).toList(), planWeek(r).map(_dayKey).toList());
    });
  });

  group('weekKey', () {
    test('ignores what the planner ignores: set order, word case, spacing, order and repeats, a copied food map', () {
      final a = weekKey(_req(excluded: {'beef', 'dairy', 'fish', 'meat', 'pork', 'poultry', 'shellfish'}, custom: const ['Rajma', ' peanut ']));
      final b = weekKey(_req(foods: {...foodsForTest}, excluded: {'shellfish', 'poultry', 'pork', 'meat', 'fish', 'dairy', 'beef'}, custom: const ['PEANUT', 'rajma', 'rajma', '']));
      expect(a, b);
    });

    test('changes whenever an input that changes the result changes', () {
      final base = weekKey(_req());
      final changed = <String, WeekRequest>{
        'energy': _req(kcal: 1800),
        'protein': _req(protein: 141),
        'excluded tag': _req(excluded: {..._eggNoDairy, 'egg'}),
        'exclusion word': _req(custom: const ['rajma']),
        'budget tier': _req(tier: 1),
        'soya limit': _req(soyaCapG: 40),
        'protein powder': _req(proteinPowder: true),
        'a food value': _req(foods: {...foodsForTest, 'B013': (foodsForTest['B013']!.copyWithProtein(24.0))}),
        'a food name': _req(foods: {...foodsForTest, 'B013': foodFromRow({'code': 'B013', 'name': 'Lentil dal, red', 'tags': <String>[], 'kcal': 322, 'protein_g': 24.35, 'carb_g': 52.53, 'fat_g': 0.75, 'fiber_g': 10.43})}),
        'a missing food': _req(foods: {...foodsForTest}..remove('B013')),
      };
      for (final MapEntry(key: what, value: r) in changed.entries) {
        expect(weekKey(r), isNot(base), reason: what);
      }
    });
  });

  group('WeekCache', () {
    test('returns what was stored, and nothing for other keys', () {
      final cache = WeekCache();
      final week = planWeek(_req());
      cache.put('a', week);
      expect(identical(cache.get('a'), week), isTrue);
      expect(cache.get('b'), isNull);
    });

    test('builds a week once per key, again only when the key changes', () {
      final cache = WeekCache();
      var builds = 0;
      List<DayPlan> make(WeekRequest r) {
        builds++;
        return planWeek(r);
      }

      final r = _req();
      for (var i = 0; i < 5; i++) {
        cache.getOrPut(weekKey(r), () => make(r)); // e.g. five rebuilds or day switches
      }
      expect(builds, 1);
      final other = _req(tier: 1);
      cache.getOrPut(weekKey(other), () => make(other));
      expect(builds, 2);
      cache.getOrPut(weekKey(r), () => make(r));
      expect(builds, 2, reason: 'the first week is still cached');
    });

    test('evicts the least recently used week beyond its capacity', () {
      final cache = WeekCache(capacity: 2);
      final w = planWeek(_req());
      cache.put('a', w);
      cache.put('b', w);
      cache.get('a'); // a is now the most recently used
      cache.put('c', w);
      expect(cache.length, 2);
      expect(cache.get('b'), isNull);
      expect(cache.get('a'), isNotNull);
      expect(cache.get('c'), isNotNull);
    });
  });

  test('a cached week keeps every nutrition check: truthful flag, exclusions, budget, soya limit, energy band', () {
    final cache = WeekCache();
    for (final r in [_req(), _req(excluded: _veg, kcal: 1450, protein: 110, tier: 1)]) {
      final week = cache.getOrPut(weekKey(r), () => planWeek(r));
      for (final (day, d) in week.indexed) {
        final within = ((d.kcal - r.kcal) / r.kcal).abs() <= kcalTolerance && d.protein / r.protein >= minProteinShare;
        expect(d.check.feasible, within, reason: 'day $day');
        expect(((d.kcal - r.kcal) / r.kcal).abs(), lessThanOrEqualTo(kcalTolerance), reason: 'day $day energy');
        final items = d.meals.expand((m) => m.items);
        for (final i in items) {
          expect(foodsForTest[i.code]!.tags.any(r.excluded.contains), isFalse, reason: 'day $day ${i.name}');
          if (r.tier == 1) expect(const {'L003', 'N003', 'S006', 'E001', 'E047'}.contains(i.code), isFalse, reason: 'day $day ${i.name}');
        }
        expect(items.where((i) => i.code == 'X001').fold(0.0, (s, i) => s + i.grams), lessThanOrEqualTo(r.soyaCapG));
      }
    }
  });
}

extension on Food {
  Food copyWithProtein(double p) => (code: code, name: name, tags: tags, kcal: kcal, protein: p, carb: carb, fat: fat, fiber: fiber, fatKnown: fatKnown);
}

// A day of Indian meals with grams for every food, built by rules over IFCT 2017 (Indian Food Composition
// Tables) values: breakfast, lunch, snack and dinner templates, foods filtered by diet, allergies and budget,
// rotated by weekday, then portions solved so the day lands on the plan's energy and protein.
// Cooking oil follows ICMR-NIN Dietary Guidelines for Indians 2024: about 27 g per 2000 kcal, 25 to 30 g a day.
import 'dart:math' as math;

typedef Food = ({String code, String name, List<String> tags, double kcal, double protein, double carb, double fat, double fiber});

Food foodFromRow(Map<String, dynamic> r) {
  double n(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  return (
    code: r['code'] as String,
    name: r['name'] as String,
    tags: ((r['tags'] as List?) ?? const []).cast<String>(),
    kcal: n(r['kcal']),
    protein: n(r['protein_g']),
    carb: n(r['carb_g']),
    fat: n(r['fat_g']),
    fiber: n(r['fiber_g']),
  );
}

/// Display name, cost tier (1 budget, 2 mid, 3 premium) and how it is weighed.
const _catalogue = <String, (String, int, String)>{
  'A011': ('Poha (rice flakes)', 1, 'dry'),
  'A010': ('Ragi flour', 1, 'dry'),
  'A019': ('Wheat atta (roti)', 1, 'dry'),
  'A015': ('Rice', 1, 'raw'),
  'A005': ('Jowar flour (bhakri)', 1, 'dry'),
  'A003': ('Bajra flour (roti)', 1, 'dry'),
  'B021': ('Toor dal', 1, 'dry'),
  'B010': ('Moong dal', 1, 'dry'),
  'B013': ('Masoor dal', 1, 'dry'),
  'B020': ('Rajma', 1, 'dry'),
  'B002': ('Kala chana', 1, 'dry'),
  'X001': ('Soya chunks', 1, 'dry'),
  'H012': ('Peanuts', 1, 'raw'),
  'L002': ('Cow milk', 1, 'ml'),
  'M004': ('Eggs, boiled', 1, 'egg'),
  'L003': ('Paneer', 2, 'raw'),
  'N003': ('Chicken breast', 2, 'raw'),
  'S006': ('Rohu fish', 2, 'raw'),
  'E012': ('Banana', 1, 'raw'),
  'E049': ('Papaya', 1, 'raw'),
  'E028': ('Guava', 1, 'raw'),
  'E001': ('Apple', 2, 'raw'),
  'E047': ('Orange', 2, 'raw'),
  'D036': ('Cauliflower', 1, 'raw'),
  'D056': ('Bhindi', 1, 'raw'),
  'C015': ('Cabbage', 1, 'raw'),
  'C033': ('Spinach (palak)', 1, 'raw'),
  'F002': ('Carrot', 1, 'raw'),
  'D043': ('Cucumber salad', 1, 'raw'),
  'D076': ('Tomato', 1, 'raw'),
  'T012': ('Sunflower oil', 1, 'oil'),
  'T006': ('Mustard oil', 1, 'oil'),
};

/// Most a single portion of a food should reach in one meal, so the solver never asks for a bowl of peanuts.
const _maxPortion = {'H012': 40.0, 'B002': 80.0, 'B021': 90.0, 'B010': 90.0, 'B013': 90.0, 'B020': 90.0, 'L003': 150.0, 'M004': 200.0, 'N003': 220.0, 'S006': 220.0};

/// Every food the planner may use, for one database read.
final plannerCodes = _catalogue.keys.toList();

enum _Scale { protein, energy, fixed }

/// [prefer]: rotate among the first n allowed codes when any of them fit the diet (lean proteins first).
/// [floor]: the smallest portion the planner may trim to when a day runs over its energy target.
/// [dense]: a top-up slot that takes the most protein-dense allowed food and starts empty.
typedef _Slot = ({List<String> codes, double base, double min, double max, double floor, double step, _Scale scale, int prefer, bool dense});

_Slot _s(List<String> codes, double base, double min, double max, _Scale scale, {double step = 5, int prefer = 99, double? floor, bool dense = false}) =>
    (codes: codes, base: base, min: min, max: max, floor: floor ?? min, step: step, scale: scale, prefer: prefer, dense: dense);

// Meal templates: (name, usual time, slots, share of the day's oil).
final _meals = <(String, String, List<_Slot>, double)>[
  ('Breakfast', '8 am', [
    _s(['A011', 'A010', 'A019'], 50, 30, 120, _Scale.energy, floor: 20),
    _s(['M004', 'L003', 'X001'], 100, 25, 200, _Scale.protein),
    _s(['L002'], 200, 200, 200, _Scale.fixed, step: 50, floor: 100),
    _s(['E012', 'E049', 'E028', 'E001'], 120, 120, 120, _Scale.fixed, floor: 60),
  ], 0.2),
  ('Lunch', '1 pm', [
    _s(['A015'], 60, 40, 150, _Scale.energy, floor: 20),
    _s(['A019', 'A005'], 40, 30, 120, _Scale.energy, floor: 20),
    _s(['B021', 'B010', 'B013', 'B020', 'B002'], 40, 30, 90, _Scale.protein),
    _s(['D036', 'D056', 'C015', 'F002', 'C033'], 150, 150, 150, _Scale.fixed),
    _s(['D043'], 100, 100, 100, _Scale.fixed),
  ], 0.4),
  ('Evening snack', '5 pm', [
    _s(['B002', 'H012'], 30, 20, 60, _Scale.protein),
    _s(['E028', 'E047', 'E012', 'E049'], 120, 120, 120, _Scale.fixed, floor: 60),
    _s(['L002'], 200, 200, 200, _Scale.fixed, step: 50, floor: 100), // a glass of milk or chaas for those who take dairy
    // Used only when the day is still short of protein: the densest food the person can eat, within its caps.
    _s(['M004', 'X001', 'L003', 'B013', 'B010', 'B021'], 0, 0, 100, _Scale.protein, floor: 0, dense: true),
  ], 0.0),
  ('Dinner', '8 pm', [
    _s(['A019', 'A005', 'A003'], 60, 30, 150, _Scale.energy, floor: 20),
    _s(['N003', 'S006', 'L003', 'M004', 'X001', 'B020', 'B013'], 100, 25, 220, _Scale.protein, prefer: 4),
    _s(['C033', 'D076', 'C015', 'D036', 'D056'], 150, 150, 150, _Scale.fixed),
  ], 0.4),
];

/// Budget tier from the protocol: low, medium, high, or the user's own rupee range. For a custom range the
/// tier follows its upper end (under ₹150 a day budget foods only, under ₹300 adds paneer, chicken, fish
/// and pricier fruit). These bands are a Levlofit rule of thumb, not a published price list.
int budgetTier(String? tier, int? maxInr) => switch (tier) {
      'low' => 1,
      'high' => 3,
      'custom' => maxInr == null ? 2 : (maxInr < 150 ? 1 : (maxInr < 300 ? 2 : 3)),
      _ => 2,
    };

/// ICMR-NIN 2024: about 27 g of oil per 2000 kcal, kept within 20 to 30 g a day.
double oilGrams(double kcal) => (27 * kcal / 2000).clamp(20.0, 30.0).roundToDouble();

/// Software acceptance checks for a planned day: energy within ±5% of the plan's target and at least 90% of its
/// protein. They decide whether the app may say a day meets the targets; they are not medical advice.
const kcalTolerance = 0.05;
const minProteinShare = 0.90;

typedef PlanItem = ({String code, String name, double grams, String unit, double kcal, double protein, double carb, double fat, double fiber});
typedef PlanMeal = ({String name, String time, List<PlanItem> items});

/// Whether the day meets the targets, and if not, why and what the person could change. Never a silent miss.
/// [proteinCeiling]: the most protein the planner's allowed foods can give within the energy limit (+5%), using
/// each slot's smallest and largest portions. Below 90% of the target, no arrangement of these foods can pass.
typedef DayCheck = ({bool feasible, double kcalDeviation, double proteinShare, double proteinCeiling, List<String> issues, List<String> options});
typedef DayPlan = ({List<PlanMeal> meals, double kcal, double protein, double carb, double fat, double fiber, DayCheck check});

PlanItem _item(Food f, double g) {
  final (label, _, unit) = _catalogue[f.code] ?? (f.name, 1, 'raw');
  final k = g / 100;
  return (code: f.code, name: label, grams: g, unit: unit, kcal: f.kcal * k, protein: f.protein * k, carb: f.carb * k, fat: f.fat * k, fiber: f.fiber * k);
}

typedef _Pick = (int, _Slot, Food); // meal index, slot, food

/// Builds one day. [day] (0 = Monday) rotates the foods so the week has variety.
/// [excluded] holds the plan's excluded food tags; [custom] free-text exclusions; [soyaCapG] the plan's soya limit.
/// [proteinPowder]: the plan's supplement advice includes protein powder, so the check may point to it.
/// Only foods that pass the diet, allergy, exclusion and budget filters are used, with their stored nutrition
/// values. When both targets cannot be met, the day is the closest one found and [DayPlan.check] says so.
DayPlan planDay({
  required Map<String, Food> foods,
  required double kcal,
  required double protein,
  required Set<String> excluded,
  List<String> custom = const [],
  int tier = 2,
  int day = 0,
  double soyaCapG = 50,
  bool proteinPowder = false,
}) {
  bool allowed(String code, int maxTier) {
    final f = foods[code];
    if (f == null) return false;
    final (label, cost, _) = _catalogue[code]!;
    if (cost > maxTier) return false;
    if (code == 'X001' && soyaCapG <= 0) return false;
    if (f.tags.any(excluded.contains)) return false;
    final text = '${f.name} $label'.toLowerCase();
    return !custom.any((c) => c.isNotEmpty && text.contains(c.toLowerCase()));
  }

  bool ok(String code) => allowed(code, tier);
  double density(Food f) => f.kcal <= 0 ? 0 : f.protein / f.kcal;

  DayCheck check(double k, double p, bool hasFood) {
    final dev = kcal > 0 ? (k - kcal) / kcal : 0.0;
    final share = protein > 0 ? p / protein : 1.0;
    return (feasible: hasFood && dev.abs() <= kcalTolerance && share >= minProteinShare, kcalDeviation: dev, proteinShare: share, proteinCeiling: 0.0, issues: const <String>[], options: const <String>[]);
  }

  // Two ways to fill the slots: the weekday rotation (variety first), and, for a day the rotation cannot make
  // work, the most protein-dense allowed food in each protein slot. The rotation is kept whenever it passes.
  List<_Pick> choose({required bool denseProtein}) {
    final picks = <_Pick>[];
    for (final (mi, (_, _, slots, _)) in _meals.indexed) {
      for (final (si, slot) in slots.indexed) {
        final all = slot.codes.where(ok).toList();
        if (all.isEmpty) continue; // a vegan breakfast has no milk
        if (slot.dense || (denseProtein && slot.scale == _Scale.protein)) {
          // Soya shares one daily limit, so a second soya slot would add almost nothing: take the next best.
          final soyaTaken = picks.any((p) => p.$3.code == 'X001');
          final pool = soyaTaken && all.length > 1 ? all.where((c) => c != 'X001').toList() : all;
          final best = pool.reduce((a, b) => density(foods[b]!) > density(foods[a]!) ? b : a);
          picks.add((mi, slot, foods[best]!));
          continue;
        }
        final preferred = slot.codes.take(slot.prefer).where(ok).toList();
        final pool = preferred.isEmpty ? all : preferred;
        picks.add((mi, slot, foods[pool[(day + si + mi) % pool.length]]!));
      }
    }
    return picks;
  }

  final oil = [foods['T012'], foods['T006']].whereType<Food>().where((f) => !f.tags.any(excluded.contains)).firstOrNull;
  final oilG = oil == null ? 0.0 : oilGrams(kcal);

  DayPlan build(List<_Pick> picks) {
    final grams = [for (final p in picks) p.$2.base];
    double soyaElsewhere(int i) => [for (final (j, p) in picks.indexed) if (j != i && p.$3.code == 'X001') grams[j]].fold(0.0, (s, g) => s + g);
    double maxFor(int i) {
      final code = picks[i].$3.code;
      final cap = code == 'X001' ? math.max(0.0, soyaCapG - soyaElsewhere(i)) : (_maxPortion[code] ?? double.infinity);
      return math.min(picks[i].$2.max, cap);
    }

    double totalKcal() => (oil == null ? 0.0 : oil.kcal * oilG / 100) + [for (final (i, p) in picks.indexed) p.$3.kcal * grams[i] / 100].fold(0.0, (s, v) => s + v);
    double totalProtein() => [for (final (i, p) in picks.indexed) p.$3.protein * grams[i] / 100].fold(0.0, (s, v) => s + v);

    // 1. Proportional rounds: protein foods close the protein gap, staples then close the energy gap.
    //    Soya is split evenly here; the greedy steps below may then use whatever the day's limit leaves.
    final soyaShare = soyaCapG / math.max(1, picks.where((p) => p.$3.code == 'X001').length);
    for (var round = 0; round < 8; round++) {
      final pIdx = [for (final (i, p) in picks.indexed) if (p.$2.scale == _Scale.protein && !p.$2.dense) i];
      final fromP = pIdx.fold(0.0, (s, i) => s + picks[i].$3.protein * grams[i] / 100);
      if (fromP > 0) {
        final f = (1 + (protein - totalProtein()) / fromP).clamp(0.5, 2.0);
        for (final i in pIdx) {
          final hi = picks[i].$3.code == 'X001' ? math.min(picks[i].$2.max, soyaShare) : maxFor(i);
          grams[i] = (grams[i] * f).clamp(math.min(picks[i].$2.min, hi), hi);
        }
      }
      final eIdx = [for (final (i, p) in picks.indexed) if (p.$2.scale == _Scale.energy) i];
      final fromE = eIdx.fold(0.0, (s, i) => s + picks[i].$3.kcal * grams[i] / 100);
      if (fromE > 0) {
        final f = (1 + (kcal - totalKcal()) / fromE).clamp(0.5, 2.0);
        for (final i in eIdx) {
          grams[i] = (grams[i] * f).clamp(picks[i].$2.min, picks[i].$2.max);
        }
      }
    }

    // 2. Greedy trade-offs in small steps, aiming inside the acceptance band so rounding cannot push a day out:
    //    raise protein with the densest foods, pay for it by trimming less protein-dense portions, then settle
    //    energy. Every portion stays between its slot's floor and cap, and soya within the day's limit.
    final kLo = kcal * (1 - 0.03), kHi = kcal * (1 + 0.03), pMin = protein * 0.93;
    int? pickBy(bool Function(int) can, double Function(int) key, {bool lowest = false}) {
      int? best;
      for (var i = 0; i < picks.length; i++) {
        if (!can(i)) continue;
        if (best == null || (lowest ? key(i) < key(best) : key(i) > key(best))) best = i;
      }
      return best;
    }

    double stepOf(int i) => picks[i].$2.step;
    bool canTrim(int i) => grams[i] - stepOf(i) >= picks[i].$2.floor - 1e-9;
    double d(int i) => density(picks[i].$3);
    var moves = 3000; // hard bound: the loops always end
    for (var pass = 0; pass < 4 && moves > 0; pass++) {
      while (totalProtein() < pMin && moves-- > 0) {
        final up = pickBy((i) => picks[i].$2.scale == _Scale.protein && grams[i] + 5 <= maxFor(i) + 1e-9, d);
        if (up == null) break;
        grams[up] += 5;
        // Pay for the extra energy with less protein-dense food, never with an equally dense one.
        while (totalKcal() > kHi && moves-- > 0) {
          final down = pickBy((i) => i != up && canTrim(i) && d(i) < d(up), d, lowest: true);
          if (down == null) break;
          grams[down] -= stepOf(down);
        }
        if (totalKcal() > kHi) {
          grams[up] -= 5; // no room left to pay for more protein
          break;
        }
      }
      while (totalKcal() > kHi && moves-- > 0) {
        // Trim the least protein-dense portion whose removal keeps protein on target; failing that, the least
        // dense portion of all. Energy is the plan's first number: a protein shortfall is reported, not hidden.
        final keep = pickBy((i) => canTrim(i) && totalProtein() - picks[i].$3.protein * stepOf(i) / 100 >= pMin, d, lowest: true);
        final down = keep ?? pickBy(canTrim, d, lowest: true);
        if (down == null) break;
        grams[down] -= stepOf(down);
      }
      while (totalKcal() < kLo && moves-- > 0) {
        final up = pickBy((i) => picks[i].$2.scale == _Scale.energy && grams[i] + 5 <= picks[i].$2.max, (i) => -i.toDouble()) ??
            pickBy((i) => picks[i].$2.scale == _Scale.fixed && grams[i] + stepOf(i) <= picks[i].$2.base, (i) => -i.toDouble()) ??
            pickBy((i) => picks[i].$2.scale == _Scale.protein && !picks[i].$2.dense && grams[i] + 5 <= maxFor(i), d);
        if (up == null) break;
        grams[up] += picks[up].$2.scale == _Scale.fixed ? stepOf(up) : 5;
      }
    }

    // 3. Portions in kitchen steps (soya rounded down so the day limit holds), then totals from what is shown.
    final meals = <PlanMeal>[];
    for (final (mi, (name, time, _, oilShare)) in _meals.indexed) {
      final items = <PlanItem>[
        for (final (i, p) in picks.indexed)
          if (p.$1 == mi && grams[i] >= p.$2.step / 2)
            _item(p.$3, p.$3.code == 'X001' ? (grams[i] / 5).floor() * 5.0 : math.max(p.$2.step, (grams[i] / p.$2.step).round() * p.$2.step)),
        if (oil != null && oilShare > 0) _item(oil, (oilG * oilShare).roundToDouble()),
      ]..removeWhere((it) => it.grams <= 0);
      if (items.isNotEmpty) meals.add((name: name, time: time, items: items));
    }
    double sum(double Function(PlanItem) f) => meals.fold(0.0, (s, m) => s + m.items.fold(0.0, (a, it) => a + f(it)));
    final k = sum((i) => i.kcal), pr = sum((i) => i.protein);
    return (meals: meals, kcal: k, protein: pr, carb: sum((i) => i.carb), fat: sum((i) => i.fat), fiber: sum((i) => i.fiber), check: check(k, pr, picks.isNotEmpty));
  }

  // Exact upper bound for one set of picks: start every portion at its floor, then spend the energy allowance on
  // the most protein-dense foods first, each up to its cap (a fractional knapsack, which is optimal here).
  double proteinCeiling(List<_Pick> picks) {
    final budget = kcal * (1 + kcalTolerance) - (oil == null ? 0.0 : oil.kcal * oilG / 100);
    final g = [for (final p in picks) p.$2.scale == _Scale.fixed ? p.$2.floor : math.min(p.$2.floor, p.$2.min)];
    double used() => [for (final (i, p) in picks.indexed) p.$3.kcal * g[i] / 100].fold(0.0, (s, v) => s + v);
    final order = [for (var i = 0; i < picks.length; i++) i]..sort((a, b) => density(picks[b].$3).compareTo(density(picks[a].$3)));
    var soya = [for (final (i, p) in picks.indexed) if (p.$3.code == 'X001') g[i]].fold(0.0, (s, v) => s + v);
    for (final i in order) {
      final p = picks[i];
      if (p.$3.kcal <= 0) continue;
      var cap = math.min(p.$2.max, _maxPortion[p.$3.code] ?? double.infinity);
      if (p.$2.scale == _Scale.fixed) cap = p.$2.base;
      if (p.$3.code == 'X001') cap = math.min(cap, g[i] + math.max(0.0, soyaCapG - soya));
      final room = (budget - used()) * 100 / p.$3.kcal;
      if (room <= 0) break;
      final add = math.max(0.0, math.min(cap - g[i], room));
      g[i] += add;
      if (p.$3.code == 'X001') soya += add;
    }
    return [for (final (i, p) in picks.indexed) p.$3.protein * g[i] / 100].fold(0.0, (s, v) => s + v);
  }

  // The rotation first. Only if it misses is the protein-dense variant tried; the closer of the two is kept.
  final rotation = build(choose(denseProtein: false));
  if (rotation.check.feasible) return rotation;
  final dense = build(choose(denseProtein: true));
  if (dense.check.feasible) return dense;
  double miss(DayPlan p) => math.max(p.check.kcalDeviation.abs() / kcalTolerance, (minProteinShare - p.check.proteinShare) / (1 - minProteinShare));
  final best = miss(dense) < miss(rotation) ? dense : rotation;

  // Explain the miss and offer only changes that respect the person's settings.
  final c = best.check;
  final ceiling = math.max(proteinCeiling(choose(denseProtein: true)), proteinCeiling(choose(denseProtein: false)));
  final issues = <String>[
    if (best.meals.isEmpty) 'None of the planner\'s foods fit your diet, allergies, exclusions and budget together.',
    if (c.proteinShare < minProteinShare)
      'Protein: this day reaches ${best.protein.round()} g of your ${protein.round()} g target (${(c.proteinShare * 100).round()}%). Within your energy target, these foods can give at most about ${ceiling.round()} g.',
    if (c.kcalDeviation > kcalTolerance)
      'Energy: ${best.kcal.round()} kcal, ${(c.kcalDeviation * 100).round()}% above your ${kcal.round()} kcal target, with portions already at their smallest sensible sizes.',
    if (c.kcalDeviation < -kcalTolerance)
      'Energy: ${best.kcal.round()} kcal, ${(-c.kcalDeviation * 100).round()}% below your ${kcal.round()} kcal target, with portions already at their largest sensible sizes.',
    'With your diet type, allergies, exclusions and budget, the foods Levlofit plans cannot meet both targets on this day.',
  ];
  final upgrade = tier >= 3 ? const <String>[] : [for (final code in _catalogue.keys) if (!ok(code) && allowed(code, 3) && density(foods[code]!) >= 0.08) _catalogue[code]!.$1];
  final options = <String>[
    if (c.proteinShare < minProteinShare && proteinPowder) 'The protein powder in your plan\'s supplement advice can cover the remaining ${(protein - best.protein).round()} g.',
    if (upgrade.isNotEmpty) 'A higher food budget in your protocol would add ${upgrade.join(', ')}.',
    'Your targets are general estimates from your profile, not medical advice. A registered dietitian can set targets that fit you.',
  ];
  return (
    meals: best.meals,
    kcal: best.kcal,
    protein: best.protein,
    carb: best.carb,
    fat: best.fat,
    fiber: best.fiber,
    check: (feasible: false, kcalDeviation: c.kcalDeviation, proteinShare: c.proteinShare, proteinCeiling: ceiling, issues: issues, options: options),
  );
}

/// How to measure an amount in the kitchen.
String amountLabel(PlanItem i) => switch (i.unit) {
      'ml' => '${i.grams.round()} ml',
      'egg' => '${(i.grams / 50).round()} ${(i.grams / 50).round() == 1 ? 'egg' : 'eggs'} (${i.grams.round()} g)',
      'oil' => '${i.grams.round()} g (about ${(i.grams / 5).round()} tsp)',
      'dry' => '${i.grams.round()} g dry',
      _ => '${i.grams.round()} g',
    };

/// The food library: only the everyday foods worth knowing for protein, fibre, good carbs and healthy fats.
/// (IFCT code, display name, group). Soya chunks values: USDA FoodData Central 174275 (defatted soy flour).
const libraryFoods = <(String, String, String)>[
  ('X001', 'Soya chunks', 'Protein'),
  ('N003', 'Chicken breast', 'Protein'),
  ('N001', 'Chicken leg', 'Protein'),
  ('M004', 'Egg, boiled', 'Protein'),
  ('M005', 'Egg white, boiled', 'Protein'),
  ('L003', 'Paneer', 'Protein'),
  ('L002', 'Cow milk', 'Protein'),
  ('S006', 'Rohu fish', 'Protein'),
  ('P084', 'Tuna', 'Protein'),
  ('P034', 'Mackerel (bangda)', 'Protein'),
  ('S008', 'Prawns', 'Protein'),
  ('O003', 'Mutton (goat leg)', 'Protein'),
  ('B013', 'Masoor dal', 'Protein'),
  ('B010', 'Moong dal', 'Protein'),
  ('B021', 'Toor dal', 'Protein'),
  ('B001', 'Chana dal', 'Protein'),
  ('B003', 'Urad dal', 'Protein'),
  ('B002', 'Kala chana', 'Fibre'),
  ('B020', 'Rajma', 'Fibre'),
  ('B011', 'Whole moong (sprouts)', 'Fibre'),
  ('B005', 'Lobia', 'Fibre'),
  ('B017', 'Dry peas (matar)', 'Fibre'),
  ('D061', 'Green peas', 'Fibre'),
  ('C033', 'Spinach (palak)', 'Fibre'),
  ('D036', 'Cauliflower', 'Fibre'),
  ('D056', 'Bhindi', 'Fibre'),
  ('C015', 'Cabbage', 'Fibre'),
  ('F002', 'Carrot', 'Fibre'),
  ('J001', 'Mushroom', 'Fibre'),
  ('E028', 'Guava', 'Fibre'),
  ('E051', 'Pear', 'Fibre'),
  ('E001', 'Apple', 'Fibre'),
  ('E049', 'Papaya', 'Fibre'),
  ('A019', 'Wheat atta (roti)', 'Carbs'),
  ('A015', 'White rice', 'Carbs'),
  ('A013', 'Brown rice', 'Carbs'),
  ('A010', 'Ragi', 'Carbs'),
  ('A005', 'Jowar', 'Carbs'),
  ('A003', 'Bajra', 'Carbs'),
  ('A011', 'Poha', 'Carbs'),
  ('A021', 'Dalia (broken wheat)', 'Carbs'),
  ('A004', 'Barley', 'Carbs'),
  ('A009', 'Quinoa', 'Carbs'),
  ('F013', 'Sweet potato', 'Carbs'),
  ('E012', 'Banana', 'Carbs'),
  ('E047', 'Orange', 'Carbs'),
  ('H001', 'Almonds', 'Fats'),
  ('H021', 'Walnuts', 'Fats'),
  ('H012', 'Peanuts', 'Fats'),
  ('H014', 'Flaxseeds (alsi)', 'Fats'),
  ('H011', 'Sesame (til)', 'Fats'),
  ('H020', 'Sunflower seeds', 'Fats'),
  ('H018', 'Pistachios', 'Fats'),
  ('T006', 'Mustard oil', 'Fats'),
  ('T005', 'Groundnut oil', 'Fats'),
  ('T013', 'Ghee', 'Fats'),
];

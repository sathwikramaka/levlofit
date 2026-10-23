// A day of Indian meals with grams for every food, built by rules over IFCT 2017 (Indian Food Composition
// Tables) values: breakfast, lunch, snack and dinner templates, foods filtered by diet, allergies and budget,
// rotated by weekday, then portions solved so the day lands on the plan's energy and protein.
// Cooking oil: ICMR-NIN Dietary Guidelines for Indians (2024) limit visible fat to 20-50 g a day depending on energy
// and activity, not more than 27-30 g at 2000 kcal (p.72); its "My Plate" lists 27 g fats and oils at 2000 kcal (p.24).
// Scaling 27 g per 2000 kcal and keeping it within 20 to 30 g a day are Levlofit's own rules within that range.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

/// [fatKnown] is false when the food table has no usable fat value: [fat] then reads 0 for the planner's sums,
/// but no fat percentage is ever shown for a day that includes the food.
typedef Food = ({String code, String name, List<String> tags, double kcal, double protein, double carb, double fat, double fiber, bool fatKnown});

Food foodFromRow(Map<String, dynamic> r) {
  double? parse(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
  double n(Object? v) => parse(v) ?? 0;
  return (
    code: r['code'] as String,
    name: r['name'] as String,
    tags: ((r['tags'] as List?) ?? const []).cast<String>(),
    kcal: n(r['kcal']),
    protein: n(r['protein_g']),
    carb: n(r['carb_g']),
    fat: n(r['fat_g']),
    fiber: n(r['fiber_g']),
    fatKnown: parse(r['fat_g']) != null,
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

/// ICMR-NIN 2024: 27 g fats and oils at 2000 kcal ("My Plate", p.24); visible fat 20-50 g a day by energy and
/// activity (p.72). Scaling with energy and the 20 to 30 g a day range are Levlofit's own rules within that.
double oilGrams(double kcal) => (27 * kcal / 2000).clamp(20.0, 30.0).roundToDouble();

/// Software acceptance checks for a planned day: energy within ±5% of the plan's target and at least 90% of its
/// protein. They decide whether the app may say a day meets the targets; they are not medical advice.
const kcalTolerance = 0.05;
const minProteinShare = 0.90;

/// Total fat at or under 30% of energy for adults: WHO guideline on total fat intake (2023) and ICMR-NIN Dietary
/// Guidelines for Indians (2024). Used only for a guidance message; it never changes the plan or its pass flag.
const maxFatEnergyShare = 0.30;

/// The guidance shown for a day's fat, separate from the energy and protein checks. [share] is the share of energy
/// from fat (9 kcal per g over the day's energy), or null when it cannot be shown; [unknown] names the planned
/// foods whose fat value is missing, in which case no percentage is given.
List<String> fatGuidance(double? share, List<String> unknown) => [
      if (unknown.isNotEmpty)
        'Fat: not shown for this day, because the fat value is missing for ${unknown.join(', ')}.'
      else if (share != null && share > maxFatEnergyShare)
        'Fat: ${fatShareText(share)} of this day\'s energy comes from fat, above the 30% or less that WHO (2023) and '
            'ICMR-NIN (2024) advise for adults. This is general guidance, not a diagnosis.',
    ];

/// A fat share for display, to one decimal ("about 30.5%"). A share above the 30% limit that would still read
/// "30.0%" at that precision is shown as "just over 30%", so a value over the limit never reads as within it.
String fatShareText(double share) {
  final tenths = (share * 1000).round() / 10;
  if (share > maxFatEnergyShare && tenths <= maxFatEnergyShare * 100) return 'just over ${(maxFatEnergyShare * 100).round()}%';
  return 'about ${tenths.toStringAsFixed(1)}%';
}

typedef PlanItem = ({String code, String name, double grams, String unit, double kcal, double protein, double carb, double fat, double fiber});
typedef PlanMeal = ({String name, String time, List<PlanItem> items});

/// Whether the day meets the targets, and if not, why and what the person could change. Never a silent miss.
/// [proteinCeiling]: when computed, the most protein any day the planner can show reaches within the energy limit
/// (+5%): one allowed food per template slot, portions in the planner's kitchen steps between each slot's floor and
/// cap, the soya limit and the budget tier (see [templateProteinCeiling]). It is a limit of Levlofit's planning
/// rules and food list, not a nutritional maximum. Null when the day passed without needing the search.
/// [hitStepLimit]: the portion adjustment stopped at its step limit, so no claim about smallest or largest portions
/// is made from it.
/// [fatEnergyShare]: share of the day's energy from fat (0 to 1), or null when a planned food's fat is unknown.
/// [guidance]: messages that inform without affecting [feasible] (see [fatGuidance]).
typedef DayCheck = ({
  bool feasible,
  double kcalDeviation,
  double proteinShare,
  double? proteinCeiling,
  bool hitStepLimit,
  List<String> issues,
  List<String> options,
  double? fatEnergyShare,
  List<String> guidance,
});
typedef DayPlan = ({List<PlanMeal> meals, double kcal, double protein, double carb, double fat, double fiber, DayCheck check});

PlanItem _item(Food f, double g) {
  final (label, _, unit) = _catalogue[f.code] ?? (f.name, 1, 'raw');
  final k = g / 100;
  return (code: f.code, name: label, grams: g, unit: unit, kcal: f.kcal * k, protein: f.protein * k, carb: f.carb * k, fat: f.fat * k, fiber: f.fiber * k);
}

typedef _Pick = (int, _Slot, Food); // meal index, slot, food

/// One whole boiled egg is counted as 50 g (a Levlofit kitchen convention), so egg portions move in whole eggs.
double _stepFor(String code, _Slot s) => code == 'M004' ? 50 : s.step;

/// Largest portion of [code] in slot [s]: fixed slots stop at their usual amount, others at the slot or food cap.
double _capFor(String code, _Slot s) => s.scale == _Scale.fixed ? s.base : math.min(s.max, _maxPortion[code] ?? double.infinity);

/// Whether a food may be planned: present in the food table, within budget, not excluded by a tag or by the
/// person's own exclusion words (matched against the IFCT name and the planner's label), and soya allowed.
bool _allowed(Map<String, Food> foods, String code, {required int tier, required Set<String> excluded, required List<String> custom, required double soyaCapG}) {
  final f = foods[code];
  final entry = _catalogue[code];
  if (f == null || entry == null) return false;
  if (entry.$2 > tier) return false;
  if (code == 'X001' && soyaCapG <= 0) return false;
  if (f.tags.any(excluded.contains)) return false;
  final text = '${f.name} ${entry.$1}'.toLowerCase();
  return !custom.any((c) => c.trim().isNotEmpty && text.contains(c.trim().toLowerCase()));
}

/// The cooking oil: the first of sunflower or mustard oil the person has not excluded by tag or by their own
/// exclusion words. No oil at all when both are excluded; an excluded oil is never used as a stand-in.
Food? _oilFor(Map<String, Food> foods, Set<String> excluded, List<String> custom) =>
    ['T012', 'T006'].where((c) => _allowed(foods, c, tier: 3, excluded: excluded, custom: custom, soyaCapG: 0)).map((c) => foods[c]!).firstOrNull;

/// Oil grams as shown per meal (rounded per meal), summed over the day.
double _oilShown(double oilG) => _meals.fold(0.0, (s, m) => s + (m.$4 > 0 ? (oilG * m.$4).roundToDouble() : 0.0));

typedef _Layer = ({int meal, _Slot slot, List<(Food, double)> options});

/// Every portion the planner can show, slot by slot: each allowed food from the slot's floor to its cap in that
/// food's kitchen steps (soya never above the day's limit). Slots with no allowed food drop out, as in planDay.
List<_Layer> _layers(Map<String, Food> foods, bool Function(String) ok, double soyaCapG) => [
      for (final (mi, (_, _, slots, _)) in _meals.indexed)
        for (final slot in slots)
          if (slot.codes.any(ok))
            (
              meal: mi,
              slot: slot,
              options: [
                for (final code in slot.codes.where(ok))
                  // Soya starts at one step: when the day limit is split between slots, a shown portion can sit
                  // below the slot floor, and every portion the planner can show must be in the search.
                  for (var g = slot.floor <= 0 ? 0.0 : (code == 'X001' ? 5.0 : (slot.floor / _stepFor(code, slot)).ceil() * _stepFor(code, slot));
                      g <= _capFor(code, slot) + 1e-9 && (code != 'X001' || g <= soyaCapG + 1e-9);
                      g += _stepFor(code, slot))
                    (foods[code]!, g),
              ],
            ),
    ];

typedef _Grid = ({double ceiling, List<_Pick> picks, List<double> grams, bool found});

/// Which kind of food a slot holds, for varying searched days: the top-up, a meal's main protein, the snack,
/// the lunch dal, a staple, fruit, or vegetables (milk and salad have a single food, so they never vary).
String _group(_Slot s) => s.dense
    ? 'topup'
    : switch (s.scale) {
        _Scale.energy => 'staples',
        _Scale.protein => s.codes.contains('H012') ? 'snack' : (s.codes.first == 'B021' ? 'dal' : 'main'),
        _Scale.fixed => s.codes.first.startsWith('E') ? 'fruit' : 'veg',
      };

/// The order in which a searched day gives up the weekday's own food, one slot at a time, to stay within the
/// checks: least valued variety first (main protein, then vegetables, fruit, staples, snack; later meals before
/// earlier ones within a kind), so the dal rotates longest, then the snack, staples, fruit and vegetables.
const _releaseOrder = ['main', 'veg', 'fruit', 'staples', 'snack', 'dal'];

/// Exhaustive search over every day the planner can show (dynamic programming over energy and soya): the most
/// protein for each energy total, with each food's energy rounded down so the result is an upper bound for real
/// days. Returns that ceiling and, for choosing a plan, the day whose energy is closest to [targetFoodKcal] among
/// those that reach [wantProtein] (or the most protein when none do). Protein per state is exact; energy per state
/// is rounded down by under 1 kcal per slot, so a day is preferred only when its energy stays inside
/// [lowFoodKcal, budget] even after that rounding. Deterministic: ties keep the first option.
_Grid _gridSearch(List<_Layer> layers,
    {required double budgetKcal, required double soyaCapG, required double targetFoodKcal, required double wantProtein, double lowFoodKcal = 0}) {
  final b = budgetKcal.floor();
  if (b < 0 || layers.isEmpty) return (ceiling: 0, picks: const [], grams: const [], found: false);
  final ns = soyaCapG > 0 ? (soyaCapG / 5).floor() + 1 : 1;
  final size = (b + 1) * ns;
  var val = Float64List(size)..fillRange(0, size, double.negativeInfinity);
  val[0] = 0;
  final choice = <Int32List>[], prev = <Int32List>[];
  for (final layer in layers) {
    final next = Float64List(size)..fillRange(0, size, double.negativeInfinity);
    final ch = Int32List(size), pv = Int32List(size);
    final ok = [for (final (f, g) in layer.options) (f.kcal * g / 100).floor()];
    final op = [for (final (f, g) in layer.options) f.protein * g / 100];
    final os = [for (final (f, g) in layer.options) f.code == 'X001' ? (g / 5).round() : 0];
    for (var k = 0; k <= b; k++) {
      for (var s = 0; s < ns; s++) {
        final v = val[k * ns + s];
        if (v == double.negativeInfinity) continue;
        for (var o = 0; o < ok.length; o++) {
          final kk = k + ok[o], ss = s + os[o];
          if (kk > b || ss >= ns) continue;
          final at = kk * ns + ss, p = v + op[o];
          if (p > next[at]) {
            next[at] = p;
            ch[at] = o;
            pv[at] = k * ns + s;
          }
        }
      }
    }
    val = next;
    choice.add(ch);
    prev.add(pv);
  }
  var ceiling = double.negativeInfinity, best = -1, bestScore = double.infinity;
  final n = layers.length; // the real energy of a state lies in [k, k + n)
  for (var at = 0; at < size; at++) {
    final v = val[at];
    if (v == double.negativeInfinity) continue;
    if (v > ceiling) ceiling = v;
    // Prefer, in order: protein reached with energy safely inside the band; protein reached; neither. Within a
    // group, energy closest to the target, then more protein.
    final k = at ~/ ns;
    final reach = v >= wantProtein;
    final safe = k >= lowFoodKcal && k + n <= b;
    final group = reach && safe ? 0 : (reach ? 1 : 2);
    final score = group * 1e9 + (k - (targetFoodKcal - n / 2)).abs() * 1000 - v;
    if (score < bestScore) {
      bestScore = score;
      best = at;
    }
  }
  if (best < 0) return (ceiling: 0, picks: const [], grams: const [], found: false);
  final picks = <_Pick>[], grams = <double>[];
  var at = best;
  for (var li = layers.length - 1; li >= 0; li--) {
    final (food, g) = layers[li].options[choice[li][at]];
    picks.add((layers[li].meal, layers[li].slot, food));
    grams.add(g);
    at = prev[li][at];
  }
  return (ceiling: ceiling, picks: picks.reversed.toList(), grams: grams.reversed.toList(), found: true);
}

/// The most protein (g) any day the planner can show reaches within the energy limit (target +5%), for these foods
/// and settings: one allowed food per template slot, portions in kitchen steps between each slot's floor and cap,
/// the soya limit and the budget tier, plus the day's oil. A limit of Levlofit's food list and planning rules,
/// not a nutritional maximum: other foods or meal patterns could give more.
double templateProteinCeiling({
  required Map<String, Food> foods,
  required double kcal,
  required Set<String> excluded,
  List<String> custom = const [],
  int tier = 2,
  double soyaCapG = 50,
}) {
  bool ok(String c) => _allowed(foods, c, tier: tier, excluded: excluded, custom: custom, soyaCapG: soyaCapG);
  final oil = _oilFor(foods, excluded, custom);
  final oilKcal = oil == null ? 0.0 : oil.kcal * _oilShown(oilGrams(kcal)) / 100;
  final layers = _layers(foods, ok, soyaCapG);
  return _gridSearch(layers, budgetKcal: kcal * (1 + kcalTolerance) - oilKcal, soyaCapG: soyaCapG, targetFoodKcal: kcal - oilKcal, wantProtein: double.infinity).ceiling;
}

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
  bool allowed(String code, int maxTier) => _allowed(foods, code, tier: maxTier, excluded: excluded, custom: custom, soyaCapG: soyaCapG);
  bool ok(String code) => allowed(code, tier);
  double density(Food f) => f.kcal <= 0 ? 0 : f.protein / f.kcal;

  DayCheck check(double k, double p, bool hasFood, {double? ceiling, bool hitStepLimit = false, double? fatShare, List<String> fatUnknown = const []}) {
    final dev = kcal > 0 ? (k - kcal) / kcal : 0.0;
    final share = protein > 0 ? p / protein : 1.0;
    return (
      feasible: hasFood && dev.abs() <= kcalTolerance && share >= minProteinShare,
      kcalDeviation: dev,
      proteinShare: share,
      proteinCeiling: ceiling,
      hitStepLimit: hitStepLimit,
      issues: const <String>[],
      options: const <String>[],
      fatEnergyShare: fatShare,
      guidance: hasFood ? fatGuidance(fatShare, fatUnknown) : const <String>[],
    );
  }

  // Two quick ways to fill the slots: the weekday rotation (variety first), and the most protein-dense allowed
  // food in each protein slot. If neither passes, an exhaustive search over the templates takes over below.
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

  final oil = _oilFor(foods, excluded, custom);
  final oilG = oil == null ? 0.0 : oilGrams(kcal);
  final oilKcal = oil == null ? 0.0 : oil.kcal * _oilShown(oilG) / 100;

  // Portions in kitchen steps (soya rounded down so the day limit holds, eggs in whole eggs), totals from what is shown.
  DayPlan assemble(List<_Pick> picks, List<double> grams, {double? ceiling, bool hitStepLimit = false}) {
    final meals = <PlanMeal>[];
    for (final (mi, (name, time, _, oilShare)) in _meals.indexed) {
      final items = <PlanItem>[
        for (final (i, p) in picks.indexed)
          if (p.$1 == mi && grams[i] >= _stepFor(p.$3.code, p.$2) / 2)
            _item(
              p.$3,
              p.$3.code == 'X001'
                  ? (grams[i] / 5).floor() * 5.0
                  : math.max(_stepFor(p.$3.code, p.$2), (grams[i] / _stepFor(p.$3.code, p.$2)).round() * _stepFor(p.$3.code, p.$2)),
            ),
        if (oil != null && oilShare > 0) _item(oil, (oilG * oilShare).roundToDouble()),
      ]..removeWhere((it) => it.grams <= 0);
      if (items.isNotEmpty) meals.add((name: name, time: time, items: items));
    }
    double sum(double Function(PlanItem) f) => meals.fold(0.0, (s, m) => s + m.items.fold(0.0, (a, it) => a + f(it)));
    final k = sum((i) => i.kcal), pr = sum((i) => i.protein), fat = sum((i) => i.fat);
    // Fat is shown only when every food on the day has a known fat value; a missing value never counts as zero.
    final unknown = <String>{for (final m in meals) for (final it in m.items) if (!(foods[it.code]?.fatKnown ?? true)) it.name}.toList();
    return (
      meals: meals,
      kcal: k,
      protein: pr,
      carb: sum((i) => i.carb),
      fat: fat,
      fiber: sum((i) => i.fiber),
      check: check(k, pr, picks.isNotEmpty,
          ceiling: ceiling, hitStepLimit: hitStepLimit, fatShare: unknown.isEmpty && k > 0 ? 9 * fat / k : null, fatUnknown: unknown),
    );
  }

  DayPlan build(List<_Pick> picks) {
    final grams = [for (final p in picks) p.$2.base];
    double soyaElsewhere(int i) => [for (final (j, p) in picks.indexed) if (j != i && p.$3.code == 'X001') grams[j]].fold(0.0, (s, g) => s + g);
    double maxFor(int i) {
      final code = picks[i].$3.code;
      final cap = code == 'X001' ? math.max(0.0, soyaCapG - soyaElsewhere(i)) : (_maxPortion[code] ?? double.infinity);
      return math.min(picks[i].$2.max, cap);
    }

    double totalKcal() => oilKcal + [for (final (i, p) in picks.indexed) p.$3.kcal * grams[i] / 100].fold(0.0, (s, v) => s + v);
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

    // 2. Greedy trade-offs in kitchen steps, aiming inside the acceptance band so rounding cannot push a day out:
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

    double stepOf(int i) => _stepFor(picks[i].$3.code, picks[i].$2);
    bool canTrim(int i) => grams[i] - stepOf(i) >= picks[i].$2.floor - 1e-9;
    double d(int i) => density(picks[i].$3);
    var moves = 3000; // hard bound: the loops always end; reaching it is reported in the check
    for (var pass = 0; pass < 4 && moves > 0; pass++) {
      while (totalProtein() < pMin && moves-- > 0) {
        final up = pickBy((i) => picks[i].$2.scale == _Scale.protein && grams[i] + stepOf(i) <= maxFor(i) + 1e-9, d);
        if (up == null) break;
        grams[up] += stepOf(up);
        // Pay for the extra energy with less protein-dense food, never with an equally dense one.
        while (totalKcal() > kHi && moves-- > 0) {
          final down = pickBy((i) => i != up && canTrim(i) && d(i) < d(up), d, lowest: true);
          if (down == null) break;
          grams[down] -= stepOf(down);
        }
        if (totalKcal() > kHi) {
          grams[up] -= stepOf(up); // no room left to pay for more protein
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
        final up = pickBy((i) => picks[i].$2.scale == _Scale.energy && grams[i] + stepOf(i) <= picks[i].$2.max, (i) => -i.toDouble()) ??
            pickBy((i) => picks[i].$2.scale == _Scale.fixed && grams[i] + stepOf(i) <= picks[i].$2.base, (i) => -i.toDouble()) ??
            pickBy((i) => picks[i].$2.scale == _Scale.protein && !picks[i].$2.dense && grams[i] + stepOf(i) <= maxFor(i), d);
        if (up == null) break;
        grams[up] += stepOf(up);
      }
    }
    return assemble(picks, grams, hitStepLimit: moves <= 0);
  }

  // The rotation first, then the protein-dense variant: both keep the planner's usual portions and variety.
  final rotation = build(choose(denseProtein: false));
  if (rotation.check.feasible) return rotation;
  final dense = build(choose(denseProtein: true));
  if (dense.check.feasible) return dense;

  // Neither passed: search every day the planner can show. Its best day is used when it passes; its protein
  // ceiling makes any impossibility statement exact for the planner's rules.
  final layers = _layers(foods, ok, soyaCapG);
  final grid = _gridSearch(layers,
      budgetKcal: kcal * (1 + kcalTolerance) - oilKcal,
      soyaCapG: soyaCapG,
      targetFoodKcal: kcal - oilKcal,
      lowFoodKcal: kcal * (1 - kcalTolerance) - oilKcal,
      wantProtein: protein * minProteinShare + 1e-6);
  // Null when no template day fits within the energy limit at all: then there is no protein figure to give.
  final ceiling = grid.found ? grid.ceiling : null;
  final searched = grid.found ? assemble(grid.picks, grid.grams, ceiling: ceiling) : null;
  if (searched != null && searched.check.feasible) {
    // A passing day exists. Vary the week: keep this weekday's rotation food in every slot, freeing slots one
    // at a time (least valued variety first) only while no passing day keeps them. The first passing day
    // wins; the fully free search above is the last resort. The top-up slot is always free.
    String? weekdayFood(_Layer l) {
      final si = _meals[l.meal].$3.indexOf(l.slot);
      final all = l.slot.codes.where(ok).toList();
      if (all.isEmpty) return null;
      final preferred = l.slot.codes.take(l.slot.prefer).where(ok).toList();
      final pool = preferred.isEmpty ? all : preferred;
      return pool[(day + si + l.meal) % pool.length];
    }

    // Slots that can vary, in release order; the top-up and single-food slots are never restricted.
    final varying = [
      for (var i = 0; i < layers.length; i++)
        if (_group(layers[i].slot) != 'topup' && layers[i].options.map((o) => o.$1.code).toSet().length > 1) i,
    ]..sort((a, b) {
        final byKind = _releaseOrder.indexOf(_group(layers[a].slot)).compareTo(_releaseOrder.indexOf(_group(layers[b].slot)));
        return byKind != 0 ? byKind : layers[b].meal.compareTo(layers[a].meal);
      });
    for (var free = 0; free < varying.length; free++) {
      final freed = varying.take(free).toSet();
      final restricted = [
        for (final (i, l) in layers.indexed)
          if (!varying.contains(i) || freed.contains(i))
            l
          else
            (meal: l.meal, slot: l.slot, options: l.options.where((o) => o.$1.code == weekdayFood(l)).toList()),
      ];
      if (restricted.any((l) => l.options.isEmpty)) continue;
      final g = _gridSearch(restricted,
          budgetKcal: kcal * (1 + kcalTolerance) - oilKcal,
          soyaCapG: soyaCapG,
          targetFoodKcal: kcal - oilKcal,
          lowFoodKcal: kcal * (1 - kcalTolerance) - oilKcal,
          wantProtein: protein * minProteinShare + 1e-6);
      if (!g.found) continue;
      final varied = assemble(g.picks, g.grams, ceiling: ceiling);
      if (varied.check.feasible) return varied;
    }
    return searched;
  }

  double miss(DayPlan p) => math.max(p.check.kcalDeviation.abs() / kcalTolerance, (minProteinShare - p.check.proteinShare) / (1 - minProteinShare));
  final best = [rotation, dense, ?searched].reduce((a, b) => miss(b) < miss(a) ? b : a);

  // Energy limits of the templates themselves: verified sums of every slot's smallest and largest allowed portion,
  // so "even the smallest/largest portions" is said only when it is true for every day the planner can show.
  final minKcal = oilKcal + layers.fold(0.0, (s, l) => s + l.options.map((o) => o.$1.kcal * o.$2 / 100).reduce(math.min));
  final maxKcal = oilKcal + layers.fold(0.0, (s, l) => s + l.options.map((o) => o.$1.kcal * o.$2 / 100).reduce(math.max));

  // Explain the miss, scoped to the planner, and offer only changes that respect the person's settings.
  final c = best.check;
  const scope = 'Levlofit\'s food list, meal templates, portion limits and your budget';
  final issues = <String>[
    if (layers.isEmpty) 'None of the planner\'s foods fit your diet, allergies, exclusions and budget together.',
    if (c.proteinShare < minProteinShare && layers.isNotEmpty)
      ceiling == null
          ? 'Protein: this day reaches ${best.protein.round()} g of your ${protein.round()} g target (${(c.proteinShare * 100).round()}%). '
              'No day built from $scope stays within your energy limit, so the planner has no protein figure to compare.'
          : 'Protein: this day reaches ${best.protein.round()} g of your ${protein.round()} g target (${(c.proteinShare * 100).round()}%). '
              'Within your energy target, no day built from $scope reaches more than about ${ceiling.round()} g.',
    if (c.kcalDeviation > kcalTolerance)
      minKcal > kcal * (1 + kcalTolerance)
          ? 'Energy: even the smallest portions $scope allow add up to about ${minKcal.round()} kcal, more than 5% above your ${kcal.round()} kcal target.'
          : 'Energy: ${best.kcal.round()} kcal, ${(c.kcalDeviation * 100).round()}% above your ${kcal.round()} kcal target.',
    if (c.kcalDeviation < -kcalTolerance)
      maxKcal < kcal * (1 - kcalTolerance)
          ? 'Energy: even the largest portions $scope allow add up to about ${maxKcal.round()} kcal, more than 5% below your ${kcal.round()} kcal target.'
          : 'Energy: ${best.kcal.round()} kcal, ${(-c.kcalDeviation * 100).round()}% below your ${kcal.round()} kcal target.',
    'Levlofit\'s planner could not build a day that meets both targets from $scope. These are limits of the planner, not of nutrition: other foods or meal patterns could do better.',
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
    check: (
      feasible: false,
      kcalDeviation: c.kcalDeviation,
      proteinShare: c.proteinShare,
      proteinCeiling: ceiling,
      hitStepLimit: c.hitStepLimit,
      issues: issues,
      options: options,
      fatEnergyShare: c.fatEnergyShare,
      guidance: c.guidance,
    ),
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

// ---- a week of days, computed once and cached ---------------------------------------------------------------

/// Everything that decides a week of meal plans. All plain data, so it can be sent to a background isolate.
typedef WeekRequest = ({
  Map<String, Food> foods,
  double kcal,
  double protein,
  Set<String> excluded,
  List<String> custom,
  int tier,
  double soyaCapG,
  bool proteinPowder,
});

/// A key over every input that changes a week: each food's full values and whether its fat is known (name included, since exclusion words
/// match names), the targets, the excluded tags and exclusion words (order, case and spacing ignored, as the
/// planner ignores them), the budget tier, the soya limit and the protein-powder flag.
String weekKey(WeekRequest r) {
  final foods = (r.foods.keys.toList()..sort()).map((c) {
    final f = r.foods[c]!;
    return [c, f.name, (f.tags.toList()..sort()).join('+'), f.kcal, f.protein, f.carb, f.fat, f.fiber, f.fatKnown].join(':');
  }).join(',');
  final custom = r.custom.map((c) => c.trim().toLowerCase()).where((c) => c.isNotEmpty).toSet().toList()..sort();
  return [foods, r.kcal, r.protein, (r.excluded.toList()..sort()).join('+'), custom.join('+'), r.tier, r.soyaCapG, r.proteinPowder].join('|');
}

/// The seven days (index 0 = Monday) for one request. Top-level and pure, so it can run in a background isolate.
List<DayPlan> planWeek(WeekRequest r) => [
      for (var day = 0; day < 7; day++)
        planDay(
          foods: r.foods,
          kcal: r.kcal,
          protein: r.protein,
          excluded: r.excluded,
          custom: r.custom,
          tier: r.tier,
          day: day,
          soyaCapG: r.soyaCapG,
          proteinPowder: r.proteinPowder,
        ),
    ];

/// [planWeek] off the UI thread: Flutter's compute() uses a background isolate on mobile and desktop, and runs
/// the work in the same thread on the web, where isolates are not available.
Future<List<DayPlan>> planWeekInBackground(WeekRequest r) => compute(planWeek, r);

/// A small least-recently-used store of computed weeks, keyed by [weekKey].
class WeekCache {
  WeekCache({this.capacity = 8});
  final int capacity;
  final _weeks = <String, List<DayPlan>>{};

  int get length => _weeks.length;

  /// The cached week for [key], marking it most recently used; null when not cached.
  List<DayPlan>? get(String key) {
    final week = _weeks.remove(key);
    if (week != null) _weeks[key] = week;
    return week;
  }

  void put(String key, List<DayPlan> week) {
    _weeks.remove(key);
    _weeks[key] = week;
    while (_weeks.length > capacity) {
      _weeks.remove(_weeks.keys.first);
    }
  }

  /// The cached week, or [make]'s result stored under [key].
  List<DayPlan> getOrPut(String key, List<DayPlan> Function() make) {
    final hit = get(key);
    if (hit != null) return hit;
    final week = make();
    put(key, week);
    return week;
  }

  void clear() => _weeks.clear();
}

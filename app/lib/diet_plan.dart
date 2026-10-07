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
typedef _Slot = ({List<String> codes, double base, double min, double max, double step, _Scale scale, int prefer});

_Slot _s(List<String> codes, double base, double min, double max, _Scale scale, {double step = 5, int prefer = 99}) =>
    (codes: codes, base: base, min: min, max: max, step: step, scale: scale, prefer: prefer);

// Meal templates: (name, usual time, slots, share of the day's oil).
final _meals = <(String, String, List<_Slot>, double)>[
  ('Breakfast', '8 am', [
    _s(['A011', 'A010', 'A019'], 50, 30, 120, _Scale.energy),
    _s(['M004', 'L003', 'X001'], 100, 25, 200, _Scale.protein),
    _s(['L002'], 200, 200, 200, _Scale.fixed, step: 50),
    _s(['E012', 'E049', 'E028', 'E001'], 120, 120, 120, _Scale.fixed),
  ], 0.2),
  ('Lunch', '1 pm', [
    _s(['A015'], 60, 40, 150, _Scale.energy),
    _s(['A019', 'A005'], 40, 30, 120, _Scale.energy),
    _s(['B021', 'B010', 'B013', 'B020', 'B002'], 40, 30, 90, _Scale.protein),
    _s(['D036', 'D056', 'C015', 'F002', 'C033'], 150, 150, 150, _Scale.fixed),
    _s(['D043'], 100, 100, 100, _Scale.fixed),
  ], 0.4),
  ('Evening snack', '5 pm', [
    _s(['B002', 'H012'], 30, 20, 60, _Scale.protein),
    _s(['E028', 'E047', 'E012', 'E049'], 120, 120, 120, _Scale.fixed),
    _s(['L002'], 200, 200, 200, _Scale.fixed, step: 50), // a glass of milk or chaas for those who take dairy
  ], 0.0),
  ('Dinner', '8 pm', [
    _s(['A019', 'A005', 'A003'], 60, 30, 150, _Scale.energy),
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

typedef PlanItem = ({String code, String name, double grams, String unit, double kcal, double protein, double carb, double fat, double fiber});
typedef PlanMeal = ({String name, String time, List<PlanItem> items});
typedef DayPlan = ({List<PlanMeal> meals, double kcal, double protein, double carb, double fat, double fiber});

PlanItem _item(Food f, double g) {
  final (label, _, unit) = _catalogue[f.code] ?? (f.name, 1, 'raw');
  final k = g / 100;
  return (code: f.code, name: label, grams: g, unit: unit, kcal: f.kcal * k, protein: f.protein * k, carb: f.carb * k, fat: f.fat * k, fiber: f.fiber * k);
}

/// Builds one day. [day] (0 = Monday) rotates the foods so the week has variety.
/// [excluded] holds the plan's excluded food tags; [custom] free-text exclusions; [soyaCapG] the plan's soya limit.
DayPlan planDay({
  required Map<String, Food> foods,
  required double kcal,
  required double protein,
  required Set<String> excluded,
  List<String> custom = const [],
  int tier = 2,
  int day = 0,
  double soyaCapG = 50,
}) {
  bool ok(String code) {
    final f = foods[code];
    if (f == null) return false;
    final (label, cost, _) = _catalogue[code]!;
    if (cost > tier) return false;
    if (code == 'X001' && soyaCapG <= 0) return false;
    if (f.tags.any(excluded.contains)) return false;
    final text = '${f.name} $label'.toLowerCase();
    return !custom.any((c) => c.isNotEmpty && text.contains(c.toLowerCase()));
  }

  // Pick a food for every slot; slots with nothing allowed drop out (a vegan breakfast has no milk).
  final picks = <(int, _Slot, Food)>[];
  for (final (mi, (_, _, slots, _)) in _meals.indexed) {
    for (final (si, slot) in slots.indexed) {
      final all = slot.codes.where(ok).toList();
      if (all.isEmpty) continue;
      final preferred = slot.codes.take(slot.prefer).where(ok).toList();
      final allowed = preferred.isEmpty ? all : preferred;
      picks.add((mi, slot, foods[allowed[(day + si + mi) % allowed.length]]!));
    }
  }
  final grams = [for (final p in picks) p.$2.base];
  // The plan's soya limit is for the whole day, shared by every meal that uses soya.
  final soyaMeals = picks.where((p) => p.$3.code == 'X001').length;
  double maxFor(int i) {
    final code = picks[i].$3.code;
    final cap = code == 'X001' ? soyaCapG / math.max(1, soyaMeals) : (_maxPortion[code] ?? double.infinity);
    return math.min(picks[i].$2.max, cap);
  }

  final oil = [foods['T012'], foods['T006']].whereType<Food>().where((f) => !f.tags.any(excluded.contains)).firstOrNull;
  final oilG = oil == null ? 0.0 : oilGrams(kcal);
  ({double kcal, double protein}) totals() {
    var k = oil == null ? 0.0 : oil.kcal * oilG / 100, pr = 0.0;
    for (final (i, p) in picks.indexed) {
      k += p.$3.kcal * grams[i] / 100;
      pr += p.$3.protein * grams[i] / 100;
    }
    return (kcal: k, protein: pr);
  }

  // Protein foods close the protein gap, staples then close the energy gap; a few rounds settle both.
  for (var round = 0; round < 8; round++) {
    var t = totals();
    final pIdx = [for (final (i, p) in picks.indexed) if (p.$2.scale == _Scale.protein) i];
    final fromP = pIdx.fold(0.0, (s, i) => s + picks[i].$3.protein * grams[i] / 100);
    if (fromP > 0) {
      final f = (1 + (protein - t.protein) / fromP).clamp(0.5, 2.0);
      for (final i in pIdx) {
        grams[i] = (grams[i] * f).clamp(math.min(picks[i].$2.min, maxFor(i)), maxFor(i));
      }
    }
    t = totals();
    final eIdx = [for (final (i, p) in picks.indexed) if (p.$2.scale == _Scale.energy) i];
    final fromE = eIdx.fold(0.0, (s, i) => s + picks[i].$3.kcal * grams[i] / 100);
    if (fromE > 0) {
      final f = (1 + (kcal - t.kcal) / fromE).clamp(0.5, 2.0);
      for (final i in eIdx) {
        grams[i] = (grams[i] * f).clamp(picks[i].$2.min, picks[i].$2.max);
      }
    }
  }

  final meals = <PlanMeal>[];
  for (final (mi, (name, time, _, oilShare)) in _meals.indexed) {
    final items = <PlanItem>[
      for (final (i, p) in picks.indexed)
        if (p.$1 == mi) _item(p.$3, p.$3.code == 'X001' ? (grams[i] / 5).floor() * 5.0 : math.max(p.$2.step, (grams[i] / p.$2.step).round() * p.$2.step)),
      if (oil != null && oilShare > 0) _item(oil, (oilG * oilShare).roundToDouble()),
    ];
    if (items.isNotEmpty) meals.add((name: name, time: time, items: items));
  }
  double sum(double Function(PlanItem) f) => meals.fold(0.0, (s, m) => s + m.items.fold(0.0, (a, it) => a + f(it)));
  return (meals: meals, kcal: sum((i) => i.kcal), protein: sum((i) => i.protein), carb: sum((i) => i.carb), fat: sum((i) => i.fat), fiber: sum((i) => i.fiber));
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

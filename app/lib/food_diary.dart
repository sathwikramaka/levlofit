// Food diary: what was eaten, as IFCT 2017 foods and gram weights. Values per 100 g edible portion come from
// public.foods at read time; nothing here estimates a nutrient that the table does not hold. Vitamins and minerals
// are summed only over foods with a value; a missing value is reported, never treated as zero. No daily targets are
// shown for them (reference intakes need review before they are shown as goals).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'main.dart';
import 'theme.dart';

typedef FoodRow = ({String code, String name, String? nameHi, double kcal, double protein, double fat, double carb, double fiber, Map<String, double> micros});
typedef DiaryEntry = ({String id, String meal, String foodCode, double grams});

/// [micros]: per nutrient, the amount from foods that have a value and the number of entries whose food has none.
typedef DiaryTotals = ({double kcal, double protein, double fat, double carb, double fiber, int unknownFoods, Map<String, ({double amount, int missing})> micros});

/// Vitamins and minerals held in public.foods (IFCT 2017): column, label, unit.
const diaryMicros = [
  ('calcium_mg', 'Calcium', 'mg'),
  ('iron_mg', 'Iron', 'mg'),
  ('zinc_mg', 'Zinc', 'mg'),
  ('magnesium_mg', 'Magnesium', 'mg'),
  ('potassium_mg', 'Potassium', 'mg'),
  ('sodium_mg', 'Sodium', 'mg'),
  ('vitamin_c_mg', 'Vitamin C', 'mg'),
  ('folate_ug', 'Folate', 'µg'),
];
const _foodColumns = 'code, name, name_hi, kcal, protein_g, fat_g, carb_g, fiber_g, '
    'calcium_mg, iron_mg, zinc_mg, magnesium_mg, potassium_mg, sodium_mg, vitamin_c_mg, folate_ug';

const diaryMeals = ['breakfast', 'lunch', 'dinner', 'snack'];
const diaryMealNames = {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'dinner': 'Dinner', 'snack': 'Snacks'};

/// Common portions offered as shortcuts, in grams only (the table is per 100 g; household measures vary too much
/// to convert without a source).
const gramPresets = [50, 100, 150, 200, 250];

FoodRow foodFromRow(Map<String, dynamic> r) => (
      code: r['code'] as String,
      name: r['name'] as String,
      nameHi: r['name_hi'] as String?,
      kcal: (r['kcal'] as num).toDouble(),
      protein: (r['protein_g'] as num? ?? 0).toDouble(),
      fat: (r['fat_g'] as num? ?? 0).toDouble(),
      carb: (r['carb_g'] as num? ?? 0).toDouble(),
      fiber: (r['fiber_g'] as num? ?? 0).toDouble(),
      micros: {for (final (k, _, _) in diaryMicros) if (r[k] case final num v) k: v.toDouble()},
    );

DiaryEntry entryFromRow(Map<String, dynamic> r) =>
    (id: r['id'] as String, meal: r['meal'] as String, foodCode: r['food_code'] as String, grams: (r['grams'] as num).toDouble());

/// Sums entries by scaling each food's per-100 g values. An entry whose food is missing from [foods] is counted in
/// [DiaryTotals.unknownFoods] and adds nothing, rather than being guessed.
DiaryTotals diaryTotals(Iterable<DiaryEntry> entries, Map<String, FoodRow> foods) {
  var kcal = 0.0, protein = 0.0, fat = 0.0, carb = 0.0, fiber = 0.0, unknown = 0;
  final amount = <String, double>{}, missing = <String, int>{};
  for (final e in entries) {
    final f = foods[e.foodCode];
    if (f == null) {
      unknown++;
      continue;
    }
    final k = e.grams / 100;
    kcal += f.kcal * k;
    protein += f.protein * k;
    fat += f.fat * k;
    carb += f.carb * k;
    fiber += f.fiber * k;
    for (final (m, _, _) in diaryMicros) {
      if (f.micros[m] case final v?) {
        amount[m] = (amount[m] ?? 0) + v * k;
      } else {
        missing[m] = (missing[m] ?? 0) + 1;
      }
    }
  }
  return (
    kcal: kcal,
    protein: protein,
    fat: fat,
    carb: carb,
    fiber: fiber,
    unknownFoods: unknown,
    micros: {for (final (m, _, _) in diaryMicros) m: (amount: amount[m] ?? 0, missing: missing[m] ?? 0)},
  );
}

/// The grams typed in, or an error to show. Same bounds as the database (above 0, at most 2000).
({double? grams, String? error}) parseGrams(String text) {
  final v = double.tryParse(text.trim());
  if (text.trim().isEmpty) return (grams: null, error: 'Enter the weight in grams');
  if (v == null || v <= 0) return (grams: null, error: 'Enter a weight above 0 g');
  if (v > 2000) return (grams: null, error: 'Enter at most 2000 g per entry');
  return (grams: (v * 10).round() / 10, error: null);
}

/// The PostgREST ilike pattern for a food search, or null when the query is too short. Characters the filter syntax
/// reserves (, ( ) * % " \) become spaces, runs of spaces collapse, and the words must appear in that order, so
/// "rice, raw, brown", "rice raw brown" and "rice brown" all find "Rice, raw, brown".
String? foodSearchPattern(String query) {
  final words = _searchWords(query);
  if (words.join(' ').length < 2) return null;
  return '*${words.join('*')}*';
}

List<String> _searchWords(String s) => s.replaceAll(RegExp(r'[%*,()"\\]'), ' ').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Client-side twin of [foodSearchPattern]: the words of [query] appear in [text] in that order, ignoring case,
/// commas, brackets and spacing. An empty query matches everything.
bool matchesFoodQuery(String text, String query) {
  final t = _searchWords(text.toLowerCase()).join(' ');
  var at = 0;
  for (final w in _searchWords(query.toLowerCase())) {
    final i = t.indexOf(w, at);
    if (i < 0) return false;
    at = i + w.length;
  }
  return true;
}

/// Diary rows newest first; rows saved in the same instant (one insert) are ordered by id, so the order is stable.
List<Map<String, dynamic>> newestFirst(List<Map<String, dynamic>> rows) => [...rows]
  ..sort((a, b) {
    final t = DateTime.parse(b['created_at'] as String).compareTo(DateTime.parse(a['created_at'] as String));
    return t != 0 ? t : (b['id'] as String).compareTo(a['id'] as String);
  });

/// Carbohydrate, fat and fibre for the totals card. Non-breaking spaces keep each "label value g" together, so a
/// narrow screen wraps only between items, never between a number and its unit.
String macroLine(DiaryTotals t) => [
      ('Carbohydrate', t.carb),
      ('Fat', t.fat),
      ('Fibre', t.fiber),
    ].map((e) => '${e.$1}\u00a0${e.$2.toStringAsFixed(1)}\u00a0g').join('  ·  ');

String isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The database accepts diary days from 730 days back to today (food_log_limit, migration 20261016100000).
const diaryDaysBack = 730;
DateTime oldestDiaryDay(DateTime today) => DateTime(today.year, today.month, today.day - diaryDaysBack);
bool diaryDayInRange(DateTime day, DateTime today) => !day.isAfter(today) && !day.isBefore(oldestDiaryDay(today));

/// The database refuses a day outside that window with 22008 (possible near midnight UTC, or with a wrong phone clock).
String diarySaveError(Object e, String fallback) => e is PostgrestException && e.code == '22008'
    ? 'That day is outside the diary (today and the last 2 years). Nothing was added.'
    : fallback;

/// Data access. The screen takes these as parameters so tests can supply their own.
typedef DiaryApi = ({
  Future<List<DiaryEntry>> Function(DateTime day) load,
  Future<Map<String, FoodRow>> Function(Iterable<String> codes) foods,
  Future<List<FoodRow>> Function(String query) search,
  Future<void> Function(DateTime day, String meal, String code, double grams) add,
  Future<void> Function(String id) remove,
  Future<void> Function(String id, String meal, double grams) update,
});

/// Food rows are hidden by the database until their source's licence is confirmed (food_sources.release_allowed,
/// 20261025100000_food_sources.sql). While no source is allowed the food screens say so, instead of "nothing found".
const foodDataPendingText = 'Food values are not available in this version yet: Levlofit is moving to openly licensed '
    'food data. Your calorie and protein targets still apply.';

/// Whether any food row is visible. A failed check counts as available, so a network error never claims a licence gap.
@visibleForTesting
Future<bool> Function() foodDataProbe = () => supabase.from('foods').select('code').limit(1).then((r) => r.isNotEmpty);
Future<bool>? _foodData;
@visibleForTesting
void resetFoodDataForTest() => _foodData = null;
Future<bool> foodDataAvailable() => _foodData ??= Future.sync(foodDataProbe).catchError((Object _) {
      _foodData = null;
      return true;
    });

/// [fallback] when food data is available (or unknown), the licence note when no food row is visible.
class EmptyFoodsText extends StatelessWidget {
  const EmptyFoodsText(this.fallback, {super.key, this.style});
  final String fallback;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: foodDataAvailable(),
        builder: (context, snap) => Text(snap.data == false ? foodDataPendingText : fallback, style: style),
      );
}

/// Attribution for each food source, keyed as in public.food_sources.
const foodSourceCredits = {
  'ifct2017': 'Food values: IFCT 2017, ICMR-National Institute of Nutrition',
  'usda_fdc': 'Food values: USDA FoodData Central, U.S. Department of Agriculture, Agricultural Research Service (fdc.nal.usda.gov)',
  'levlofit_recipe': 'Recipe values: Levlofit, summed from the ingredients above',
};

/// The sources of the food rows this person can see (the database hides unlicensed ones). A database from before
/// 20261025100000_food_sources has no source column and holds only IFCT rows; any other failure credits nothing
/// rather than a source that may not be shown.
@visibleForTesting
Future<Set<String>> Function() foodSourcesProbe = () async {
  try {
    return {for (final r in await supabase.from('foods').select('source').limit(2000)) r['source'] as String};
  } on PostgrestException catch (e) {
    if (e.code == '42703') return {'ifct2017'};
    rethrow;
  }
};
Future<Set<String>>? _sources;

/// One line crediting every visible food source, after [lead]. Shows only [lead] when no source is visible.
class FoodCredit extends StatelessWidget {
  const FoodCredit({super.key, this.lead = '', this.trail = '', this.style});
  final String lead, trail;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => FutureBuilder<Set<String>>(
        future: _sources ??= Future.sync(foodSourcesProbe).catchError((Object _) {
          _sources = null;
          return <String>{};
        }),
        builder: (context, snap) {
          final credits = [for (final MapEntry(:key, :value) in foodSourceCredits.entries) if (snap.data?.contains(key) ?? false) value];
          final text = [lead.trim(), if (credits.isNotEmpty) '${credits.join('. ')}.', trail.trim()].where((p) => p.isNotEmpty).join(' ');
          return text.isEmpty ? const SizedBox.shrink() : Text(text, style: style);
        },
      );
}

@visibleForTesting
void resetFoodSourcesForTest() => _sources = null;

final DiaryApi supabaseDiary = (
  load: (day) async => [
        for (final r in newestFirst(await supabase.from('food_log').select('id, meal, food_code, grams, created_at').eq('day', isoDay(day)))) entryFromRow(r)
      ],
  foods: (codes) async {
    final list = codes.toSet().toList();
    if (list.isEmpty) return <String, FoodRow>{};
    final rows = await supabase.from('foods').select(_foodColumns).inFilter('code', list);
    return {for (final r in rows) r['code'] as String: foodFromRow(r)};
  },
  search: (query) async {
    final q = foodSearchPattern(query);
    if (q == null) return <FoodRow>[];
    final rows = await supabase
        .from('foods')
        .select(_foodColumns)
        .or('name.ilike.$q,name_hi.ilike.$q')
        .order('name')
        .limit(30);
    return [for (final r in rows) foodFromRow(r)];
  },
  add: (day, meal, code, grams) => supabase.from('food_log').insert({'day': isoDay(day), 'meal': meal, 'food_code': code, 'grams': grams}),
  remove: (id) => supabase.from('food_log').delete().eq('id', id),
  update: (id, meal, grams) => supabase.from('food_log').update({'meal': meal, 'grams': grams}).eq('id', id),
);

class FoodDiaryScreen extends StatefulWidget {
  const FoodDiaryScreen({super.key, this.leading, this.kcalTarget, this.proteinTarget, this.api, this.recipes, this.today});
  final Widget? leading;
  final num? kcalTarget, proteinTarget; // from the current plan, when there is one
  final DiaryApi? api; // tests only; the app uses Supabase
  final RecipeApi? recipes; // tests only
  final DateTime? today; // tests only

  @override
  State<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends State<FoodDiaryScreen> {
  late DiaryApi api = widget.api ?? supabaseDiary;
  late DateTime _day = _dateOnly(widget.today ?? DateTime.now());
  List<DiaryEntry>? _entries; // null while loading
  Map<String, FoodRow> _foods = {};
  String? _error;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _loadSeq = 0; // only the latest day's answer is shown, however the replies arrive

  Future<void> _load() async {
    final n = ++_loadSeq;
    setState(() {
      _entries = null;
      _error = null;
    });
    try {
      final entries = await api.load(_day);
      final foods = await api.foods(entries.map((e) => e.foodCode));
      if (mounted && n == _loadSeq) {
        setState(() {
          _entries = entries;
          _foods = foods;
        });
      }
    } catch (_) {
      if (mounted && n == _loadSeq) {
        setState(() {
          _entries = const [];
          _error = 'Could not load your diary. Check your connection and try again.';
        });
      }
    }
  }

  void _shift(int days) {
    final next = DateTime(_day.year, _day.month, _day.day + days);
    if (!diaryDayInRange(next, _dateOnly(widget.today ?? DateTime.now()))) return; // no future days, nothing older than the database keeps
    _day = next;
    _load();
  }

  Future<void> _add(String meal) async {
    final picked = await showModalBottomSheet<(FoodRow, double)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddFoodSheet(search: api.search, mealName: diaryMealNames[meal]!),
    );
    if (picked == null || !mounted) return;
    try {
      await api.add(_day, meal, picked.$1.code, picked.$2);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(diarySaveError(e, 'Could not save that entry. Nothing was added.'))));
    }
  }

  Future<void> _remove(DiaryEntry e) async {
    final name = _foods[e.foodCode]?.name ?? 'this food';
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove this entry?'),
        content: Text('$name, ${_fmt(e.grams)} g, will be removed from this day.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await api.remove(e.id);
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove that entry.')));
    }
  }

  Future<void> _edit(DiaryEntry e) async {
    final grams = TextEditingController(text: _fmt(e.grams)); // not disposed: the closing dialog still reads it
    var meal = e.meal;
    String? error;
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(_foods[e.foodCode]?.name ?? 'Edit entry'),
          content: SizedBox(
            width: 320, // a TextField cannot size itself inside the dialog's intrinsic width
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: grams,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d?)?$'))],
                decoration: InputDecoration(labelText: 'Weight eaten', suffixText: 'g', errorText: error),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [
                for (final m in diaryMeals) ChoiceChip(label: Text(diaryMealNames[m]!), selected: meal == m, onSelected: (_) => set(() => meal = m)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final r = parseGrams(grams.text);
                if (r.error != null) return set(() => error = r.error);
                Navigator.pop(d, (meal, r.grams!));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null || (result.$1 == e.meal && result.$2 == e.grams) || !mounted) return;
    try {
      await api.update(e.id, result.$1, result.$2);
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save that change. The entry is unchanged.')));
    }
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final entries = _entries;
    final today = _dateOnly(widget.today ?? DateTime.now());
    final isToday = _day == today;
    final isOldest = !_day.isAfter(oldestDiaryDay(today));
    final totals = entries == null ? null : diaryTotals(entries, _foods);
    return Scaffold(
      appBar: AppBar(leading: widget.leading, title: const Text('Food diary'), actions: [
        TextButton.icon(
          onPressed: () async {
            final logged = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => RecipesScreen(api: widget.recipes ?? supabaseRecipes, diary: api, day: _day)),
            );
            if (logged == true) _load();
          },
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text('Recipes'),
        ),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
            Row(children: [
              IconButton(tooltip: 'Previous day', onPressed: isOldest ? null : () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Text(isToday ? 'Today' : isoDay(_day), textAlign: TextAlign.center, style: t.titleMedium)),
              IconButton(tooltip: 'Next day', onPressed: isToday ? null : () => _shift(1), icon: const Icon(Icons.chevron_right)),
            ]),
            if (isOldest)
              Text('The diary keeps the last 2 years. Older days cannot be opened.',
                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (_error != null) ...[
              Text(_error!, style: t.bodyMedium?.copyWith(color: c.error)),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ] else if (totals == null)
              const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2))
            else ...[
              _TotalsCard(totals: totals, kcalTarget: widget.kcalTarget, proteinTarget: widget.proteinTarget),
              if (totals.unknownFoods > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${totals.unknownFoods} entr${totals.unknownFoods == 1 ? 'y uses a food' : 'ies use foods'} no longer in the food table; '
                      'not counted in the totals.', style: t.bodySmall?.copyWith(color: c.error)),
                ),
              if (entries!.isNotEmpty) _MicrosTile(totals: totals),
              const SizedBox(height: 12),
              for (final meal in diaryMeals) ...[
                Row(children: [
                  Expanded(child: Text(diaryMealNames[meal]!.toUpperCase(), style: monoLabel(context))),
                  TextButton.icon(onPressed: () => _add(meal), icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
                ]),
                for (final e in entries.where((e) => e.meal == meal))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_foods[e.foodCode]?.name ?? 'Unknown food (${e.foodCode})'),
                    subtitle: Text(_foods[e.foodCode] == null
                        ? '${_fmt(e.grams)} g'
                        : '${_fmt(e.grams)} g  ·  ${(_foods[e.foodCode]!.kcal * e.grams / 100).round()} kcal  ·  ${(_foods[e.foodCode]!.protein * e.grams / 100).toStringAsFixed(1)} g protein'),
                    onTap: () => _edit(e),
                    trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: () => _remove(e)),
                  ),
                if (!entries.any((e) => e.meal == meal)) Text('Nothing logged.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              FoodCredit(
                  lead: 'Values per 100 g edible portion. ',
                  trail: 'Weigh food as eaten. Vitamins and minerals count only foods with a value in the table; a missing value is not zero.',
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals, this.kcalTarget, this.proteinTarget});
  final DiaryTotals totals;
  final num? kcalTarget, proteinTarget;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    String of(num? target) => target == null ? '' : ' of ${target.round()}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${totals.kcal.round()}${of(kcalTarget)} kcal', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('${totals.protein.toStringAsFixed(1)}${of(proteinTarget)} g protein', style: t.titleMedium),
        const SizedBox(height: 8),
        Text(macroLine(totals), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ]),
    );
  }
}

/// Vitamin and mineral totals for the day, with how many entries had no value for each.
class _MicrosTile extends StatelessWidget {
  const _MicrosTile({required this.totals});
  final DiaryTotals totals;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Vitamins and minerals', style: t.titleSmall),
      children: [
        for (final (k, label, unit) in diaryMicros)
          if (totals.micros[k] case final m?)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              subtitle: m.missing == 0 ? null : Text('No value for ${m.missing} entr${m.missing == 1 ? 'y' : 'ies'}; the total may be higher.'),
              trailing: Text('${m.amount < 10 ? m.amount.toStringAsFixed(1) : m.amount.round()} $unit', style: t.bodyMedium),
            ),
        Text('No daily targets are shown for these yet.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

/// Search the food table, pick a food, enter grams. Pops with (food, grams).
class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet({required this.search, required this.mealName, this.weightLabel = 'Weight eaten'});
  final Future<List<FoodRow>> Function(String) search;
  final String mealName, weightLabel;

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _query = TextEditingController();
  final _grams = TextEditingController(text: '100');
  List<FoodRow> _results = const [];
  FoodRow? _picked;
  String? _gramsError, _searchError;
  int _seq = 0;

  @override
  void dispose() {
    _query.dispose();
    _grams.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final n = ++_seq;
    try {
      final r = await widget.search(q);
      if (mounted && n == _seq) {
        setState(() {
          _results = r;
          _searchError = null;
        });
      }
    } catch (_) {
      if (mounted && n == _seq) setState(() => _searchError = 'Search failed. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final picked = _picked;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add to ${widget.mealName}', style: t.titleLarge),
        const SizedBox(height: 12),
        if (picked == null) ...[
          TextField(
            controller: _query,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Search foods', hintText: 'rice, dal, paneer, banana'),
            onChanged: _search,
          ),
          if (_searchError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_searchError!, style: TextStyle(color: c.error))),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(shrinkWrap: true, children: [
              for (final f in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(f.name),
                  subtitle: Text('${f.kcal.round()} kcal · ${f.protein.toStringAsFixed(1)} g protein per 100 g${f.nameHi == null ? '' : '  ·  ${f.nameHi}'}'),
                  onTap: () => setState(() => _picked = f),
                ),
              if (_query.text.trim().length >= 2 && _results.isEmpty && _searchError == null)
                Padding(padding: const EdgeInsets.only(top: 8), child: EmptyFoodsText('No matching foods.', style: t.bodySmall)),
            ]),
          ),
        ] else ...[
          Text(picked.name, style: t.titleMedium),
          Text('${picked.kcal.round()} kcal · ${picked.protein.toStringAsFixed(1)} g protein per 100 g', style: t.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _grams,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d?)?$'))],
            decoration: InputDecoration(labelText: widget.weightLabel, suffixText: 'g', errorText: _gramsError),
            onChanged: (_) => setState(() => _gramsError = null),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final g in gramPresets) ChoiceChip(label: Text('$g g'), selected: _grams.text == '$g', onSelected: (_) => setState(() => _grams.text = '$g')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            TextButton(onPressed: () => setState(() => _picked = null), child: const Text('Back')),
            const Spacer(),
            FilledButton(
              onPressed: () {
                final r = parseGrams(_grams.text);
                if (r.error != null) return setState(() => _gramsError = r.error);
                Navigator.pop(context, (picked, r.grams!));
              },
              child: const Text('Add'),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- recipes

typedef RecipeItem = ({String foodCode, double grams});
typedef Recipe = ({String id, String name, int servings, List<RecipeItem> items});

Recipe recipeFromRow(Map<String, dynamic> r) => (
      id: r['id'] as String,
      name: r['name'] as String,
      servings: (r['servings'] as num).toInt(),
      items: [for (final i in (r['recipe_items'] as List? ?? const [])) (foodCode: i['food_code'] as String, grams: (i['grams'] as num).toDouble())],
    );

/// Ingredient weights for [eaten] servings of [r], to one decimal. Null when a weight would fall outside the diary's
/// 0.1 to 2000 g per entry.
List<RecipeItem>? recipePortion(Recipe r, double eaten) {
  final out = [for (final i in r.items) (foodCode: i.foodCode, grams: (i.grams * eaten / r.servings * 10).round() / 10)];
  return out.any((i) => i.grams <= 0 || i.grams > 2000) ? null : out;
}

/// Servings the log dialog offers.
const recipeServingChoices = [0.5, 1.0, 1.5, 2.0];

typedef RecipeApi = ({
  Future<List<Recipe>> Function() list,
  Future<void> Function(String name, int servings, List<RecipeItem> items) save,
  Future<void> Function(String id) remove,
  Future<void> Function(DateTime day, String meal, List<RecipeItem> items) log,
});

final RecipeApi supabaseRecipes = (
  list: () async => [for (final r in await supabase.from('recipes').select('id, name, servings, recipe_items(food_code, grams)').order('name')) recipeFromRow(r)],
  save: (name, servings, items) => supabase.rpc<dynamic>('save_recipe', params: {
        'p_name': name,
        'p_servings': servings,
        'p_items': [for (final i in items) {'food_code': i.foodCode, 'grams': i.grams}],
      }),
  remove: (id) => supabase.from('recipes').delete().eq('id', id),
  // One insert: all ingredients are added, or none.
  log: (day, meal, items) => supabase.from('food_log').insert([for (final i in items) {'day': isoDay(day), 'meal': meal, 'food_code': i.foodCode, 'grams': i.grams}]),
);

/// The user's recipes: create, log a portion to the diary day, delete.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, required this.api, required this.diary, required this.day});
  final RecipeApi api;
  final DiaryApi diary; // food search and values
  final DateTime day; // the diary day a logged portion goes to

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Recipe>? _recipes;
  Map<String, FoodRow> _foods = {};
  String? _error;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await widget.api.list();
      final foods = await widget.diary.foods(list.expand((r) => r.items.map((i) => i.foodCode)));
      if (mounted) {
        setState(() {
          _recipes = list;
          _foods = foods;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your recipes. Check your connection and try again.');
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _new() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _RecipeEditor(api: widget.api, diary: widget.diary)));
    if (saved == true) _load();
  }

  Future<void> _log(Recipe r) async {
    var meal = 'lunch';
    var eaten = 1.0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('Log ${r.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Servings eaten (the recipe makes ${r.servings})'),
            Wrap(spacing: 6, children: [
              for (final s in recipeServingChoices)
                ChoiceChip(label: Text(s == s.roundToDouble() ? '${s.round()}' : '$s'), selected: eaten == s, onSelected: (_) => set(() => eaten = s)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              for (final m in diaryMeals) ChoiceChip(label: Text(diaryMealNames[m]!), selected: meal == m, onSelected: (_) => set(() => meal = m)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Log')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final items = recipePortion(r, eaten);
    if (items == null) return _snack('That portion makes an ingredient weigh more than 2000 g or less than 0.1 g. Log the foods one by one.');
    try {
      await widget.api.log(widget.day, meal, items);
      _logged = true;
      if (mounted) _snack('Added ${items.length} ingredient${items.length == 1 ? '' : 's'} to ${diaryMealNames[meal]}.');
    } catch (e) {
      if (mounted) _snack(diarySaveError(e, 'Could not log that recipe. Nothing was added.'));
    }
  }

  Future<void> _remove(Recipe r) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete this recipe?'),
        content: Text('${r.name} will be deleted. Diary entries already logged from it stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await widget.api.remove(r.id);
      await _load();
    } catch (_) {
      if (mounted) _snack('Could not delete that recipe.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final recipes = _recipes;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _logged);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Recipes')),
        floatingActionButton: FloatingActionButton.extended(onPressed: _new, icon: const Icon(Icons.add), label: const Text('New recipe')),
        body: _Column640(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
          if (_error != null) ...[
            Text(_error!, style: t.bodyMedium?.copyWith(color: c.error)),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ] else if (recipes == null)
            const LinearProgressIndicator(minHeight: 2)
          else if (recipes.isEmpty)
            Text('No recipes yet. Add a dish you cook often, with the raw weight of each ingredient, and log a serving in one step.',
                style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant))
          else
            for (final r in recipes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.name),
                subtitle: Text(_summary(r)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'Log a serving', icon: const Icon(Icons.add_circle_outline), onPressed: () => _log(r)),
                  IconButton(tooltip: 'Delete recipe', icon: const Icon(Icons.delete_outline), onPressed: () => _remove(r)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  String _summary(Recipe r) {
    final known = r.items.where((i) => _foods.containsKey(i.foodCode)).toList();
    final kcal = known.fold(0.0, (s, i) => s + _foods[i.foodCode]!.kcal * i.grams / 100) / r.servings;
    final missing = r.items.length - known.length;
    return '${r.items.length} ingredient${r.items.length == 1 ? '' : 's'}  ·  ${r.servings} serving${r.servings == 1 ? '' : 's'}  ·  '
        '${kcal.round()} kcal a serving${missing == 0 ? '' : ' ($missing not counted)'}';
  }
}

class _RecipeEditor extends StatefulWidget {
  const _RecipeEditor({required this.api, required this.diary});
  final RecipeApi api;
  final DiaryApi diary;

  @override
  State<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<_RecipeEditor> {
  final _name = TextEditingController();
  final _servings = TextEditingController(text: '2');
  final _items = <(FoodRow, double)>[];
  String? _nameError, _servingsError, _itemsError;
  bool _saving = false, _done = false;

  /// Something typed or added that leaving would lose.
  bool get _dirty => !_done && (_name.text.trim().isNotEmpty || _servings.text != '2' || _items.isNotEmpty);

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Discard this recipe?'),
        content: const Text('It has not been saved. What you entered will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) {
      _done = true;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    // Drop the field's focus itself (not just the scope's), or closing the sheet hands it back to Name and the
    // keyboard reopens.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showModalBottomSheet<(FoodRow, double)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddFoodSheet(search: widget.diary.search, mealName: 'recipe', weightLabel: 'Raw weight in the whole recipe'),
    );
    if (picked != null) {
      setState(() {
        _items.add(picked);
        _itemsError = null;
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final servings = int.tryParse(_servings.text.trim());
    setState(() {
      _nameError = name.isEmpty ? 'Give the recipe a name' : (name.length > 60 ? 'Use at most 60 characters' : null);
      _servingsError = servings == null || servings < 1 || servings > 20 ? 'Enter 1 to 20 servings' : null;
      _itemsError = _items.isEmpty ? 'Add at least one ingredient' : (_items.length > 30 ? 'Use at most 30 ingredients' : null);
    });
    if (_nameError != null || _servingsError != null || _itemsError != null) return;
    setState(() => _saving = true);
    try {
      await widget.api.save(name, servings!, [for (final (f, g) in _items) (foodCode: f.code, grams: g)]);
      _done = true;
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the recipe. Nothing was saved.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('New recipe')),
      body: _Column640(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        // Errors clear as soon as the field changes; Save checks again.
        TextField(
          controller: _name,
          maxLength: 60,
          decoration: InputDecoration(labelText: 'Name', errorText: _nameError),
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: 12), // room for the name's error line above the next label
        TextField(
          controller: _servings,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'Servings it makes', errorText: _servingsError),
          onChanged: (_) => setState(() => _servingsError = null),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('INGREDIENTS', style: monoLabel(context))),
          TextButton.icon(onPressed: _items.length >= 30 ? null : _addItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add ingredient')),
        ]),
        for (final (i, (f, g)) in _items.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(f.name),
            subtitle: Text('${_FoodDiaryScreenState._fmt(g)} g'),
            trailing: IconButton(tooltip: 'Remove ingredient', icon: const Icon(Icons.close), onPressed: () => setState(() => _items.removeAt(i))),
          ),
        if (_itemsError != null) Text(_itemsError!, style: t.bodySmall?.copyWith(color: c.error)),
        const SizedBox(height: 8),
        Text('Enter the raw weight of each ingredient for the whole dish. Water and salt add no energy and can be left out.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving' : 'Save recipe')),
        ]),
      ),
      ),
    );
  }
}

/// Content centred at the diary's 640 px reading width.
class _Column640 extends StatelessWidget {
  const _Column640({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child));
}

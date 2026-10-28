// Packaged foods by barcode (audit 12.12). The barcode digits alone go to Open Food Facts (open data, ODbL), nothing
// about the person. What comes back is only a suggestion: the person checks it against the label and corrects it
// before anything is saved, and a missing value stays empty for them to fill in, never 0. Products are saved per
// person in public.packaged_foods (migration 20261029700000) and logged through food_log.packaged_food_id.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'main.dart';

/// A product's label values per 100 g. Null = not known yet.
typedef Packaged = ({String? barcode, String name, String? brand, double? kcal, double? protein, double? fat, double? carb, double? fiber, String source, DateTime? sourceDate});

/// EAN-8, UPC-A (12), EAN-13 or a 14-digit GTIN.
bool validBarcode(String code) => RegExp(r'^\d{8}$|^\d{12,14}$').hasMatch(code);

/// Open Food Facts asks every app to name itself and give a contact.
const offUserAgent = 'Levlofit/1.0 (levlofit.app@gmail.com)';
const offCredit = 'Product data from Open Food Facts (openfoodfacts.org), ODbL. Check it against your pack.';

/// The product in an Open Food Facts v2 reply, or null when there is none. Energy falls back to kJ / 4.184.
Packaged? packagedFromOff(String barcode, Map<String, dynamic> json) {
  if (json['status'] != 1 || json['product'] is! Map) return null;
  final p = (json['product'] as Map).cast<String, dynamic>();
  final n = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
  double? v(String k) => switch (n[k]) { final num x => x.toDouble(), final String s => double.tryParse(s), _ => null };
  final kj = v('energy-kj_100g') ?? (n['energy_unit'] == 'kJ' ? v('energy_100g') : null);
  final name = '${p['product_name'] ?? ''}'.trim();
  final modified = p['last_modified_t'];
  return (
    barcode: barcode,
    name: name.isEmpty ? 'Product $barcode' : name,
    brand: '${p['brands'] ?? ''}'.split(',').first.trim().nullIfEmpty,
    kcal: v('energy-kcal_100g') ?? (kj == null ? null : (kj / 4.184 * 10).round() / 10),
    protein: v('proteins_100g'),
    fat: v('fat_100g'),
    carb: v('carbohydrates_100g'),
    fiber: v('fiber_100g'),
    source: 'open_food_facts',
    sourceDate: modified is int ? DateTime.fromMillisecondsSinceEpoch(modified * 1000, isUtc: true) : null,
  );
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// Looks [barcode] up: the person's own saved product first, then Open Food Facts. Null when neither knows it.
Future<({Packaged product, String? id})?> lookupBarcode(String barcode, {http.Client? client}) async {
  final own = await supabase.from('packaged_foods').select().eq('barcode', barcode).maybeSingle();
  if (own != null) return (product: packagedFromRow(own), id: own['id'] as String);
  final res = await (client ?? http.Client())
      .get(
        Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json',
            {'fields': 'product_name,brands,nutriments,last_modified_t'}),
        headers: {'User-Agent': offUserAgent},
      )
      .timeout(const Duration(seconds: 12));
  if (res.statusCode == 404) return null;
  if (res.statusCode != 200) throw http.ClientException('Open Food Facts answered ${res.statusCode}');
  final p = packagedFromOff(barcode, jsonDecode(res.body) as Map<String, dynamic>);
  return p == null ? null : (product: p, id: null);
}

Packaged packagedFromRow(Map<String, dynamic> r) => (
      barcode: r['barcode'] as String?,
      name: r['name'] as String,
      brand: r['brand'] as String?,
      kcal: (r['kcal'] as num?)?.toDouble(),
      protein: (r['protein_g'] as num?)?.toDouble(),
      fat: (r['fat_g'] as num?)?.toDouble(),
      carb: (r['carb_g'] as num?)?.toDouble(),
      fiber: (r['fiber_g'] as num?)?.toDouble(),
      source: r['source'] as String,
      sourceDate: r['source_date'] == null ? null : DateTime.parse(r['source_date'] as String),
    );

/// Saves (or updates, for a barcode already saved) the confirmed product and returns its id.
Future<String> savePackaged(Packaged p, {String? id}) async {
  final row = {
    'name': p.name.trim(),
    'brand': p.brand,
    'kcal': p.kcal,
    'protein_g': p.protein,
    'fat_g': p.fat,
    'carb_g': p.carb,
    'fiber_g': p.fiber,
    'source': p.source,
    'source_date': p.sourceDate?.toIso8601String().substring(0, 10),
  };
  if (id != null) {
    await supabase.from('packaged_foods').update(row).eq('id', id);
    return id;
  }
  final saved = await supabase.from('packaged_foods').insert({...row, 'barcode': p.barcode}).select('id').single();
  return saved['id'] as String;
}

/// The label check before saving: an error to show, or null. Same bounds as the database.
String? packagedProblem(Packaged p) {
  if (p.name.trim().length < 2) return 'Enter the product name';
  for (final (v, label, max) in [(p.kcal, 'Energy', 900.0), (p.protein, 'Protein', 100.0), (p.fat, 'Fat', 100.0), (p.carb, 'Carbs', 100.0)]) {
    if (v == null) return '$label per 100 g is missing: copy it from the label';
    if (v < 0 || v > max) return '$label per 100 g looks wrong: check the label';
  }
  if (p.fiber case final f? when f < 0 || f > 100) return 'Fibre per 100 g looks wrong: check the label';
  if ((p.protein ?? 0) + (p.fat ?? 0) + (p.carb ?? 0) > 100.5) return 'Protein, fat and carbs add up to more than 100 g: check the label';
  return null;
}

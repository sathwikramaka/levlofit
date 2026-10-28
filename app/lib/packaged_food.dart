// Screens for packaged foods: scan a barcode (on-device ZXing, no image leaves the phone), then check the values
// against the pack and save. Also the by-hand path for a product Open Food Facts does not know.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'barcode.dart';
import 'food_diary.dart' show FoodRow, gramPresets, parseGrams;

/// Scan (when [scan] and not on the web) or type a product, look it up, confirm it. The confirmed product and the
/// grams eaten, ready for the diary, or null when the person backs out.
Future<(FoodRow, double)?> addPackagedFood(BuildContext context, {required bool scan}) async {
  final nav = Navigator.of(context);
  String? code;
  if (scan && !kIsWeb) {
    code = await nav.push<String>(MaterialPageRoute(builder: (_) => const ScanBarcodeScreen()));
    if (code == null) return null;
  }
  ({Packaged product, String? id})? found;
  String? note;
  if (code != null) {
    try {
      found = await lookupBarcode(code);
      if (found == null) note = 'No product found for $code. Copy the values from the pack below.';
    } catch (_) {
      note = 'Could not look up $code. Check your connection, or copy the values from the pack below.';
    }
  }
  final blank = (barcode: code, name: '', brand: null, kcal: null, protein: null, fat: null, carb: null, fiber: null, source: code == null ? 'manual' : 'label', sourceDate: null) as Packaged;
  if (!nav.mounted) return null;
  return nav.push<(FoodRow, double)>(MaterialPageRoute(
    builder: (_) => PackagedFoodForm(initial: found?.product ?? blank, id: found?.id, note: note, save: savePackaged),
  ));
}

class ScanBarcodeScreen extends StatefulWidget {
  const ScanBarcodeScreen({super.key});

  @override
  State<ScanBarcodeScreen> createState() => _ScanBarcodeScreenState();
}

class _ScanBarcodeScreenState extends State<ScanBarcodeScreen> {
  bool _done = false;
  bool _noCamera = false; // refused or unavailable: typing the number still works

  void _finish(String code) {
    if (_done || !validBarcode(code)) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, code);
  }

  Future<void> _type() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Type the barcode'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
          decoration: const InputDecoration(labelText: 'The digits under the bars'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Look up')),
        ],
      ),
    );
    c.dispose();
    if (code != null && validBarcode(code)) {
      _finish(code);
    } else if (code != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A barcode has 8, 12, 13 or 14 digits.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan a barcode'), actions: [TextButton(onPressed: _type, child: const Text('Type it'))]),
        body: Stack(children: [
          ReaderWidget(
            codeFormat: Format.ean8 | Format.ean13 | Format.upca | Format.upce,
            showGallery: false,
            showToggleCamera: false,
            onScan: (c) {
              if (c.isValid && c.text != null) _finish(c.text!);
            },
            onControllerCreated: (_, error) {
              if (error != null && mounted) setState(() => _noCamera = true);
            },
          ),
          if (_noCamera)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('The camera is not available. Allow Camera for Levlofit in your phone settings, or type the number under the bars.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _type, child: const Text('Type the barcode')),
                  ]),
                ),
              ),
            ),
          if (!_noCamera) const Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Hold the bars inside the frame. Scanning happens on this phone; only the number is looked up.'),
              ),
            ),
          ),
        ]),
      );
}

/// Check and correct a product's values per 100 g, then choose the grams eaten. [save] stores it and returns its id.
class PackagedFoodForm extends StatefulWidget {
  const PackagedFoodForm({super.key, required this.initial, required this.save, this.id, this.note});
  final Packaged initial;
  final String? id, note;
  final Future<String> Function(Packaged p, {String? id}) save;

  @override
  State<PackagedFoodForm> createState() => _PackagedFoodFormState();
}

class _PackagedFoodFormState extends State<PackagedFoodForm> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _brand = TextEditingController(text: widget.initial.brand ?? '');
  late final _fields = {
    'kcal': TextEditingController(text: _fmt(widget.initial.kcal)),
    'protein': TextEditingController(text: _fmt(widget.initial.protein)),
    'fat': TextEditingController(text: _fmt(widget.initial.fat)),
    'carb': TextEditingController(text: _fmt(widget.initial.carb)),
    'fiber': TextEditingController(text: _fmt(widget.initial.fiber)),
  };
  final _grams = TextEditingController(text: '30');
  String? _error;
  bool _saving = false;

  static String _fmt(double? v) => v == null ? '' : (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1));
  double? _v(String k) => double.tryParse(_fields[k]!.text.trim());

  @override
  void dispose() {
    for (final c in [_name, _brand, _grams, ..._fields.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final edited = _fields.entries.any((e) => e.value.text != _fmt(switch (e.key) {
          'kcal' => widget.initial.kcal,
          'protein' => widget.initial.protein,
          'fat' => widget.initial.fat,
          'carb' => widget.initial.carb,
          _ => widget.initial.fiber,
        }));
    final p = (
      barcode: widget.initial.barcode,
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      kcal: _v('kcal'),
      protein: _v('protein'),
      fat: _v('fat'),
      carb: _v('carb'),
      fiber: _v('fiber'),
      // Values the person changed came from the label, not from the database.
      source: edited && widget.initial.source == 'open_food_facts' ? 'label' : widget.initial.source,
      sourceDate: edited ? DateTime.now() : widget.initial.sourceDate,
    );
    final grams = parseGrams(_grams.text);
    final problem = packagedProblem(p) ?? grams.error;
    if (problem != null) return setState(() => _error = problem);
    setState(() => _saving = true);
    try {
      final id = await widget.save(p, id: widget.id);
      final row = (
        code: 'pkg:$id',
        name: p.brand == null ? p.name : '${p.name} (${p.brand})',
        nameHi: null,
        kcal: p.kcal!,
        protein: p.protein!,
        fat: p.fat!,
        carb: p.carb!,
        fiber: p.fiber ?? 0,
        micros: const <String, double>{},
      );
      if (mounted) Navigator.pop(context, (row, grams.grams!));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the product. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    Widget num(String k, String label, String unit) => TextField(
          controller: _fields[k],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d?)?$'))],
          decoration: InputDecoration(labelText: label, suffixText: unit, hintText: 'from the label'),
        );
    final fromOff = widget.initial.source == 'open_food_facts';
    return Scaffold(
      appBar: AppBar(title: const Text('Check the label')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        if (widget.note != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.note!, style: t.bodyMedium)),
        if (fromOff)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '$offCredit${widget.initial.sourceDate == null ? '' : ' Last updated ${widget.initial.sourceDate!.toIso8601String().substring(0, 10)}.'}',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Product name')),
        const SizedBox(height: 10),
        TextField(controller: _brand, decoration: const InputDecoration(labelText: 'Brand (optional)')),
        const SizedBox(height: 18),
        Text('PER 100 G, AS ON THE PACK', style: t.labelSmall),
        const SizedBox(height: 8),
        num('kcal', 'Energy', 'kcal'),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: num('protein', 'Protein', 'g')), const SizedBox(width: 10), Expanded(child: num('fat', 'Fat', 'g'))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: num('carb', 'Carbs', 'g')), const SizedBox(width: 10), Expanded(child: num('fiber', 'Fibre (optional)', 'g'))]),
        const SizedBox(height: 18),
        TextField(
          controller: _grams,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d?)?$'))],
          decoration: const InputDecoration(labelText: 'Weight eaten', suffixText: 'g', helperText: 'The pack says the weight of one serving'),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final g in [15, 30, ...gramPresets.take(3)]) ChoiceChip(label: Text('$g g'), selected: _grams.text == '$g', onSelected: (_) => setState(() => _grams.text = '$g')),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: c.error))),
        const SizedBox(height: 18),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Saving…' : 'Save and add')),
      ]),
    );
  }
}

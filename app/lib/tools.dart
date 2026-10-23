// Fitness calculators. Formulas and cut-offs are cited on screen; nothing here is stored.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Body mass index, kg/m².
double bmi(double heightCm, double weightKg) => weightKg / math.pow(heightCm / 100, 2);

/// Asian Indian cut-offs (Misra et al., 2009): under 18, normal to 22.9, overweight to 24.9, obese from 25.
/// Pass the value already rounded to 1 dp (see [bmiCheck]) so the band matches the number shown.
String bmiBandIndia(double v) => v < 18 ? 'Underweight' : v < 23 ? 'Normal' : v < 25 ? 'Overweight' : 'Obese';

/// Same ranges as onboarding and the plan engine (validateInput).
const bmiHeightCm = (min: 120, max: 230), bmiWeightKg = (min: 30, max: 250);

double cmFromFeetInches(double feet, double inches) => (feet * 12 + inches) * 2.54;
double kgFromPounds(double lb) => lb * 0.45359237;

/// The calculator's whole decision, pure so it can be tested. Missing fields are not errors (not entered yet);
/// out-of-range ones are. The value is rounded to 1 dp before banding, exactly as the plan engine does (bmiOf),
/// so 22.96 shows "23.0 Overweight" in both places. Adult cut-offs are not applied under 18.
({double? value, String? band, String? note, Map<String, String> errors}) bmiCheck({double? heightCm, double? weightKg, int? age, bool imperial = false}) {
  // Messages in the units on screen, rounded inwards so every value they name is accepted.
  String feet(int inches) => '${inches ~/ 12} ft ${inches % 12} in';
  final heightRange = imperial
      ? '${feet((bmiHeightCm.min / 2.54).ceil())} and ${feet((bmiHeightCm.max / 2.54).floor())}'
      : '${bmiHeightCm.min} and ${bmiHeightCm.max} cm';
  final weightRange = imperial
      ? '${(bmiWeightKg.min / 0.45359237).ceil()} and ${(bmiWeightKg.max / 0.45359237).floor()} lb'
      : '${bmiWeightKg.min} and ${bmiWeightKg.max} kg';
  final errors = <String, String>{
    if (heightCm != null && (heightCm < bmiHeightCm.min || heightCm > bmiHeightCm.max)) 'height': 'Enter a height between $heightRange',
    if (weightKg != null && (weightKg < bmiWeightKg.min || weightKg > bmiWeightKg.max)) 'weight': 'Enter a weight between $weightRange',
    if (age != null && (age < 2 || age > 120)) 'age': 'Enter an age between 2 and 120',
  };
  if (heightCm == null || weightKg == null || errors.isNotEmpty) return (value: null, band: null, note: null, errors: errors);
  final v = (bmi(heightCm, weightKg) * 10).round() / 10;
  if (age != null && age < 18) {
    return (value: v, band: null, note: 'Adult cut-offs do not apply under 18. Children and teens are assessed with BMI-for-age charts; ask a doctor.', errors: errors);
  }
  return (value: v, band: bmiBandIndia(v), note: null, errors: errors);
}

/// Waist-to-height boundaries (Ashwell and Gibson, BMJ Open 2016;6:e010159, UK adults): under 0.5 no increased
/// risk, 0.5 to under 0.6 increased risk, 0.6 and over very high risk. Same units for both, so cm or inches.
/// Banded on the value rounded to 2 dp, the number shown, so 0.497 shows "0.50 Increased risk".
const whtrCuts = [0.5, 0.6];
const waistCm = (min: 40, max: 200); // as onboarding

({double? value, String? band, Map<String, String> errors}) whtrCheck({double? height, double? waist, bool inches = false}) {
  final f = inches ? 2.54 : 1.0;
  String range(num min, num max) => inches ? '${(min / 2.54).round()} and ${(max / 2.54).round()} in' : '$min and $max cm';
  final errors = <String, String>{
    if (height != null && (height * f < bmiHeightCm.min || height * f > bmiHeightCm.max)) 'height': 'Enter a height between ${range(bmiHeightCm.min, bmiHeightCm.max)}',
    if (waist != null && (waist * f < waistCm.min || waist * f > waistCm.max)) 'waist': 'Enter a waist between ${range(waistCm.min, waistCm.max)}',
  };
  if (height == null || waist == null || errors.isNotEmpty) return (value: null, band: null, errors: errors);
  final v = (waist / height * 100).round() / 100;
  return (value: v, band: v < whtrCuts[0] ? 'No increased risk' : v < whtrCuts[1] ? 'Increased risk' : 'Very high risk', errors: errors);
}

// ---------------------------------------------------------------- screens

class BmiScreen extends StatefulWidget {
  const BmiScreen({super.key, this.heightCm, this.weightKg, this.age, this.leading});
  final num? heightCm, weightKg;
  final int? age;
  final Widget? leading; // the app menu when shown as a tab

  @override
  State<BmiScreen> createState() => _BmiScreenState();
}

class _BmiScreenState extends State<BmiScreen> {
  bool _imperial = false;
  late final _h = TextEditingController(text: _fmt(widget.heightCm));
  late final _w = TextEditingController(text: _fmt(widget.weightKg));
  late final _age = TextEditingController(text: widget.age?.toString() ?? '');
  final _ft = TextEditingController(), _in = TextEditingController(), _lb = TextEditingController();

  @override
  void dispose() {
    for (final x in [_h, _w, _age, _ft, _in, _lb]) {
      x.dispose();
    }
    super.dispose();
  }

  double? get _heightCm {
    if (!_imperial) return _num(_h.text);
    final ft = _num(_ft.text), inch = _num(_in.text);
    return ft == null && inch == null ? null : cmFromFeetInches(ft ?? 0, inch ?? 0);
  }

  double? get _weightKg => _imperial ? (_num(_lb.text) == null ? null : kgFromPounds(_num(_lb.text)!)) : _num(_w.text);

  /// Switching units carries what was typed across, so nothing has to be entered twice.
  void _switch(bool imperial) {
    final h = _heightCm, w = _weightKg;
    setState(() {
      _imperial = imperial;
      if (imperial) {
        final inches = h == null ? null : (h / 2.54).round();
        _ft.text = inches == null ? '' : '${inches ~/ 12}';
        _in.text = inches == null ? '' : '${inches % 12}';
        _lb.text = w == null ? '' : '${(w / 0.45359237).round()}';
      } else {
        _h.text = h == null ? '' : '${h.round()}';
        _w.text = w == null ? '' : _fmt((w * 10).round() / 10);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = bmiCheck(heightCm: _heightCm, weightKg: _weightKg, age: _age.text.trim().isEmpty ? null : int.tryParse(_age.text.trim()), imperial: _imperial);
    final v = r.value;
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    void refresh() => setState(() {});
    return _ToolPage(
      leading: widget.leading,
      title: 'BMI',
      eyebrow: 'TOOLS  ·  BODY MASS INDEX',
      children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('cm, kg')), ButtonSegment(value: true, label: Text('ft in, lb'))],
          selected: {_imperial},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            _switch(s.first);
          },
        ),
        const SizedBox(height: 20),
        if (_imperial)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Field(label: 'Height', unit: 'ft', controller: _ft, onChanged: refresh, error: r.errors['height'])),
            const SizedBox(width: 12),
            Expanded(child: _Field(label: '', unit: 'in', controller: _in, onChanged: refresh)),
          ])
        else
          _Field(label: 'Height', unit: 'cm', controller: _h, onChanged: refresh, error: r.errors['height']),
        _imperial
            ? _Field(label: 'Weight', unit: 'lb', controller: _lb, onChanged: refresh, error: r.errors['weight'])
            : _Field(label: 'Weight', unit: 'kg', controller: _w, onChanged: refresh, error: r.errors['weight']),
        _Field(label: 'Age', unit: 'years', controller: _age, onChanged: refresh, error: r.errors['age'], whole: true),
        _Result(
          value: v?.toStringAsFixed(1),
          unit: 'kg/m²',
          band: v == null ? null : r.band ?? 'No adult band under 18',
          scale: v == null || r.band == null ? null : (lo: 14, hi: 35, at: v, cuts: const [18, 23, 25]),
        ),
        if (r.note != null) ...[Text(r.note!, style: t.bodyMedium), const SizedBox(height: 16)],
        Text('Cut-offs for Asian Indians are lower than the WHO global ones (normal 18 to 22.9, not 18.5 to 24.9) because risk rises at a lower BMI. '
            'BMI cannot tell muscle from fat, so pair it with your waist.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Source: Misra et al., Consensus BMI cut-offs for Asian Indians, JAPI 2009;57:163.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

/// Waist check: waist-to-height ratio. Replaced the tape-measure body-fat estimate (US Navy method, 2026-10-14):
/// it needed neck, waist and hip measured to protocol, its source reports could not be retrieved to verify, its
/// categories were not validated thresholds, and the plan never used the number. Waist-to-height needs one tape
/// measurement and has a published risk boundary.
class WaistScreen extends StatefulWidget {
  const WaistScreen({super.key, this.heightCm, this.waistCm, this.leading});
  final Widget? leading;
  final num? heightCm, waistCm;

  @override
  State<WaistScreen> createState() => _WaistScreenState();
}

class _WaistScreenState extends State<WaistScreen> {
  bool _inches = false;
  late final _h = TextEditingController(text: _fmt(widget.heightCm));
  late final _waist = TextEditingController(text: _fmt(widget.waistCm));

  @override
  void dispose() {
    _h.dispose();
    _waist.dispose();
    super.dispose();
  }

  void _switch(bool inches) {
    // The ratio does not change with units; convert what is typed so the numbers stay true.
    double? conv(String s) => _num(s) == null ? null : (inches ? _num(s)! / 2.54 : _num(s)! * 2.54);
    final h = conv(_h.text), w = conv(_waist.text);
    setState(() {
      _inches = inches;
      _h.text = h == null ? '' : _fmt((h * 10).round() / 10);
      _waist.text = w == null ? '' : _fmt((w * 10).round() / 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final r = whtrCheck(height: _num(_h.text), waist: _num(_waist.text), inches: _inches);
    final unit = _inches ? 'in' : 'cm';
    void refresh() => setState(() {});
    return _ToolPage(
      leading: widget.leading,
      title: 'Waist check',
      eyebrow: 'TOOLS  ·  WAIST TO HEIGHT',
      children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('cm')), ButtonSegment(value: true, label: Text('inches'))],
          selected: {_inches},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            _switch(s.first);
          },
        ),
        const SizedBox(height: 20),
        _Field(label: 'Height', unit: unit, controller: _h, onChanged: refresh, error: r.errors['height']),
        _Field(label: 'Waist, midway between lowest rib and hip bone, breathing out', unit: unit, controller: _waist, onChanged: refresh, error: r.errors['waist']),
        _Result(
          value: r.value?.toStringAsFixed(2),
          unit: 'waist ÷ height',
          band: r.band,
          scale: r.value == null ? null : (lo: 0.3, hi: 0.8, at: r.value!, cuts: whtrCuts),
        ),
        Text('Keep your waist under half your height. Waist size tracks the fat around your organs better than weight alone, '
            'and it changes as you train even when the scale does not.', style: t.bodyMedium),
        const SizedBox(height: 12),
        Text('A screening number for adults, not a diagnosis. If yours is 0.5 or more, talk to a doctor about checking blood pressure, '
            'blood sugar and cholesterol.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Why no body-fat percentage? Tape-measure formulas need three or four measurements taken exactly, are only estimates, '
            'and their categories are not validated health thresholds. If you have a real measurement (DEXA or similar), log it in Progress.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Source: Ashwell and Gibson, BMJ Open 2016;6:e010159 (UK adults). Boundaries pending clinical review for Indian adults.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

// ---------------------------------------------------------------- parts

String _fmt(num? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');
double? _num(String s) => double.tryParse(s.trim());

class _ToolPage extends StatelessWidget {
  const _ToolPage({required this.title, required this.eyebrow, required this.children, this.leading});
  final String title, eyebrow;
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: leading),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              children: staggered([
                Text(eyebrow, style: monoLabel(context)),
                const SizedBox(height: 6),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                ...children,
              ]),
            ),
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.unit, required this.controller, required this.onChanged, this.error, this.whole = false});
  final String label, unit;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? error;
  final bool whole; // whole numbers only (age)

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FieldLabel(label),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType: TextInputType.numberWithOptions(decimal: !whole),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(whole ? r'^\d{0,3}$' : r'^\d{0,3}(\.\d?)?$'))],
            style: monoNumber(context, size: 18),
            decoration: InputDecoration(suffixText: unit, errorText: error, errorMaxLines: 2),
          ),
        ]),
      );
}

/// The answer plate: big number, its band, and where it sits on the scale.
class _Result extends StatelessWidget {
  const _Result({required this.value, required this.unit, required this.band, required this.scale});
  final String? value, band;
  final String unit;
  final ({double lo, double hi, double at, List<double> cuts})? scale;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ink = c.secondary, onInk = c.onSecondary;
    final s = scale;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.outline)),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(23)),
        child: AnimatedSwitcher(
          duration: motion(context, 320),
          switchInCurve: spring,
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
          child: value == null
              ? Text('Enter your measurements', key: const ValueKey('empty'), style: t.titleMedium?.copyWith(color: onInk.withValues(alpha: 0.6)))
              : Column(key: const ValueKey('value'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(value!, style: monoNumber(context, size: 48).copyWith(color: onInk)),
                    const SizedBox(width: 8),
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(unit, style: t.bodySmall?.copyWith(color: onInk.withValues(alpha: 0.6)))),
                  ]),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(band!.toUpperCase(), style: monoLabel(context).copyWith(color: onInk.withValues(alpha: 0.8))),
                  ]),
                  if (s != null) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 16,
                      width: double.infinity,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: ((s.at - s.lo) / (s.hi - s.lo)).clamp(0.0, 1.0)),
                        duration: motion(context, 600),
                        curve: spring,
                        builder: (_, v, _) => CustomPaint(
                          painter: _ScalePainter(at: v, cuts: [for (final x in s.cuts) (x - s.lo) / (s.hi - s.lo)], track: onInk.withValues(alpha: 0.18), mark: c.primary),
                        ),
                      ),
                    ),
                  ],
                ]),
        ),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({required this.at, required this.cuts, required this.track, required this.mark});
  final double at;
  final List<double> cuts;
  final Color track, mark;

  @override
  void paint(Canvas canvas, Size size) {
    final edges = [0.0, ...cuts, 1.0];
    for (var i = 0; i < edges.length - 1; i++) {
      final r = Rect.fromLTWH(size.width * edges[i], 5, math.max(0, size.width * (edges[i + 1] - edges[i]) - 3), 6);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = track);
    }
    final x = (size.width * at).clamp(5.0, size.width - 5);
    canvas.drawCircle(Offset(x, 8), 7, Paint()..color = mark);
  }

  @override
  bool shouldRepaint(_ScalePainter old) => old.at != at || old.track != track;
}

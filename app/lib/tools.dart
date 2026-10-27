// Fitness calculators. Formulas and cut-offs are cited on screen; nothing here is stored.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Body mass index, kg/m².
double bmi(double heightCm, double weightKg) => weightKg / math.pow(heightCm / 100, 2);

/// WHO adult classification (owner choice 2026-10-27, as calculator.net shows it): severe, moderate and mild
/// thinness under 16, 17 and 18.5; normal 18.5 to under 25; overweight to under 30; obese class I, II and III from
/// 30, 35 and 40. Pass the value already rounded to 1 dp (see [bmiCheck]) so the band matches the number shown.
String bmiBandWho(double v) => v < 16
    ? 'Severe thinness'
    : v < 17
        ? 'Moderate thinness'
        : v < 18.5
            ? 'Mild thinness'
            : v < 25
                ? 'Normal'
                : v < 30
                    ? 'Overweight'
                    : v < 35
                        ? 'Obese class I'
                        : v < 40
                            ? 'Obese class II'
                            : 'Obese class III';

/// The healthy BMI range (WHO normal) and the weights it gives for a height.
const healthyBmi = (min: 18.5, max: 25.0);
({double min, double max}) healthyWeightKg(double heightCm) {
  final m2 = math.pow(heightCm / 100, 2).toDouble();
  return (min: healthyBmi.min * m2, max: healthyBmi.max * m2);
}

/// BMI Prime: BMI divided by the upper limit of normal (25). Under 1 is within or below the normal range.
double bmiPrime(double bmiValue) => bmiValue / 25;

/// Ponderal index, kg/m³: weight over height cubed, which scales better than BMI for very short or tall people.
double ponderalIndex(double heightCm, double weightKg) => weightKg / math.pow(heightCm / 100, 3);

/// Same ranges as onboarding and the plan engine (validateInput).
const bmiHeightCm = (min: 120, max: 230), bmiWeightKg = (min: 30, max: 250);

double cmFromFeetInches(double feet, double inches) => (feet * 12 + inches) * 2.54;
double kgFromPounds(double lb) => lb * 0.45359237;

/// The calculator's whole decision, pure so it can be tested. Missing fields are not errors (not entered yet);
/// out-of-range ones are. The value is rounded to 1 dp before banding, exactly as the plan engine does (bmiOf),
/// so 24.96 shows "25.0 Overweight" in both places. The adult table applies from age 20, as on calculator.net.
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
  if (age != null && age < 20) {
    return (value: v, band: null, note: 'Under 20, BMI is read against BMI-for-age percentile charts (CDC), not the adult table. Ask a doctor to check it.', errors: errors);
  }
  return (value: v, band: bmiBandWho(v), note: null, errors: errors);
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
          band: v == null ? null : r.band ?? 'No adult band under 20',
          scale: v == null || r.band == null ? null : (lo: 14, hi: 42, at: v, cuts: const [16, 17, 18.5, 25, 30, 35, 40]),
        ),
        if (r.note != null) ...[Text(r.note!, style: t.bodyMedium), const SizedBox(height: 16)],
        if (v != null && r.band != null && _heightCm != null && _weightKg != null) ...[
          _Stat('Healthy BMI range', '${healthyBmi.min} to ${healthyBmi.max.toStringAsFixed(0)} kg/m²'),
          _Stat(
            'Healthy weight for your height',
            _imperial
                ? '${(healthyWeightKg(_heightCm!).min / 0.45359237).toStringAsFixed(1)} to ${(healthyWeightKg(_heightCm!).max / 0.45359237).toStringAsFixed(1)} lb'
                : '${healthyWeightKg(_heightCm!).min.toStringAsFixed(1)} to ${healthyWeightKg(_heightCm!).max.toStringAsFixed(1)} kg',
          ),
          _Stat('BMI Prime', bmiPrime(v).toStringAsFixed(2)),
          _Stat('Ponderal index', '${ponderalIndex(_heightCm!, _weightKg!).toStringAsFixed(1)} kg/m³'),
          const SizedBox(height: 12),
        ],
        Text('BMI cannot tell muscle from fat, so read it with how your training is going. For South Asian adults, health risk starts '
            'to rise at a lower BMI, from about 23 (WHO expert consultation, Lancet 2004), so keeping nearer the middle of the normal range helps.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Source: WHO adult BMI classification; BMI Prime and ponderal index as used by calculator.net.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

// ---------------------------------------------------------------- parts

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Text(value, style: monoNumber(context, size: 14)),
      ]),
    );
  }
}

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

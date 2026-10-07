// Fitness calculators. Formulas and cut-offs are cited on screen; nothing here is stored.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Body mass index, kg/m².
double bmi(double heightCm, double weightKg) => weightKg / math.pow(heightCm / 100, 2);

/// Asian Indian cut-offs (Misra et al., 2009): under 18, normal to 22.9, overweight to 24.9, obese from 25.
String bmiBandIndia(double v) => v < 18 ? 'Underweight' : v < 23 ? 'Normal' : v < 25 ? 'Overweight' : 'Obese';

/// US Navy circumference method (Hodgdon & Beckett, 1984), centimetres. Null when the tape values cannot be right.
double? navyBodyFat({required bool male, required double heightCm, required double neckCm, required double waistCm, double? hipCm}) {
  final double pct;
  if (male) {
    if (waistCm - neckCm <= 0) return null;
    pct = 495 / (1.0324 - 0.19077 * _log10(waistCm - neckCm) + 0.15456 * _log10(heightCm)) - 450;
  } else {
    if (hipCm == null || waistCm + hipCm - neckCm <= 0) return null;
    pct = 495 / (1.29579 - 0.35004 * _log10(waistCm + hipCm - neckCm) + 0.22100 * _log10(heightCm)) - 450;
  }
  return pct.isFinite && pct > 0 && pct < 75 ? pct : null;
}

double _log10(num x) => math.log(x) / math.ln10;

/// American Council on Exercise body-fat categories.
String bodyFatBand(double pct, {required bool male}) {
  final cuts = male ? [6, 14, 18, 25] : [14, 21, 25, 32];
  const names = ['Essential fat', 'Athletes', 'Fitness', 'Average', 'Obese'];
  for (var i = 0; i < cuts.length; i++) {
    if (pct < cuts[i]) return names[i];
  }
  return names.last;
}

// ---------------------------------------------------------------- screens

class BmiScreen extends StatefulWidget {
  const BmiScreen({super.key, this.heightCm, this.weightKg, this.leading});
  final num? heightCm, weightKg;
  final Widget? leading; // the app menu when shown as a tab

  @override
  State<BmiScreen> createState() => _BmiScreenState();
}

class _BmiScreenState extends State<BmiScreen> {
  late final _h = TextEditingController(text: _fmt(widget.heightCm));
  late final _w = TextEditingController(text: _fmt(widget.weightKg));

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _num(_h.text), w = _num(_w.text);
    final ok = h != null && w != null && h >= 100 && h <= 250 && w >= 25 && w <= 300;
    final v = ok ? bmi(h, w) : null;
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _ToolPage(
      leading: widget.leading,
      title: 'BMI',
      eyebrow: 'TOOLS  ·  BODY MASS INDEX',
      children: [
        _Field(label: 'Height', unit: 'cm', controller: _h, onChanged: () => setState(() {})),
        _Field(label: 'Weight', unit: 'kg', controller: _w, onChanged: () => setState(() {})),
        _Result(
          value: v?.toStringAsFixed(1),
          unit: 'kg/m²',
          band: v == null ? null : bmiBandIndia(v),
          scale: v == null ? null : (lo: 14, hi: 35, at: v, cuts: const [18, 23, 25]),
        ),
        Text('Cut-offs for Asian Indians are lower than the WHO global ones (normal 18 to 22.9, not 18.5 to 24.9) because risk rises at a lower BMI. '
            'BMI cannot tell muscle from fat, so pair it with your waist.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Source: Misra et al., Consensus BMI cut-offs for Asian Indians, JAPI 2009;57:163.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

class BodyFatScreen extends StatefulWidget {
  const BodyFatScreen({super.key, this.male, this.heightCm, this.waistCm, this.leading});
  final Widget? leading;
  final bool? male;
  final num? heightCm, waistCm;

  @override
  State<BodyFatScreen> createState() => _BodyFatScreenState();
}

class _BodyFatScreenState extends State<BodyFatScreen> {
  late bool _male = widget.male ?? true;
  late final _h = TextEditingController(text: _fmt(widget.heightCm));
  late final _waist = TextEditingController(text: _fmt(widget.waistCm));
  final _neck = TextEditingController();
  final _hip = TextEditingController();

  @override
  void dispose() {
    for (final x in [_h, _waist, _neck, _hip]) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final h = _num(_h.text), waist = _num(_waist.text), neck = _num(_neck.text), hip = _num(_hip.text);
    final pct = h == null || waist == null || neck == null || h < 100 ? null : navyBodyFat(male: _male, heightCm: h, neckCm: neck, waistCm: waist, hipCm: hip);
    final whtr = h == null || waist == null || h < 100 ? null : waist / h;
    void refresh() => setState(() {});
    return _ToolPage(
      leading: widget.leading,
      title: 'Body fat',
      eyebrow: 'TOOLS  ·  TAPE MEASURE METHOD',
      children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: true, label: Text('Male')), ButtonSegment(value: false, label: Text('Female'))],
          selected: {_male},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            setState(() => _male = s.first);
          },
        ),
        const SizedBox(height: 20),
        _Field(label: 'Height', unit: 'cm', controller: _h, onChanged: refresh),
        _Field(label: 'Neck, just below the larynx', unit: 'cm', controller: _neck, onChanged: refresh),
        _Field(label: _male ? 'Waist, at the navel' : 'Waist, at the narrowest point', unit: 'cm', controller: _waist, onChanged: refresh),
        AnimatedSize(
          duration: motion(context, 280),
          curve: spring,
          child: _male ? const SizedBox(width: double.infinity) : _Field(label: 'Hips, at the widest point', unit: 'cm', controller: _hip, onChanged: refresh),
        ),
        _Result(
          value: pct?.toStringAsFixed(1),
          unit: '% body fat',
          band: pct == null ? null : bodyFatBand(pct, male: _male),
          scale: pct == null ? null : (lo: 0, hi: 45, at: pct, cuts: _male ? const [6, 14, 18, 25] : const [14, 21, 25, 32]),
        ),
        if (whtr != null) ...[
          Text('WAIST TO HEIGHT', style: monoLabel(context)),
          const SizedBox(height: 6),
          Text('${whtr.toStringAsFixed(2)}  ·  ${whtr < 0.5 ? 'Healthy' : whtr < 0.6 ? 'Increased risk' : 'High risk'}', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Keep your waist under half your height.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 20),
        ],
        Text('An estimate, usually within 3 to 4 percentage points of a lab scan. Measure relaxed, tape level, same time of day, and track the trend rather than one reading.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Sources: Hodgdon and Beckett, Naval Health Research Center reports 84-11 and 84-29 (1984). Categories: American Council on Exercise. Waist to height: NICE (2022).',
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
  const _Field({required this.label, required this.unit, required this.controller, required this.onChanged});
  final String label, unit;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FieldLabel(label),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d?)?$'))],
            style: monoNumber(context, size: 18),
            decoration: InputDecoration(suffixText: unit),
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

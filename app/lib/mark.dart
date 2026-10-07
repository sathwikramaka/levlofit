// Levlofit mark ("L·o": L stroke + orange bubble) and wordmark ("levl" + bubble + "fit").
// Geometry matches brand/levlo-mark-on-*.svg (120 x 120 viewBox).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// DESIGN.md logo motion: bubble slides in and settles, about 1 s.
const _settle = Cubic(0.32, 0.72, 0, 1);

class LevloMark extends StatefulWidget {
  const LevloMark({super.key, this.size = 48, this.animate = false});
  final double size;
  final bool animate;

  @override
  State<LevloMark> createState() => _LevloMarkState();
}

class _LevloMarkState extends State<LevloMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000), value: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && !MediaQuery.disableAnimationsOf(context) && _c.value == 1) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Levlofit',
        image: true,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _MarkPainter(Theme.of(context).colorScheme.onSurface, _settle.transform(_c.value)),
          ),
        ),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.ink, this.t);
  final Color ink;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    canvas.drawPath(
      Path()
        ..moveTo(26, 26)
        ..lineTo(26, 94)
        ..lineTo(94, 94),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Bubble travels in from the right edge and settles at (70, 60).
    canvas.drawCircle(Offset(70 + 40 * (1 - t), 60), 16, Paint()..color = accent.withValues(alpha: t));
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.t != t || old.ink != ink;
}

class LevloWordmark extends StatelessWidget {
  const LevloWordmark({super.key, this.fontSize = 28});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final d = fontSize * 0.6; // bubble diameter close to Unbounded's x-height
    return Semantics(
      label: 'Levlofit',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'levl'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: fontSize * 0.06),
              child: Container(width: d, height: d, decoration: const BoxDecoration(color: accent, shape: BoxShape.circle)),
            ),
          ),
          const TextSpan(text: 'fit'),
        ]),
        style: GoogleFonts.unbounded(fontSize: fontSize, fontWeight: FontWeight.w700, letterSpacing: -fontSize * 0.025),
      ),
    );
  }
}

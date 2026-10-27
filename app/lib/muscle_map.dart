// Tappable front and back body map for the exercise library. Regions are the guide's muscle groups
// (exercise_guide.dart muscleRegions), drawn as simple shapes on a 100 x 220 figure; tapping one picks that group.
import 'package:flutter/material.dart';

/// One tappable shape: the guide group it stands for and its outline on the 100 x 220 figure.
typedef MapRegion = ({String group, RRect shape});

RRect _r(double l, double t, double w, double h, [double radius = 6]) => RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(radius));

// Mirrored pairs share a group, so a tap on either side selects it.
List<MapRegion> _pair(String group, double l, double t, double w, double h, [double radius = 6]) => [
      (group: group, shape: _r(l, t, w, h, radius)),
      (group: group, shape: _r(100 - l - w, t, w, h, radius)),
    ];

final frontRegions = <MapRegion>[
  ..._pair('Shoulders', 22, 38, 14, 14, 7),
  (group: 'Chest', shape: _r(36, 40, 28, 20)),
  ..._pair('Arms', 17, 54, 11, 46, 5),
  (group: 'Core', shape: _r(38, 62, 24, 34)),
  (group: 'Hips and glutes', shape: _r(34, 98, 32, 14)),
  ..._pair('Thighs', 33, 114, 15, 46),
  ..._pair('Calves', 34, 164, 12, 42),
];

final backRegions = <MapRegion>[
  ..._pair('Shoulders', 22, 38, 14, 14, 7),
  (group: 'Back', shape: _r(36, 40, 28, 40)),
  ..._pair('Arms', 17, 54, 11, 46, 5),
  (group: 'Core', shape: _r(38, 82, 24, 14)),
  (group: 'Hips and glutes', shape: _r(34, 98, 32, 18)),
  ..._pair('Thighs', 33, 118, 15, 42),
  ..._pair('Calves', 34, 164, 12, 42),
];

/// Front/back toggle plus the figure. [selected] is a guide group name or null.
class MuscleMap extends StatefulWidget {
  const MuscleMap({super.key, required this.selected, required this.onGroup});
  final String? selected;
  final ValueChanged<String> onGroup;

  @override
  State<MuscleMap> createState() => _MuscleMapState();
}

class _MuscleMapState extends State<MuscleMap> {
  bool _back = false;

  @override
  Widget build(BuildContext context) {
    final regions = _back ? backRegions : frontRegions;
    return Column(children: [
      SegmentedButton<bool>(
        segments: const [ButtonSegment(value: false, label: Text('Front')), ButtonSegment(value: true, label: Text('Back'))],
        selected: {_back},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _back = s.first),
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: 100 / 220,
        child: LayoutBuilder(builder: (context, box) {
          final scale = box.maxWidth / 100;
          return Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BodyPainter(regions: regions, selected: widget.selected, scheme: Theme.of(context).colorScheme),
              ),
            ),
            // One invisible button per region: hit testing and screen-reader labels without a custom hit test.
            for (final r in regions)
              Positioned(
                left: r.shape.left * scale,
                top: r.shape.top * scale,
                width: r.shape.width * scale,
                height: r.shape.height * scale,
                child: Semantics(
                  button: true,
                  selected: widget.selected == r.group,
                  label: r.group,
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.onGroup(r.group)),
                ),
              ),
          ]);
        }),
      ),
    ]);
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.regions, required this.selected, required this.scheme});
  final List<MapRegion> regions;
  final String? selected;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    // Visible on both themes: a light tint of the text colour, not a surface colour close to the background.
    final base = scheme.onSurface.withValues(alpha: 0.16);
    final skin = Paint()..color = scheme.onSurface.withValues(alpha: 0.08);
    final line = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    // Head, neck, hands and feet: not selectable, drawn for shape.
    canvas.drawCircle(const Offset(50, 20), 11, skin);
    canvas.drawCircle(const Offset(50, 20), 11, line);
    canvas.drawRRect(_r(45, 30, 10, 9, 3), skin);
    for (final x in [20.0, 80.0]) {
      canvas.drawCircle(Offset(x, 105), 4.5, skin);
    }
    for (final x in [40.0, 60.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 210), width: 14, height: 6), const Radius.circular(3)), skin);
    }
    for (final r in regions) {
      final on = r.group == selected;
      canvas.drawRRect(r.shape, Paint()..color = on ? scheme.primary : base);
      canvas.drawRRect(r.shape, line..color = on ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.selected != selected || old.regions != regions || old.scheme != scheme;
}

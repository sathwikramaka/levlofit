// Tappable front and back muscle map for the exercise library, drawn from anatomical outlines (muscle_shapes.dart).
// Each muscle belongs to one of the guide's groups (exercise_guide.dart muscleRegions); tapping it picks the group,
// and every muscle of the selected group lights up.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'muscle_shapes.dart';

const _canvas = Size(100, 220); // the back view's feet reach y = 220, past the source's 200-high viewBox

Path _path(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

Rect _bounds(List<double> xy) {
  var l = xy[0], t = xy[1], r = xy[0], b = xy[1];
  for (var i = 2; i < xy.length; i += 2) {
    l = l < xy[i] ? l : xy[i];
    r = r > xy[i] ? r : xy[i];
    t = t < xy[i + 1] ? t : xy[i + 1];
    b = b > xy[i + 1] ? b : xy[i + 1];
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// The selectable muscle at [point] (canvas units), or null. Inside a muscle outline first; failing that, within 2
/// units of one (thin muscles such as the forearms are hard to hit exactly with a finger).
MuscleShape? muscleAt(List<MuscleShape> shapes, Offset point) {
  for (final s in shapes) {
    if (s.group == null) continue;
    if (s.polygons.any((p) => _path(p).contains(point))) return s;
  }
  for (final s in shapes) {
    if (s.group == null) continue;
    if (s.polygons.any((p) => _bounds(p).inflate(2).contains(point))) return s;
  }
  return null;
}

/// The guide group at [point], or null (see [muscleAt]).
String? groupAt(List<MuscleShape> shapes, Offset point) => muscleAt(shapes, point)?.group;

/// Front/back toggle plus the figure. [selected] is a guide group name or null.
class MuscleMap extends StatefulWidget {
  const MuscleMap({super.key, required this.selected, required this.onGroup, this.onMuscle});
  final String? selected;
  final ValueChanged<String> onGroup;
  final ValueChanged<String>? onMuscle; // the tapped muscle's label (e.g. Trapezius); its group still goes to [onGroup]

  @override
  State<MuscleMap> createState() => _MuscleMapState();
}

class _MuscleMapState extends State<MuscleMap> {
  bool _back = false;

  @override
  Widget build(BuildContext context) {
    final shapes = _back ? backMuscles : frontMuscles;
    return Column(children: [
      SegmentedButton<bool>(
        segments: const [ButtonSegment(value: false, label: Text('Front')), ButtonSegment(value: true, label: Text('Back'))],
        selected: {_back},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _back = s.first),
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: _canvas.width / _canvas.height,
        child: LayoutBuilder(builder: (context, box) {
          final scale = box.maxWidth / _canvas.width;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final m = muscleAt(shapes, d.localPosition / scale);
              if (m == null) return;
              widget.onGroup(m.group!);
              widget.onMuscle?.call(m.label);
            },
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxWidth * _canvas.height / _canvas.width),
              painter: _BodyPainter(shapes: shapes, selected: widget.selected, scheme: Theme.of(context).colorScheme, onGroup: widget.onGroup),
            ),
          );
        }),
      ),
    ]);
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.shapes, required this.selected, required this.scheme, required this.onGroup});
  final List<MuscleShape> shapes;
  final String? selected;
  final ColorScheme scheme;
  final ValueChanged<String> onGroup;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _canvas.width);
    final muscle = Paint()..color = scheme.onSurface.withValues(alpha: 0.22);
    final other = Paint()..color = scheme.onSurface.withValues(alpha: 0.10);
    final on = Paint()..color = scheme.primary;
    final edge = Paint()
      ..color = scheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeJoin = StrokeJoin.round;
    for (final s in shapes) {
      final fill = s.group == null ? other : (s.group == selected ? on : muscle);
      for (final p in s.polygons) {
        final path = _path(p);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, edge);
      }
    }
  }

  // One node per guide group, over the union of its muscles, so screen readers can pick a group by name.
  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
        final k = size.width / _canvas.width;
        final byGroup = <String, Rect>{};
        for (final s in shapes) {
          final g = s.group;
          if (g == null) continue;
          for (final p in s.polygons) {
            final r = _bounds(p);
            byGroup[g] = byGroup[g]?.expandToInclude(r) ?? r;
          }
        }
        return [
          for (final e in byGroup.entries)
            CustomPainterSemantics(
              rect: Rect.fromLTRB(e.value.left * k, e.value.top * k, e.value.right * k, e.value.bottom * k),
              properties: SemanticsProperties(
                label: e.key,
                button: true,
                selected: e.key == selected,
                textDirection: ui.TextDirection.ltr,
                onTap: () => onGroup(e.key),
              ),
            ),
        ];
      };

  @override
  bool shouldRepaint(_BodyPainter old) => old.selected != selected || old.shapes != shapes || old.scheme != scheme;

  @override
  bool shouldRebuildSemantics(_BodyPainter old) => old.selected != selected || old.shapes != shapes;
}

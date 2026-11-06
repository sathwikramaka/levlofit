// The Diet tab's plate cards (redesign 2026-11-03, owner request: a diet section anyone can follow). Each meal is a
// small plate picture, the food in household servings, and two actions: Swap and Ate it. Grams and nutrients wait
// behind a tap. Interaction idea only from a public plate builder; text, data and look are Levlofit's own.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'diet_plan.dart';
import 'icons.dart';
import 'theme.dart';

/// A quiet card above or below the meals: a label and short lines. Training day and supplements use it.
class PlateInfoCard extends StatelessWidget {
  const PlateInfoCard({super.key, required this.title, required this.lines});
  final String title;
  final List<({String? name, String text})> lines;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: monoLabel(context).copyWith(color: c.tertiary)),
        for (final l in lines) ...[
          const SizedBox(height: 6),
          if (l.name != null) Text(l.name!, style: t.titleSmall),
          Text(l.text, style: l.name == null ? t.bodyMedium : t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// The plate parts in drawing order, with their names for the key under the meals.
const plateParts = [('grain', 'Grain'), ('protein', 'Protein'), ('veg', 'Veg'), ('fruit', 'Fruit and milk')];

/// Fill per plate part, from the theme only: accent for grain, ink for protein, the muted text tone for veg, the
/// raised surface for fruit and milk. The same four in light and dark.
Color plateColor(BuildContext context, String part) {
  final c = Theme.of(context).colorScheme;
  return switch (part) {
    'grain' => c.primary,
    'protein' => c.secondary,
    'veg' => c.onSurfaceVariant,
    _ => c.surfaceContainerHighest,
  };
}

/// A round plate split by [shares] (plateShares), drawn as wedges from twelve o'clock.
class PlatePicture extends StatelessWidget {
  const PlatePicture({super.key, required this.shares, this.size = 52});
  final Map<String, double> shares;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Plate: ${[for (final (k, name) in plateParts)
          if ((shares[k] ?? 0) >= 0.05) '$name ${((shares[k]!) * 100).round()}%'].join(', ')}',
    child: CustomPaint(
      size: Size.square(size),
      painter: _PlatePainter([for (final (k, _) in plateParts) (shares[k] ?? 0, plateColor(context, k))], Theme.of(context).colorScheme.outline),
    ),
  );
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.parts, this.rim);
  final List<(double, Color)> parts;
  final Color rim;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    var start = -math.pi / 2;
    for (final (share, color) in parts) {
      if (share <= 0) continue;
      final sweep = share * 2 * math.pi;
      canvas.drawArc(r, start, sweep, true, Paint()..color = color);
      start += sweep;
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = rim,
    );
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.parts.toString() != parts.toString() || old.rim != rim;
}

/// The key under the meals: what each plate colour means.
class PlateKey extends StatelessWidget {
  const PlateKey({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (k, name) in plateParts)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: plateColor(context, k),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: c.outline),
                ),
              ),
              const SizedBox(width: 6),
              Text(name, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ],
          ),
        Text('Plate shows where the energy comes from.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

/// One meal: plate, servings, a short note, Swap and Ate it; tap for grams and nutrients.
/// [onAte] is null when the meal is not today's (only today can be logged); [logged] once it is in the diary.
class PlateMealCard extends StatefulWidget {
  const PlateMealCard({super.key, required this.meal, this.tag, this.notes = const [], this.onSwap, this.onAte, this.logged = false});
  final PlanMeal meal;
  final String? tag; // PRE-WORKOUT or POST-WORKOUT, FROM THE MESS
  final List<String> notes;
  final VoidCallback? onSwap;
  final Future<void> Function()? onAte;
  final bool logged;

  @override
  State<PlateMealCard> createState() => _PlateMealCardState();
}

class _PlateMealCardState extends State<PlateMealCard> {
  bool _open = false, _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final m = widget.meal;
    final food = m.items.where((i) => i.unit != 'oil').toList(); // oil is shown once for the whole day
    final kcal = m.items.fold(0.0, (s, i) => s + i.kcal), protein = m.items.fold(0.0, (s, i) => s + i.protein);
    // The dashboard tile (dashboard.dart _Tile): surface, outline, 22 radius, pressable.
    return Pressable(
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _open = !_open);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PlatePicture(shares: plateShares(m)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: t.titleLarge),
                          Text([m.time.toUpperCase(), ?widget.tag].join('  ·  '), style: monoLabel(context).copyWith(color: c.tertiary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${kcal.round()} kcal', style: monoNumber(context, size: 16)),
                        Text('${protein.round()} g protein', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final i in food)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _open
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text(servingLabel(i), style: t.bodyLarge)),
                              const SizedBox(width: 10),
                              Text(
                                '${exactLabel(i)}\n${i.kcal.round()} kcal · P ${i.protein.toStringAsFixed(1)} g',
                                textAlign: TextAlign.right,
                                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                              ),
                            ],
                          )
                        : Text(servingLabel(i), style: t.bodyLarge),
                  ),
                for (final n in widget.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(n, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (widget.onSwap != null)
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          widget.onSwap!();
                        },
                        icon: const Icon(LvIcons.arrowsClockwise, size: 16),
                        label: const Text('Swap'),
                      ),
                    const Spacer(),
                    if (widget.logged)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LvIcons.checkCircle, size: 18, color: c.primary),
                            const SizedBox(width: 6),
                            Text('IN YOUR DIARY', style: monoLabel(context)),
                          ],
                        ),
                      )
                    else if (widget.onAte != null)
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await widget.onAte!();
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: Text(_busy ? 'Logging...' : 'Ate it'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

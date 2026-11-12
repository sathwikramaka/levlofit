// Choices for the session screen, kept on this phone (owner request 2026-11-12): keep the screen on, the rest length,
// sound and flash when rest ends, and how big the exercise animations are.
import 'package:flutter/material.dart';

import 'main.dart' show prefs;
import 'theme.dart';

enum Animations { full, small, hidden }

typedef WorkoutPrefs = ({bool awake, int? rest, bool sounds, bool flash, Animations animations});

/// Defaults: screen on, rest set per move (null), sound on, no flash, full animations.
const defaultWorkoutPrefs = (awake: true, rest: null, sounds: true, flash: false, animations: Animations.full);

/// Rest choices in seconds; null is "by move" (2 min after main lifts, 90 s after the rest).
const restChoices = <int?>[null, 60, 90, 120, 180];

WorkoutPrefs loadWorkoutPrefs() {
  try {
    final r = prefs.getInt('wo_rest');
    return (
      awake: prefs.getBool('wo_awake') ?? true,
      rest: restChoices.contains(r) ? r : null,
      sounds: prefs.getBool('wo_sounds') ?? true,
      flash: prefs.getBool('wo_flash') ?? false,
      animations: Animations.values.asNameMap()[prefs.getString('wo_anim')] ?? Animations.full,
    );
  } catch (_) {
    return defaultWorkoutPrefs; // no local storage (tests)
  }
}

Future<void> saveWorkoutPrefs(WorkoutPrefs p) async {
  await prefs.setBool('wo_awake', p.awake);
  p.rest == null ? await prefs.remove('wo_rest') : await prefs.setInt('wo_rest', p.rest!);
  await prefs.setBool('wo_sounds', p.sounds);
  await prefs.setBool('wo_flash', p.flash);
  await prefs.setString('wo_anim', p.animations.name);
}

String restLabel(int? s) => s == null ? 'By move' : s % 60 == 0 ? '${s ~/ 60} min' : '$s s';

/// The "During a workout" group in Settings.
class WorkoutPrefsSection extends StatefulWidget {
  const WorkoutPrefsSection({super.key});

  @override
  State<WorkoutPrefsSection> createState() => _WorkoutPrefsSectionState();
}

class _WorkoutPrefsSectionState extends State<WorkoutPrefsSection> {
  WorkoutPrefs _p = loadWorkoutPrefs();

  void _set(WorkoutPrefs p) {
    setState(() => _p = p);
    saveWorkoutPrefs(p);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final p = _p;
    Widget toggle(String title, String sub, bool v, WorkoutPrefs Function(bool) next) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: t.bodyLarge),
          subtitle: Text(sub, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          value: v,
          onChanged: (x) => _set(next(x)),
        );
    WorkoutPrefs w({bool? awake, int? rest, bool restSet = false, bool? sounds, bool? flash, Animations? animations}) =>
        (awake: awake ?? p.awake, rest: restSet ? rest : p.rest, sounds: sounds ?? p.sounds, flash: flash ?? p.flash, animations: animations ?? p.animations);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DURING A WORKOUT', style: monoLabel(context)),
      const SizedBox(height: 4),
      toggle('Keep screen on', 'No unlocking the phone between sets while a session is open.', p.awake, (x) => w(awake: x)),
      toggle('Sound when rest ends', 'A short chime; the phone always vibrates.', p.sounds, (x) => w(sounds: x)),
      toggle('Flash when rest ends', 'The screen flashes orange once, for a noisy gym.', p.flash, (x) => w(flash: x)),
      const SizedBox(height: 8),
      Text('Rest between sets', style: t.bodyLarge),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in restChoices)
          ChoiceChip(label: Text(restLabel(r)), selected: p.rest == r, onSelected: (_) => _set(w(rest: r, restSet: true))),
      ]),
      const SizedBox(height: 4),
      Text('By move: 2 min after main lifts, 90 s after the rest. You can still add or skip time during rest.',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      const SizedBox(height: 14),
      Text('Exercise animations', style: t.bodyLarge),
      const SizedBox(height: 6),
      SegmentedButton<Animations>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: Animations.full, label: Text('Full')),
          ButtonSegment(value: Animations.small, label: Text('Small')),
          ButtonSegment(value: Animations.hidden, label: Text('Hidden')),
        ],
        selected: {p.animations},
        onSelectionChanged: (s) => _set(w(animations: s.first)),
      ),
    ]);
  }
}

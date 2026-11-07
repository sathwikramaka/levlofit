// Daily check-in (roadmap Stage 3, brief 5.2): how today went, every answer optional and editable. One row per day in
// daily_checkins (migration 20261103300000), own-row only. Stored and shown back; no plan rule reads it yet, and it is
// not sent to the AI coach.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'main.dart';
import 'theme.dart';

typedef CheckIn = Map<String, dynamic>; // keys: workout, food, energy, sleep, soreness, note (any may be missing)
typedef CheckInStore = ({Future<CheckIn?> Function(String day) load, Future<void> Function(String day, CheckIn answers) save});

String _isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final CheckInStore supabaseCheckIns = (
  load: (day) async => await supabase.from('daily_checkins').select('workout, food, energy, sleep, soreness, note').eq('day', day).maybeSingle(),
  // Upsert on (user_id, day): a second save the same day edits the row. Unanswered questions are sent as null, so
  // clearing an answer clears it.
  save: (day, answers) => supabase.from('daily_checkins').upsert({'day': day, ...answers, 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'user_id,day'),
);

const workoutAnswers = [('done', 'Trained'), ('partly', 'Partly'), ('skipped', 'Skipped'), ('rest', 'Rest day')];
const foodAnswers = [('followed', 'Followed it'), ('partly', 'Partly'), ('not', 'Not today')];
const sorenessAnswers = [(0, 'None'), (1, 'A little'), (2, 'Sore'), (3, 'Very sore')];

/// One line for the card, from whatever was answered. Neutral wording: a skipped day is a fact, not a failure.
String checkInSummary(CheckIn? c) {
  if (c == null) return '';
  String? label<T>(List<(T, String)> options, Object? v) => options.where((o) => o.$1 == v).firstOrNull?.$2;
  return [
    if (label(workoutAnswers, c['workout']) case final w?) 'Training: ${w.toLowerCase()}',
    if (label(foodAnswers, c['food']) case final f?) 'Food plan: ${f.toLowerCase()}',
    if (c['energy'] != null) 'Energy ${c['energy']}/5',
    if (c['sleep'] != null) 'Sleep ${c['sleep']}/5',
    if (label(sorenessAnswers, c['soreness']) case final s?) 'Soreness: ${s.toLowerCase()}',
  ].join('  ·  ');
}

/// True when nothing in the check-in is answered (an empty save is not worth a row).
bool checkInEmpty(CheckIn c) => c.values.every((v) => v == null || (v is String && v.trim().isEmpty));

class CheckInCard extends StatefulWidget {
  const CheckInCard({super.key, this.store, this.now});
  final CheckInStore? store; // tests only
  final DateTime Function()? now; // tests only

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  late final CheckInStore _store = widget.store ?? supabaseCheckIns;
  // Today is read again on every load and tap: the dashboard can stay open past midnight, and a check-in made at
  // 00:10 belongs to the new day.
  String get _today => _isoDay((widget.now ?? DateTime.now)());
  late String _day = _today;
  CheckIn? _answers;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _day = _today;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final a = await _store.load(_day);
      if (mounted) setState(() => _answers = a);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    if (_today != _day) await _load(); // a new day: start from that day's answers (usually none)
    if (!mounted || _failed) return;
    final day = _day;
    final saved = await showModalBottomSheet<CheckIn>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CheckInSheet(initial: _answers, onSave: (a) => _store.save(day, a)),
    );
    if (saved != null && mounted) setState(() => _answers = saved);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final summary = checkInSummary(_answers);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Icon(summary.isEmpty ? LvIcons.notePencil : LvIcons.checkCircle, size: 20, color: summary.isEmpty ? c.onSurface : c.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DAILY CHECK-IN', style: monoLabel(context)),
            const SizedBox(height: 2),
            if (_loading)
              Text('Loading…', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))
            else if (_failed)
              Text('Could not load. Tap to try again.', style: t.bodySmall?.copyWith(color: c.error))
            else if (summary.isEmpty)
              Text('How did today go? Optional, takes 20 seconds.', style: t.bodyMedium)
            else
              Text(summary, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
        ),
        Icon(summary.isEmpty ? LvIcons.caretRight : LvIcons.pencilSimple, size: 16, color: c.onSurfaceVariant),
      ]),
    );
    return Pressable(
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius), side: BorderSide(color: c.outline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: _loading ? null : (_failed ? _load : _open), child: Semantics(button: true, label: 'Daily check-in', child: body)),
      ),
    );
  }
}

class CheckInSheet extends StatefulWidget {
  const CheckInSheet({super.key, this.initial, required this.onSave});
  final CheckIn? initial;
  final Future<void> Function(CheckIn answers) onSave;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  late final CheckIn _a = {
    for (final k in const ['workout', 'food', 'energy', 'sleep', 'soreness']) k: widget.initial?[k],
  };
  late final _note = TextEditingController(text: widget.initial?['note'] as String? ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _note.text.trim();
    final answers = {..._a, 'note': note.isEmpty ? null : note};
    if (checkInEmpty(answers) && widget.initial == null) return Navigator.pop(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(answers);
      HapticFeedback.selectionClick();
      if (mounted) Navigator.pop(context, answers);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chips<T>(String key, List<(T, String)> options) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (v, label) in options)
          ChoiceChip(label: Text(label), selected: _a[key] == v, onSelected: (on) => setState(() => _a[key] = on ? v : null)),
      ]);

  List<(int, String)> _scale(String low, String high) => [for (var i = 1; i <= 5; i++) (i, i == 1 ? '1 $low' : i == 5 ? '5 $high' : '$i')];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    Widget q(String text) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(text, style: t.bodyMedium));
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How did today go?', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Answer any, skip any. You can change it later today.', style: t.bodySmall),
          q('Training'),
          _chips('workout', workoutAnswers),
          q('Food plan'),
          _chips('food', foodAnswers),
          q('Energy'),
          _chips('energy', _scale('low', 'high')),
          q('Sleep last night'),
          _chips('sleep', _scale('poor', 'great')),
          q('Muscle soreness'),
          _chips('soreness', sorenessAnswers),
          if (_a['soreness'] == 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Go easier today. Sharp pain, swelling, or pain that lasts more than a few days is worth showing a physiotherapist or doctor.',
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ),
          q('Note (only you see it)'),
          TextField(controller: _note, maxLength: 500, maxLines: 2, minLines: 1, decoration: const InputDecoration(hintText: 'Optional')),
          if (_error != null) ErrorLine(_error!),
          const SizedBox(height: 8),
          Row(children: [
            TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            const Spacer(),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
          ]),
        ]),
      ),
    );
  }
}

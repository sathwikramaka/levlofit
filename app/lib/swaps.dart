// Coach action "swap today's exercise" (batch 3a; table exercise_swaps). Levlofit AI can propose replacing one move
// of today's session; the server checks it against the catalogue, the person's equipment and their injuries, and
// the app shows a Swap / Not now card. Today's session changes only after Swap, which the server checks again before
// confirming. The app can read and delete its own swaps but never write them.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'food_diary.dart' show isoDay;
import 'main.dart';
import 'theme.dart';

typedef SwapProposal = ({int id, String day, String fromId, String fromName, String toId, String toName});

/// The proposal in a coach-chat reply, or null when there is none or it is malformed.
SwapProposal? swapFromJson(Object? j) {
  if (j is! Map) return null;
  final from = j['from'], to = j['to'];
  if (j['id'] is! int || j['day'] is! String || from is! Map || to is! Map) return null;
  if (from['id'] is! String || to['id'] is! String) return null;
  return (
    id: j['id'] as int,
    day: j['day'] as String,
    fromId: from['id'] as String,
    fromName: (from['name'] ?? from['id']) as String,
    toId: to['id'] as String,
    toName: (to['name'] ?? to['id']) as String,
  );
}

/// [ids] with each confirmed swap applied (from -> to), keeping order and dropping a repeat a swap would create.
List<String> applySwaps(List<String> ids, Map<String, String> swaps) {
  if (swaps.isEmpty) return ids;
  final out = <String>[];
  for (final id in ids) {
    final use = swaps[id] ?? id;
    if (!out.contains(use)) out.add(use);
  }
  return out;
}

/// Today's session as the dashboard last built it (before swaps): sent with chat messages so the coach can offer
/// swaps for exactly these moves, or a move to one of [restDays] (later free days this week). Null until the
/// dashboard has shown a training day.
({String day, List<String> ids, List<String> restDays})? todaySession;

/// Bumped after a swap is confirmed, so the dashboard reloads today's session.
final swapsChanged = ValueNotifier<int>(0);

/// Data access. Widgets take it as a parameter so tests can supply their own. [confirm] returns null when the swap
/// was made, else the reason to show.
typedef SwapApi = ({
  Future<String?> Function(int id) confirm,
  Future<void> Function(int id) dismiss,
  Future<String?> Function(int id) confirmChange,
  Future<void> Function(int id) dismissChange,
  Future<void> Function(MealProposal meal) logMeal, // writes the person's own diary entries, after Log it
});

/// Asks coach-chat to confirm a proposal ({'confirmSwap': id} or {'confirmChange': id}); null when done.
Future<String?> _confirmOnServer(Map<String, Object> body) async {
  try {
    await supabase.functions.invoke('coach-chat', body: body);
    swapsChanged.value++;
    return null;
  } on FunctionException catch (e) {
    final d = e.details;
    return d is Map && d['error'] is String ? d['error'] as String : 'Could not make the change. Try again.';
  }
}

final SwapApi supabaseSwaps = (
  confirm: (id) => _confirmOnServer({'confirmSwap': id}),
  dismiss: (id) => supabase.from('exercise_swaps').delete().eq('id', id),
  confirmChange: (id) => _confirmOnServer({'confirmChange': id}),
  dismissChange: (id) => supabase.from('session_changes').delete().eq('id', id),
  // Today on this phone: the diary day the person sees.
  logMeal: (m) => supabase.from('food_log').insert([
        for (final i in m.items) {'day': isoDay(DateTime.now()), 'meal': m.meal, 'food_code': i.code, 'grams': i.grams},
      ]),
);

/// A meal the coach proposes from the person's own diary foods (batch 3d), checked by the server; nothing is
/// written until the person taps Log it.
typedef MealProposal = ({String meal, List<({String code, String name, double grams})> items});

MealProposal? mealFromJson(Object? j) {
  if (j is! Map || j['meal'] is! String || j['items'] is! List) return null;
  if (!const ['breakfast', 'lunch', 'dinner', 'snack'].contains(j['meal'])) return null;
  final items = <({String code, String name, double grams})>[];
  for (final i in j['items'] as List) {
    if (i is! Map || i['code'] is! String || i['name'] is! String || i['grams'] is! num) return null;
    final g = (i['grams'] as num).toDouble();
    if (g <= 0 || g > 2000) return null;
    items.add((code: i['code'] as String, name: i['name'] as String, grams: g));
  }
  return items.isEmpty || items.length > 6 ? null : (meal: j['meal'] as String, items: items);
}

String _grams(double g) => '${g % 1 == 0 ? g.toInt() : g} g';

/// The card for a proposed meal. Nothing is logged until the person taps Log it.
class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.proposal, required this.api});
  final MealProposal proposal;
  final SwapApi api;

  @override
  Widget build(BuildContext context) {
    final meal = '${proposal.meal[0].toUpperCase()}${proposal.meal.substring(1)}';
    return _ActionCard(
      label: 'LOG THIS MEAL?',
      line: '$meal: ${proposal.items.map((i) => '${i.name} ${_grams(i.grams)}').join(', ')}',
      note: 'Amounts are estimates: change them in your food diary any time.',
      confirmText: 'Log it',
      doneText: 'Logged to today\'s food diary.',
      onConfirm: () async {
        await api.logMeal(proposal);
        return null;
      },
      onDismiss: () async {}, // nothing was stored
    );
  }
}

/// Whether the person confirmed a lighter session for [day]. False when the read fails.
Future<bool> loadLighter(String day) async {
  try {
    final rows = await supabase.from('session_changes').select('id').eq('day', day).eq('kind', 'lighter').eq('status', 'confirmed').limit(1);
    return rows.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Confirmed swaps for [day] (YYYY-MM-DD) as from -> to. Empty when the read fails: the session is then shown as planned.
Future<Map<String, String>> loadSwaps(String day) async {
  try {
    final rows = await supabase.from('exercise_swaps').select('from_exercise, to_exercise').eq('day', day).eq('status', 'confirmed');
    return {for (final r in rows) r['from_exercise'] as String: r['to_exercise'] as String};
  } catch (_) {
    return const {};
  }
}

/// The card under a coach reply that proposes a swap. Nothing changes until Swap is tapped.
class SwapCard extends StatelessWidget {
  const SwapCard({super.key, required this.proposal, required this.api});
  final SwapProposal proposal;
  final SwapApi api;

  @override
  Widget build(BuildContext context) => _ActionCard(
        key: ValueKey('swap-${proposal.id}'),
        label: "SWAP TODAY'S MOVE?",
        line: '${proposal.fromName} → ${proposal.toName}',
        note: 'Checked against your equipment and injury notes. Stop any move that hurts.',
        confirmText: 'Swap',
        doneText: "Swapped. Today's session now has ${proposal.toName}.",
        onConfirm: () => api.confirm(proposal.id),
        onDismiss: () => api.dismiss(proposal.id),
      );
}

/// A whole-session change the coach proposes (table session_changes): a lighter day, or a move to [toDay].
typedef ChangeProposal = ({int id, String kind, String day, String? toDay});

ChangeProposal? changeFromJson(Object? j) {
  if (j is! Map || j['id'] is! int || j['day'] is! String) return null;
  return switch (j['kind']) {
    'lighter' => (id: j['id'] as int, kind: 'lighter', day: j['day'] as String, toDay: null),
    'move' when j['toDay'] is String => (id: j['id'] as int, kind: 'move', day: j['day'] as String, toDay: j['toDay'] as String),
    _ => null,
  };
}

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "Thursday" for a YYYY-MM-DD date.
String weekdayName(String day) => _weekdayNames[DateTime.parse(day).weekday - 1];

/// The card for a lighter day or a moved session. Nothing changes until the person confirms.
class LighterCard extends StatelessWidget {
  const LighterCard({super.key, required this.proposal, required this.api});
  final ChangeProposal proposal;
  final SwapApi api;

  @override
  Widget build(BuildContext context) => proposal.kind == 'move'
      ? _ActionCard(
          key: ValueKey('change-${proposal.id}'),
          label: "MOVE TODAY'S SESSION?",
          line: 'Train on ${weekdayName(proposal.toDay!)} instead; today becomes a rest day.',
          note: 'Only this week changes. Your reminders keep the usual days.',
          confirmText: 'Move',
          doneText: "Moved to ${weekdayName(proposal.toDay!)}.",
          onConfirm: () => api.confirmChange(proposal.id),
          onDismiss: () => api.dismissChange(proposal.id),
        )
      : _ActionCard(
          key: ValueKey('change-${proposal.id}'),
          label: 'MAKE TODAY LIGHTER?',
          line: 'One set fewer on each move, 3 or more reps in reserve.',
          note: 'Pain, dizziness or feeling ill: rest instead and see a doctor.',
          confirmText: 'Make it lighter',
          doneText: "Done. Today's session is lighter.",
          onConfirm: () => api.confirmChange(proposal.id),
          onDismiss: () => api.dismissChange(proposal.id),
        );
}

/// Confirmed moves of this week's sessions as (from weekday, to weekday), 1 = Monday. Empty when the read fails.
Future<List<(int, int)>> loadSessionMoves(String monday, String sunday) async {
  try {
    final rows = await supabase.from('session_changes').select('day, to_day').eq('kind', 'move').eq('status', 'confirmed').gte('day', monday).lte('day', sunday);
    return [for (final r in rows) if (r['to_day'] is String) (DateTime.parse(r['day'] as String).weekday, DateTime.parse(r['to_day'] as String).weekday)];
  } catch (_) {
    return const [];
  }
}

/// The weekday whose planned session shows on [weekday] after this week's [moves]: the one moved here, none when
/// today's session moved away, else today's own (null on a rest day).
int? sessionDayFor(int weekday, Set<int> trainingDays, List<(int, int)> moves) {
  for (final (from, to) in moves) {
    if (to == weekday) return from;
  }
  if (moves.any((m) => m.$1 == weekday)) return null;
  return trainingDays.contains(weekday) ? weekday : null;
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    super.key,
    required this.label,
    required this.line,
    required this.note,
    required this.confirmText,
    required this.doneText,
    required this.onConfirm,
    required this.onDismiss,
  });
  final String label, line, note, confirmText, doneText;
  final Future<String?> Function() onConfirm; // null when done, else the reason to show
  final Future<void> Function() onDismiss;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  String? _outcome; // shown instead of the buttons once answered
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    String? error;
    try {
      error = await widget.onConfirm();
    } catch (_) {
      error = 'Could not make the change. Try again.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) _outcome = widget.doneText;
    });
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _notNow() async {
    setState(() => _busy = true);
    try {
      await widget.onDismiss();
    } catch (_) {
      // An unanswered proposal changes nothing and is replaced by the next one.
    }
    if (mounted) setState(() => (_busy = false, _outcome = 'Kept as planned.'));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.label, style: monoLabel(context)),
        const SizedBox(height: 4),
        Text(widget.line, style: t.bodyMedium),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.note, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
        if (_outcome case final done?)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(done, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)))
        else
          Wrap(spacing: 4, children: [
            TextButton(onPressed: _busy ? null : _confirm, child: Text(widget.confirmText)),
            TextButton(onPressed: _busy ? null : _notNow, child: const Text('Not now')),
          ]),
      ]),
    );
  }
}

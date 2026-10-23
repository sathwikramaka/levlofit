// Levlofit AI memory the person controls (table coach_facts). The coach can only suggest a fact; nothing is used in
// later chats until the person confirms it here or on the suggestion card under a reply. Every fact can be edited
// or deleted. Rows are owner-only (row level security), and deleting the account deletes them.
import 'package:flutter/material.dart';

import 'icons.dart';
import 'main.dart';
import 'theme.dart';

typedef Fact = ({int id, String category, String fact, bool confirmed});

const factCategories = ['injury', 'schedule', 'equipment', 'preference', 'goal', 'other'];

Fact factFromRow(Map<dynamic, dynamic> r) => (
      id: r['id'] as int,
      category: factCategories.contains(r['category']) ? r['category'] as String : 'other',
      fact: r['fact'] as String,
      confirmed: r['status'] == 'confirmed',
    );

/// Data access. Screens take these as a parameter so tests can supply their own.
typedef MemoryApi = ({
  Future<List<Fact>> Function() list,
  Future<void> Function(int id) confirm,
  Future<void> Function(int id, String category, String fact, {required bool confirm}) save,
  Future<void> Function(int id) remove,
  Future<void> Function() removeAll,
});

final MemoryApi supabaseMemory = (
  list: () async => [
        for (final r in await supabase.from('coach_facts').select('id, category, fact, status').order('id', ascending: true).limit(500)) factFromRow(r),
      ],
  confirm: (id) => supabase.from('coach_facts').update({'status': 'confirmed'}).eq('id', id),
  save: (id, category, fact, {required confirm}) =>
      supabase.from('coach_facts').update({'category': category, 'fact': fact, if (confirm) 'status': 'confirmed'}).eq('id', id),
  remove: (id) => supabase.from('coach_facts').delete().eq('id', id),
  // Also clears the free-text notes kept from before facts existed (no longer used by the coach).
  removeAll: () async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('coach_facts').delete().eq('user_id', uid);
    await supabase.from('coach_notes').delete().eq('user_id', uid);
  },
);

String categoryLabel(String c) => '${c[0].toUpperCase()}${c.substring(1)}';

/// Edit a fact's words and kind. Returns the new values, or null when cancelled. [action] names the save button.
Future<({String category, String fact})?> editFact(BuildContext context, Fact f, {required String action}) {
  final text = TextEditingController(text: f.fact);
  var category = f.category;
  return showDialog<({String category, String fact})>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) {
        final words = text.text.trim();
        final valid = words.length >= 3 && words.length <= 200;
        return AlertDialog(
          title: const Text('Edit what Levlofit AI remembers'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: [for (final c in factCategories) DropdownMenuItem(value: c, child: Text(categoryLabel(c)))],
              onChanged: (v) => set(() => category = v ?? category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              maxLength: 200,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Fact'),
              onChanged: (_) => set(() {}),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
            FilledButton(onPressed: valid ? () => Navigator.pop(dialog, (category: category, fact: words)) : null, child: Text(action)),
          ],
        );
      },
    ),
  );
}

/// The person's memory: what is used in chats (confirmed) and what waits for their OK (suggested).
class MemorySheet extends StatefulWidget {
  const MemorySheet({super.key, required this.api});
  final MemoryApi api;

  @override
  State<MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<MemorySheet> {
  List<Fact>? _facts;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final facts = await widget.api.list();
      if (mounted) {
        setState(() {
          _facts = facts;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your memory. Try again.');
    }
  }

  /// Runs a change, then reloads, so the list always shows what is stored.
  Future<void> _do(Future<void> Function() change, String failure) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await change();
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _edit(Fact f) async {
    final out = await editFact(context, f, action: f.confirmed ? 'Save' : 'Save and remember');
    if (out == null) return;
    await _do(() => widget.api.save(f.id, out.category, out.fact, confirm: true), 'Could not save that change.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final facts = _facts;
    final confirmed = facts?.where((f) => f.confirmed).toList() ?? const <Fact>[];
    final waiting = facts?.where((f) => !f.confirmed).toList() ?? const <Fact>[];
    Widget section(String label, String note, List<Fact> list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          Text(label, style: monoLabel(context)),
          Text(note, style: t.bodySmall?.copyWith(color: muted)),
          for (final f in list)
            ListTile(
              key: ValueKey('fact-${f.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(f.fact),
              subtitle: Text(categoryLabel(f.category)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!f.confirmed)
                  IconButton(
                    tooltip: 'Remember this',
                    icon: const Icon(LvIcons.check, size: 20),
                    onPressed: _working ? null : () => _do(() => widget.api.confirm(f.id), 'Could not save that.'),
                  ),
                IconButton(tooltip: 'Edit', icon: const Icon(LvIcons.pencilSimple, size: 20), onPressed: _working ? null : () => _edit(f)),
                IconButton(
                  tooltip: f.confirmed ? 'Forget this' : 'Dismiss',
                  icon: const Icon(LvIcons.trash, size: 20),
                  onPressed: _working ? null : () => _do(() => widget.api.remove(f.id), 'Could not delete that.'),
                ),
              ]),
            ),
        ]);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MEMORY', style: monoLabel(context)),
          const SizedBox(height: 6),
          Text('What Levlofit AI remembers about you', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Only you can see these. A fact is used only after you confirm it: confirmed facts go to our AI provider with your messages to '
            'personalise replies, and an injury fact only when you ask about training, movement or pain. Suggestions waiting for your OK are never sent.',
            style: t.bodySmall?.copyWith(color: muted),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
          if (facts == null && _error == null) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (facts != null)
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (facts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('Nothing yet. When you mention your schedule, equipment, likes or an injury, Levlofit AI will ask whether to remember it.', style: t.bodyMedium),
                      ),
                    if (confirmed.isNotEmpty) section('REMEMBERED', 'Used in your chats.', confirmed),
                    if (waiting.isNotEmpty) section('WAITING FOR YOUR OK', 'Suggested by Levlofit AI. Not used until you confirm.', waiting),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (facts != null && facts.isNotEmpty)
            OutlinedButton(
              onPressed: _working ? null : () => _do(widget.api.removeAll, 'Could not delete your memory.'),
              child: const Text('Forget everything'),
            ),
        ]),
      ),
    );
  }
}

/// Under a reply: the facts the coach suggests remembering, each with Remember, Edit and Not now.
class FactSuggestions extends StatefulWidget {
  const FactSuggestions({super.key, required this.facts, required this.api});
  final List<Fact> facts;
  final MemoryApi api;

  @override
  State<FactSuggestions> createState() => _FactSuggestionsState();
}

class _FactSuggestionsState extends State<FactSuggestions> {
  final _outcome = <int, String>{}; // fact id -> what happened, shown instead of the buttons
  final _busy = <int>{};

  Future<void> _do(Fact f, Future<void> Function() change, String done) async {
    setState(() => _busy.add(f.id));
    try {
      await change();
      if (mounted) setState(() => _outcome[f.id] = done);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update your memory. Try again.')));
    } finally {
      if (mounted) setState(() => _busy.remove(f.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final f in widget.facts)
        Container(
          key: ValueKey('suggestion-${f.id}'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('REMEMBER THIS? · ${f.category.toUpperCase()}', style: monoLabel(context)),
            const SizedBox(height: 4),
            Text(f.fact, style: t.bodyMedium),
            if (f.category == 'injury' && _outcome[f.id] == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'If you remember this, it is sent to our AI provider when you ask about training, movement or pain, so advice can work around it. '
                  'It is not a diagnosis.',
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (_outcome[f.id] case final done?)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(done, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)))
            else
              Wrap(spacing: 4, children: [
                TextButton(
                  onPressed: _busy.contains(f.id) ? null : () => _do(f, () => widget.api.confirm(f.id), 'Remembered. You can change it in Memory.'),
                  child: const Text('Remember'),
                ),
                TextButton(
                  onPressed: _busy.contains(f.id)
                      ? null
                      : () async {
                          final out = await editFact(context, f, action: 'Save and remember');
                          if (out == null) return;
                          await _do(f, () => widget.api.save(f.id, out.category, out.fact, confirm: true), 'Remembered: ${out.fact}');
                        },
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: _busy.contains(f.id) ? null : () => _do(f, () => widget.api.remove(f.id), 'Not remembered.'),
                  child: const Text('Not now'),
                ),
              ]),
          ]),
        ),
    ]);
  }
}

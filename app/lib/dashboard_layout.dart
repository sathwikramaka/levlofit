// Which dashboard cards show, and in what order. Saved per user on this device (shared_preferences); the merge
// is pure so new cards appear for everyone and unknown ids from an older or newer app are dropped.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef CardPref = ({String id, bool visible});

/// Every card the dashboard can show, in the default order, with its label in the customise sheet.
const dashboardCards = <String, String>{
  'rings': 'Weekly rings',
  'today': "Today's session",
  'rewards': 'Daily goal and streak',
  'week': 'This week',
  'hydration': 'Water',
  'habits': 'Habits',
  'fuel': 'Food targets',
  'body': 'Body',
};

/// Cards that cannot be hidden: today's session is the dashboard's main job.
const requiredCards = {'today'};

/// Half-width cards; two in a row share a line, a lone one takes the full width.
const halfCards = {'hydration', 'habits', 'fuel', 'body'};

List<CardPref> get defaultLayout => [for (final id in dashboardCards.keys) (id: id, visible: true)];

/// Saved order first (known ids, once each), then any card the saved layout does not know yet, shown, in the
/// default order. Required cards are always visible.
List<CardPref> mergeLayout(List<CardPref>? saved) {
  final seen = <String>{};
  return [
    for (final c in saved ?? const <CardPref>[])
      if (dashboardCards.containsKey(c.id) && seen.add(c.id)) (id: c.id, visible: c.visible || requiredCards.contains(c.id)),
    for (final id in dashboardCards.keys)
      if (!seen.contains(id)) (id: id, visible: true),
  ];
}

String encodeLayout(List<CardPref> l) => jsonEncode([for (final c in l) {'id': c.id, 'visible': c.visible}]);

/// Null for anything unreadable, which falls back to the default layout.
List<CardPref>? decodeLayout(String? s) {
  if (s == null) return null;
  try {
    return [for (final m in (jsonDecode(s) as List).cast<Map<String, dynamic>>()) (id: m['id'] as String, visible: m['visible'] as bool)];
  } catch (_) {
    return null;
  }
}

/// Visible cards grouped into lines: consecutive half cards pair up.
List<List<String>> layoutRows(List<CardPref> l) {
  final rows = <List<String>>[];
  for (final c in l.where((c) => c.visible)) {
    final last = rows.isEmpty ? null : rows.last;
    if (halfCards.contains(c.id) && last != null && last.length == 1 && halfCards.contains(last.single)) {
      last.add(c.id);
    } else {
      rows.add([c.id]);
    }
  }
  return rows;
}

/// Show, hide and reorder the cards. Calls [onChanged] on every change, so it is saved as it is made.
class DashboardCustomiser extends StatefulWidget {
  const DashboardCustomiser({super.key, required this.initial, required this.onChanged});
  final List<CardPref> initial;
  final ValueChanged<List<CardPref>> onChanged;

  @override
  State<DashboardCustomiser> createState() => _DashboardCustomiserState();
}

class _DashboardCustomiserState extends State<DashboardCustomiser> {
  late List<CardPref> _l = mergeLayout(widget.initial);

  void _set(List<CardPref> l) {
    setState(() => _l = l);
    widget.onChanged(l);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
          child: Row(children: [
            Expanded(child: Text('Customise dashboard', style: t.titleLarge)),
            TextButton(onPressed: () => _set(defaultLayout), child: const Text('Reset')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Drag to reorder. Switch off what you do not need. Safety alerts always show.', style: t.bodySmall),
        ),
        Flexible(
          child: ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              HapticFeedback.selectionClick();
              final l = [..._l];
              l.insert(to, l.removeAt(from)); // [to] is already adjusted for the removed item
              _set(l);
            },
            children: [
              for (final (i, c) in _l.indexed)
                ListTile(
                  key: ValueKey(c.id),
                  leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
                  title: Text(dashboardCards[c.id]!),
                  trailing: Semantics(
                    label: 'Show ${dashboardCards[c.id]!}',
                    child: Switch(
                      value: c.visible,
                      onChanged: requiredCards.contains(c.id) ? null : (on) => _set([for (final x in _l) x.id == c.id ? (id: x.id, visible: on) : x]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

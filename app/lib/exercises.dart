// Exercise library: 1,500 anatomy-style animations (grey figure, target muscles in red).
// Media: ExerciseDB free V1 by AscendAPI. Non-commercial only and credit is required, so every screen that shows
// a GIF also shows the credit. Swap exercises.gif_url before Levlofit earns money (media/SOURCES.md).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exercise_guide.dart';
import 'icons.dart';
import 'main.dart';
import 'theme.dart';

typedef _Json = Map<String, dynamic>;

const exerciseMediaCredit = 'Animations: ExerciseDB by AscendAPI';

const _bodyParts = ['chest', 'back', 'shoulders', 'upper arms', 'lower arms', 'upper legs', 'lower legs', 'waist', 'cardio', 'neck'];

String _title(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// The animation on the white card it was drawn for, so it reads the same in light and dark mode.
class ExerciseGif extends StatelessWidget {
  const ExerciseGif(this.url, {super.key, this.size});
  final String url;
  final double? size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          // The media host sends no CORS headers; an <img> element still shows it on web. Mobile is unaffected.
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(child: Icon(LvIcons.warningCircle, color: Colors.black38)),
          loadingBuilder: (_, child, p) => p == null ? child : const Center(child: SizedBox(width: 28, height: 3, child: LinearProgressIndicator(minHeight: 3))),
        ),
      );
}

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, this.leading});
  final Widget? leading; // the app menu when shown as a tab

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  static const _page = 30;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _items = <_Json>[];
  String _query = '';
  String? _part;
  String? _group; // muscle group open in the Levlofit moves guide
  bool _loading = false, _done = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reset({String? query, String? part, bool clearPart = false}) {
    setState(() {
      _query = query ?? _query;
      _part = clearPart ? null : (part ?? _part);
      _items.clear();
      _done = false;
      _failed = false;
    });
    _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      var req = supabase.from('exercises').select('id, name, gif_url, target_muscles').eq('has_media', true);
      if (_part != null) req = req.contains('body_parts', [_part!]);
      if (_query.trim().isNotEmpty) req = req.textSearch('search', _query.trim(), config: 'english', type: TextSearchType.websearch);
      final rows = await req.order('name', ascending: true).range(_items.length, _items.length + _page - 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(List<_Json>.from(rows));
        _done = rows.length < _page;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(leading: widget.leading, title: const Text('Exercise library')),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverList.list(children: [
              Reveal(child: Text('See every move.', style: t.headlineMedium)),
              const SizedBox(height: 6),
              Reveal(index: 1, child: Text('Red shows the muscles doing the work.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant))),
              const SizedBox(height: 20),
              Reveal(index: 2, child: _MuscleGuide(group: _group, onGroup: (g) => setState(() => _group = g == _group ? null : g))),
              const SizedBox(height: 20),
              Reveal(
                index: 2,
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => _reset(query: v),
                  onChanged: (v) {
                    if (v.isEmpty && _query.isNotEmpty) _reset(query: '');
                  },
                  decoration: InputDecoration(
                    hintText: 'Search: squat, biceps, dumbbell',
                    prefixIcon: const Icon(LvIcons.magnifyingGlass, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(LvIcons.x, size: 18),
                            onPressed: () {
                              _search.clear();
                              _reset(query: '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final p in [null, ..._bodyParts])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p == null ? 'All' : _title(p)),
                        selected: _part == p,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (_) => p == null ? _reset(clearPart: true) : _reset(part: p),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
            ]),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.74),
              itemCount: _items.length,
              itemBuilder: (context, i) => Reveal(index: i % _page, child: _ExerciseCard(_items[i])),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            sliver: SliverList.list(children: [
              if (_failed) ...[
                const ErrorLine('Could not load exercises. Check your connection.'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => _reset(), child: const Text('Try again')),
              ] else if (_loading)
                const LinearProgressIndicator(minHeight: 4)
              else if (_items.isEmpty)
                Text('Nothing found. Try a simpler word, or another body part.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              const SizedBox(height: 16),
              Text(exerciseMediaCredit, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(this.row);
  final _Json row;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final target = (row['target_muscles'] as List).cast<String>();
    return Pressable(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: row['id'] as String))),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: Hero(tag: 'ex-${row['id']}', child: ExerciseGif(row['gif_url'] as String))),
              const SizedBox(height: 10),
              Text(_title(row['name'] as String), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25)),
              const SizedBox(height: 4),
              if (target.isNotEmpty) Text(target.first.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: monoLabel(context).copyWith(color: c.tertiary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// True when the catalogue read found no row for the id (PostgREST "0 rows" for .single()), as opposed to a network or
/// server failure.
bool notInCatalogue(Object? error) => error is PostgrestException && error.code == 'PGRST116';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key, required this.id, @visibleForTesting this.load});
  final String id;
  final Future<Map<String, dynamic>> Function()? load; // tests only; the app reads public.exercises

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder(
        future: (load ?? () => supabase.from('exercises').select().eq('id', id).single())(),
        builder: (context, snap) {
          final guide = moveGuide[id];
          final missing = notInCatalogue(snap.error);
          if (snap.hasError && guide == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorLine(missing ? 'This exercise is not in the catalogue yet.' : 'Could not load this exercise. Check your connection.'),
            );
          }
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 40), children: [
              Text(guide!.name, style: t.headlineMedium),
              const SizedBox(height: 14),
              _GuideTags(guide),
              if (guide.versions.isNotEmpty) _Versions(guide.versions),
              const SizedBox(height: 8),
              ErrorLine(missing
                  ? 'The animation and steps for this move are not in the catalogue yet.'
                  : 'The animation and steps could not load. Check your connection.'),
            ]);
          }
          final row = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AspectRatio(aspectRatio: 1, child: Hero(tag: 'ex-$id', child: row == null ? const SizedBox() : ExerciseGif(row['gif_url'] as String))),
                ),
              ),
              const SizedBox(height: 20),
              if (row == null)
                const LinearProgressIndicator(minHeight: 4)
              else
                ...staggered([
                  Text(guide?.name ?? _title(row['name'] as String), style: t.headlineMedium),
                  const SizedBox(height: 14),
                  if (guide != null && guide.main.isNotEmpty)
                    _GuideTags(guide)
                  else ...[
                    _Tags('WORKS', (row['target_muscles'] as List).cast<String>(), strong: true),
                    _Tags('ALSO', (row['secondary_muscles'] as List).cast<String>()),
                  ],
                  _Tags('EQUIPMENT', (row['equipment'] as List).cast<String>()),
                  if (guide != null && guide.versions.isNotEmpty) _Versions(guide.versions),
                  const SizedBox(height: 12),
                  Text('HOW TO DO IT', style: monoLabel(context)),
                  const SizedBox(height: 12),
                  for (final (i, s) in (row['instructions'] as List).cast<String>().indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: i == 0 ? c.primary : c.secondary, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: monoNumber(context, size: 13).copyWith(color: i == 0 ? c.onPrimary : c.onSecondary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(s, style: t.bodyLarge))),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  Text(exerciseMediaCredit, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ]),
            ],
          );
        },
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags(this.label, this.items, {this.strong = false, this.titleCase = true});
  final String label;
  final List<String> items;
  final bool strong;
  final bool titleCase; // catalogue values are lower case; Levlofit's own guide text is written as shown

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 96, child: Padding(padding: const EdgeInsets.only(top: 7), child: Text(label, style: monoLabel(context)))),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: strong ? c.primary : c.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: strong ? c.primary : c.outline),
                ),
                child: Text(titleCase ? _title(m) : m, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: strong ? c.onPrimary : c.onSurface)),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Levlofit's muscle notes for a prescribed move.
class _GuideTags extends StatelessWidget {
  const _GuideTags(this.g);
  final MoveGuide g;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Tags('GROUP', [g.group], strong: true, titleCase: false),
        _Tags(g.group == 'Mobility' ? 'STRETCHES' : 'WORKS', g.main, titleCase: false),
        _Tags('HELPS', g.assist, titleCase: false),
        if (g.equipment != null) _Tags('NEEDS', [g.equipment!], titleCase: false),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Muscle lists are general anatomy, pending expert review.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ]);
}

/// Other versions of the same movement used in Levlofit plans.
class _Versions extends StatelessWidget {
  const _Versions(this.ids);
  final List<String> ids;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Padding(padding: const EdgeInsets.only(top: 7), child: Text('VERSIONS', style: monoLabel(context)))),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in ids)
                if (moveGuide[id] case final g?)
                  ActionChip(
                    label: Text(g.name),
                    onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: id))),
                  ),
            ]),
          ),
        ]),
      );
}

/// Browse the moves Levlofit prescribes by muscle group, with the anatomical regions of each group.
class _MuscleGuide extends StatelessWidget {
  const _MuscleGuide({required this.group, required this.onGroup});
  final String? group;
  final ValueChanged<String> onGroup;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final g = group;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('LEVLOFIT MOVES BY MUSCLE', style: monoLabel(context)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final name in muscleRegions.keys)
          ChoiceChip(label: Text(name), selected: g == name, showCheckmark: false, onSelected: (_) => onGroup(name)),
      ]),
      if (g != null) ...[
        const SizedBox(height: 14),
        if (muscleRegions[g]!.isNotEmpty) ...[
          for (final r in muscleRegions[g]!) Text('·  $r', style: t.bodyMedium),
          const SizedBox(height: 6),
          Text(regionNote, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 8),
        ],
        for (final n in evidenceNotes[g] ?? const <({String text, String source})>[]) ...[
          Text(n.text, style: t.bodyMedium),
          Text('Study: ${n.source}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 8),
        ],
        for (final (id, m) in movesIn(g))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(m.name),
            subtitle: m.main.isEmpty
                ? const Text('Conditioning: many muscles at once')
                : Text('${m.group == 'Mobility' ? 'Stretches ' : ''}${m.main.join('  ·  ')}'),
            trailing: const Icon(LvIcons.caretRight, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: id))),
          ),
      ],
    ]);
  }
}

// Exercise library: 1,500 anatomy-style animations (grey figure, target muscles in red).
// Media: ExerciseDB free V1 by AscendAPI. Non-commercial only and credit is required, so every screen that shows
// a GIF also shows the credit. Swap exercises.gif_url before Levlofit earns money (media/SOURCES.md).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder(
        future: supabase.from('exercises').select().eq('id', id).single(),
        builder: (context, snap) {
          if (snap.hasError) return const Padding(padding: EdgeInsets.all(24), child: ErrorLine('Could not load this exercise. Check your connection.'));
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
                  Text(_title(row['name'] as String), style: t.headlineMedium),
                  const SizedBox(height: 14),
                  _Tags('WORKS', (row['target_muscles'] as List).cast<String>(), strong: true),
                  _Tags('ALSO', (row['secondary_muscles'] as List).cast<String>()),
                  _Tags('EQUIPMENT', (row['equipment'] as List).cast<String>()),
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
  const _Tags(this.label, this.items, {this.strong = false});
  final String label;
  final List<String> items;
  final bool strong;

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
                child: Text(_title(m), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: strong ? c.onPrimary : c.onSurface)),
              ),
          ]),
        ),
      ]),
    );
  }
}

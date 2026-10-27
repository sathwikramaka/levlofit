// The Handbook: chapter list with search, and a reader that draws each chapter from visual blocks.
// Content lives in handbook_chapters.blocks (built by data/build_handbook.py). Every number there is cited.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'handbook_book.dart';
import 'icons.dart';
import 'main.dart';
import 'theme.dart';

typedef _Json = Map<String, dynamic>;

// DESIGN.md success token; the theme has no slot for it.
Color _success(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5FB482) : const Color(0xFF2F7D4F);

class HandbookScreen extends StatefulWidget {
  const HandbookScreen({super.key, this.leading});
  final Widget? leading; // the app menu when shown as a tab

  @override
  State<HandbookScreen> createState() => _HandbookScreenState();
}

class _HandbookScreenState extends State<HandbookScreen> {
  final _search = TextEditingController();
  late Future<List<_Json>> _chapters = _load();
  String _query = '';

  Future<List<_Json>> _load([String q = '']) async {
    var req = supabase.from('handbook_chapters').select('id, part, part_title, title, summary, minutes');
    if (q.trim().isNotEmpty) req = req.textSearch('search', q.trim(), config: 'english', type: TextSearchType.websearch);
    return List<_Json>.from(await req.order('id', ascending: true)); // postgrest-dart defaults to descending
  }

  void _run(String q) {
    if (q == _query) return;
    setState(() {
      _query = q;
      _chapters = _load(q);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(leading: widget.leading, title: const Text('Handbook')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Reveal(child: Text('Know why, not just what.', style: t.headlineMedium)),
          const SizedBox(height: 6),
          Reveal(index: 1, child: Text('Short, visual chapters. Every number names its source. General information from published guidelines, not medical advice and not reviewed by a clinician.', style: t.bodyMedium?.copyWith(color: muted))),
          const SizedBox(height: 20),
          Reveal(
            index: 2,
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _run,
              onChanged: (v) {
                if (v.isEmpty) _run('');
              },
              decoration: InputDecoration(
                hintText: 'Search: protein, warm-up, creatine',
                prefixIcon: const Icon(LvIcons.magnifyingGlass, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(LvIcons.x, size: 18),
                        onPressed: () {
                          _search.clear();
                          _run('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Read like a book: introduction and objectives first, the conclusion after the last chapter.
          if (_query.isEmpty) ...[
            Text('START HERE', style: monoLabel(context)),
            const SizedBox(height: 10),
            const BookPageTile(bookIntroduction),
            const SizedBox(height: 10),
            const BookPageTile(bookObjectives),
            const SizedBox(height: 26),
          ],
          FutureBuilder(
            future: _chapters,
            builder: (context, snap) {
              if (snap.hasError) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ErrorLine('Could not load the Handbook. Check your connection.'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => setState(() { _chapters = _load(_query); }), child: const Text('Try again')),
                ]);
              }
              if (!snap.hasData) return const LinearProgressIndicator(minHeight: 4);
              final rows = snap.data!;
              if (rows.isEmpty) return Text('Nothing found for "$_query". Try a simpler word.', style: t.bodyMedium?.copyWith(color: muted));
              final out = <Widget>[];
              String? part;
              for (final r in rows) {
                if (r['part'] != part) {
                  part = r['part'] as String;
                  out.addAll([
                    if (out.isNotEmpty) const SizedBox(height: 16),
                    Text('PART $part  ·  ${(r['part_title'] as String? ?? '').toUpperCase()}', style: monoLabel(context)),
                    const SizedBox(height: 10),
                  ]);
                }
                out.addAll([_ChapterTile(r), const SizedBox(height: 10)]);
              }
              if (_query.isEmpty) {
                out.addAll([
                  const SizedBox(height: 16),
                  Text('THE END', style: monoLabel(context)),
                  const SizedBox(height: 10),
                  const BookPageTile(bookConclusion),
                ]);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: staggered(out));
            },
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile(this.row);
  final _Json row;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Pressable(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChapterScreen(id: row['id'] as int))),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 36, child: Text((row['id'] as int).toString().padLeft(2, '0'), style: monoNumber(context, size: 18).copyWith(color: c.tertiary))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row['title'] as String, style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text(row['summary'] as String? ?? '', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('${row['minutes'] ?? 3} MIN', style: monoLabel(context)),
                ]),
              ),
              Icon(LvIcons.caretRight, size: 18, color: c.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

class ChapterScreen extends StatelessWidget {
  // Opened by id from the chapter list, or by slug from an "Up next" link (slugs never change; ids follow book order).
  const ChapterScreen({super.key, this.id, this.slug, @visibleForTesting this.load}) : assert(id != null || slug != null);
  final int? id;
  final String? slug;
  final Future<Map<String, dynamic>> Function()? load; // tests only: replaces the database read

  static String label(int? id) => id == null ? 'CHAPTER' : 'CHAPTER ${id.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // One read serves the title bar and the body. Opened by slug, the chapter number comes from the row.
    final Future<Map<String, dynamic>> future = load?.call() ??
        (id != null
            ? supabase.from('handbook_chapters').select('id, part, part_title, title, minutes, blocks').eq('id', id!).single()
            : supabase.from('handbook_chapters').select('id, part, part_title, title, minutes, blocks').eq('slug', slug!).single());
    return Scaffold(
      appBar: AppBar(
        title: id != null
            ? Text(label(id), style: monoLabel(context))
            : FutureBuilder(future: future, builder: (context, snap) => Text(label(snap.data?['id'] as int?), style: monoLabel(context))),
      ),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) return const Padding(padding: EdgeInsets.all(24), child: ErrorLine('Could not load this chapter. Check your connection.'));
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: LinearProgressIndicator(minHeight: 4));
          final row = snap.data!;
          final data = row['blocks'] as _Json;
          final sources = (data['sources'] as Map).cast<String, String>();
          final blocks = (data['blocks'] as List).cast<_Json>();
          // jsonb does not keep key order, so number sources by first appearance in the chapter.
          final keys = <String>{
            for (final b in blocks) ...[
              if (b['source'] is String) b['source'] as String,
              for (final i in (b['items'] as List?) ?? const []) if (i is Map && i['source'] is String) i['source'] as String,
            ],
            ...sources.keys,
          }.where(sources.containsKey).toList();
          // Source keys become numbered markers that match the list at the end of the chapter.
          String? cite(Object? key) => key is String && keys.contains(key) ? '[${keys.indexOf(key) + 1}]' : null;
          // Textbook frame (owner request 2026-10-28): chapter opener, numbered figures, takeaways, references.
          final chapter = row['id'] as int? ?? 0;
          var n = 0;
          final figureNo = <_Json, String>{for (final b in blocks) if (figureBlocks.contains(b['t'])) b: '$chapter.${++n}'};
          final lead = blocks.where((b) => b['t'] == 'lead').firstOrNull;
          final takeaways = blocks.where((b) => b['t'] == 'keypoints').toList();
          final next = blocks.where((b) => b['t'] == 'next').toList();
          final body = blocks.where((b) => b != lead && b['t'] != 'keypoints' && b['t'] != 'next').toList();
          final figureCount = figureNo.length;
          return _ReadingProgress(
            child: (controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
              children: staggered([
                _ChapterOpener(
                  part: row['part'] as String?,
                  partTitle: row['part_title'] as String?,
                  number: chapter,
                  title: row['title'] as String,
                  meta: '${row['minutes'] ?? 3} min  ·  $figureCount ${figureCount == 1 ? 'figure' : 'figures'}  ·  ${keys.length} sources',
                ),
                const SizedBox(height: 22),
                _InThisChapter(lead: lead?['text'] as String?, figures: [for (final e in figureNo.entries) (e.value, e.key['title'] as String? ?? '')]),
                const SizedBox(height: 26),
                for (final b in body) ...[
                  figureNo[b] != null ? _Figure(number: figureNo[b]!, child: handbookBlock(context, b, cite)) : handbookBlock(context, b, cite),
                  const SizedBox(height: 24),
                ],
                for (final b in takeaways) ...[handbookBlock(context, b, cite), const SizedBox(height: 24)],
                for (final b in next) ...[handbookBlock(context, b, cite), const SizedBox(height: 24)],
                const Divider(),
                const SizedBox(height: 16),
                Text('REFERENCES', style: monoLabel(context)),
              const SizedBox(height: 10),
              for (final (i, k) in keys.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 32, child: Text('[${i + 1}]', style: monoLabel(context).copyWith(color: Theme.of(context).colorScheme.tertiary))),
                    Expanded(child: Text(sources[k]!, style: t.bodySmall?.copyWith(color: muted))),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// One chapter block. Public so widget tests can draw blocks without the database.
Widget handbookBlock(BuildContext context, Map<String, dynamic> b, String? Function(Object?) cite) => switch (b['t']) {
        'part' => _PartOpener(b),
        'keypoints' => _KeyPoints(b),
        'next' => _UpNext(b),
        'lead' => _Lead(b['text'] as String),
        'rule' => _Note(label: 'RULE', text: b['text'] as String, filled: false),
        'evidence' => _Note(label: 'EVIDENCE', text: b['text'] as String, filled: true, cite: cite(b['source']), grade: b['grade'] as String?),
        'stats' => _Stats(b, cite),
        'steps' => _Steps(b),
        'compare' => _Compare(b),
        'bars' => _Bars(b, cite(b['source'])),
        'scale' => _Scale(b, cite(b['source'])),
        'week' => _Week(b),
        'plate' => _Plate(b, cite(b['source'])),
        'cycle' => _Cycle(b),
        'table' => _Table(b, cite(b['source'])),
        'flow' => _Flow(b, cite(b['source'])),
        'band' => _Band(b, cite(b['source'])),
        _ => Text(b['text'] as String? ?? '', style: Theme.of(context).textTheme.bodyLarge),
      };

// ---------------------------------------------------------------- textbook frame

/// Block types drawn as numbered figures.
const figureBlocks = {'stats', 'steps', 'compare', 'bars', 'scale', 'week', 'plate', 'cycle', 'table', 'flow', 'band'};

/// A thin reading-progress bar over the chapter, driven by its scroll position.
class _ReadingProgress extends StatefulWidget {
  const _ReadingProgress({required this.child});
  final Widget Function(ScrollController controller) child;

  @override
  State<_ReadingProgress> createState() => _ReadingProgressState();
}

class _ReadingProgressState extends State<_ReadingProgress> {
  final _controller = ScrollController();
  final _progress = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.position;
      _progress.value = p.maxScrollExtent <= 0 ? 1 : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ValueListenableBuilder(
          valueListenable: _progress,
          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: Colors.transparent),
        ),
        Expanded(child: widget.child(_controller)),
      ]);
}

/// The chapter's opening: part, a large chapter number, the title and what it holds.
class _ChapterOpener extends StatelessWidget {
  const _ChapterOpener({required this.part, required this.partTitle, required this.number, required this.title, required this.meta});
  final String? part, partTitle;
  final int number;
  final String title, meta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final partLine = part == null ? null : (partTitle == null ? 'PART $part' : 'PART $part  ·  ${partTitle!.toUpperCase()}');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (partLine != null) Text(partLine, style: monoLabel(context).copyWith(color: c.tertiary)),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number.toString().padLeft(2, '0'), style: monoNumber(context, size: 44).copyWith(color: c.primary, height: 1)),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: t.headlineMedium)),
      ]),
      const SizedBox(height: 8),
      Text(meta, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
    ]);
  }
}

/// "In this chapter": the opening idea and the list of figures, like a textbook's chapter preview.
class _InThisChapter extends StatelessWidget {
  const _InThisChapter({required this.lead, required this.figures});
  final String? lead;
  final List<(String, String)> figures;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('IN THIS CHAPTER', style: monoLabel(context)),
        if (lead != null) ...[const SizedBox(height: 8), Text(lead!, style: t.titleMedium?.copyWith(height: 1.45))],
        if (figures.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final (no, title) in figures)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(title.isEmpty ? 'Figure $no' : 'Figure $no  ·  $title', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ),
        ],
      ]),
    );
  }
}

/// A numbered figure panel around a visual block.
class _Figure extends StatelessWidget {
  const _Figure({required this.number, required this.child});
  final String number;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FIGURE $number', style: monoLabel(context).copyWith(color: c.tertiary)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

// ---------------------------------------------------------------- book structure blocks (Handbook v4)

/// Opens a part of the book: "Part B. Getting better" and what the part covers.
class _PartOpener extends StatelessWidget {
  const _PartOpener(this.b);
  final _Json b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _box(context, filled: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((b['title'] as String).toUpperCase(), style: monoLabel(context)),
        const SizedBox(height: 8),
        Text(b['text'] as String, style: t.bodyLarge),
      ]),
    );
  }
}

/// The chapter's summary, a short list.
class _KeyPoints extends StatelessWidget {
  const _KeyPoints(this.b);
  final _Json b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _box(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KEY POINTS', style: monoLabel(context)),
        const SizedBox(height: 10),
        for (final p in (b['items'] as List).cast<String>())
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 9, right: 10), child: Container(width: 6, height: 6, color: Theme.of(context).colorScheme.primary)),
              Expanded(child: Text(p, style: t.bodyLarge)),
            ]),
          ),
      ]),
    );
  }
}

/// Links to the next chapter(s) of the book, opened by slug.
class _UpNext extends StatelessWidget {
  const _UpNext(this.b);
  final _Json b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('UP NEXT', style: monoLabel(context)),
      const SizedBox(height: 10),
      for (final i in (b['items'] as List).cast<_Json>())
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChapterScreen(slug: i['ref'] as String))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: _box(context),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i['title'] as String, style: t.titleMedium),
                      const SizedBox(height: 4),
                      Text(i['why'] as String, style: t.bodyMedium?.copyWith(color: muted)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: muted),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

// ---------------------------------------------------------------- shared pieces

class _Title extends StatelessWidget {
  const _Title(this.text, {this.cite});
  final String text;
  final String? cite;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(text.toUpperCase(), style: monoLabel(context))),
          if (cite != null) Text(cite!, style: monoLabel(context).copyWith(color: Theme.of(context).colorScheme.tertiary)),
        ]),
      );
}

BoxDecoration _box(BuildContext context, {bool filled = false}) {
  final c = Theme.of(context).colorScheme;
  return BoxDecoration(color: filled ? c.surfaceContainerHighest : c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.outline));
}

/// Plays once when the block first builds: 0 to 1 on the brand ease, optionally after a delay within the timeline.
class _Grow extends StatelessWidget {
  const _Grow({required this.builder, this.ms = 900, this.delay = 0});
  final Widget Function(double v) builder;
  final int ms;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, ms);
    if (d == Duration.zero) return builder(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Interval(delay.clamp(0.0, 0.9), 1, curve: spring),
      builder: (_, v, _) => builder(v),
    );
  }
}

// ---------------------------------------------------------------- blocks

class _Lead extends StatelessWidget {
  const _Lead(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3))),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.label, required this.text, required this.filled, this.cite, this.grade});
  final String label, text;
  final bool filled;
  final String? cite, grade;

  // How sure the science is: filled bars, like a signal meter, plus the word so it never relies on shape alone.
  // 'unverified' (Handbook v4): the cited source has not been read yet, so no bar is filled.
  static const _grades = {
    'strong': (3, 'STRONG EVIDENCE'),
    'moderate': (2, 'MODERATE EVIDENCE'),
    'consensus': (1, 'EXPERT CONSENSUS'),
    'unverified': (0, 'NOT YET VERIFIED'),
  };

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _box(context, filled: filled),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Title(label, cite: cite),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
          if (_grades[grade] case (final level, final word)) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 14,
                  height: 6,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i < level ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: 8),
              Text(word, style: monoLabel(context)),
            ]),
          ],
        ]),
      );
}

class _Stats extends StatelessWidget {
  const _Stats(this.b, this.cite);
  final _Json b;
  final String? Function(Object?) cite;

  @override
  Widget build(BuildContext context) {
    final items = (b['items'] as List).cast<_Json>();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, box) {
      final two = box.maxWidth > 420 && items.length > 1;
      final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final s in items)
          Container(
            width: w,
            padding: const EdgeInsets.all(18),
            decoration: _box(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
                CountUp(s['value'] as String, style: monoNumber(context, size: 34)),
                if ((s['unit'] as String? ?? '').isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(s['unit'] as String, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant))),
              ]),
              const SizedBox(height: 8),
              Text(s['label'] as String, style: t.bodyMedium),
              if (cite(s['source']) != null) ...[const SizedBox(height: 8), Text(cite(s['source'])!, style: monoLabel(context).copyWith(color: c.tertiary))],
            ]),
          ),
      ]);
    });
  }
}

class _Steps extends StatelessWidget {
  const _Steps(this.b);
  final _Json b;

  @override
  Widget build(BuildContext context) {
    final items = (b['items'] as List).cast<_Json>();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Title(b['title'] as String),
      for (final (i, s) in items.indexed)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 40,
              child: Column(children: [
                _Grow(
                  delay: i * 0.12,
                  ms: 800,
                  builder: (v) => Transform.scale(
                    scale: 0.6 + 0.4 * v,
                    child: Opacity(
                      opacity: v,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: i == 0 ? c.primary : c.secondary, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: monoNumber(context, size: 14).copyWith(color: i == 0 ? c.onPrimary : c.onSecondary)),
                      ),
                    ),
                  ),
                ),
                if (i < items.length - 1) Expanded(child: Container(width: 1.5, margin: const EdgeInsets.symmetric(vertical: 4), color: c.outline)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: i < items.length - 1 ? 18 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['title'] as String, style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(s['text'] as String, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _Compare extends StatelessWidget {
  const _Compare(this.b);
  final _Json b;

  @override
  Widget build(BuildContext context) {
    Widget side(_Json s, bool ok) {
      final c = Theme.of(context).colorScheme;
      final tone = ok ? _success(context) : c.error;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: tone.withValues(alpha: 0.5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              child: Icon(ok ? LvIcons.check : LvIcons.x, size: 14, color: c.surface),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(s['title'] as String, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 12),
          for (final item in (s['items'] as List).cast<String>())
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: tone, shape: BoxShape.circle))),
                Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
              ]),
            ),
        ]),
      );
    }

    final good = side(b['do'] as _Json, true);
    final bad = side(b['dont'] as _Json, false);
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth > 520
          ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: good), const SizedBox(width: 12), Expanded(child: bad)]))
          : Column(children: [good, const SizedBox(height: 12), bad]),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars(this.b, this.cite);
  final _Json b;
  final String? cite;

  @override
  Widget build(BuildContext context) {
    final items = (b['items'] as List).cast<_Json>();
    final max = items.map((i) => (i['value'] as num).toDouble()).reduce(math.max);
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Title(b['title'] as String, cite: cite),
        for (final (i, item) in items.indexed) ...[
          Row(children: [
            Expanded(child: Text(item['label'] as String, style: t.bodyMedium)),
            Text(item['note'] as String? ?? '${item['value']}', style: monoNumber(context, size: 14)),
          ]),
          const SizedBox(height: 6),
          _Grow(
            delay: i * 0.1,
            builder: (v) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 10, color: c.surfaceContainerHighest),
                FractionallySizedBox(
                  widthFactor: ((item['value'] as num) / max * v).clamp(0.0, 1.0),
                  child: Container(height: 10, color: i == items.length - 1 ? c.primary : c.secondary),
                ),
              ]),
            ),
          ),
          if (i < items.length - 1) const SizedBox(height: 14),
        ],
      ]),
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale(this.b, this.cite);
  final _Json b;
  final String? cite;

  @override
  Widget build(BuildContext context) {
    final items = (b['items'] as List).cast<_Json>();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Title(b['title'] as String, cite: cite),
        for (final (i, s) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              // Harder means more orange; the words carry the meaning too, never colour alone.
              _Grow(
                delay: i * 0.08,
                ms: 700,
                builder: (v) {
                  final heat = (1 - i / (items.length - 1)) * v;
                  return Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Color.lerp(c.surfaceContainerHighest, c.primary, heat), borderRadius: BorderRadius.circular(10)),
                    child: Text(s['mark'] as String, style: monoNumber(context, size: 16).copyWith(color: heat > 0.5 ? c.onPrimary : c.onSurface)),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['label'] as String, style: t.titleMedium),
                  Text(s['text'] as String, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week(this.b);
  final _Json b;

  @override
  Widget build(BuildContext context) {
    final days = (b['days'] as List).cast<_Json>();
    final c = Theme.of(context).colorScheme;
    (Color, Color) tone(String kind) => switch (kind) {
          'strength' => (c.primary, c.onPrimary),
          'cardio' => (c.secondary, c.onSecondary),
          'mobility' => (c.surfaceContainerHighest, c.onSurface),
          _ => (c.surface, c.onSurfaceVariant),
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Title(b['title'] as String),
      Row(children: [
        for (final (i, d) in days.indexed) ...[
          Expanded(
            child: _Grow(
              delay: i * 0.07,
              ms: 800,
              builder: (v) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - v)),
                  child: Container(
                    height: 96,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    decoration: BoxDecoration(color: tone(d['kind'] as String).$1, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.outline)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text((d['day'] as String).toUpperCase(), style: monoLabel(context).copyWith(color: tone(d['kind'] as String).$2, fontSize: 10)),
                      Text(
                        d['label'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tone(d['kind'] as String).$2, fontSize: 11, height: 1.2, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (i < days.length - 1) const SizedBox(width: 4),
        ],
      ]),
    ]);
  }
}

class _Plate extends StatelessWidget {
  const _Plate(this.b, this.cite);
  final _Json b;
  final String? cite;

  @override
  Widget build(BuildContext context) {
    final items = (b['items'] as List).cast<_Json>();
    final c = Theme.of(context).colorScheme;
    // One accent plus graded ink: the largest share is orange, the rest step down.
    final colors = [c.primary, c.secondary, c.secondary.withValues(alpha: 0.7), c.secondary.withValues(alpha: 0.5), c.secondary.withValues(alpha: 0.32), c.secondary.withValues(alpha: 0.18)];
    final shares = items.map((i) => (i['share'] as num).toDouble()).toList();
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Title(b['title'] as String, cite: cite),
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: _Grow(ms: 1300, builder: (v) => CustomPaint(painter: _DonutPainter(shares, colors, v, c.surface))),
          ),
        ),
        const SizedBox(height: 16),
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(4), border: Border.all(color: c.outline)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item['label'] as String, style: t.bodyMedium)),
              Text(item['note'] as String? ?? '', style: monoNumber(context, size: 14)),
            ]),
          ),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.shares, this.colors, this.progress, this.gap);
  final List<double> shares;
  final List<Color> colors;
  final double progress;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final total = shares.fold<double>(0, (a, b) => a + b);
    final stroke = size.width * 0.16;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    Paint pen(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    var start = -math.pi / 2;
    for (final (i, s) in shares.indexed) {
      final sweep = (s / total) * 2 * math.pi * progress;
      canvas.drawArc(rect, start, sweep, false, pen(colors[i % colors.length]));
      canvas.drawArc(rect, start, 0.012, false, pen(gap)); // hairline gap keeps the shades readable
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress;
}

class _Cycle extends StatelessWidget {
  const _Cycle(this.b);
  final _Json b;

  @override
  Widget build(BuildContext context) {
    final items = (b['items'] as List).cast<String>();
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Title(b['title'] as String),
        LayoutBuilder(builder: (context, box) {
          final size = math.min(box.maxWidth, 320.0);
          final r = size / 2 - 42;
          return Center(
            child: SizedBox(
              width: size,
              height: size,
              child: _Grow(
                ms: 1600,
                builder: (v) => Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _RingPainter(v, c.outline, c.primary))),
                  for (final (i, label) in items.indexed)
                    Positioned(
                      left: size / 2 + r * math.cos(-math.pi / 2 + i * 2 * math.pi / items.length) - 42,
                      top: size / 2 + r * math.sin(-math.pi / 2 + i * 2 * math.pi / items.length) - 22,
                      width: 84,
                      height: 44,
                      child: Opacity(
                        opacity: ((v * items.length) - i).clamp(0.0, 1.0),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: i == 0 ? c.primary : c.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: i == 0 ? c.primary : c.outline),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.15, color: i == 0 ? c.onPrimary : c.onSurface),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.track, this.accent);
  final double progress;
  final Color track, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(42);
    canvas.drawOval(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..color = accent);
    // A dot at the leading edge shows which way the loop runs.
    final a = -math.pi / 2 + 2 * math.pi * progress;
    canvas.drawCircle(rect.center + Offset(math.cos(a) * rect.width / 2, math.sin(a) * rect.height / 2), 5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _Table extends StatelessWidget {
  const _Table(this.b, this.cite);
  final _Json b;
  final String? cite;

  @override
  Widget build(BuildContext context) {
    final head = (b['head'] as List).cast<String>();
    final rows = (b['rows'] as List).map((r) => (r as List).cast<String>()).toList();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: _box(context),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (cite != null) Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: _Title('Data', cite: cite)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 64,
            horizontalMargin: 16,
            columnSpacing: 20,
            headingTextStyle: monoLabel(context),
            columns: [for (final h in head) DataColumn(label: Text(h.toUpperCase()))],
            rows: [
              for (final (i, r) in rows.indexed)
                DataRow(
                  color: WidgetStatePropertyAll(i.isOdd ? c.surfaceContainerHighest.withValues(alpha: 0.4) : null),
                  cells: [
                    for (final (j, cell) in r.indexed) DataCell(Text(cell, style: j == 0 ? t.bodyMedium?.copyWith(fontWeight: FontWeight.w600) : monoNumber(context, size: 13))),
                  ],
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow(this.b, this.cite);
  final _Json b;
  final String? cite;

  @override
  Widget build(BuildContext context) {
    final items = (b['items'] as List).cast<_Json>();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    Widget answer(String label, String text, Color tone) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: tone.withValues(alpha: 0.6))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: monoLabel(context).copyWith(color: tone)),
              const SizedBox(height: 4),
              Text(text, style: t.bodySmall),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Title(b['title'] as String, cite: cite),
      for (final (i, s) in items.indexed) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _box(context, filled: true),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Q${i + 1}', style: monoLabel(context).copyWith(color: c.tertiary)),
            const SizedBox(height: 4),
            Text(s['q'] as String, style: t.titleMedium),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                answer('YES', s['yes'] as String, c.error),
                const SizedBox(width: 8),
                answer('NO', s['no'] as String, _success(context)),
              ]),
            ),
          ]),
        ),
        if (i < items.length - 1) Center(child: Container(width: 1.5, height: 16, color: c.outline)),
      ],
      if (b['note'] != null) ...[const SizedBox(height: 12), Text(b['note'] as String, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))],
    ]);
  }
}

class _Band extends StatelessWidget {
  const _Band(this.b, this.cite);
  final _Json b;
  final String? cite;

  @override
  Widget build(BuildContext context) {
    final ranges = (b['ranges'] as List).cast<_Json>();
    final c = Theme.of(context).colorScheme;
    final lo = (ranges.first['from'] as num).toDouble();
    final hi = (ranges.last['to'] as num).toDouble();
    Color tone(String t) => switch (t) { 'good' => _success(context), 'bad' => c.error, _ => c.primary };
    String fmt(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();
    int flex(_Json r) => (((r['to'] as num) - (r['from'] as num)) / (hi - lo) * 1000).round();
    // The outer edges only frame the chart, so the legend says "under" and "and over" instead.
    String span(int i) {
      final r = ranges[i];
      if (i == 0) return 'under ${fmt(r['to'] as num)}';
      if (i == ranges.length - 1) return '${fmt(r['from'] as num)} and over';
      return '${fmt(r['from'] as num)} to under ${fmt(r['to'] as num)}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Title('${b['title']}  ·  ${b['unit']}', cite: cite),
        _Grow(
          ms: 1000,
          builder: (v) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(children: [
              for (final r in ranges)
                Expanded(flex: flex(r), child: Container(height: 14, margin: const EdgeInsets.only(right: 2), color: Color.lerp(c.surfaceContainerHighest, tone(r['tone'] as String), v))),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (final (i, r) in ranges.indexed)
            Expanded(flex: flex(r), child: Text(i == 0 ? '' : fmt(r['from'] as num), style: monoLabel(context))),
        ]),
        const SizedBox(height: 14),
        for (final (i, r) in ranges.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: tone(r['tone'] as String), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(r['label'] as String, style: Theme.of(context).textTheme.bodyMedium)),
              Text(span(i), style: monoNumber(context, size: 13)),
            ]),
          ),
      ]),
    );
  }
}

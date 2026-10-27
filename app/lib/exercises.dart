// Exercise library. Two modes:
// - ExerciseDB (default, every build while Levlofit is free with no ads): adds the ExerciseDB free V1 animations,
//   names and steps by AscendAPI. Their terms allow non-commercial use only, with credit (checked 2026-10-16,
//   docs/LICENSING_REQUIREMENTS.md), so every screen that shows them shows the credit.
// - Licensed (--dart-define=LEVLOFIT_EXERCISEDB=false; required before subscriptions or ads without a paid plan):
//   Levlofit's own move names and muscle notes (exercise_guide.dart) and its own demonstrations.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exercise_guide.dart';
import 'icons.dart';
import 'main.dart';
import 'move_animation.dart';
import 'move_animations.dart';
import 'muscle_map.dart';
import 'theme.dart';

typedef _Json = Map<String, dynamic>;

/// Whether ExerciseDB content may be shown. On in every build while Levlofit is free with no ads (ExerciseDB V1 free
/// tier: non-commercial, credit required). Build with --dart-define=LEVLOFIT_EXERCISEDB=false before any subscription
/// or ads ship, unless a paid ExerciseDB plan is in place. Tests set it directly.
bool exerciseDbContent = const bool.fromEnvironment('LEVLOFIT_EXERCISEDB', defaultValue: true);

String get exerciseMediaCredit => exerciseDbContent
    ? 'Animations: ExerciseDB by AscendAPI'
    : 'Exercise notes and figure animations: Levlofit. $animationCredit. $drawingCredit';

const drawingCredit = 'Drawings: Everkinetic by Greg Priday, CC BY-SA 4.0';

/// The full attribution for the Licences page (CC BY-SA 4.0 section 3(a)).
const drawingNotice = 'Exercise drawings by Greg Priday, Everkinetic (http://everkinetic.com), from the Everkinetic open data '
    'project https://github.com/everkinetic/data (commit 446bb9a). Used unmodified. Licensed under Creative Commons '
    'Attribution-ShareAlike 4.0 International, https://creativecommons.org/licenses/by-sa/4.0/ . Full licence text below.';

/// Levlofit move id -> Everkinetic drawing number (exact matches only; assets/drawings/everkinetic/SOURCE.md). Each has
/// two positions, named by muscle state (relaxation, tension), not by order: for a squat the relaxed drawing is the
/// bottom. So they are never labelled start and finish. Moves without one show a plain icon.
const moveDrawings = {
  'I4hDWkc': '0077',
  'EIeI8Vf': '0042',
  'SpYC0Kp': '0055',
  '9WTm7dq': '0054',
  'lBDjFxJ': '0087',
  'fUBheHs': '0025',
  'bZGHsAZ': '0086',
  'qXTaZnJ': '0122',
  'RRWFUcw': '0114',
  'IZVHb27': '0121',
  'aXtJhlg': '0137',
  'wQ2c4XD': '0118',
  'ila4NZS': '0099',
  'u0cNiij': '0109',
  'RKjH6Lt': '0113',
};

String drawingAsset(String number, {bool end = true}) => 'assets/drawings/everkinetic/$number-${end ? 'tension' : 'relaxation'}.svg';

/// Levlofit move id -> a bundled animation whose rights are verified (assets/animations/SOURCE.md: CDC Growing Stronger,
/// public domain, unmodified). Each was checked frame by frame against the move; a move without one uses its two
/// drawings in turn.
const moveAnimations = <String, String>{
  'QChZi3x': 'assets/animations/cdc/Squat-CDC_strength_training_for_older_adults.gif',
  'IZVHb27': 'assets/animations/cdc/Lunge-CDC_strength_training_for_older_adults.gif',
  'aXtJhlg': 'assets/animations/cdc/Step_up-CDC_strength_training_for_older_adults.gif',
  'B1EVP9F': 'assets/animations/cdc/Wallpushup-CDC_strength_training_for_older_adults.gif',
  'A6wtbuL': 'assets/animations/cdc/Overhead_press-CDC_strength_training_for_older_adults.gif',
  'bJYHBIN': 'assets/animations/cdc/Toe_stand-CDC_strength_training_for_older_adults.gif',
};

/// What an animation shows that differs from the move as Levlofit describes it.
const moveAnimationNotes = {
  'QChZi3x': 'Shown with a chair as a depth guide.',
  'IZVHb27': 'Shown holding a rail for balance; that is optional.',
  'B1EVP9F': 'Shown against a wall; a bench or table works the same way.',
  'A6wtbuL': 'Shown seated; the press is the same standing.',
};

const animationCredit = 'Animations: CDC, Growing Stronger (public domain)';

/// For the Licences page: CDC asks for attribution, no implied endorsement, no changes, and a note that the material is
/// free from CDC (cdc.gov/other/agencymaterials.html).
const animationNotice = 'Exercise animations: Centers for Disease Control and Prevention (CDC), "Growing Stronger: Strength '
    'Training for Older Adults", published free of charge by CDC. Public domain (a work of the U.S. federal government), '
    'used unmodified, from Wikimedia Commons. Use of these animations does not imply endorsement of Levlofit by CDC or the '
    'U.S. Department of Health and Human Services.';

/// A licensed demonstration of a move, played from the app bundle (works offline): Levlofit's own animation where one
/// exists ([moveVectorAnimations], drawn in code), else a bundled animation ([moveAnimations]), else the two
/// Everkinetic positions shown in turn, else a plain icon. With the system's "remove animations" setting on, the
/// animation holds its working position and the drawings hold the tension position.
class MoveDemo extends StatefulWidget {
  const MoveDemo(this.id, {super.key, this.label, this.iconSize = 36});
  final String? id;
  final String? label; // for screen readers
  final double iconSize;

  @override
  State<MoveDemo> createState() => _MoveDemoState();
}

class _MoveDemoState extends State<MoveDemo> {
  static const _swap = Duration(milliseconds: 1200);
  Timer? _timer;
  bool _end = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = moveVectorAnimations[widget.id] == null &&
        moveAnimations[widget.id] == null &&
        moveDrawings[widget.id] != null &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && _timer == null) {
      _timer = Timer.periodic(_swap, (_) => setState(() => _end = !_end));
    } else if (!animate) {
      _timer?.cancel();
      _timer = null;
      _end = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget get _icon => Center(child: Icon(LvIcons.barbell, color: Colors.black26, size: widget.iconSize));

  @override
  Widget build(BuildContext context) {
    if (moveVectorAnimations[widget.id] case final move?) return MoveAnimationView(move, label: widget.label);
    if (moveAnimations[widget.id] case final gif?) {
      return Image.asset(gif, fit: BoxFit.contain, gaplessPlayback: true, semanticLabel: widget.label, errorBuilder: (_, _, _) => _icon);
    }
    final n = moveDrawings[widget.id];
    if (n == null) return _icon;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: SvgPicture.asset(drawingAsset(n, end: _end), key: ValueKey(_end), fit: BoxFit.contain, semanticsLabel: widget.label),
    );
  }
}

const _bodyParts = ['chest', 'back', 'shoulders', 'upper arms', 'lower arms', 'upper legs', 'lower legs', 'waist', 'cardio', 'neck'];

String _title(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// The animation on the white card it was drawn for, so it reads the same in light and dark mode. Without a licensed
/// animation (release builds, or no url) the card shows a plain icon instead.
class ExerciseGif extends StatelessWidget {
  const ExerciseGif(this.url, {super.key, this.size, this.id});
  final String? url;
  final double? size;
  final String? id; // the move, for its licensed drawing when no animation may be shown

  /// The catalogue url, else the ExerciseDB V1 media address for a catalogue id (same host and pattern), so a move
  /// still animates when its catalogue row has not loaded.
  String? get _src => url ?? (id != null && RegExp(r'^[A-Za-z0-9]{7}$').hasMatch(id!) ? 'https://static.exercisedb.dev/media/$id.gif' : null);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    clipBehavior: Clip.antiAlias,
    child: !exerciseDbContent || _src == null
        ? Padding(padding: const EdgeInsets.all(6), child: MoveDemo(id))
        : Image.network(
            _src!,
            fit: BoxFit.contain,
            // The media host sends no CORS headers; an <img> element still shows it on web. Mobile is unaffected.
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            gaplessPlayback: true,
            // Offline or a missing file: Levlofit's own demonstration instead of a broken image.
            errorBuilder: (_, _, _) => Padding(padding: const EdgeInsets.all(6), child: MoveDemo(id)),
            loadingBuilder: (_, child, p) =>
                p == null ? child : const Center(child: SizedBox(width: 28, height: 3, child: LinearProgressIndicator(minHeight: 3))),
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
    if (!exerciseDbContent) return; // licensed mode: the Levlofit moves guide only
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
            sliver: SliverList.list(
              children: [
                Reveal(child: Text('See every move.', style: t.headlineMedium)),
                const SizedBox(height: 6),
                Reveal(
                  index: 1,
                  child: Text(
                    exerciseDbContent ? 'Red shows the muscles doing the work.' : 'Pick a muscle group to see the moves your plans use.',
                    style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 20),
                Reveal(
                  index: 2,
                  child: _MuscleGuide(group: _group, onGroup: (g) => setState(() => _group = g == _group ? null : g)),
                ),
                const SizedBox(height: 20),
                if (!exerciseDbContent) Text(exerciseMediaCredit, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          if (exerciseDbContent) ..._catalogue(context),
        ],
      ),
    );
  }

  /// Search, body-part chips and the animation grid (development builds only).
  List<Widget> _catalogue(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverList.list(
          children: [
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
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.74,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) => Reveal(index: i % _page, child: _ExerciseCard(_items[i])),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        sliver: SliverList.list(
          children: [
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
          ],
        ),
      ),
    ];
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Hero(tag: 'ex-${row['id']}', child: ExerciseGif(row['gif_url'] as String?, id: row['id'] as String?)),
                ),
                const SizedBox(height: 10),
                Text(
                  _title(row['name'] as String),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                ),
                const SizedBox(height: 4),
                if (target.isNotEmpty)
                  Text(
                    target.first.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoLabel(context).copyWith(color: c.tertiary),
                  ),
              ],
            ),
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
      body: !exerciseDbContent
          ? (moveGuide[id] == null
                ? const Padding(padding: EdgeInsets.all(24), child: ErrorLine('This move is not in the Levlofit guide yet.'))
                : _guideOnly(context, id, moveGuide[id]!, Text(exerciseMediaCredit, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))))
          : FutureBuilder(
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
                  return _guideOnly(
                    context,
                    id,
                    guide!,
                    ErrorLine(
                      missing
                          ? 'The animation and steps for this move are not in the catalogue yet.'
                          : 'The animation and steps could not load. Check your connection.',
                    ),
                  );
                }
                final row = snap.data;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Hero(tag: 'ex-$id', child: ExerciseGif(row?['gif_url'] as String?, id: id)),
                        ),
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
                        _Steps((row['instructions'] as List).cast<String>()),
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

/// Who demonstrates Levlofit's own animations. Remembered on this device; the profile sets it until then.
class _FigureChoice extends StatelessWidget {
  const _FigureChoice();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: demoFigure,
    builder: (context, f, _) => SegmentedButton<DemoFigure>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: DemoFigure.man, label: Text('Man')),
        ButtonSegment(value: DemoFigure.woman, label: Text('Woman')),
      ],
      selected: {f},
      onSelectionChanged: (s) {
        demoFigure.value = s.first;
        try {
          prefs.setString(demoFigureKey, s.first.name);
        } catch (_) {} // no device settings yet (tests): the choice still applies on screen
      },
    ),
  );
}

/// A move from Levlofit's own guide: name, muscles and versions, then [footer].
Widget _guideOnly(BuildContext context, String id, MoveGuide guide, Widget footer) => ListView(
  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
  children: [
    if (moveVectorAnimations[id] != null || moveAnimations[id] != null || moveDrawings[id] != null) ...[
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: MoveDemo(id, label: '${guide.name}, demonstration', iconSize: 56),
            ),
          ),
        ),
      ),
      if (moveVectorAnimations[id] != null)
        const Padding(padding: EdgeInsets.only(top: 8), child: Center(child: _FigureChoice()))
      else if (moveAnimations[id] == null || moveAnimationNotes[id] != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(moveAnimationNotes[id] ?? 'Two positions of the move, shown in turn.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      const SizedBox(height: 16),
    ],
    Text(guide.name, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 14),
    _GuideTags(guide),
    if (guide.versions.isNotEmpty) _Versions(guide.versions),
    if (moveCues[id] case final cues?) ...[
      const SizedBox(height: 12),
      Text('HOW TO DO IT', style: monoLabel(context)),
      const SizedBox(height: 12),
      _Steps(cues),
      Text(
        'General technique cues from Levlofit, pending expert review. Stop if a move hurts.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
    const SizedBox(height: 8),
    footer,
  ],
);

/// Numbered steps.
class _Steps extends StatelessWidget {
  const _Steps(this.steps);
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i == 0 ? c.primary : c.secondary, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: monoNumber(context, size: 13).copyWith(color: i == 0 ? c.onPrimary : c.onSecondary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(s, style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
              ],
            ),
          ),
      ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(label, style: monoLabel(context)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: strong ? c.primary : c.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: strong ? c.primary : c.outline),
                    ),
                    child: Text(
                      titleCase ? _title(m) : m,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: strong ? c.onPrimary : c.onSurface),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Levlofit's muscle notes for a prescribed move.
class _GuideTags extends StatelessWidget {
  const _GuideTags(this.g);
  final MoveGuide g;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Tags('GROUP', [g.group], strong: true, titleCase: false),
      _Tags(g.group == 'Mobility' ? 'STRETCHES' : 'WORKS', g.main, titleCase: false),
      _Tags('HELPS', g.assist, titleCase: false),
      if (g.equipment != null) _Tags('NEEDS', [g.equipment!], titleCase: false),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Muscle lists are general anatomy, pending expert review.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ],
  );
}

/// Other versions of the same movement used in Levlofit plans.
class _Versions extends StatelessWidget {
  const _Versions(this.ids);
  final List<String> ids;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text('VERSIONS', style: monoLabel(context)),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in ids)
                if (moveGuide[id] case final g?)
                  // Not an ActionChip: a chip has a fixed height, so a long name ("Dumbbell Romanian deadlift") was cut off
                  // at phone width (device check 2026-10-24). This box grows to a second line instead.
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Theme.of(context).colorScheme.outline)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: id))),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text(g.name, style: Theme.of(context).textTheme.labelLarge),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Browse the moves Levlofit prescribes by muscle group, with the anatomical regions of each group.
class _MuscleGuide extends StatefulWidget {
  const _MuscleGuide({required this.group, required this.onGroup});
  final String? group;
  final ValueChanged<String> onGroup;

  @override
  State<_MuscleGuide> createState() => _MuscleGuideState();
}

class _MuscleGuideState extends State<_MuscleGuide> {
  String? _equipment, _difficulty;

  Widget _chips(List<String> options, String? value, ValueChanged<String?> onChanged) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(label: Text(o), selected: value == o, showCheckmark: false, onSelected: (_) => onChanged(value == o ? null : o)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final g = widget.group;
    final filtering = g != null || _equipment != null || _difficulty != null;
    final moves = filtering ? filteredMoves(group: g, equipment: _equipment, difficulty: _difficulty) : const <(String, MoveGuide)>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LEVLOFIT MOVES BY MUSCLE', style: monoLabel(context)),
        const SizedBox(height: 4),
        Text('Tap a muscle to see its exercises, or pick a group below.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 220,
            child: MuscleMap(
              selected: g,
              onGroup: widget.onGroup,
              // A tap on the body opens that muscle's exercises, as MuscleWiki does; the chips below still filter by group.
              onMuscle: (m) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MuscleExercisesScreen(muscle: m))),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in muscleRegions.keys) ChoiceChip(label: Text(name), selected: g == name, showCheckmark: false, onSelected: (_) => widget.onGroup(name)),
          ],
        ),
        const SizedBox(height: 14),
        Text('EQUIPMENT', style: monoLabel(context)),
        const SizedBox(height: 8),
        _chips(equipmentKinds, _equipment, (v) => setState(() => _equipment = v)),
        const SizedBox(height: 14),
        Text('DIFFICULTY', style: monoLabel(context)),
        const SizedBox(height: 8),
        _chips(difficultyLevels, _difficulty, (v) => setState(() => _difficulty = v)),
        const SizedBox(height: 4),
        Text("Levlofit's own rating of how much strength or skill a first try needs.", style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
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
        ],
        if (filtering) ...[
          const SizedBox(height: 8),
          if (moves.isEmpty) Text('No moves match these filters. Clear one to see more.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          for (final (id, m) in moves)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m.name),
              subtitle: Text([
                if (m.main.isEmpty) 'Conditioning: many muscles at once' else '${m.group == 'Mobility' ? 'Stretches ' : ''}${m.main.join('  ·  ')}',
                '${difficultyOf(id)}  ·  ${equipmentKind(m)}',
              ].join('\n')),
              isThreeLine: true,
              trailing: const Icon(LvIcons.caretRight, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: id))),
            ),
        ],
      ],
    );
  }
}

/// One muscle's exercises, opened by tapping it on the body map (MuscleWiki-style): Levlofit's guide moves first
/// (main movers, then moves where it assists), then every catalogue exercise that targets it, with its animation.
class MuscleExercisesScreen extends StatefulWidget {
  const MuscleExercisesScreen({super.key, required this.muscle, @visibleForTesting this.loadCatalogue});
  final String muscle;
  final Future<List<Map<String, dynamic>>> Function(List<String> names)? loadCatalogue; // tests

  @override
  State<MuscleExercisesScreen> createState() => _MuscleExercisesScreenState();
}

class _MuscleExercisesScreenState extends State<MuscleExercisesScreen> {
  late final Future<List<_Json>> _catalogue = !exerciseDbContent
      ? Future.value(const <_Json>[])
      : (widget.loadCatalogue ?? _load)(muscleMatch[widget.muscle]?.catalogue ?? const []);

  static Future<List<_Json>> _load(List<String> names) async => names.isEmpty
      ? const <_Json>[]
      : List<_Json>.from(await supabase
          .from('exercises')
          .select('id, name, gif_url, target_muscles')
          .eq('has_media', true)
          .overlaps('target_muscles', names)
          .order('name', ascending: true)
          .limit(60));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final moves = movesForMuscle(widget.muscle);
    return Scaffold(
      appBar: AppBar(title: Text(widget.muscle)),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverList.list(children: [
            Text('LEVLOFIT MOVES', style: monoLabel(context)),
            const SizedBox(height: 8),
            if (moves.isEmpty) Text('No Levlofit move trains this muscle yet.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            for (final (id, m, main) in moves)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox.square(dimension: 56, child: ExerciseGif(null, id: id)),
                title: Text(m.name),
                subtitle: Text('${main ? 'Main mover' : 'Also works it'}  ·  ${difficultyOf(id)}  ·  ${equipmentKind(m)}'),
                trailing: const Icon(LvIcons.caretRight, size: 16),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: id))),
              ),
            const SizedBox(height: 20),
          ]),
        ),
        if (exerciseDbContent)
          FutureBuilder<List<_Json>>(
            future: _catalogue,
            builder: (context, snap) {
              final rows = snap.data ?? const <_Json>[];
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                sliver: SliverMainAxisGroup(slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(snap.connectionState != ConnectionState.done ? 'MORE EXERCISES' : 'MORE EXERCISES  ·  ${rows.length}', style: monoLabel(context)),
                    ),
                  ),
                  if (snap.connectionState != ConnectionState.done)
                    const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 3))
                  else if (snap.hasError)
                    SliverToBoxAdapter(child: Text('Could not load more exercises. Check your connection.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)))
                  else
                    SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.74),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _ExerciseCard(rows[i]),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(exerciseMediaCredit, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))),
                  ),
                ]),
              );
            },
          ),
      ]),
    );
  }
}

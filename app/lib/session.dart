// Training sessions with real moves: which exercises a goal's session uses, how much of each, and the screens
// that show them as animated GIFs. Doses follow the Handbook chapter "Sets, reps and progress" (ACSM 2026):
// 2 to 3 sets per lift, a rep range such as 8 to 12, ending sets with 1 to 3 reps in reserve.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'exercises.dart';
import 'icons.dart';
import 'main.dart';
import 'reminders.dart';
import 'theme.dart';

enum Tier { none, home, gym }

/// What the user trains with: gym, home dumbbells, or nothing.
Tier tierFor(String? equipment, List<dynamic>? items) => switch (equipment) {
      'gym' => Tier.gym,
      'home' => Tier.home,
      'custom' => (items ?? const []).any((i) => '$i'.contains('dumbbell') || '$i'.contains('kettlebell')) ? Tier.home : Tier.none,
      _ => Tier.none,
    };

// ExerciseDB ids (public.exercises), all with working animations. Two sessions, A and B, alternate within a week.
const _strength = {
  Tier.gym: [
    ['qXTaZnJ', 'EIeI8Vf', 'fUBheHs', 'wQ2c4XD', 'iny3m5y'], // squat, bench, seated row, RDL, dead bug
    ['ila4NZS', 'znQUdHY', 'RVwzP10', 'RRWFUcw', 'qPEzJjA'], // deadlift, shoulder press, pulldown, lunge, carry
  ],
  Tier.home: [
    ['yn8yg1r', 'SpYC0Kp', 'BJ0Hz5L', 'rR0LJzx', 'iny3m5y'], // goblet squat, DB bench, DB row, DB RDL, dead bug
    ['aXtJhlg', 'A6wtbuL', 'I4hDWkc', 'qPEzJjA', 'RKjH6Lt'], // step-up, overhead press, push-up, carry, side bridge
  ],
  Tier.none: [
    ['QChZi3x', 'I4hDWkc', 'bZGHsAZ', 'u0cNiij', 'iny3m5y'], // squat, push-up, inverted row, glute bridge, dead bug
    ['9E25EOx', 'B1EVP9F', 'wd4ds3s', 'IZVHb27', 'RKjH6Lt'], // split squat, incline push-up, row, lunge, side bridge
  ],
};
const _skillBasics = ['bZGHsAZ', 'B1EVP9F', '9RT8oQW', 'QChZi3x', 'iny3m5y']; // levels 0 and 1
const _skillBuilt = ['lBDjFxJ', 'I4hDWkc', '9WTm7dq', '9E25EOx', 'I3tsCnC']; // pull-up, push-up, dip, split squat, leg raise
const _endurance = ['ealLwvX', 'DFGXwZr', 'oLrKqDH', 'bJYHBIN', '0mB6wHO']; // drills, run, calf raise, stretch
const _hybridKit = ['UHJlbu3', 'IZVHb27', 'dK9394r', 'qPEzJjA', 'oLrKqDH']; // swing, lunge, burpee, carry, run
const _hybridBody = ['LIlE5Tn', 'IZVHb27', 'dK9394r', 'RJgzwny', 'oLrKqDH']; // jump squat, lunge, burpee, climber, run
const _mobility = ['DFGXwZr', '0mB6wHO', '99rWm7w', 'DeDThfG', 'f38OEuO', 'JbC2iaV'];

const _stretches = {'DFGXwZr', '0mB6wHO', '99rWm7w', 'DeDThfG', 'f38OEuO', 'JbC2iaV'};
const _drills = {'ealLwvX'};
const _carries = {'qPEzJjA'};
const _core = {'iny3m5y', 'RKjH6Lt', 'I3tsCnC'};
const _run = 'oLrKqDH';
// Multi-joint lifts get the longer rest.
const _compounds = {'qXTaZnJ', 'EIeI8Vf', 'fUBheHs', 'wQ2c4XD', 'ila4NZS', 'znQUdHY', 'RVwzP10', 'yn8yg1r', 'SpYC0Kp', 'BJ0Hz5L', 'rR0LJzx', 'A6wtbuL', 'lBDjFxJ', '9WTm7dq'};

/// Rest after a set, in seconds: 2 min or more maximises strength on big lifts (Grgic 2018);
/// over 60 s gives a small edge for muscle growth (Singer 2024), so 90 s for the rest.
int restFor(String id) => _compounds.contains(id) ? 120 : 90;

/// Exercise ids for one session of [kind] at [level]. [index] is which session of that goal this is in the week.
List<String> sessionIds(String kind, Tier tier, int level, int index) => switch (kind) {
      'skill' => level <= 1 ? _skillBasics : _skillBuilt,
      'endurance' => _endurance,
      'hybrid' => tier == Tier.none ? _hybridBody : _hybridKit,
      'mobility' => _mobility,
      _ => _strength[tier]![index % 2],
    };

/// Lifts log reps and kilograms per set; everything else is just ticked.
bool isLift(String id) => setsFor(id, 1) > 0 && !_carries.contains(id) && !_core.contains(id);

typedef SetLog = ({int reps, double? kg});

/// The coach's next step for a lift, from last session's sets, by double progression (Handbook,
/// "Sets, reps and progress", ACSM 2026): stay at a weight until every set reaches 12 reps, then add the
/// smallest weight step you have and work back up from 8.
String nextStep(List<SetLog> last) {
  if (last.isEmpty) return 'First time: pick a weight you can lift 8 to 12 times with 1 to 3 reps left.';
  final kg = last.first.kg;
  final at = kg == null || kg == 0 ? 'bodyweight' : '${kg % 1 == 0 ? kg.toInt() : kg} kg';
  final reps = last.map((x) => x.reps).join(', ');
  if (last.every((x) => x.reps >= 12)) return 'Last time $reps at $at. Every set hit 12: add the smallest weight step today and aim for 8 or more.';
  return 'Last time $reps at $at. Same weight today; beat at least one of those numbers.';
}

/// Sets to tick on the session screen; 0 when the move is done once (run, stretch, drill).
int setsFor(String id, int level) => _stretches.contains(id) || _drills.contains(id) || id == _run ? 0 : (level <= 1 ? 2 : 3);

/// How much of a move, in words. Lifting doses: Handbook "Sets, reps and progress" (ACSM 2026).
/// Stretch holds stay under the 60 s that can blunt strength for a while (Behm 2016).
String doseFor(String id, int level) {
  final sets = setsFor(id, level);
  if (id == _run) return 'Main block at an easy pace you can talk at';
  if (_stretches.contains(id)) return 'Hold 30 s or less, each side';
  if (_drills.contains(id)) return 'Warm-up, until you feel loose';
  if (_carries.contains(id)) return '$sets walks, stop before grip or posture fades';
  if (_core.contains(id)) return '$sets sets, slow and controlled';
  return '$sets sets × 8–12 reps, 1–3 left in the tank';
}

final _cache = <String, Map<String, dynamic>>{};

/// Loads name and GIF for [ids], keeping their order; cached for the app session.
Future<List<Map<String, dynamic>>> loadMoves(List<String> ids) async {
  final missing = ids.where((i) => !_cache.containsKey(i)).toList();
  if (missing.isNotEmpty) {
    final rows = await supabase.from('exercises').select('id, name, gif_url, target_muscles').inFilter('id', missing);
    for (final r in rows) {
      _cache[r['id'] as String] = r;
    }
  }
  return [for (final i in ids) ?_cache[i]];
}

String moveName(Map<String, dynamic> m) => (m['name'] as String).split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// A horizontal strip of animated moves with names and doses. Tapping a move opens its detail.
class MoveStrip extends StatelessWidget {
  const MoveStrip({super.key, required this.ids, required this.level, this.tile = 128});
  final List<String> ids;
  final int level;
  final double tile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: tile + 54,
      child: FutureBuilder(
        future: loadMoves(ids),
        builder: (context, snap) {
          final moves = snap.data;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: moves?.length ?? ids.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final m = moves?[i];
              return SizedBox(
                width: tile,
                child: Pressable(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: m == null ? null : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: m['id'] as String))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: tile,
                        height: tile,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.outline)),
                        child: m == null ? null : ExerciseGif(m['gif_url'] as String),
                      ),
                      const SizedBox(height: 8),
                      Text(m == null ? ' ' : moveName(m), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge),
                      Text(
                        m == null ? ' ' : doseFor(m['id'] as String, level),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(fontSize: 11, height: 1.3, color: c.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// One session, move by move: animation, dose, and a box per set to tick. Finishing logs the day.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.title, required this.ids, required this.level, this.onFinish, this.done = false});
  final String title;
  final List<String> ids;
  final int level;
  final Future<void> Function()? onFinish; // null when this session is not today's
  final bool done;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final _moves = loadMoves(widget.ids);
  final _ticked = <String, int>{};
  final _today = <String, List<SetLog>>{}; // sets logged in this session, by move
  Map<String, List<SetLog>> _last = {}; // the previous session's sets, by move
  bool _saving = false;
  late bool _done = widget.done;
  // Rest timer: counts down from [_restTotal] after a set is ticked.
  Timer? _rest;
  DateTime? _restEnds;
  int _restTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  /// The most recent earlier session for each lift, so every move can show the next step.
  Future<void> _loadLast() async {
    final lifts = widget.ids.where(isLift).toList();
    if (lifts.isEmpty) return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('set_logs')
          .select('exercise_id, performed_on, set_no, reps, kg')
          .eq('user_id', supabase.auth.currentUser!.id)
          .inFilter('exercise_id', lifts)
          .lt('performed_on', today)
          .order('performed_on', ascending: false)
          .order('set_no', ascending: true)
          .limit(300);
      final last = <String, List<SetLog>>{};
      final day = <String, String>{};
      for (final r in rows) {
        final id = r['exercise_id'] as String;
        day.putIfAbsent(id, () => r['performed_on'] as String);
        if (day[id] != r['performed_on']) continue;
        (last[id] ??= []).add((reps: r['reps'] as int, kg: (r['kg'] as num?)?.toDouble()));
      }
      if (mounted) setState(() => _last = last);
    } catch (_) {
      // Without history the session still works; the hint says it is the first time.
    }
  }

  /// A lift's set: ask for reps and load (prefilled from last time), save it, then tick it.
  Future<void> _logSet(String id, int setNo) async {
    final prev = _today[id]?.lastOrNull ?? _last[id]?.elementAtOrNull(setNo - 1) ?? _last[id]?.lastOrNull;
    var reps = prev?.reps ?? 10;
    final kg = TextEditingController(text: prev?.kg == null ? '' : '${prev!.kg! % 1 == 0 ? prev.kg!.toInt() : prev.kg}');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SET $setNo', style: monoLabel(sheet)),
                const SizedBox(height: 12),
                Row(children: [
                  Text('Reps', style: Theme.of(sheet).textTheme.titleMedium),
                  const Spacer(),
                  IconButton.outlined(onPressed: reps > 1 ? () => setSheet(() => reps--) : null, icon: const Icon(LvIcons.minus, size: 18)),
                  SizedBox(width: 56, child: Text('$reps', textAlign: TextAlign.center, style: monoNumber(sheet, size: 28))),
                  IconButton.outlined(onPressed: reps < 100 ? () => setSheet(() => reps++) : null, icon: const Icon(LvIcons.plus, size: 18)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: kg,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d?)?$'))],
                  decoration: const InputDecoration(labelText: 'Weight, leave empty for bodyweight', suffixText: 'kg'),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Log set'))),
              ]),
            ),
          ),
        ),
      ),
    );
    final load = double.tryParse(kg.text);
    kg.dispose();
    if (saved != true) return;
    try {
      await supabase.from('set_logs').insert({'exercise_id': id, 'set_no': setNo, 'reps': reps, 'kg': load});
      if (!mounted) return;
      setState(() {
        (_today[id] ??= []).add((reps: reps, kg: load));
        _ticked[id] = setNo;
      });
      if (_doneSets < _totalSets) _startRest(restFor(id));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the set. Check your connection.')));
    }
  }

  /// Unticks back to [setNo] and removes those sets from today's log.
  Future<void> _undoSet(String id, int setNo) async {
    setState(() {
      _ticked[id] = setNo - 1;
      _today[id] = [...?_today[id]].take(setNo - 1).toList();
    });
    if (!isLift(id)) return;
    try {
      await supabase
          .from('set_logs')
          .delete()
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('exercise_id', id)
          .eq('performed_on', DateTime.now().toIso8601String().substring(0, 10))
          .gte('set_no', setNo);
    } catch (_) {}
  }

  int get _restLeft => _restEnds == null ? 0 : _restEnds!.difference(DateTime.now()).inMilliseconds.clamp(0, 1 << 30) ~/ 1000;

  void _startRest(int seconds) {
    _rest?.cancel();
    setState(() {
      _restTotal = seconds;
      _restEnds = DateTime.now().add(Duration(seconds: seconds));
    });
    _rest = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_restLeft <= 0) {
        _stopRest();
        HapticFeedback.heavyImpact();
        Reminders.chime();
      } else {
        setState(() {});
      }
    });
  }

  void _stopRest() {
    _rest?.cancel();
    if (mounted) setState(() => _restEnds = null);
  }

  void _adjustRest(int by) => setState(() {
        _restEnds = _restEnds!.add(Duration(seconds: by));
        _restTotal = (_restTotal + by).clamp(1, 600);
      });

  @override
  void dispose() {
    _rest?.cancel();
    super.dispose();
  }

  int get _totalSets => widget.ids.fold(0, (s, id) => s + setsFor(id, widget.level));
  int get _doneSets => _ticked.values.fold(0, (s, n) => s + n);

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await widget.onFinish!();
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection and try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: t.titleMedium),
        actions: [
          IconButton(tooltip: 'Timer', icon: const Icon(LvIcons.timer, size: 22), onPressed: () => showTimerSheet(context)),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: motion(context, 400),
            curve: spring,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 3),
          ),
        ),
      ),
      body: FutureBuilder(
        future: _moves,
        builder: (context, snap) {
          if (snap.hasError) return const Padding(padding: EdgeInsets.all(24), child: ErrorLine('Could not load this session. Check your connection.'));
          final moves = snap.data;
          if (moves == null) return const Center(child: CircularProgressIndicator());
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: staggered([
                  Text('${moves.length} MOVES  ·  $_doneSets OF $_totalSets SETS', style: monoLabel(context)),
                  const SizedBox(height: 14),
                  for (final (i, m) in moves.indexed) ...[
                    _MoveCard(
                      number: i + 1,
                      move: m,
                      level: widget.level,
                      ticked: _ticked[m['id']] ?? 0,
                      hint: isLift(m['id'] as String) ? nextStep(_last[m['id']] ?? const []) : null,
                      onSet: (s) {
                        HapticFeedback.selectionClick();
                        final id = m['id'] as String;
                        final done = _ticked[id] ?? 0;
                        if (s <= done) {
                          _undoSet(id, s);
                          return;
                        }
                        // Sets fill in order; lifts ask for reps and load first.
                        if (isLift(id)) {
                          _logSet(id, done + 1);
                          return;
                        }
                        setState(() => _ticked[id] = done + 1);
                        // Rest after each set except the very last one of the session.
                        if (_doneSets < _totalSets) _startRest(restFor(id));
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text('Warm up first, stop any move that hurts, and rest long enough to repeat good reps. $exerciseMediaCredit.',
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ]),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: 600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: motion(context, 300),
              switchInCurve: spring,
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, alignment: Alignment.bottomCenter, child: child)),
              child: _restEnds == null
                  ? const SizedBox(width: double.infinity, key: ValueKey('no-rest'))
                  : Padding(
                      key: const ValueKey('rest'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RestBar(left: _restLeft, total: _restTotal, onAdjust: _adjustRest, onSkip: _stopRest),
                    ),
            ),
            if (widget.onFinish != null)
              SizedBox(
                height: 56,
                child: AnimatedSwitcher(
                  duration: motion(context, 300),
                  child: _done
                      ? Container(
                          key: const ValueKey('done'),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.secondary, borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LvIcons.checkCircle, color: c.primary),
                            const SizedBox(width: 8),
                            Text('Session logged', style: t.titleMedium?.copyWith(color: c.onSecondary)),
                          ]),
                        )
                      : FilledButton(
                          key: const ValueKey('finish'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: _saving ? null : _finish,
                          child: Text(_doneSets == 0 ? 'Mark session done' : 'Finish and log session'),
                        ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MoveCard extends StatelessWidget {
  const _MoveCard({required this.number, required this.move, required this.level, required this.ticked, required this.hint, required this.onSet});
  final int number;
  final Map<String, dynamic> move;
  final int level, ticked;
  final String? hint; // the coach's next step for a lift
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final id = move['id'] as String;
    final sets = setsFor(id, level);
    final complete = sets > 0 && ticked >= sets;
    return AnimatedContainer(
      duration: motion(context, 260),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: complete ? c.primary : c.outline, width: complete ? 1.5 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExerciseScreen(id: id))),
          child: Container(
            width: 104,
            height: 104,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ExerciseGif(move['gif_url'] as String),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$number'.padLeft(2, '0'), style: monoLabel(context).copyWith(color: c.tertiary)),
            const SizedBox(height: 2),
            Text(moveName(move), style: t.titleMedium),
            const SizedBox(height: 2),
            Text(doseFor(id, level), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!, style: t.bodySmall?.copyWith(color: c.tertiary, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 10),
            if (sets > 0)
              Wrap(spacing: 8, children: [
                for (var s = 1; s <= sets; s++)
                  Semantics(
                    button: true,
                    label: 'Set $s ${s <= ticked ? 'done' : 'not done'}',
                    child: GestureDetector(
                      onTap: () => onSet(s),
                      child: AnimatedContainer(
                        duration: motion(context, 220),
                        curve: spring,
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s <= ticked ? c.primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: s <= ticked ? c.primary : c.outline, width: 1.5),
                        ),
                        child: s <= ticked ? Icon(LvIcons.check, size: 16, color: c.onPrimary) : Text('$s', style: monoNumber(context, size: 13)),
                      ),
                    ),
                  ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// The rest countdown that slides up after each set: time left, a draining bar, nudges and skip.
class _RestBar extends StatelessWidget {
  const _RestBar({required this.left, required this.total, required this.onAdjust, required this.onSkip});
  final int left, total;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const onInk = cloud;
    return Material(
      color: Theme.of(context).brightness == Brightness.dark ? c.surfaceContainerHighest : graphite,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: total == 0 ? 0 : left / total, minHeight: 3, backgroundColor: Colors.transparent),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('REST', style: monoLabel(context).copyWith(color: onInk.withValues(alpha: 0.6), fontSize: 10)),
              Text(_clock(left), style: monoNumber(context, size: 26).copyWith(color: onInk)),
            ]),
            const Spacer(),
            TextButton(onPressed: () => onAdjust(-15), style: TextButton.styleFrom(foregroundColor: onInk), child: const Text('-15s')),
            TextButton(onPressed: () => onAdjust(15), style: TextButton.styleFrom(foregroundColor: onInk), child: const Text('+15s')),
            FilledButton(onPressed: onSkip, style: FilledButton.styleFrom(minimumSize: const Size(64, 40)), child: const Text('Skip')),
          ]),
        ),
      ]),
    );
  }
}

/// A free timer for anything in a session: countdown presets or a stopwatch.
Future<void> showTimerSheet(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (_) => const SafeArea(child: _TimerSheet()));

class _TimerSheet extends StatefulWidget {
  const _TimerSheet();

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  bool _stopwatch = false;
  int _preset = 90;
  DateTime? _started; // running since
  Duration _banked = Duration.zero; // time already counted before a pause
  Timer? _tick;

  Duration get _elapsed => _banked + (_started == null ? Duration.zero : DateTime.now().difference(_started!));
  int get _shown => _stopwatch ? _elapsed.inSeconds : (_preset - _elapsed.inSeconds).clamp(0, _preset);

  void _toggle() {
    HapticFeedback.selectionClick();
    if (_started != null) {
      _tick?.cancel();
      setState(() {
        _banked = _elapsed;
        _started = null;
      });
      return;
    }
    setState(() => _started = DateTime.now());
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (!_stopwatch && _shown == 0) {
        _tick?.cancel();
        setState(() {
          _started = null;
          _banked = Duration.zero;
        });
        HapticFeedback.heavyImpact();
        Reminders.chime();
      } else {
        setState(() {});
      }
    });
  }

  void _reset() {
    _tick?.cancel();
    setState(() {
      _started = null;
      _banked = Duration.zero;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _started != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Timer')), ButtonSegment(value: true, label: Text('Stopwatch'))],
          selected: {_stopwatch},
          showSelectedIcon: false,
          onSelectionChanged: running
              ? null
              : (v) => setState(() {
                    _stopwatch = v.first;
                    _banked = Duration.zero;
                  }),
        ),
        const SizedBox(height: 20),
        Text(_clock(_shown), style: monoNumber(context, size: 64)),
        const SizedBox(height: 12),
        if (!_stopwatch)
          Wrap(spacing: 8, children: [
            for (final p in const [30, 60, 90, 120, 180])
              ChoiceChip(
                label: Text(p < 60 ? '${p}s' : _clock(p)),
                selected: _preset == p,
                onSelected: running
                    ? null
                    : (_) => setState(() {
                          _preset = p;
                          _banked = Duration.zero;
                        }),
              ),
          ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _reset, child: const Text('Reset'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: _toggle, child: Text(running ? 'Pause' : 'Start'))),
        ]),
      ]),
    );
  }
}

// The side menu and the pages it opens: Workout, Diet, Calendar, Progress, plus tools and learning.
// A part of dashboard.dart so the pages share its plan helpers (schedule, tiles, sheets) without exporting them.
// Calendar and Progress take their shape from the owner's earlier APS project (ideas only, rebuilt here):
// a calendar of marks with a day drawer, and a progress page that answers "is this working?" before anything else.
part of 'dashboard.dart';

/// Three lines of unequal length; the short ones stretch under the finger.
class _MenuButton extends StatefulWidget {
  const _MenuButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget line(double w) => AnimatedContainer(
          duration: motion(context, 260),
          curve: spring,
          width: w,
          height: 1.6,
          decoration: BoxDecoration(color: c.onSurface, borderRadius: BorderRadius.circular(1)),
        );
    return Semantics(
      button: true,
      label: 'Open menu',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hot = true),
        onExit: (_) => setState(() => _hot = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // the whole slot is the target; the visible disc stays small
          onTapDown: (_) => setState(() => _hot = true),
          onTapCancel: () => setState(() => _hot = false),
          onTap: () {
            setState(() => _hot = false);
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.outline), color: c.surface),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                line(14),
                const SizedBox(height: 3),
                line(_hot ? 14 : 8),
                const SizedBox(height: 3),
                line(_hot ? 14 : 11),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.current, required this.data, required this.onSelect});
  final _Tab current;
  final _Data? Function() data;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final first = (data()?.name ?? '').split(' ').first;

    void go(_Tab tab) {
      Navigator.pop(context);
      onSelect(tab);
    }

    Widget item(IconData icon, String label, _Tab tab) => _MenuItem(icon: icon, label: label, selected: current == tab, onTap: () => go(tab));

    final items = <Widget>[
      const _MenuSection('TRAIN'),
      item(LvIcons.house, 'Dashboard', _Tab.home),
      item(LvIcons.barbell, 'Workout', _Tab.workout),
      item(LvIcons.notePencil, 'Protocol', _Tab.protocol),
      item(LvIcons.calendarBlank, 'Calendar', _Tab.calendar),
      item(LvIcons.chartLineUp, 'Progress', _Tab.progress),
      const _MenuSection('FUEL'),
      item(LvIcons.forkKnife, 'Diet', _Tab.diet),
      item(LvIcons.drop, 'Hydration', _Tab.hydration),
      item(LvIcons.forkKnife, 'Food diary', _Tab.foodDiary),
      item(LvIcons.magnifyingGlass, 'Food library', _Tab.foods),
      const _MenuSection('HABITS AND TOOLS'),
      item(LvIcons.checkCircle, 'Habits', _Tab.habits),
      item(LvIcons.scales, 'BMI calculator', _Tab.bmi),
      const _MenuSection('LEARN'),
      item(LvIcons.bookOpen, 'Handbook', _Tab.handbook),
      item(LvIcons.personSimpleRun, 'Exercise library', _Tab.library),
      item(LvIcons.lightbulb, 'Glossary', _Tab.glossary),
      const SizedBox(height: 8),
      _MenuItem(
        icon: LvIcons.sparkle,
        label: 'Levlofit AI',
        accent: true,
        onTap: () {
          final page = Navigator.of(context).context;
          Navigator.pop(context);
          openCoach(page);
        },
      ),
    ];

    return Drawer(
      width: math.min(320, MediaQuery.sizeOf(context).width * 0.86),
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
            child: Row(children: [
              const LevloMark(size: 36, animate: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(first.isEmpty ? 'Levlofit' : first, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleLarge),
                  Text('Find your level', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ]),
              ),
              IconButton(tooltip: 'Close menu', onPressed: () => Navigator.pop(context), icon: const Icon(LvIcons.x, size: 20)),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), children: staggered(items))),
          Divider(height: 1, color: c.outline),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(children: [
              item(LvIcons.timer, 'Reminders', _Tab.reminders),
              item(LvIcons.userCircle, 'Profile', _Tab.profile),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(12, 20, 12, 8), child: Text(text, style: monoLabel(context)));
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.selected = false, this.accent = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected, accent;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final lit = accent || selected;
    return Pressable(
      child: Material(
        color: selected ? c.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: lit ? c.primary : c.surface, borderRadius: BorderRadius.circular(11), border: lit ? null : Border.all(color: c.outline)),
                child: Icon(icon, size: 19, color: lit ? c.onPrimary : c.onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16))),
              if (!selected) Icon(LvIcons.caretRight, size: 16, color: c.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- pages

/// Shared page frame: eyebrow, big title, staggered content, readable width.
class _Page extends StatelessWidget {
  const _Page({required this.eyebrow, required this.title, required this.children, this.subtitle});
  final String eyebrow, title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: const _ShellMenu()),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
            children: staggered([
              Text(eyebrow, style: monoLabel(context)),
              const SizedBox(height: 6),
              Text(title, style: t.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 24),
              ...children,
            ]),
          ),
        ),
      ),
    );
  }
}

class _WorkoutScreen extends StatefulWidget {
  const _WorkoutScreen({required this.data, required this.logged, required this.onEditGoals, required this.onToggleToday, required this.onPlanChanged});
  final _Data data;
  final Set<DateTime> logged;
  final VoidCallback onEditGoals;
  final Future<bool> Function(String goal, int? minutes) onToggleToday;
  final VoidCallback onPlanChanged; // a level check rebuilt the plan

  @override
  State<_WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<_WorkoutScreen> {
  late Set<DateTime> _logged = widget.logged;

  Future<void> _checkLevel(_Json g) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _LevelCheckScreen(goal: g['goal'] as String, goalName: (g['name'] ?? g['goal']) as String, current: g['startLevel'] as int)),
    );
    if (changed == true) widget.onPlanChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final data = widget.data;
    final plan = data.plan;
    final now = DateTime.now();
    final monday = _monday(now);
    final today = _day(now);
    final minutes = data.input['sessionMinutes'] as int?;
    final week = weekPlan(plan, sessionMinutes: minutes, estimate: sessionEstimator(data.tier, kitOf(data.profile)));
    final dayGoal = week.days;
    final goals = (plan['goals'] as List).cast<_Json>();
    final phase = plan['phase'] as _Json?;
    final roadmap = plan['roadmap'] as _Json?;
    return _Page(
      eyebrow: 'WORKOUT',
      title: phase == null ? 'Your training week' : phase['title'] as String,
      subtitle: phase?['why'] as String?,
      children: [
        if (roadmap != null) ...[
          _Roadmap(roadmap: roadmap),
          const SizedBox(height: 24),
        ],
        Row(children: [
          Expanded(child: Text('YOUR GOALS', style: monoLabel(context))),
          TextButton.icon(onPressed: widget.onEditGoals, icon: const Icon(LvIcons.pencilSimple, size: 16), label: const Text('Edit goals')),
        ]),
        const SizedBox(height: 4),
        for (final (i, g) in goals.indexed) ...[
          _GoalCard(
            goal: g,
            primary: i == 0,
            levelRow: data.levels[g['goal']],
            assessed: data.assessed.contains(g['goal']),
            onOpen: data.levels[g['goal']] == null ? null : () => _showLevel(context, (g['name'] ?? g['goal']) as String, data.levels[g['goal']]!),
            onCheck: data.levels.containsKey(g['goal']) && g['status'] != 'queued' ? () => _checkLevel(g) : null,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
        Text('THIS WEEK  ·  ${dayGoal.length} DAYS${minutes == null ? '' : '  ·  $minutes MIN'}${switch (trainingTimeLabel(plan)) { final l? => '  ·  ${l.toUpperCase()}', _ => '' }}',
            style: monoLabel(context)),
        const SizedBox(height: 8),
        for (final a in week.addOns)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(addOnLine(a), style: t.bodyMedium),
          ),
        for (final n in week.notices)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(n, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ),
        if (week.addOns.isNotEmpty || week.notices.isNotEmpty) const SizedBox(height: 8),
        for (var i = 0; i < 7; i++) ...[
          Builder(builder: (context) {
            final day = monday.add(Duration(days: i));
            final done = _logged.contains(day);
            final isToday = day == today;
            // A session moved with Levlofit AI shows on its new day; the day it left says where it went (swaps.dart).
            final src = sessionDayFor(i + 1, dayGoal.keys.toSet(), data.moves);
            final movedTo = data.moves.where((m) => m.$1 == i + 1).map((m) => m.$2).firstOrNull;
            // A rest day may carry an add-on as its own short session; a training day may carry blocks after it.
            final own = src == null && movedTo == null && dayGoal[i + 1] == null ? week.addOns.where((a) => a.day == i + 1).firstOrNull : null;
            final ownBlock = own == null ? null : blocksFor(week, i + 1, data.tier, kitOf(data.profile), const []).first;
            final g = own == null ? dayGoal[src] : {...own.session, 'name': '${own.name} add-on', 'startLevel': ownBlock!.level};
            if (g == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(children: [
                  SizedBox(width: 52, child: Text(_days[i], style: monoLabel(context).copyWith(color: isToday ? c.tertiary : null))),
                  Expanded(
                    child: Text(movedTo != null ? 'Session moved to ${_days[movedTo - 1]}' : dayGoal.containsKey(i + 1) ? 'Open session' : 'Rest and recover',
                        style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                  ),
                  if (done) Icon(LvIcons.checkCircle, size: 18, color: c.primary),
                ]),
              );
            }
            final name = (g['name'] ?? g['goal']) as String;
            final level = g['startLevel'] as int;
            final List<String> ids;
            if (ownBlock != null) {
              ids = ownBlock.ids;
            } else {
              // Which session of this goal it is (by its planned day), so A and B alternate as on the dashboard.
              final nth = [for (var d = 1; d < src!; d++) if (dayGoal[d]?['goal'] == g['goal']) d].length;
              ids = sessionIds(g['kind'] as String? ?? 'strength', data.tier, level, nth, goal: g['goal'] as String?, kit: kitOf(data.profile));
            }
            final blocks = own != null ? const <AddOnBlock>[] : blocksFor(week, i + 1, data.tier, kitOf(data.profile), ids);
            final levelRow = data.levels[g['goal']];
            return _Tile(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${_days[i]}  ${day.day}${isToday ? '  ·  TODAY' : ''}', style: monoLabel(context).copyWith(color: isToday ? c.tertiary : null)),
                  const Spacer(),
                  if (done) Text('DONE', style: monoLabel(context).copyWith(color: c.tertiary)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: t.titleMedium),
                      Text(
                        [g['levelAssessed'] == false ? 'Level not assessed, lightest dose' : 'Level $level', if (levelRow != null) levelRow['title'] as String, if (minutes != null) '$minutes min'].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ]),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Start $name',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SessionScreen(
                          title: name,
                          ids: ids,
                          level: level,
                          blocks: blocks,
                          done: done,
                          injury: data.profile['injuries'] as String?,
                          sessionMinutes: minutes,
                          medicalHold: data.plan['medicalHold'] == true,
                          kind: g['kind'] as String? ?? 'strength',
                          gym: data.tier == Tier.gym,
                          onFinish: isToday && !done
                              ? () async {
                                  // An add-on day logs its own length (the block and a warm-up), not the session setting.
                                  final saved = await widget.onToggleToday(g['goal'] as String, ownBlock == null ? minutes : ownBlock.minutes + 5);
                                  if (saved && mounted) setState(() => _logged = {..._logged, today});
                                  return saved;
                                }
                              : null,
                        ),
                      ),
                    ),
                    icon: const Icon(LvIcons.play, size: 18),
                  ),
                ]),
                const SizedBox(height: 12),
                MoveStrip(ids: ids, level: level, tile: 104, injury: data.profile['injuries'] as String?, lighter: data.plan['medicalHold'] == true),
                for (final b in blocks) ...[
                  const SizedBox(height: 10),
                  Text(blockSummary(b).toUpperCase(), style: monoLabel(context)),
                  if (b.ids.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    MoveStrip(ids: b.ids, level: b.level, tile: 80, injury: data.profile['injuries'] as String?, lighter: data.plan['medicalHold'] == true),
                  ],
                ],
              ]),
            );
          }),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        _Sources(plan: plan),
      ],
    );
  }
}

/// One goal: where you stand on the ladder, whether it trains now or waits, and the level check.
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.primary, required this.levelRow, required this.assessed, required this.onOpen, required this.onCheck});
  final _Json goal;
  final bool primary, assessed;
  final _Json? levelRow;
  final VoidCallback? onOpen, onCheck;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final queued = goal['status'] == 'queued';
    final level = goal['startLevel'] as int;
    return Opacity(
      opacity: queued ? 0.72 : 1,
      child: _Tile(
        onTap: onOpen,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(primary ? 'MAIN GOAL' : (queued ? 'WAITING' : 'ALSO TRAINING'), style: monoLabel(context).copyWith(color: primary ? c.tertiary : null)),
            const Spacer(),
            if (!queued) Text((goal['sessionsPerWeek'] as int) > 0 ? '${goal['sessionsPerWeek']}x / WK' : '+20 MIN', style: monoLabel(context)),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('L', style: monoNumber(context, size: 16).copyWith(color: c.onSurfaceVariant)),
            Text('$level', style: monoNumber(context, size: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((goal['name'] ?? goal['goal']) as String, style: t.titleMedium),
                if (levelRow != null) Text(levelRow!['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          // Six levels, 0 to 5: where you stand on the ladder.
          Row(children: [
            for (var l = 0; l <= 5; l++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(color: l <= level && !queued ? c.primary : c.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (l < 5) const SizedBox(width: 3),
            ],
          ]),
          if (queued) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(LvIcons.timer, size: 16, color: c.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text('Unlocks when ${goal['unlockWhen']}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))),
            ]),
          ],
          if (onCheck != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onCheck,
                icon: Icon(assessed ? LvIcons.trendUp : LvIcons.checkCircle, size: 16),
                label: Text(assessed ? 'Ready to level up? Check again' : 'Check my real level'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// The personal step-by-step path, written by Levlofit AI from the plan and the curriculum level checks.
class _Roadmap extends StatelessWidget {
  const _Roadmap({required this.roadmap});
  final _Json roadmap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final steps = ((roadmap['steps'] as List?) ?? const []).cast<_Json>();
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.outline)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? c.surface : graphite, borderRadius: BorderRadius.circular(23)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(LvIcons.trendUp, size: 16, color: c.primary),
            const SizedBox(width: 8),
            Flexible(child: Text('YOUR PATH  ·  COACH PLAN', overflow: TextOverflow.ellipsis, style: monoLabel(context).copyWith(color: cloud.withValues(alpha: 0.65)))),
          ]),
          const SizedBox(height: 10),
          Text(roadmap['intro'] as String? ?? '', style: t.bodyMedium?.copyWith(color: cloud.withValues(alpha: 0.85))),
          const SizedBox(height: 14),
          for (final (i, s) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i == 0 ? c.primary : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: i == 0 ? c.primary : cloud.withValues(alpha: 0.4))),
                  child: Text('${i + 1}', style: monoNumber(context, size: 12).copyWith(color: i == 0 ? graphite : cloud)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['title'] as String, style: t.titleMedium?.copyWith(color: cloud)),
                    const SizedBox(height: 2),
                    Text(s['focus'] as String, style: t.bodySmall?.copyWith(color: cloud.withValues(alpha: 0.75))),
                    const SizedBox(height: 4),
                    Text('Move on when: ${s['moveOnWhen']}', style: t.bodySmall?.copyWith(color: c.primary)),
                  ]),
                ),
              ]),
            ),
          Text('Built by Levlofit coaching rules from the curriculum level checks. No AI writes your training.', style: t.bodySmall?.copyWith(color: cloud.withValues(alpha: 0.5), fontSize: 11)),
        ]),
      ),
    );
  }
}

class _DietScreen extends StatefulWidget {
  const _DietScreen({required this.data, required this.onChanged});
  final _Data data;
  final VoidCallback onChanged; // Build my plate saved new choices and rebuilt the plan

  @override
  State<_DietScreen> createState() => _DietScreenState();
}

/// Weeks of meal plans already built, shared by every visit to the Diet tab. Keyed by every input that changes
/// the result (diet_plan.dart weekKey), so a rebuild or a day switch never repeats the search.
final _weekCache = WeekCache();

class _DietScreenState extends State<_DietScreen> {
  Map<String, Food>? _foods;
  int _day = DateTime.now().weekday - 1;
  int _tier = 2;
  String? _region; // cuisine_region: staples preferred in the rotation (diet_plan.dart regionStaples)
  String _budget = 'Medium';
  _Json _choices = const {}; // dietary_profiles: diet_type, budget_tier, cuisine_region, diet_pace
  String? _error;
  String? _buildingKey; // the week being built in the background, so it is started only once
  String? _failedKey; // a week that could not be built; not retried on every rebuild

  /// Builds all seven days for [request] off the UI thread, then rebuilds with the cached result.
  void _buildWeek(String key, WeekRequest request) {
    if (_buildingKey == key || _failedKey == key) return;
    _buildingKey = key;
    planWeekInBackground(request).then((week) {
      // Cached under its own key, so a finished older week can never stand in for the week now requested.
      _weekCache.put(key, week);
      // Only the computation the screen is still waiting for clears the marker and rebuilds; an older one
      // finishing later must not clear the marker of a newer week that is still running.
      if (mounted && _buildingKey == key) setState(() => _buildingKey = null);
    }, onError: (Object _) {
      if (!mounted) return;
      _failedKey = key; // remembered for these inputs only
      if (_buildingKey == key) setState(() => _buildingKey = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(_DietScreen old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _fetch(); // a rebuilt plan may come with new budget or region
  }

  Future<void> _openBuilder() async {
    HapticFeedback.selectionClick();
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _BuildMyPlate(data: widget.data, choices: _choices)));
    if (changed == true) widget.onChanged();
  }

  /// Choices made before B2 live only on this phone: copy them to the account once, then forget the phone's copy.
  /// Kidney disease and pregnancy change the plan (plan engine 3.3), so the plan is rebuilt for them.
  Future<void> _movePlateToAccount(PlateChoices plate) async {
    try {
      await supabase.from('dietary_profiles').update({'health_conditions': plate.conditions, 'whey_scoops': plate.scoops}).eq('user_id', supabase.auth.currentUser!.id);
      await prefs.remove(_conditionsKey);
      await prefs.remove(_scoopsKey);
      if (plate.conditions.any(planConditions.contains)) {
        await supabase.functions.invoke('generate-plan');
        widget.onChanged();
      }
    } catch (_) {
      // Best effort: the phone's copy stays and is used until a later move succeeds.
    }
  }

  Future<void> _fetch() async {
    try {
      final [rows, diet] = await Future.wait<dynamic>([
        supabase.from('foods').select('code, name, tags, kcal, protein_g, carb_g, fat_g, fiber_g').inFilter('code', plannerCodes),
        supabase.from('dietary_profiles').select('diet_type, diet_pace, budget_tier, budget_min_inr, budget_max_inr, cuisine_region, restrictions, supplements, health_conditions, whey_scoops, kitchen, cook_time, kitchen_equipment, kitchen_other, mess_meals').eq('user_id', supabase.auth.currentUser!.id).maybeSingle(),
      ]);
      final tier = diet?['budget_tier'] as String?;
      final hi = diet?['budget_max_inr'] as int?;
      if (!mounted) return;
      final plate = plateChoices((diet as _Json?) ?? const {}, localConditions: prefs.getStringList(_conditionsKey), localScoops: prefs.getInt(_scoopsKey));
      if (plate.fromPhone && diet != null) unawaited(_movePlateToAccount(plate));
      setState(() {
        _foods = plannerFoods((rows as List).cast<Map<String, dynamic>>());
        _tier = budgetTier(tier, hi);
        _region = diet?['cuisine_region'] as String?;
        _choices = {...?diet, 'health_conditions': plate.conditions, 'whey_scoops': plate.scoops};
        _budget = tier == 'custom' && hi != null
            ? rupeesAMonth(monthlyFromDaily(hi))
            : budgetOptions.where((o) => o.$1 == tier).firstOrNull?.$2 ?? budgetOptions[1].$2;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your meal plan. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final food = widget.data.plan['nutrition'] as _Json;
    final kcal = (food['energyKcal'] as num).toDouble();
    final protein = (food['proteinG'] as num).toDouble();
    final foods = _foods;
    if (foods == null) {
      return _Page(eyebrow: 'DIET', title: 'Your meal plan', children: [
        if (_error != null) ErrorLine(_error!) else const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: LevloMark(size: 48, animate: true))),
      ]);
    }
    if (foods.isEmpty) {
      // No food source is licensed for this build yet (food_sources): no meal plan rather than one built from nothing.
      return _Page(eyebrow: 'DIET', title: 'Your meal plan', children: [
        Text('${kcal.round()} kcal and ${protein.round()} g protein a day', style: t.titleMedium),
        const SizedBox(height: 8),
        Text(foodDataPendingText, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
      ]);
    }
    final supps = ((food['supplements'] as List?) ?? const []).cast<_Json>();
    final excluded = {...(food['excludedFoodTags'] as List).cast<String>()};
    // Whey step of Build my plate (scoops kept on this device): the food is planned around the shakes.
    final scoops = _choices['whey_scoops'] as int? ?? 0;
    // Kitchen and mess: meals made at home use only what the equipment and time allow; mess meals are not limited.
    final have = equipmentOf(_choices['kitchen'] as String?, _choices['kitchen_equipment'] as List?, _choices['kitchen_other'] as String?);
    final messMeals = ((_choices['mess_meals'] as List?) ?? const []).cast<String>();
    final cookTime = _choices['cook_time'] as String?;
    final conditions = ((_choices['health_conditions'] as List?) ?? const []).cast<String>();
    final powderAdvised = supps.any((x) => x['name'] == 'Protein powder');
    final WeekRequest request = (
      foods: foods,
      kcal: kcal - scoopKcal * scoops,
      protein: protein - scoopProtein * scoops,
      excluded: excluded,
      custom: ((food['customExclusions'] as List?) ?? const []).cast<String>(),
      tier: _tier,
      soyaCapG: ((food['maxSoyaChunksDryG'] as num?) ?? 50).toDouble(),
      proteinPowder: supps.any((x) => (x['name'] as String).toLowerCase().contains('protein')),
      region: _region,
      mealCodes: mealCodes(foods.keys, have: have, cookTime: cookTime, messMeals: messMeals),
      // Protein powder only when they said they are open to it (the plan's advice lists it), chose no fixed shakes,
      // the budget is above the lowest band, and they did not tell Build my plate about kidney disease or pregnancy.
      topUpScoop: powderAdvised && scoops == 0 && _tier >= 2 && !conditions.contains('kidney') && !conditions.contains('pregnancy'),
    );
    final key = weekKey(request);
    final week = _weekCache.get(key);
    if (week == null) {
      _buildWeek(key, request);
      return _Page(eyebrow: 'DIET', title: 'Your meal plan', children: [
        if (_failedKey == key)
          const ErrorLine('Could not build your meal plan. Reopen the Diet tab to try again.')
        else
          const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: LevloMark(size: 48, animate: true))),
      ]);
    }
    final plan = addShake(week[_day], scoops, kcal: kcal, protein: protein, plant: excluded.contains('dairy'));
    // A training day (the week view's days, 1 = Monday): mark the pre- and post-workout meals; no food is added.
    final training = weekPlan(widget.data.plan).days.containsKey(_day + 1)
        ? workoutDay(plan.meals, (widget.data.plan['schedule'] as _Json?)?['trainingTime'] as String?)
        : null;
    final short = protein - plan.protein;
    Widget macro(String label, double v, double? target, String unit) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: monoLabel(context).copyWith(color: cloud.withValues(alpha: 0.6), fontSize: 10)),
            Text('${v.round()}$unit', style: monoNumber(context, size: 18).copyWith(color: cloud)),
            if (target != null) Text('of ${target.round()}$unit', style: t.bodySmall?.copyWith(color: cloud.withValues(alpha: 0.55), fontSize: 11)),
          ]),
        );
    return _Page(
      eyebrow: 'DIET  ·  YOUR PLATE',
      title: 'Your 7-day plate',
      subtitle: 'Indian meals in household servings, built for your targets, diet, allergies and budget ($_budget).',
      children: [
        _PlateChoices(choices: _choices, onTap: _openBuilder),
        const SizedBox(height: 12),
        if (kitchenNote(have, cookTime, messMeals) case final note?) ...[
          Text(note, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 12),
        ],
        if (conditions.isNotEmpty) ...[
          _Tile(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              'You told Build my plate about ${conditions.map((k) => _conditionNames[k] ?? k).join(', ').toLowerCase()}. '
              'This plan is not adjusted for ${conditions.length == 1 ? 'it' : 'them'}: show it to your doctor or a registered dietitian before you follow it.',
              style: t.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Day picker: each day rotates the foods so the week does not repeat.
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var d = 0; d < 7; d++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(_days[d]),
                  selected: _day == d,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _day = d);
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.outline)),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? c.surface : graphite, borderRadius: BorderRadius.circular(23)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('THIS DAY ADDS UP TO', style: monoLabel(context).copyWith(color: cloud.withValues(alpha: 0.65))),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${plan.kcal.round()}', style: monoNumber(context, size: 40).copyWith(color: cloud)),
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('of ${kcal.round()} kcal', style: t.bodySmall?.copyWith(color: cloud.withValues(alpha: 0.7)))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                macro('PROTEIN', plan.protein, protein, ' g'),
                macro('CARBS', plan.carb, null, ' g'),
                macro('FAT', plan.fat, null, ' g'),
                macro('FIBRE', plan.fiber, null, ' g'),
              ]),
              const SizedBox(height: 10),
              // Share of energy from fat; never shown when a planned food's fat value is missing.
              Text(
                plan.check.fatEnergyShare == null
                    ? 'FAT SHARE OF ENERGY NOT SHOWN'
                    : 'FAT  ·  ${fatShareText(plan.check.fatEnergyShare!).toUpperCase()} OF ENERGY',
                style: monoLabel(context).copyWith(color: cloud.withValues(alpha: 0.65), fontSize: 10),
              ),
            ]),
          ),
        ),
        // Guidance (for example fat above 30% of energy) informs only: it never changes the plan or its pass flag.
        if (plan.check.guidance.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Tile(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final line in plan.check.guidance) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, style: t.bodyMedium)),
            ]),
          ),
        ],
        // The planner reports when it cannot build a day that meets both targets from its food list, templates and
        // portion limits for this person; say so plainly and offer only changes that respect their settings.
        if (!plan.check.feasible) ...[
          const SizedBox(height: 10),
          _Tile(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('THIS DAY MISSES YOUR TARGETS', style: monoLabel(context)),
              const SizedBox(height: 6),
              for (final line in [...plan.check.issues, ...plan.check.options])
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, style: t.bodyMedium)),
            ]),
          ),
        ] else if (short > protein * 0.05) ...[
          const SizedBox(height: 10),
          _Tile(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              'Food in this plan gives ${plan.protein.round()} g of your ${protein.round()} g protein. '
              '${supps.any((x) => (x['name'] as String).toLowerCase().contains('protein')) ? 'The protein powder in your plan can cover the last ${short.round()} g.' : 'A slightly bigger portion of the protein foods above would add about ${short.round()} g, but it may take the day over your calorie target.'}',
              style: t.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (training != null) ...[
          Text(training.note, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 12),
        ],
        for (final (mi, m) in (training?.meals ?? plan.meals).indexed) ...[
          _MealCard(
            meal: m,
            tag: training == null ? null : mi == training.pre ? 'PRE-WORKOUT' : mi == training.post ? 'POST-WORKOUT' : null,
            fromMess: messMeals.contains(_messKeyOf(m.name)),
            messExtra: messProteinHint(excluded, ((food['customExclusions'] as List?) ?? const []).cast<String>()),
            prep: messMeals.contains(_messKeyOf(m.name)) ? null : prepNote(m, have),
          ),
          const SizedBox(height: 10),
        ],
        if (dayOilGrams(plan) > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(dayOilLabel(plan), style: t.bodyMedium)),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text('TARGETS, SUPPLEMENTS AND PROTEIN FOODS', style: monoLabel(context)),
            childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: _fuelDetails(context, widget.data.plan, widget.data.proteins),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => openCoach(context, prompt: 'Help me cook today\'s Levlofit meal plan. Suggest simple Indian recipes using these foods and amounts.'),
          icon: const Icon(LvIcons.sparkle, size: 18),
          label: const Text('Recipes for today with Levlofit AI'),
        ),
        const SizedBox(height: 12),
        FoodCredit(
            trail: 'Cooking oil: ICMR-NIN Dietary Guidelines for Indians 2024 (27 g at 2000 kcal), scaled to your energy by Levlofit. '
                'Swap like for like (one dal for another, one roti flour for another) and the totals stay close.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

/// The plate choices in one line, with the way into Build my plate.
class _PlateChoices extends StatelessWidget {
  const _PlateChoices({required this.choices, required this.onTap});
  final _Json choices;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    String pick(List<(String, String, String)> options, Object? v) => options.where((o) => o.$1 == v).firstOrNull?.$2 ?? '';
    final line = [
      pick(regionOptions, choices['cuisine_region'] ?? 'any'),
      _dietNames[choices['diet_type']] ?? '',
      choices['budget_tier'] == 'custom' && choices['budget_max_inr'] != null
          ? rupeesAMonth(monthlyFromDaily(choices['budget_max_inr'] as int))
          : pick(budgetOptions, choices['budget_tier']),
      '${_paceNames[choices['diet_pace'] ?? 'balanced']} pace',
    ].where((s) => s.isNotEmpty).join('  ·  ');
    return _Tile(
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BUILD MY PLATE', style: monoLabel(context)),
            const SizedBox(height: 4),
            Text(line, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
        Icon(LvIcons.pencilSimple, size: 18, color: c.onSurfaceVariant),
      ]),
    );
  }
}

// Before B2 these lived only on the phone; now they are read once, moved to dietary_profiles and removed.
String get _scoopsKey => 'whey_scoops:${supabase.auth.currentUser?.id}';
String get _conditionsKey => 'plate_conditions:${supabase.auth.currentUser?.id}';

/// Build my plate conditions that change the plan itself (plan engine 3.3); the others only add a doctor note.
const planConditions = {'kidney', 'pregnancy'};

typedef PlateChoices = ({List<String> conditions, int scoops, bool fromPhone});

/// Build my plate's health conditions and shake scoops: the account's (dietary_profiles, B2) when it has any, else the
/// ones this phone kept before B2 (fromPhone: they still need moving to the account). Unknown values are dropped,
/// scoops kept to 0 to 3, as the database allows.
PlateChoices plateChoices(Map<String, dynamic> account, {List<String>? localConditions, int? localScoops}) {
  List<String> known(Iterable<Object?> xs) => [for (final x in xs) if (_conditionNames.containsKey(x)) x as String];
  final conditions = known((account['health_conditions'] as List?) ?? const []);
  final scoops = (account['whey_scoops'] as int?) ?? 0;
  final phone = known(localConditions ?? const []);
  final phoneScoops = (localScoops ?? 0).clamp(0, 3);
  final useAccount = conditions.isNotEmpty || scoops > 0 || (phone.isEmpty && phoneScoops == 0);
  return useAccount
      ? (conditions: conditions, scoops: scoops.clamp(0, 3), fromPhone: false)
      : (conditions: phone, scoops: phoneScoops, fromPhone: true);
}

/// Health step of Build my plate. Lactose and gluten change the food list (dietary_profiles.restrictions); the
/// others are not diets Levlofit can plan without a clinician, so the plan shows a see-your-doctor note instead.
const _foodConditions = [
  ('lactose', 'Milk allergy or lactose intolerance', 'No milk, paneer, curd, ghee or whey; a protein shake becomes plant protein'),
  ('gluten', 'Gluten intolerance', 'Wheat is left out: rice, millets, idli and dosa instead'),
];
const _conditionNames = {
  'diabetes': 'Diabetes',
  'pcos': 'PCOD or PCOS',
  'thyroid': 'A thyroid condition',
  'hypertension': 'High blood pressure',
  'cholesterol': 'High cholesterol',
  'kidney': 'Kidney disease',
  'ibs': 'IBS or gut problems',
  'pregnancy': 'Pregnancy',
};

const _dietNames = {'vegetarian': 'Vegetarian', 'eggitarian': 'Eggitarian', 'non_vegetarian': 'Non-vegetarian', 'vegan': 'Vegan'};
const _paceNames = {'easy': 'Easy', 'balanced': 'Balanced', 'hard': 'Hard'};
const _paceOptions = [
  ('easy', 'Easy', 'A small daily gap or surplus. Slowest, and the easiest to keep up.'),
  ('balanced', 'Balanced', 'The usual pace for most people.'),
  ('hard', 'Hard', 'A bigger gap or surplus. Faster, harder to sustain; for short phases.'),
];

/// Build my plate: five short steps (your numbers, region, diet, budget, pace), then the plan is rebuilt. Pops true
/// when the choices were saved.
class _BuildMyPlate extends StatefulWidget {
  const _BuildMyPlate({required this.data, required this.choices});
  final _Data data;
  final _Json choices;

  @override
  State<_BuildMyPlate> createState() => _BuildMyPlateState();
}

class _BuildMyPlateState extends State<_BuildMyPlate> {
  late final _Json _d = {
    'cuisine_region': widget.choices['cuisine_region'] ?? 'any',
    'diet_type': widget.choices['diet_type'],
    'budget_tier': widget.choices['budget_tier'],
    'diet_pace': widget.choices['diet_pace'] ?? 'balanced',
  };
  late final Set<String> _restrictions = {...((widget.choices['restrictions'] as List?) ?? const []).cast<String>()};
  late final Set<String> _conditions = {...((widget.choices['health_conditions'] as List?) ?? const []).cast<String>()};
  late int _scoops = widget.choices['whey_scoops'] as int? ?? 0;
  late final _monthly = TextEditingController(
      text: widget.choices['budget_max_inr'] == null ? '' : '${monthlyFromDaily(widget.choices['budget_max_inr'] as int)}');
  int _step = 0;
  bool _saving = false;
  String? _error;

  int? get _ownMonthly => int.tryParse(_monthly.text.trim());

  @override
  void dispose() {
    _monthly.dispose();
    super.dispose();
  }

  static const _titles = ['Your numbers', 'Your regional food', 'How you eat', 'Your food budget', 'Health conditions', 'Protein powder', 'Your pace'];

  bool get _ready => switch (_step) {
        2 => _d['diet_type'] != null,
        3 => _d['budget_tier'] != null && (_d['budget_tier'] != 'custom' || (_ownMonthly ?? 0) >= 900),
        _ => true,
      };

  Future<void> _build() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      final supps = {...((widget.choices['supplements'] as List?) ?? const []).cast<String>()};
      _scoops > 0 ? supps.add('protein_powder') : supps.remove('protein_powder');
      await supabase.from('dietary_profiles').update({
        ..._d,
        'budget_min_inr': null,
        'budget_max_inr': _d['budget_tier'] == 'custom' ? dailyFromMonthly(_ownMonthly!) : null,
        'restrictions': _restrictions.toList(),
        'supplements': supps.toList(),
        'health_conditions': _conditions.toList(),
        'whey_scoops': _scoops,
      }).eq('user_id', supabase.auth.currentUser!.id);
      await prefs.remove(_scoopsKey); // the account holds them now (B2)
      await prefs.remove(_conditionsKey);
      saved = true;
      await supabase.functions.invoke('generate-plan');
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = saved
            ? 'Your choices are saved, but your plan could not be rebuilt. Try again.'
            : 'Could not save. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Widget> _tiles(String key, List<(String, String, String)> options) => [
        for (final (k, title, sub) in options) ...[
          ChoiceTile(title: title, subtitle: sub, selected: _d[key] == k, onTap: () => setState(() => _d[key] = k)),
          const SizedBox(height: 10),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final p = widget.data.profile;
    final food = widget.data.plan['nutrition'] as _Json;
    final age = p['birth_year'] == null ? null : DateTime.now().year - (p['birth_year'] as int);
    final last = _step == _titles.length - 1;
    final body = switch (_step) {
      0 => [
          Text('Your daily targets come from your profile: Mifflin-St Jeor energy for your age, sex, height and weight, '
              'your activity, and your goal.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 14),
          for (final (k, v) in [
            ('Sex', p['sex'] == 'female' ? 'Female' : 'Male'),
            if (age != null) ('Age', '$age years'),
            ('Height', '${p['height_cm'] ?? '-'} cm'),
            ('Weight', '${p['weight_kg'] ?? '-'} kg'),
            if (food['energy'] case {'maintenanceKcal': final num m}) ('Maintenance (TDEE)', '${m.round()} kcal'),
            ('Target a day', '${(food['energyKcal'] as num).round()} kcal'),
            ('Protein a day', '${(food['proteinG'] as num).round()} g'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [Expanded(child: Text(k, style: t.bodyLarge)), Text(v, style: monoNumber(context, size: 16))]),
            ),
          const SizedBox(height: 10),
          Text('Change these in Protocol or your profile.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
      1 => _tiles('cuisine_region', regionOptions),
      2 => _tiles('diet_type', [for (final MapEntry(:key, :value) in _dietNames.entries) (key, value, switch (key) {
            'vegetarian' => 'Dairy, no egg, meat or fish',
            'eggitarian' => 'Vegetarian plus eggs',
            'vegan' => 'No animal products',
            _ => 'Chicken, fish and eggs',
          })]),
      3 => [
          ..._tiles('budget_tier', [...budgetOptions, ('custom', 'My own amount', 'Enter what you spend on food in a month')]),
          if (_d['budget_tier'] == 'custom')
            TextField(
              controller: _monthly,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Food budget for a month', prefixText: 'Rs ', suffixText: 'a month', helperText: 'At least Rs 900'),
            ),
        ],
      4 => [
          Text('Optional. Pick any that apply.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final (k, title, sub) in _foodConditions) ...[
            ChoiceTile(
              title: title,
              subtitle: sub,
              selected: _restrictions.contains(k),
              onTap: () => setState(() => _restrictions.contains(k) ? _restrictions.remove(k) : _restrictions.add(k)),
            ),
            const SizedBox(height: 10),
          ],
          for (final MapEntry(key: k, value: title) in _conditionNames.entries) ...[
            ChoiceTile(
              title: title,
              subtitle: 'Your plan will ask you to check it with your doctor',
              selected: _conditions.contains(k),
              onTap: () => setState(() => _conditions.contains(k) ? _conditions.remove(k) : _conditions.add(k)),
            ),
            const SizedBox(height: 10),
          ],
        ],
      5 => [
          Text('A shake is added to your evening snack and your meals are planned around it. Counted as a typical '
              '30 g scoop: 120 kcal and 24 g protein; check your tub\'s label.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final (n, title, sub) in const [
            (0, 'No protein powder', 'Protein from food only'),
            (1, '1 scoop a day', 'About 24 g protein, 120 kcal'),
            (2, '2 scoops a day', 'About 48 g protein, 240 kcal'),
            (3, '3 scoops a day', 'About 72 g protein, 360 kcal'),
          ]) ...[
            ChoiceTile(title: title, subtitle: sub, selected: _scoops == n, onTap: () => setState(() => _scoops = n)),
            const SizedBox(height: 10),
          ],
        ],
      _ => _tiles('diet_pace', _paceOptions),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Build my plate')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
          Text('STEP ${_step + 1} OF ${_titles.length}', style: monoLabel(context).copyWith(color: c.tertiary)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: (_step + 1) / _titles.length, minHeight: 3),
          const SizedBox(height: 18),
          Text(_titles[_step], style: t.headlineSmall),
          const SizedBox(height: 14),
          ...body,
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: ErrorLine(_error!)),
          const SizedBox(height: 18),
          Row(children: [
            if (_step > 0) ...[
              OutlinedButton(onPressed: _saving ? null : () => setState(() => _step--), child: const Text('Back')),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                onPressed: !_ready || _saving ? null : (last ? _build : () => setState(() => _step++)),
                child: Text(_saving ? 'Building your plate...' : (last ? 'Build my 7-day plate' : 'Next')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// The mess_meals key of a planner meal name.
String? _messKeyOf(String meal) => switch (meal) { 'Breakfast' => 'breakfast', 'Lunch' => 'lunch', 'Evening snack' => 'snack', 'Dinner' => 'dinner', _ => null };

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, this.tag, this.fromMess = false, this.prep, this.messExtra = 'dal'});
  final String messExtra; // mess foods to ask for when protein is short, already filtered by diet and allergies
  final String? tag; // PRE-WORKOUT or POST-WORKOUT on a training day
  final bool fromMess; // eaten from the hostel or PG mess: pick the closest items there
  final String? prep; // how to make it with a kettle, microwave or blender
  final PlanMeal meal;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final kcal = meal.items.fold(0.0, (s, i) => s + i.kcal), protein = meal.items.fold(0.0, (s, i) => s + i.protein);
    return _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([meal.time.toUpperCase(), ?tag, if (fromMess) 'FROM THE MESS'].join('  ·  '), style: monoLabel(context).copyWith(color: c.tertiary)),
              Text(meal.name, style: t.titleLarge),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${kcal.round()} kcal', style: monoNumber(context, size: 16)),
            Text('${protein.round()} g protein', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
        ]),
        const SizedBox(height: 8),
        // The plate named as dishes; each part below in household servings, exact grams and nutrients behind Details.
        Text(mealTitle(meal), style: t.titleMedium),
        if (fromMess)
          Text('From your mess: take the closest items to these amounts. Short on protein? Add an extra serving of $messExtra if served.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        if (prep != null) Text(prep!, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        if (tag != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tag == 'PRE-WORKOUT'
                  ? 'Eat this before you train. It is part of your day\'s food, not extra.'
                  : 'Eat this after you train: it brings your protein. It is part of your day\'s food, not extra.',
              style: t.bodyMedium?.copyWith(color: c.primary, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        for (final i in meal.items.where((i) => i.unit != 'oil')) // oil is shown once for the whole day
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outline))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(itemRole(i), style: monoLabel(context).copyWith(fontSize: 10, color: c.tertiary)),
                  Text(servingLabel(i), style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 10),
              Text(exactLabel(i), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ]),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text('Details', style: t.labelLarge),
            children: [
              for (final i in meal.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(i.name, style: t.bodySmall)),
                    Text('${i.kcal.round()} kcal  ·  P ${i.protein.toStringAsFixed(1)}  ·  C ${i.carb.toStringAsFixed(1)}  ·  F ${i.fat.toStringAsFixed(1)} g',
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant, fontSize: 12)),
                  ]),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- calendar

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// What happened on one day, from every source the calendar shows.
class _DayRecord {
  bool trained = false;
  _Json? body; // body_metrics row
  int photos = 0;
}

enum _Mark { training, body, photo }

class _CalendarScreen extends StatefulWidget {
  const _CalendarScreen({required this.plan});
  final _Json plan;

  @override
  State<_CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<_CalendarScreen> {
  DateTime _anchor = _day(DateTime.now()); // any day inside the shown month or week
  bool _week = false;
  final _shown = {..._Mark.values}; // the legend is the filter
  Map<DateTime, _DayRecord> _records = {};
  bool _loading = true;
  int _dir = 1;
  late final _dayGoal = _schedule(widget.plan);

  String get _uid => supabase.auth.currentUser!.id;

  (DateTime, DateTime) get _range {
    if (_week) {
      final m = _monday(_anchor);
      return (m, m.add(const Duration(days: 7)));
    }
    return (DateTime(_anchor.year, _anchor.month), DateTime(_anchor.year, _anchor.month + 1));
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  int _fetchSeq = 0; // only the latest month's answer is shown, however the replies arrive

  Future<void> _fetch() async {
    final n = ++_fetchSeq;
    setState(() => _loading = true);
    final (from, to) = _range;
    try {
      final [logs, body, photos] = await Future.wait([
        supabase.from('workout_logs').select('performed_on').eq('user_id', _uid).gte('performed_on', _iso(from)).lt('performed_on', _iso(to)),
        supabase.from('body_metrics').select().eq('user_id', _uid).gte('measured_on', _iso(from)).lt('measured_on', _iso(to)),
        supabase.from('progress_photos').select('taken_on').eq('user_id', _uid).gte('taken_on', _iso(from)).lt('taken_on', _iso(to)),
      ]);
      final records = <DateTime, _DayRecord>{};
      _DayRecord at(String iso) => records.putIfAbsent(DateTime.parse(iso), _DayRecord.new);
      for (final r in logs) {
        at(r['performed_on'] as String).trained = true;
      }
      for (final r in body) {
        at(r['measured_on'] as String).body = r;
      }
      for (final r in photos) {
        at(r['taken_on'] as String).photos++;
      }
      if (n != _fetchSeq) return; // a newer month was asked for meanwhile
      _records = records;
    } catch (_) {
      if (n != _fetchSeq) return;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load the calendar. Check your connection.')));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _shift(int n) {
    HapticFeedback.selectionClick();
    setState(() {
      _dir = n;
      _anchor = _week ? _anchor.add(Duration(days: 7 * n)) : DateTime(_anchor.year, _anchor.month + n);
    });
    _fetch();
  }

  void _today() {
    final today = _day(DateTime.now());
    setState(() {
      _dir = _anchor.isBefore(today) ? 1 : -1;
      _anchor = today;
    });
    _fetch();
  }

  /// Logs or removes training on a past day (or today). The future cannot be logged.
  Future<void> _toggle(DateTime day) async {
    final done = _records[day]?.trained ?? false;
    HapticFeedback.mediumImpact();
    try {
      if (done) {
        await supabase.from('workout_logs').delete().eq('user_id', _uid).eq('performed_on', _iso(day));
      } else {
        final goal = _dayGoal[day.weekday] ?? (widget.plan['goals'] as List).first as _Json;
        // A day already logged from the dashboard is not logged twice.
        final existing = await supabase.from('workout_logs').select('id').eq('user_id', _uid).eq('performed_on', _iso(day)).limit(1);
        if (existing.isEmpty) await supabase.from('workout_logs').insert({'user_id': _uid, 'performed_on': _iso(day), 'goal': goal['goal']});
      }
      setState(() => _records.putIfAbsent(day, _DayRecord.new).trained = !done);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection and try again.')));
    }
  }

  Set<_Mark> _marks(DateTime d) {
    final r = _records[d];
    if (r == null) return const {};
    return {if (r.trained) _Mark.training, if (r.body != null) _Mark.body, if (r.photos > 0) _Mark.photo}.intersection(_shown);
  }

  Color _markColor(ColorScheme c, _Mark m) => switch (m) {
        _Mark.training => c.primary,
        _Mark.body => c.onSurface,
        _Mark.photo => const Color(0xFFFFB27A),
      };

  void _openDay(DateTime day) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final future = day.isAfter(_day(DateTime.now()));
    final planned = _dayGoal[day.weekday];
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final r = _records[day];
          final body = r?.body;
          final measures = [
            if (body?['weight_kg'] != null) ('Weight', '${body!['weight_kg']} kg'),
            if (body?['body_fat_pct'] != null) ('Body fat', '${body!['body_fat_pct']} %'),
            for (final (k, label) in _measureFields)
              if (body?[k] != null) (label, '${body![k]} cm'),
          ];
          final trained = r?.trained ?? false;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_days[day.weekday - 1], style: monoLabel(context)),
                const SizedBox(height: 4),
                Text('${day.day} ${_monthNames[day.month - 1]} ${day.year}', style: t.titleLarge),
                const SizedBox(height: 16),
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: trained ? c.primary : c.outline, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      trained ? 'Training logged' : (planned != null ? 'Planned: ${planned['name'] ?? planned['goal']}' : 'Rest day'),
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!future)
                    TextButton(
                      onPressed: () async {
                        await _toggle(day);
                        setSheet(() {});
                      },
                      child: Text(trained ? 'Remove' : 'Log it'),
                    ),
                ]),
                if (measures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('BODY', style: monoLabel(context)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 18, runSpacing: 6, children: [
                    for (final (label, v) in measures)
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        Text(v, style: monoNumber(context, size: 16)),
                      ]),
                  ]),
                ],
                if ((r?.photos ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  Text('${r!.photos} progress photo${r.photos == 1 ? '' : 's'}. See them on Progress.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final today = _day(DateTime.now());
    final (from, to) = _range;
    final last = to.subtract(const Duration(days: 1));
    final training = _records.values.where((r) => r.trained).length;
    final label = _week ? '${from.day} ${_months[from.month - 1]} to ${last.day} ${_months[last.month - 1]}' : '${_monthNames[_anchor.month - 1]} ${_anchor.year}';
    return _Page(
      eyebrow: 'CALENDAR',
      title: 'Where you are',
      subtitle: 'Every day you trained, weighed in, measured or took a photo. Tap a day for details.',
      children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Month')), ButtonSegment(value: true, label: Text('Week'))],
          selected: {_week},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            setState(() => _week = s.first);
            _fetch();
          },
        ),
        const SizedBox(height: 14),
        _Tile(
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: t.titleMedium),
                  Text(_loading ? ' ' : '$training SESSION${training == 1 ? '' : 'S'}', style: monoLabel(context).copyWith(fontSize: 10, color: c.tertiary)),
                ]),
              ),
              IconButton(tooltip: 'Previous', onPressed: () => _shift(-1), icon: const Icon(LvIcons.caretLeft, size: 20)),
              TextButton(onPressed: _today, child: const Text('Today')),
              IconButton(tooltip: 'Next', onPressed: () => _shift(1), icon: const Icon(LvIcons.caretRight, size: 20)),
            ]),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: motion(context, 360),
              switchInCurve: spring,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: Offset(0.08 * _dir, 0), end: Offset.zero).animate(a), child: child),
              ),
              child: KeyedSubtree(key: ValueKey('$_week $from'), child: _week ? _weekList(context, from, today) : _monthGrid(context, from, today)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // The legend is the filter: tap to show or hide a source.
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (m, text) in [(_Mark.training, 'Training'), (_Mark.body, 'Weight and tape'), (_Mark.photo, 'Photos')])
            FilterChip(
              selected: _shown.contains(m),
              showCheckmark: false,
              avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: _markColor(c, m), shape: BoxShape.circle)),
              label: Text(text),
              onSelected: (on) => setState(() => on ? _shown.add(m) : _shown.remove(m)),
            ),
        ]),
        const SizedBox(height: 10),
        Text('Ringed days are planned sessions. Train on any day; every logged day counts.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }

  Widget _dots(ColorScheme c, Set<_Mark> marks, {double size = 5}) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (final m in marks)
          Container(width: size, height: size, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(color: _markColor(c, m), shape: BoxShape.circle)),
      ]);

  Widget _monthGrid(BuildContext context, DateTime first, DateTime today) {
    final c = Theme.of(context).colorScheme;
    final lead = first.weekday - 1;
    final days = DateTime(first.year, first.month + 1, 0).day;
    return Column(children: [
      Row(children: [for (final d in _days) Expanded(child: Text(d.substring(0, 1), textAlign: TextAlign.center, style: monoLabel(context)))]),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.82,
        children: [
          for (var i = 0; i < lead; i++) const SizedBox(),
          for (var n = 1; n <= days; n++)
            Builder(builder: (context) {
              final day = DateTime(first.year, first.month, n);
              final marks = _marks(day);
              final trained = marks.contains(_Mark.training);
              final planned = _dayGoal.containsKey(day.weekday) && !day.isBefore(today) && !trained;
              final isToday = day == today;
              return Semantics(
                button: true,
                label: '$n ${_monthNames[first.month - 1]}${trained ? ', trained' : planned ? ', planned' : ''}',
                child: InkResponse(
                  onTap: () => _openDay(day),
                  radius: 24,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: motion(context, 260),
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: trained ? c.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: trained ? c.primary : (isToday ? c.onSurface : planned ? c.outline : Colors.transparent), width: isToday ? 1.5 : 1),
                      ),
                      child: Text('$n', style: monoNumber(context, size: 13).copyWith(color: trained ? c.onPrimary : (day.isAfter(today) ? c.onSurfaceVariant : c.onSurface))),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 5, child: _dots(c, marks.difference({_Mark.training}))),
                  ]),
                ),
              );
            }),
        ],
      ),
    ]);
  }

  Widget _weekList(BuildContext context, DateTime monday, DateTime today) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(children: [
      for (var i = 0; i < 7; i++)
        Builder(builder: (context) {
          final day = monday.add(Duration(days: i));
          final trained = _records[day]?.trained ?? false;
          final planned = _dayGoal[day.weekday];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openDay(day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(children: [
                SizedBox(
                  width: 48,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_days[i], style: monoLabel(context).copyWith(color: day == today ? c.tertiary : null)),
                    Text('${day.day}', style: monoNumber(context, size: 20)),
                  ]),
                ),
                Expanded(
                  child: Text(
                    trained ? 'Trained' : (planned != null ? '${planned['name'] ?? planned['goal']}' : 'Rest'),
                    style: t.bodyLarge?.copyWith(color: !trained && planned == null ? c.onSurfaceVariant : null, fontWeight: trained ? FontWeight.w600 : null),
                  ),
                ),
                _dots(c, _marks(day), size: 8),
              ]),
            ),
          );
        }),
    ]);
  }
}

// ---------------------------------------------------------------- progress

const _measureFields = [('waist_cm', 'Waist'), ('chest_cm', 'Chest'), ('hips_cm', 'Hips'), ('arm_cm', 'Arm'), ('thigh_cm', 'Thigh'), ('neck_cm', 'Neck')];

typedef _Photo = ({String id, String path, DateTime day, String? url});

/// Least-squares weight trend as % of body weight per week, or null without enough data
/// (at least 3 weigh-ins spread over 14 days or more).
@visibleForTesting
double? weeklyTrendPct(List<({DateTime day, double kg})> points) {
  if (points.length < 3 || points.last.day.difference(points.first.day).inDays < 14) return null;
  final x = [for (final p in points) p.day.difference(points.first.day).inDays.toDouble()];
  final y = [for (final p in points) p.kg];
  final mx = x.reduce((a, b) => a + b) / x.length, my = y.reduce((a, b) => a + b) / y.length;
  var num = 0.0, den = 0.0;
  for (var i = 0; i < x.length; i++) {
    num += (x[i] - mx) * (y[i] - my);
    den += (x[i] - mx) * (x[i] - mx);
  }
  return den == 0 ? null : num / den * 7 / my * 100;
}

/// The verdict: is the scale moving the way the plan intends?
/// Cut 0.5 to 1 % a week (ISSN, Aragon 2017); lean gain 0.25 to 0.5 % a week (Iraki 2019); otherwise steady.
@visibleForTesting
({String title, String detail}) verdict(String? weightGoal, double? pct) {
  if (pct == null) return (title: 'Not enough data yet', detail: 'Weigh in at least 3 times over 2 weeks and the trend appears here.');
  final rate = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)} % of body weight a week';
  return switch (weightGoal) {
    'cut' || 'lose' => pct > -0.5
        ? (title: 'Slower than planned', detail: '$rate. A cut aims for 0.5 to 1 %. Check portions and daily steps before eating less.')
        : pct < -1.0
            ? (title: 'Faster than planned', detail: '$rate. Faster than 1 % risks muscle. Consider eating a little more.')
            : (title: 'On track', detail: '$rate, inside the 0.5 to 1 % range for a cut.'),
    'bulk' || 'gain' => pct < 0.25
        ? (title: 'Slower than planned', detail: '$rate. A lean gain aims for 0.25 to 0.5 %.')
        : pct > 0.5
            ? (title: 'Faster than planned', detail: '$rate. Above 0.5 % adds mostly fat for most people.')
            : (title: 'On track', detail: '$rate, inside the 0.25 to 0.5 % range for a lean gain.'),
    _ => pct.abs() <= 0.25
        ? (title: 'Holding steady', detail: '$rate. Steady weight is the aim; watch strength and the tape.')
        : (title: pct > 0 ? 'Drifting up' : 'Drifting down', detail: '$rate. More than expected while holding weight.'),
  };
}

/// Plan weight change from real weigh-ins (batch B3): the average of the readings in the 7 days up to the newest one,
/// to 0.1 kg, when it is 2 % or more away from the weight the plan uses; null otherwise. One reading alone moves with
/// water and food, so a week's average is used. Only weights the plan engine accepts (30 to 250 kg) are proposed.
double? proposedPlanWeight(num? planKg, List<({DateTime day, double kg})> weighIns) {
  if (planKg == null || planKg <= 0 || weighIns.isEmpty) return null;
  final newest = weighIns.map((w) => w.day).reduce((a, b) => a.isAfter(b) ? a : b);
  final week = [for (final w in weighIns) if (!w.day.isAfter(newest) && newest.difference(w.day).inDays < 7) w.kg];
  final avg = (week.reduce((a, b) => a + b) / week.length * 10).round() / 10;
  if (avg < 30 || avg > 250) return null;
  return (avg - planKg).abs() / planKg >= 0.02 ? avg : null;
}

/// Asks before the plan changes: true only when the person taps Update plan.
Future<bool> confirmPlanWeight(BuildContext context, {required num fromKg, required double toKg}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Update your plan to $toKg kg?'),
        content: Text('Your weigh-ins this week average $toKg kg; your plan still uses $fromKg kg. Calories, protein and '
            'your meal plan are worked out from your weight, so updating recalculates them. Nothing else changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Update plan')),
        ],
      ),
    ) ??
    false;

class _ProgressScreen extends StatefulWidget {
  const _ProgressScreen({required this.data, required this.onPlanChanged});
  final _Data data;
  final VoidCallback onPlanChanged; // the person confirmed a new plan weight and the plan was rebuilt

  @override
  State<_ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<_ProgressScreen> {
  List<_Json>? _logs;
  List<_Json> _body = [];
  List<_Photo> _photos = [];
  String? _error;
  bool _uploading = false;

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final [logs, body, photos] = await Future.wait([
        supabase.from('workout_logs').select('performed_on, duration_min').eq('user_id', _uid).order('performed_on', ascending: true).limit(2000),
        supabase.from('body_metrics').select().eq('user_id', _uid).order('measured_on', ascending: true).limit(730),
        supabase.from('progress_photos').select('id, path, taken_on').eq('user_id', _uid).order('taken_on', ascending: false).limit(60),
      ]);
      // Private bucket: each photo gets a short-lived signed link.
      final urls = <String, String>{
        if (photos.isNotEmpty)
          for (final r in await supabase.storage.from('progress-photos').createSignedUrlsResult([for (final p in photos) p['path'] as String], 3600))
            if (r case SignedUrlSuccess(:final path, :final signedUrl)) path: signedUrl,
      };
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _body = body;
        _photos = [
          for (final p in photos) (id: p['id'] as String, path: p['path'] as String, day: DateTime.parse(p['taken_on'] as String), url: urls[p['path']]),
        ];
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your progress. Check your connection.');
    }
  }

  /// Saves only the given columns for that day; other measurements on the same day stay.
  Future<void> _saveBody(DateTime day, Map<String, num> values) async {
    try {
      await supabase.from('body_metrics').upsert({'user_id': _uid, 'measured_on': _iso(day), ...values}, onConflict: 'user_id,measured_on');
      HapticFeedback.mediumImpact();
      await _fetch();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check the numbers and your connection.')));
      return;
    }
    if (values.containsKey('weight_kg')) await _offerPlanWeight();
  }

  /// After a weigh-in: propose the week's average as the plan weight; the plan changes only when the person confirms.
  Future<void> _offerPlanWeight() async {
    final planKg = widget.data.profile['weight_kg'] as num?;
    final to = proposedPlanWeight(planKg, [
      for (final b in _body)
        if (b['weight_kg'] != null) (day: DateTime.parse(b['measured_on'] as String), kg: (b['weight_kg'] as num).toDouble()),
    ]);
    if (to == null || !mounted || !await confirmPlanWeight(context, fromKg: planKg!, toKg: to)) return;
    var saved = false;
    try {
      await supabase.from('profiles').update({'weight_kg': to}).eq('id', _uid);
      saved = true;
      await supabase.functions.invoke('generate-plan');
      widget.onPlanChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan updated for $to kg.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved
              ? 'Your weight is saved, but the plan could not be rebuilt. Save your details in Profile to retry.'
              : 'Could not update your plan. Check your connection.'),
        ));
      }
    }
  }

  Future<void> _logBody({required bool tape}) async {
    final fields = tape ? _measureFields : const [('weight_kg', 'Weight, kg'), ('body_fat_pct', 'Body fat %, only from a real measurement')];
    final lastWeight = _body.lastWhere((b) => b['weight_kg'] != null, orElse: () => const {})['weight_kg'];
    // Every field starts empty: a pre-filled last weight would be saved as a new reading when only body fat is logged.
    final controllers = {for (final (k, _) in fields) k: TextEditingController()};
    var day = _day(DateTime.now());
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final t = Theme.of(sheet).textTheme;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tape ? 'MEASUREMENTS' : 'WEIGH-IN', style: monoLabel(sheet)),
                  const SizedBox(height: 6),
                  Text(tape ? 'Log measurements' : 'Log your weight', style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    tape
                        ? 'Centimetres. Same tape, same spot, same time of day, every 2 to 4 weeks. Fill only what you measured.'
                        : 'Same time of day, before food. One reading means little; the trend over weeks matters.',
                    style: t.bodySmall?.copyWith(color: Theme.of(sheet).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(context: sheet, initialDate: day, firstDate: DateTime(2020), lastDate: _day(DateTime.now()));
                      if (picked != null) setSheet(() => day = picked);
                    },
                    icon: const Icon(LvIcons.calendarBlank, size: 18),
                    label: Text(day == _day(DateTime.now()) ? 'Today' : '${day.day} ${_months[day.month - 1]} ${day.year}'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final (k, label) in fields)
                      SizedBox(
                        width: tape ? 150 : double.infinity,
                        child: TextField(
                          controller: controllers[k],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d?)?$'))],
                          style: monoNumber(sheet, size: 18),
                          decoration: InputDecoration(labelText: label, hintText: k == 'weight_kg' && lastWeight != null ? 'Last: $lastWeight' : null),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Save'))),
                ]),
              ),
            ),
          );
        },
      ),
    );
    final values = <String, num>{
      for (final e in controllers.entries) e.key: ?double.tryParse(e.value.text),
    };
    // Not disposed here: the sheet is still animating out (and rebuilding as the keyboard closes) when this runs, and
    // a disposed controller in it throws (found on the phone, 2026-10-28). They hold no resources and are collected
    // with the sheet.
    if (saved == true && values.isNotEmpty) await _saveBody(day, values);
  }

  Future<void> _addPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final png = file.name.toLowerCase().endsWith('.png');
      final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
      await supabase.storage.from('progress-photos').uploadBinary(path, await file.readAsBytes(), fileOptions: FileOptions(contentType: png ? 'image/png' : 'image/jpeg'));
      await supabase.from('progress_photos').insert({'path': path, 'taken_on': _iso(DateTime.now())});
      HapticFeedback.mediumImpact();
      await _fetch();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload the photo. Use a JPG or PNG under 8 MB.')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(_Photo p) async {
    try {
      await supabase.storage.from('progress-photos').remove([p.path]);
      await supabase.from('progress_photos').delete().eq('id', p.id);
      await _fetch();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete the photo.')));
    }
  }

  void _viewPhoto(_Photo p) => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (route) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text('${p.day.day} ${_months[p.day.month - 1]} ${p.day.year}'),
              actions: [
                IconButton(
                  tooltip: 'Delete photo',
                  icon: const Icon(LvIcons.trash),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: route,
                      builder: (d) => AlertDialog(
                        title: const Text('Delete this photo?'),
                        content: const Text('It is removed from your account for good.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok != true || !route.mounted) return;
                    Navigator.pop(route);
                    _deletePhoto(p);
                  },
                ),
              ],
            ),
            body: Center(child: InteractiveViewer(child: p.url == null ? const SizedBox() : Image.network(p.url!, webHtmlElementStrategy: WebHtmlElementStrategy.prefer))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final logs = _logs;
    if (logs == null) {
      return _Page(eyebrow: 'PROGRESS', title: 'Is this working?', children: [
        if (_error != null) ErrorLine(_error!) else const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: LevloMark(size: 48, animate: true))),
      ]);
    }
    return _Page(
      eyebrow: 'PROGRESS',
      title: 'Is this working?',
      children: [
        const StepsCard(),
        ..._progressBody(
        context,
        plan: widget.data.plan,
        logs: logs,
        body: _body,
        photos: _photos,
        uploading: _uploading,
        onLogWeight: () => _logBody(tape: false),
        onLogTape: () => _logBody(tape: true),
        onAddPhoto: _addPhoto,
        onViewPhoto: _viewPhoto,
      ),
      ],
    );
  }
}

/// Renders the progress body from rows, without Supabase, so layout can be tested.
@visibleForTesting
Widget progressBodyForTest(Map<String, dynamic> plan, List<Map<String, dynamic>> logs, List<Map<String, dynamic>> body) => Builder(
      builder: (context) => _Page(
        eyebrow: 'PROGRESS',
        title: 'Is this working?',
        children: _progressBody(context, plan: plan, logs: logs, body: body, photos: const [], uploading: false, onLogWeight: () {}, onLogTape: () {}, onAddPhoto: () {}, onViewPhoto: (_) {}),
      ),
    );

List<Widget> _progressBody(
  BuildContext context, {
  required _Json plan,
  required List<_Json> logs,
  required List<_Json> body,
  required List<_Photo> photos,
  required bool uploading,
  required VoidCallback onLogWeight,
  required VoidCallback onLogTape,
  required VoidCallback onAddPhoto,
  required void Function(_Photo) onViewPhoto,
}) {
  final c = Theme.of(context).colorScheme;
  final t = Theme.of(context).textTheme;
  final now = DateTime.now();
  final monday = _monday(now);
  final perWeek = (plan['trainingDaysPerWeek'] as int).clamp(1, 7);
  final days = {for (final l in logs) DateTime.parse(l['performed_on'] as String)};
  final minutes = logs.fold<int>(0, (s, l) => s + ((l['duration_min'] as int?) ?? 0));
  // Sessions in each of the last 12 weeks, oldest first.
  final weeks = [
    for (var w = 11; w >= 0; w--) days.where((d) => !d.isBefore(monday.subtract(Duration(days: 7 * w))) && d.isBefore(monday.subtract(Duration(days: 7 * (w - 1))))).length,
  ];
  // Adherence over the last 4 full weeks.
  final adherence = (100 * weeks.sublist(7, 11).fold(0, (s, n) => s + n) / (perWeek * 4)).clamp(0, 100).round();

  final weights = [
    for (final b in body)
      if (b['weight_kg'] != null) (day: DateTime.parse(b['measured_on'] as String), kg: (b['weight_kg'] as num).toDouble()),
  ];
  final v = verdict(plan['weightGoal'] as String?, weeklyTrendPct([for (final w in weights) if (now.difference(w.day).inDays <= 42) w]));
  final change = weights.length > 1 ? weights.last.kg - weights.first.kg : null;
  final fat = body.lastWhere((b) => b['body_fat_pct'] != null, orElse: () => const {})['body_fat_pct'];
  final tape = [
    for (final (k, label) in _measureFields)
      if (body.where((b) => b[k] != null).toList() case final rows when rows.isNotEmpty)
        (label: label, now: (rows.last[k] as num).toDouble(), from: (rows.first[k] as num).toDouble()),
  ];
  Widget photo(_Photo p, {double radius = 10}) => GestureDetector(
        onTap: () => onViewPhoto(p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: p.url == null ? ColoredBox(color: c.surfaceContainerHighest) : Image.network(p.url!, fit: BoxFit.cover, webHtmlElementStrategy: WebHtmlElementStrategy.prefer),
        ),
      );

  return [
    // The verdict leads, as the answer to the page's question.
    Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.outline)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: c.secondary, borderRadius: BorderRadius.circular(23)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WEIGHT TREND  ·  LAST 6 WEEKS', style: monoLabel(context).copyWith(color: c.onSecondary.withValues(alpha: 0.65))),
          const SizedBox(height: 8),
          Text(v.title, style: t.headlineMedium?.copyWith(color: c.onSecondary)),
          const SizedBox(height: 6),
          Text(v.detail, style: t.bodyMedium?.copyWith(color: c.onSecondary.withValues(alpha: 0.75))),
        ]),
      ),
    ),
    const SizedBox(height: 12),
    IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _Stat(value: '$adherence', label: 'ADHERENCE %', accent: true)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: '${days.length}', label: 'SESSIONS')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: '${_Bento._weekStreak(days, monday, perWeek)}', label: 'WEEK STREAK')),
      ]),
    ),
    const SizedBox(height: 12),
    _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('BODY WEIGHT', trailing: TextButton.icon(onPressed: onLogWeight, icon: const Icon(LvIcons.plus, size: 16), label: const Text('Log'))),
        if (weights.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Weigh in once a week, same time of day, and the trend appears here.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          )
        else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            CountUp(weights.last.kg.toStringAsFixed(1), style: monoNumber(context, size: 34)),
            const SizedBox(width: 6),
            Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('kg', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))),
            const SizedBox(width: 12),
            if (change != null) Expanded(child: Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} KG SINCE START', textAlign: TextAlign.right, style: monoLabel(context))),
          ]),
          if (fat != null) Text('Body fat $fat %', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          if (weights.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 96,
              width: double.infinity,
              child: _Grow(builder: (g) => CustomPaint(painter: _LinePainter(values: [for (final w in weights) w.kg], grow: g, color: c.primary))),
            ),
          ],
        ],
      ]),
    ),
    const SizedBox(height: 12),
    _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('MEASUREMENTS', trailing: TextButton.icon(onPressed: onLogTape, icon: const Icon(LvIcons.ruler, size: 16), label: const Text('Log'))),
        if (tape.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Waist, chest, hips, arm, thigh and neck, every 2 to 4 weeks. The tape shows change the scale hides.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          )
        else
          for (final m in tape)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outline))),
              child: Row(children: [
                Expanded(child: Text(m.label, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
                if (m.now != m.from) ...[
                  Icon(m.now < m.from ? LvIcons.trendDown : LvIcons.trendUp, size: 16, color: c.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${m.now >= m.from ? '+' : ''}${(m.now - m.from).toStringAsFixed(1)}', style: monoNumber(context, size: 13).copyWith(color: c.onSurfaceVariant)),
                  const SizedBox(width: 16),
                ],
                Text('${m.now.toStringAsFixed(1)} cm', style: monoNumber(context, size: 15)),
              ]),
            ),
      ]),
    ),
    const SizedBox(height: 12),
    const BodyCheckCard(),
    const SizedBox(height: 12),
    _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label(
          'PHOTOS',
          trailing: TextButton.icon(
            onPressed: uploading ? null : onAddPhoto,
            icon: uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LvIcons.camera, size: 16),
            label: const Text('Add'),
          ),
        ),
        if (photos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Same light, pose, distance and time of day, every few weeks. Private to your account.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          )
        else ...[
          const SizedBox(height: 8),
          if (photos.length > 1) ...[
            // First and latest side by side: change you cannot see day to day.
            Row(children: [
              for (final (label, p) in [('FIRST', photos.last), ('LATEST', photos.first)]) ...[
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AspectRatio(aspectRatio: 3 / 4, child: photo(p, radius: 14)),
                    const SizedBox(height: 4),
                    Text('$label  ·  ${p.day.day} ${_months[p.day.month - 1].toUpperCase()}', style: monoLabel(context).copyWith(fontSize: 10)),
                  ]),
                ),
                if (label == 'FIRST') const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 12),
          ],
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3 / 4,
            children: [for (final p in photos) photo(p)],
          ),
        ],
      ]),
    ),
    const SizedBox(height: 12),
    _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('TRAINING, LAST 12 WEEKS', trailing: Text('TARGET $perWeek / WK', style: monoLabel(context))),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: _Grow(builder: (g) => CustomPaint(painter: _WeeksPainter(weeks: weeks, target: perWeek, grow: g, bar: c.primary, track: c.surfaceContainerHighest, line: c.onSurfaceVariant))),
        ),
        const SizedBox(height: 8),
        Row(children: [Text('12 WK AGO', style: monoLabel(context)), const Spacer(), Text('THIS WEEK', style: monoLabel(context))]),
        if (minutes > 0) ...[
          const SizedBox(height: 12),
          Text('${(minutes / 60).toStringAsFixed(1)} hours trained in total', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        ],
      ]),
    ),
    const SizedBox(height: 12),
    Text('Trend targets: ISSN position stand on diets and body composition (Aragon et al., 2017); off-season gain rates (Iraki et al., 2019).',
        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
  ];
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.accent = false});
  final String value, label;
  final bool accent;

  @override
  Widget build(BuildContext context) => _Tile(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CountUp(value, style: monoNumber(context, size: 28).copyWith(color: accent ? Theme.of(context).colorScheme.tertiary : null)),
          const SizedBox(height: 4),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: monoLabel(context).copyWith(fontSize: 10)), // two lines at phone width
        ]),
      );
}

class _WeeksPainter extends CustomPainter {
  _WeeksPainter({required this.weeks, required this.target, required this.grow, required this.bar, required this.track, required this.line});
  final List<int> weeks;
  final int target;
  final double grow;
  final Color bar, track, line;

  @override
  void paint(Canvas canvas, Size size) {
    final top = math.max(7, math.max(target, weeks.fold(0, math.max))).toDouble();
    const gap = 6.0;
    final w = (size.width - gap * (weeks.length - 1)) / weeks.length;
    for (final (i, n) in weeks.indexed) {
      final x = i * (w + gap);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, w, size.height), const Radius.circular(6)), Paint()..color = track);
      final h = size.height * (n / top) * grow;
      if (h > 0) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, w, h), const Radius.circular(6)), Paint()..color = bar);
    }
    // Dashed target line.
    final y = size.height * (1 - target / top);
    final pen = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), pen);
    }
  }

  @override
  bool shouldRepaint(_WeeksPainter old) => old.grow != grow || old.weeks != weeks || old.bar != bar;
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.values, required this.grow, required this.color});
  final List<double> values;
  final double grow;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min) - 0.5, hi = values.reduce(math.max) + 0.5;
    Offset at(int i) => Offset(size.width * i / (values.length - 1), size.height * (1 - (values[i] - lo) / (hi - lo)));
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    // Draws left to right as it grows in.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, -6, size.width * grow, size.height + 12));
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)]).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    if (grow == 1) canvas.drawCircle(at(values.length - 1), 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.grow != grow || old.values != values;
}

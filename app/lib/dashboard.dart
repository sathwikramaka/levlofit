// Dashboard v2: a bento of real numbers. Today first (one action), then the week, then fuel, body and coach,
// then goals and learning. Nothing here is decorative: every figure comes from the plan or the user's own logs.
import 'dart:async';
import 'dart:math' as math;


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'coach_chat.dart';
import 'diet_plan.dart';
import 'exercises.dart';
import 'handbook.dart';
import 'icons.dart';
import 'main.dart';
import 'mark.dart';
import 'onboarding.dart';
import 'reminders.dart';
import 'session.dart';
import 'theme.dart';
import 'tools.dart';

part 'dashboard_menu.dart';
part 'dashboard_tabs.dart';

typedef _Json = Map<String, dynamic>;

const _bmiLabels = {'underweight': 'Underweight', 'normal': 'Normal', 'overweight': 'Overweight', 'obese': 'Obese'};
const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// Suggested training weekdays (1 = Monday) for each number of days a week: spread out, rest between hard days.
const _pattern = {
  1: [3],
  2: [2, 5],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 5, 6],
  6: [1, 2, 3, 4, 5, 6],
  7: [1, 2, 3, 4, 5, 6, 7],
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monday(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1));
String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


/// Weekday (1 = Monday) to the goal trained that day; rest days are absent.
/// Spreads sessions across the suggested days, primary goal first, one goal per day in turn.
Map<int, _Json?> _schedule(_Json plan) {
  final goals = (plan['goals'] as List).cast<_Json>();
  final trainingDays = _pattern[(plan['trainingDaysPerWeek'] as int).clamp(1, 7)]!;
  final queue = <_Json>[];
  final remaining = {for (final g in goals) g['goal']: g['sessionsPerWeek'] as int};
  while (queue.length < trainingDays.length && remaining.values.any((n) => n > 0)) {
    for (final g in goals) {
      if (queue.length < trainingDays.length && remaining[g['goal']]! > 0) {
        queue.add(g);
        remaining[g['goal']] = remaining[g['goal']]! - 1;
      }
    }
  }
  final dayGoal = <int, _Json?>{for (final (i, d) in trainingDays.indexed) d: i < queue.length ? queue[i] : null};
  return dayGoal;
}

typedef _Data = ({
  String? name,
  _Json profile,
  _Json plan,
  _Json input,
  Map<String, _Json> levels,
  List<_Json> proteins,
  Tier tier,
  Set<String> assessed, // goals with a level check on record
  Map<DateTime, int> water, // ml drunk per day, last 7 days
  Set<(DateTime, String)> habits, // hand-ticked habits, last 7 days
});

/// Every place the side menu can take you. The shell swaps the body; the menu stays the same everywhere.
enum _Tab { home, workout, protocol, diet, hydration, habits, calendar, progress, foods, bmi, bodyFat, handbook, library, glossary, settings, profile }

final _shellKey = GlobalKey<ScaffoldState>();

/// The three-line menu button every tab shows in place of a back arrow.
class _ShellMenu extends StatelessWidget {
  const _ShellMenu();

  @override
  Widget build(BuildContext context) => _MenuButton(onTap: () => _shellKey.currentState?.openDrawer());
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Future<_Data> _data = _load();
  Set<DateTime> _logged = {}; // days with a logged session, last 8 weeks
  Map<DateTime, int> _minutes = {}; // minutes trained on those days, when known
  bool _saving = false;
  _Data? _loaded; // for the menu, which can open before or after the first load
  _Tab _tab = _Tab.home;

  String get _uid => supabase.auth.currentUser!.id;

  Future<_Data> _load() async {
    final now = DateTime.now();
    final [profile, latest] = await Future.wait([
      supabase.from('profiles').select('display_name, sex, birth_year, height_cm, weight_kg, waist_cm, equipment, equipment_items, days_per_week, session_minutes, water_target_ml').eq('id', _uid).single(),
      supabase.from('generated_plans').select('plan, input').eq('user_id', _uid).order('created_at', ascending: false).limit(1).single(),
    ]);
    final plan = latest['plan'] as _Json;
    final goals = (plan['goals'] as List).cast<_Json>();
    final results = await Future.wait<Object?>([
      supabase.from('curriculum_levels').select('goal, level, title, practice, advance_when, coach_recommended, source').inFilter('goal', [for (final g in goals) g['goal']]),
      _proteinSources(plan),
      supabase.from('workout_logs').select('performed_on, duration_min').eq('user_id', _uid).gte('performed_on', _iso(_monday(now).subtract(const Duration(days: 49)))),
      supabase.from('goal_levels').select('goal').eq('user_id', _uid),
      supabase.from('water_intake').select('taken_at, ml').eq('user_id', _uid).gte('taken_at', _day(now).subtract(const Duration(days: 6)).toUtc().toIso8601String()),
      supabase.from('habit_logs').select('day, habit').eq('user_id', _uid).gte('day', _iso(_day(now).subtract(const Duration(days: 6)))),
    ]);
    final water = <DateTime, int>{};
    for (final r in (results[4] as List).cast<_Json>()) {
      final d = _day(DateTime.parse(r['taken_at'] as String).toLocal());
      water[d] = (water[d] ?? 0) + (r['ml'] as int);
    }
    final rows = (results[0] as List).cast<_Json>();
    final logs = (results[2] as List).cast<_Json>();
    _logged = {for (final r in logs) DateTime.parse(r['performed_on'] as String)};
    _minutes = {for (final r in logs) if (r['duration_min'] != null) DateTime.parse(r['performed_on'] as String): r['duration_min'] as int};
    _loaded = (
      name: profile['display_name'] as String?,
      profile: profile,
      plan: plan,
      input: (latest['input'] as _Json?) ?? const <String, dynamic>{},
      levels: {
        for (final r in rows)
          if (goals.any((g) => g['goal'] == r['goal'] && g['startLevel'] == r['level'])) r['goal'] as String: r,
      },
      proteins: results[1] as List<_Json>,
      tier: tierFor(profile['equipment'] as String?, profile['equipment_items'] as List?),
      assessed: {for (final r in (results[3] as List).cast<_Json>()) r['goal'] as String},
      water: water,
      habits: {for (final r in (results[5] as List).cast<_Json>()) (DateTime.parse(r['day'] as String), r['habit'] as String)},
    );
    _scheduleReminders(plan);
    return _loaded!;
  }

  /// Re-arms reminders for the current plan. Never blocks or breaks the dashboard.
  Future<void> _scheduleReminders(_Json plan) async {
    try {
      final sessions = {for (final e in _schedule(plan).entries) e.key: ((e.value?['name'] ?? e.value?['goal'] ?? 'Your session') as String)};
      await Reminders.apply(await loadReminderPrefs(), sessions, inApp: _inApp);
    } catch (_) {}
  }

  /// In-app reminder banner: drops in from the top with the Levlofit chime, then leaves on its own.
  void _inApp(String title, String body) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ReminderBanner(title: title, body: body, onDone: () => entry.remove()));
    overlay.insert(entry);
  }

  /// Best protein-per-calorie foods from IFCT 2017 that pass this plan's diet and allergy filters.
  Future<List<_Json>> _proteinSources(_Json plan) async {
    final food = plan['nutrition'] as _Json;
    final excluded = (food['excludedFoodTags'] as List).cast<String>();
    final custom = ((food['customExclusions'] as List?) ?? const []).cast<String>();
    final rows = await supabase
        .from('foods')
        .select('name, name_hi, tags, kcal, protein_g')
        .eq('suggestible', true)
        .gte('protein_g', 15) // a real protein source per 100 g; leafy greens rank high per kcal but not per plate
        .not('food_group', 'in', '("Condiments and Spices","Edible Oils and Fats","Sugars")')
        .not('tags', 'ov', '{${excluded.join(',')}}');
    bool mentions(_Json f, String term) => '${f['name']} ${f['name_hi'] ?? ''} ${(f['tags'] as List).join(' ')}'.toLowerCase().contains(term);
    final allowed = [for (final f in rows) if (!custom.any((t) => mentions(f, t))) f]
      ..sort((a, b) => ((b['protein_g'] as num) / (b['kcal'] as num)).compareTo((a['protein_g'] as num) / (a['kcal'] as num)));
    // One entry per food family ("Rajmah, red" and "Rajmah, brown" collapse) keeps the list useful.
    final seen = <String>{};
    return [for (final f in allowed) if (seen.add((f['name'] as String).split(',').first)) f].take(6).toList();
  }

  /// Logs today's session, or removes it again. Writes to workout_logs under the user's own row policy.
  Future<void> _toggleToday(String goal, int? minutes) async {
    if (_saving) return;
    final today = _day(DateTime.now());
    final done = _logged.contains(today);
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      if (done) {
        await supabase.from('workout_logs').delete().eq('user_id', _uid).eq('performed_on', _iso(today));
        setState(() {
          _logged = {..._logged}..remove(today);
          _minutes = {..._minutes}..remove(today);
        });
      } else {
        await supabase.from('workout_logs').insert({'user_id': _uid, 'performed_on': _iso(today), 'goal': goal, 'duration_min': minutes});
        setState(() {
          _logged = {..._logged, today};
          if (minutes != null) _minutes = {..._minutes, today: minutes};
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection and try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _go(_Tab tab) {
    if (tab == _tab) return;
    setState(() {
      // Coming home picks up anything logged on the other tabs.
      if (tab == _Tab.home) _data = _load();
      _tab = tab;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // The system back gesture returns to the dashboard instead of leaving the app.
        canPop: _tab == _Tab.home,
        onPopInvokedWithResult: (didPop, _) => didPop ? null : _go(_Tab.home),
        child: Scaffold(
          key: _shellKey,
          drawer: _Menu(current: _tab, data: () => _loaded, onSelect: _go),
          drawerScrimColor: Colors.black.withValues(alpha: 0.45),
          floatingActionButton: _tab == _Tab.home || _tab == _Tab.workout || _tab == _Tab.diet ? const CoachLauncher() : null,
          body: AnimatedSwitcher(
            duration: motion(context, 320),
            switchInCurve: spring,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a), child: child),
            ),
            child: KeyedSubtree(key: ValueKey(_tab), child: _body(context)),
          ),
        ),
      );

  Widget _body(BuildContext context) {
    final p = _loaded?.profile ?? const <String, dynamic>{};
    return switch (_tab) {
      _Tab.home => _home(context),
      _Tab.glossary => const _GlossaryScreen(),
      _Tab.bmi => BmiScreen(leading: const _ShellMenu(), heightCm: p['height_cm'] as num?, weightKg: p['weight_kg'] as num?),
      _Tab.bodyFat => BodyFatScreen(leading: const _ShellMenu(), male: p['sex'] == null ? null : p['sex'] == 'male', heightCm: p['height_cm'] as num?, waistCm: p['waist_cm'] as num?),
      _Tab.handbook => const HandbookScreen(leading: _ShellMenu()),
      _Tab.library => const ExerciseLibraryScreen(leading: _ShellMenu()),
      _ => _withData((d) => switch (_tab) {
            _Tab.workout => _WorkoutScreen(
                data: d,
                logged: _logged,
                onEditGoals: () => _editGoals(context, d.plan),
                onToggleToday: _toggleToday,
                onPlanChanged: () => setState(() => _data = _load()),
              ),
            _Tab.diet => _DietScreen(data: d),
            _Tab.protocol => _ProtocolScreen(data: d, onEditGoals: () => _editGoals(context, d.plan), onSaved: () => setState(() => _data = _load())),
            _Tab.profile => _ProfileScreen(
                data: d,
                onOpen: _go,
                onSignOut: () => supabase.auth.signOut(),
                onDelete: () => _confirmDelete(context),
                onEditDetails: () => _editDetails(context, d),
              ),
            _Tab.hydration => _HydrationScreen(data: d),
            _Tab.habits => _HabitsScreen(data: d, logged: _logged),
            _Tab.calendar => _CalendarScreen(plan: d.plan),
            _Tab.progress => _ProgressScreen(data: d),
            _Tab.foods => _FoodsScreen(data: d),
            _Tab.settings => _SettingsScreen(onRemindersChanged: () => _scheduleReminders(d.plan)),
            _ => const SizedBox.shrink(),
          }),
    };
  }

  /// Tabs that need the plan wait for it under the same menu button.
  Widget _withData(Widget Function(_Data d) page) => FutureBuilder(
        future: _data,
        builder: (context, snap) => snap.hasData
            ? page(snap.data!)
            : Scaffold(
                appBar: AppBar(leading: const _ShellMenu()),
                body: Center(child: snap.hasError ? const ErrorLine('Could not load your plan. Check your connection.') : const LevloMark(size: 48, animate: true)),
              ),
      );

  Widget _home(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: const _ShellMenu(),
          leadingWidth: 64,
          titleSpacing: 4,
          title: const LevloWordmark(fontSize: 22),
          actions: [
            IconButton(tooltip: 'Profile', icon: const Icon(LvIcons.userCircle, size: 24), onPressed: () => _go(_Tab.profile)),
            const SizedBox(width: 12),
          ],
        ),
        body: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ErrorLine('Could not load your plan. Check your connection.'),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => setState(() => _data = _load()), child: const Text('Try again')),
                ]),
              );
            }
            if (!snap.hasData) return const Center(child: LevloMark(size: 56, animate: true));
            return _Bento(
              data: snap.data!,
              logged: _logged,
              minutes: _minutes,
              saving: _saving,
              onToggleToday: _toggleToday,
              onCheckLevel: () => _go(_Tab.workout),
              onOpen: _go,
              onAddWater: _addWater,
            );
          },
        ),
      );

  /// One glass from the dashboard tile.
  Future<void> _addWater() async {
    HapticFeedback.mediumImpact();
    try {
      await supabase.from('water_intake').insert({'ml': 250});
      setState(() => _data = _load());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection.')));
    }
  }

  /// Name, height and weight. Height and weight feed the calorie and protein targets, so the plan is rebuilt.
  Future<void> _editDetails(BuildContext context, _Data d) async {
    final name = TextEditingController(text: d.name ?? ''), h = TextEditingController(text: '${d.profile['height_cm'] ?? ''}'), w = TextEditingController(text: '${d.profile['weight_kg'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Your details'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name'), maxLength: 60),
          TextField(controller: h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm')),
          const SizedBox(height: 10),
          TextField(controller: w, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dlg, true), child: const Text('Save')),
        ],
      ),
    );
    final height = double.tryParse(h.text), weight = double.tryParse(w.text), display = name.text.trim();
    name.dispose();
    h.dispose();
    w.dispose();
    if (ok != true || height == null || weight == null || height < 120 || height > 230 || weight < 30 || weight > 250) return;
    try {
      await supabase.from('profiles').update({'display_name': display.isEmpty ? null : display, 'height_cm': height, 'weight_kg': weight}).eq('id', _uid);
      await supabase.functions.invoke('generate-plan');
      if (mounted) setState(() => _data = _load());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Could not save your details.')));
    }
  }

  /// Reuses the onboarding goal steps, prefilled from the current plan; a new plan snapshot is saved.
  Future<void> _editGoals(BuildContext context, _Json plan) async {
    final goals = (plan['goals'] as List).cast<_Json>();
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (route) => Onboarding(
          goalsOnly: true,
          initialGoals: [for (final g in goals) g['goal'] as String],
          initialLevels: {for (final g in goals) g['goal'] as String: g['experience'] as String},
          onDone: () => Navigator.pop(route, true),
        ),
      ),
    );
    if (updated == true && mounted) setState(() => _data = _load());
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final danger = Theme.of(context).colorScheme.error;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This permanently deletes your profile, plans and logs. It cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger, foregroundColor: Theme.of(d).colorScheme.onError),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.functions.invoke('delete-account');
      // The user no longer exists server-side, so only clear the local session.
      await supabase.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not delete your account. Try again.')));
    }
  }
}

// ---------------------------------------------------------------- the bento

/// Renders the dashboard body from a plan without Supabase, so layout can be tested at phone size.
@visibleForTesting
Widget dashboardBentoForTest(Map<String, dynamic> plan, {Set<DateTime> logged = const {}}) => _Bento(
      data: (name: 'Asha Rao', profile: const {}, plan: plan, input: const {'sessionMinutes': 45}, levels: const {}, proteins: const [], tier: Tier.home, assessed: const {}, water: const {}, habits: const {}),
      logged: logged,
      minutes: {for (final d in logged) d: 45},
      saving: false,
      onToggleToday: (_, _) async {},
      onCheckLevel: () {},
      onOpen: (_) {},
      onAddWater: () {},
    );


class _Bento extends StatelessWidget {
  const _Bento({
    required this.data,
    required this.logged,
    required this.minutes,
    required this.saving,
    required this.onToggleToday,
    required this.onCheckLevel,
    required this.onOpen,
    required this.onAddWater,
  });
  final _Data data;
  final Set<DateTime> logged;
  final Map<DateTime, int> minutes;
  final bool saving;
  final Future<void> Function(String goal, int? minutes) onToggleToday;
  final VoidCallback onCheckLevel;
  final ValueChanged<_Tab> onOpen;
  final VoidCallback onAddWater;

  @override
  Widget build(BuildContext context) {
    final plan = data.plan;
    final goals = (plan['goals'] as List).cast<_Json>();
    final now = DateTime.now();
    final today = _day(now);
    final monday = _monday(now);
    final perWeek = (plan['trainingDaysPerWeek'] as int).clamp(1, 7);
    final dayGoal = _schedule(plan);
    bool thisWeek(DateTime d) => !d.isBefore(monday) && d.isBefore(monday.add(const Duration(days: 7)));

    final doneThisWeek = logged.where(thisWeek).length;
    final minutesThisWeek = minutes.entries.where((e) => thisWeek(e.key)).fold(0, (s, e) => s + e.value);
    // WHO 2020: 150 to 300 minutes of moderate activity a week; the plan carries the range.
    final moveTarget = ((plan['activityGuideline'] as _Json?)?['moderateMinutesPerWeek'] as List?)?.first as int? ?? 150;
    final streak = _weekStreak(logged, monday, perWeek);
    final todayGoal = dayGoal[now.weekday] ?? goals.first;
    final isTrainingDay = dayGoal.containsKey(now.weekday);
    final sessionMinutes = data.input['sessionMinutes'] as int?;
    final level = todayGoal['startLevel'] as int;
    // Which session of this goal today is, so A and B alternate through the week.
    final nth = [for (var d = 1; d < now.weekday; d++) if (dayGoal[d]?['goal'] == todayGoal['goal']) d].length;
    final ids = sessionIds(todayGoal['kind'] as String? ?? 'strength', data.tier, level, nth);

    final first = (data.name ?? '').split(' ').first;
    final hello = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final review = ((plan['review'] as List?) ?? const []).cast<_Json>();
    final important = review.where((f) => f['level'] == 'stop' || f['level'] == 'change').toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 112), // room for the floating assistant
          children: staggered([
            Text('${_days[now.weekday - 1]}  ·  ${now.day} ${_months[now.month - 1].toUpperCase()}', style: monoLabel(context)),
            const SizedBox(height: 6),
            Text(first.isEmpty ? hello : '$hello, $first', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            _Rings(days: doneThisWeek, daysTarget: perWeek, minutes: minutesThisWeek, minutesTarget: moveTarget, streak: streak),
            const SizedBox(height: 12),
            _TodayCard(
              isTrainingDay: isTrainingDay,
              goal: todayGoal,
              levelRow: data.levels[todayGoal['goal']],
              minutes: sessionMinutes,
              ids: ids,
              done: logged.contains(today),
              saving: saving,
              onToggle: () => onToggleToday(todayGoal['goal'] as String, sessionMinutes),
            ),
            // Level first: until the main goal has a level check on record, that is the next thing to do.
            if (!data.assessed.contains(goals.first['goal']) && data.levels.containsKey(goals.first['goal'])) ...[
              const SizedBox(height: 12),
              _LevelPrompt(goalName: (goals.first['name'] ?? goals.first['goal']) as String, onTap: onCheckLevel),
            ],
            if (important.isNotEmpty) ...[const SizedBox(height: 12), _ReviewRow(review: review, important: important)],
            const SizedBox(height: 12),
            _WeekStrip(monday: monday, today: today, dayGoal: dayGoal, logged: logged, streak: streak),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final habits = _habitList(data, logged, data.habits, data.water);
              final week = [for (var i = 6; i >= 0; i--) habits.where((h) => h.$5(today.subtract(Duration(days: i)))).length];
              return _Pair(
                left: _HydrationTile(ml: data.water[today] ?? 0, target: waterTarget(data.profile, training: isTrainingDay), onAdd: onAddWater, onOpen: () => onOpen(_Tab.hydration)),
                right: _HabitsTile(done: week.last, total: habits.length, week: week, onOpen: () => onOpen(_Tab.habits)),
              );
            }),
            const SizedBox(height: 12),
            _Pair(left: _FuelTile(plan: plan, proteins: data.proteins), right: _BodyTile(plan: plan)),
          ]),
        ),
      ),
    );
  }

  /// Consecutive weeks, counting back from last week, in which the planned number of days was logged.
  /// This week joins the count once it is already met.
  static int _weekStreak(Set<DateTime> logged, DateTime monday, int perWeek) {
    int daysIn(DateTime start) => logged.where((d) => !d.isBefore(start) && d.isBefore(start.add(const Duration(days: 7)))).length;
    var streak = daysIn(monday) >= perWeek ? 1 : 0;
    for (var w = 1; w <= 7; w++) {
      if (daysIn(monday.subtract(Duration(days: 7 * w))) < perWeek) break;
      streak++;
    }
    return streak;
  }
}

// ---------------------------------------------------------------- rings and today

/// Activity rings, read at a glance: outer is training days against the plan, inner is active minutes
/// against the WHO weekly target. Both close when the week's job is done.
class _Rings extends StatelessWidget {
  const _Rings({required this.days, required this.daysTarget, required this.minutes, required this.minutesTarget, required this.streak});
  final int days, daysTarget, minutes, minutesTarget, streak;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // Always a dark plate, like a watch face: graphite on the light page, a raised surface on the dark one.
    final ink = Theme.of(context).brightness == Brightness.dark ? c.surface : graphite;
    const onInk = cloud;
    const move = Color(0xFFFFB27A); // a lighter tint of the brand orange, so the two rings read apart
    Widget stat(Color dot, String label, String value, String unit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: monoLabel(context).copyWith(color: onInk.withValues(alpha: 0.65))),
            ]),
            const SizedBox(height: 2),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              CountUp(value, style: monoNumber(context, size: 24).copyWith(color: onInk)),
              const SizedBox(width: 6),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: onInk.withValues(alpha: 0.6))),
                ),
              ),
            ]),
          ]),
        );
    return Semantics(
      label: '$days of $daysTarget training days and $minutes of $minutesTarget active minutes this week',
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(30), border: Border.all(color: c.outline)),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(25)),
          child: Row(children: [
            SizedBox(
              width: 128,
              height: 128,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: motion(context, 1300),
                curve: spring,
                builder: (_, v, _) => CustomPaint(
                  painter: _RingsPainter(
                    outer: (days / daysTarget).clamp(0.0, 1.0) * v,
                    inner: (minutes / minutesTarget).clamp(0.0, 1.0) * v,
                    outerColor: c.primary,
                    innerColor: move,
                    track: onInk.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                stat(c.primary, 'TRAIN', '$days', 'of $daysTarget days'),
                stat(move, 'MOVE', '$minutes', 'of $minutesTarget min'),
                stat(onInk.withValues(alpha: 0.5), 'STREAK', '$streak', streak == 1 ? 'week on plan' : 'weeks on plan'),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.outer, required this.inner, required this.outerColor, required this.innerColor, required this.track});
  final double outer, inner;
  final Color outerColor, innerColor, track;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 14.0;
    void ring(Rect r, double v, Color color) {
      Paint pen(Color col) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = col;
      canvas.drawArc(r, 0, 2 * math.pi, false, pen(track));
      if (v > 0) canvas.drawArc(r, -math.pi / 2, 2 * math.pi * v, false, pen(color));
    }

    final o = (Offset.zero & size).deflate(w / 2);
    ring(o, outer, outerColor);
    ring(o.deflate(w + 4), inner, innerColor);
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.outer != outer || old.inner != inner || old.outerColor != outerColor;
}

/// Today's session with its moves animated, and one action to start it.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.isTrainingDay,
    required this.goal,
    required this.levelRow,
    required this.minutes,
    required this.ids,
    required this.done,
    required this.saving,
    required this.onToggle,
  });
  final bool isTrainingDay, done, saving;
  final _Json goal;
  final _Json? levelRow;
  final int? minutes;
  final List<String> ids;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = (goal['name'] ?? goal['goal']) as String;
    final level = goal['startLevel'] as int;
    final meta = ['Level $level', if (levelRow != null) levelRow!['title'] as String, if (minutes != null) '$minutes min'].join('  ·  ');
    void start() => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => SessionScreen(title: name, ids: ids, level: level, done: done, onFinish: done ? null : onToggle)),
        );
    return _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: isTrainingDay ? c.primary : c.onSurfaceVariant, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(isTrainingDay ? 'TODAY\'S WORKOUT' : 'TODAY  ·  REST DAY', style: monoLabel(context))),
          if (done) Text('DONE', style: monoLabel(context).copyWith(color: c.tertiary)),
        ]),
        const SizedBox(height: 10),
        Text(isTrainingDay ? name : 'Recover today', style: t.titleLarge),
        const SizedBox(height: 2),
        Text(isTrainingDay ? meta : 'Sleep, walk, eat well. Or train anyway, it still counts.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 16),
        MoveStrip(ids: ids, level: level, tile: 112),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: motion(context, 320),
          switchInCurve: spring,
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child)),
          child: done
              ? Row(key: const ValueKey('done'), children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    child: Icon(LvIcons.check, size: 18, color: c.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Done today', style: t.titleMedium)),
                  TextButton(onPressed: saving ? null : onToggle, child: const Text('Undo')),
                ])
              : Row(key: const ValueKey('start'), children: [
                  Expanded(
                    child: FilledButton(onPressed: start, child: Text(isTrainingDay ? 'Start workout' : 'Train anyway')),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: saving ? null : onToggle,
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 48)),
                      child: Tooltip(message: 'Log as done', child: Icon(LvIcons.check, size: 20, color: c.onSurface)),
                    ),
                  ),
                ]),
        ),
      ]),
    );
  }
}

/// Only when the coach review changed the plan or flagged a doctor visit: one quiet row, not a tile.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, required this.important});
  final List<_Json> review, important;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final stop = important.any((f) => f['level'] == 'stop');
    return _Tile(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => _showReview(context, review),
      child: Row(children: [
        Icon(stop ? LvIcons.warningCircle : LvIcons.lightbulb, size: 20, color: stop ? c.error : c.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            stop ? 'See a doctor before hard training. Tap for why.' : '${important.length} coach note${important.length == 1 ? '' : 's'} shaped your plan',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Icon(LvIcons.caretRight, size: 16, color: c.onSurfaceVariant),
      ]),
    );
  }
}

/// Two columns of equal height; stacks on very narrow screens.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});
  final Widget left, right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => box.maxWidth < 330
            ? Column(children: [left, const SizedBox(height: 12), right])
            : IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)])),
      );
}

/// A tappable surface with the house finish: hairline border, soft radius, press-in.
class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.onTap, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final body = Padding(padding: padding, child: child);
    final tile = Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: c.outline)),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
    return onTap == null ? tile : Pressable(child: tile);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(text, style: monoLabel(context))), ?trailing]);
}

/// Plays once on first build: 0 to 1 on the brand ease.
class _Grow extends StatelessWidget {
  const _Grow({required this.builder, this.delay = 0});
  final Widget Function(double v) builder;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, 900);
    if (d == Duration.zero) return builder(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Interval(delay.clamp(0.0, 0.9), 1, curve: spring),
      builder: (_, v, _) => builder(v),
    );
  }
}

// ---------------------------------------------------------------- week

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.monday, required this.today, required this.dayGoal, required this.logged, required this.streak});
  final DateTime monday, today;
  final Map<int, _Json?> dayGoal;
  final Set<DateTime> logged;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label(
          'THIS WEEK',
          trailing: Text(streak > 0 ? '$streak WEEK${streak == 1 ? '' : 'S'} ON PLAN' : 'PLANNED  ·  DONE', style: monoLabel(context).copyWith(color: streak > 0 ? c.tertiary : null)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (context) {
                final day = monday.add(Duration(days: i));
                final planned = dayGoal.containsKey(i + 1);
                final done = logged.contains(day);
                final isToday = day == today;
                final goal = dayGoal[i + 1];
                return Semantics(
                  label: '${_days[i]}: ${done ? 'done' : planned ? 'planned' : 'rest'}${isToday ? ', today' : ''}',
                  child: Column(children: [
                    Text(_days[i].substring(0, 1), style: monoLabel(context).copyWith(color: isToday ? c.onSurface : null)),
                    const SizedBox(height: 8),
                    _Grow(
                      delay: i * 0.06,
                      builder: (v) => Transform.scale(
                        scale: 0.5 + 0.5 * v,
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: done ? c.primary : (planned ? Colors.transparent : c.surfaceContainerHighest),
                            shape: BoxShape.circle,
                            border: Border.all(color: done ? c.primary : (planned ? c.onSurface : Colors.transparent), width: 1.5),
                          ),
                          child: done
                              ? Icon(LvIcons.check, size: 16, color: c.onPrimary)
                              : Text('${day.day}', style: monoNumber(context, size: 12).copyWith(color: planned ? c.onSurface : c.onSurfaceVariant)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(duration: motion(context, 300), width: isToday ? 14 : 0, height: 2, color: c.primary),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 28,
                      child: Text(
                        goal == null ? '' : ((goal['name'] ?? goal['goal']) as String).split(' ').first,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(fontSize: 10, height: 1.2, color: c.onSurfaceVariant),
                      ),
                    ),
                  ]),
                );
              }),
            ),
        ]),
        Text('Suggested days. Train on any day; every logged day counts.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- fuel and body

class _FuelTile extends StatelessWidget {
  const _FuelTile({required this.plan, required this.proteins});
  final _Json plan;
  final List<_Json> proteins;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final food = plan['nutrition'] as _Json;
    final protein = (food['proteinG'] as num).round();
    // ISSN: 20 to 40 g per meal, every 3 to 4 hours. Four meals fits a common Indian day.
    final perMeal = (protein / 4).round();
    return _Tile(
      onTap: () => _showFuel(context, plan, proteins),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('FUEL', trailing: Icon(LvIcons.caretRight, size: 16, color: c.onSurfaceVariant)),
        const SizedBox(height: 14),
        CountUp('${food['energyKcal']}', style: monoNumber(context, size: 34)),
        Text('kcal a day', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const Spacer(),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CountUp('$protein', style: monoNumber(context, size: 24).copyWith(color: c.tertiary)),
          const SizedBox(width: 4),
          Flexible(child: Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('g protein', overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)))),
        ]),
        const SizedBox(height: 10),
        // Four meals, each a quarter of the day's protein.
        Row(children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: _Grow(
                delay: 0.2 + i * 0.1,
                builder: (v) => Container(
                  height: 26,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                  child: FractionallySizedBox(
                    heightFactor: v,
                    widthFactor: 1,
                    child: DecoratedBox(decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(6))),
                  ),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 4),
          ],
        ]),
        const SizedBox(height: 6),
        Text('4 MEALS  ·  ~$perMeal G EACH', style: monoLabel(context)),
      ]),
    );
  }
}

class _BodyTile extends StatelessWidget {
  const _BodyTile({required this.plan});
  final _Json plan;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final bmi = plan['bmi'] as _Json;
    final value = (bmi['value'] as num).toDouble();
    // Asian Indian cut-offs (Misra 2009), drawn on a 14 to 35 scale.
    const lo = 14.0, hi = 35.0;
    double at(double v) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
    final success = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF5FB482) : const Color(0xFF2F7D4F);
    return _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('BODY  ·  BMI'),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CountUp('${bmi['value']}', style: monoNumber(context, size: 26)),
          const SizedBox(width: 6),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(_bmiLabels[bmi['category']] ?? '', overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // A painter, not a LayoutBuilder: this tile sits in an equal-height row, which measures intrinsic sizes.
        SizedBox(
          height: 14,
          width: double.infinity,
          child: _Grow(
            builder: (v) => CustomPaint(
              painter: _BandPainter(
                value: at(value) * v,
                segments: [(at(lo), at(18), c.primary.withValues(alpha: 0.55)), (at(18), at(23), success), (at(23), at(25), c.primary), (at(25), at(hi), c.error)],
                marker: c.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('INDIAN CUT-OFFS', style: monoLabel(context)),
      ]),
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter({required this.value, required this.segments, required this.marker});
  final double value; // 0 to 1 along the band
  final List<(double, double, Color)> segments;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (a, b, col) in segments) {
      final r = Rect.fromLTWH(size.width * a, 4, math.max(0, size.width * (b - a) - 2), 6);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = col);
    }
    final x = (size.width * value).clamp(1.5, size.width - 1.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.5, 0, 3, size.height), const Radius.circular(2)), Paint()..color = marker);
  }

  @override
  bool shouldRepaint(_BandPainter old) => old.value != value || old.marker != marker;
}

class _Sources extends StatelessWidget {
  const _Sources({required this.plan});
  final _Json plan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text('SOURCES BEHIND YOUR PLAN', style: monoLabel(context)),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in (plan['sources'] as List).cast<String>()) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: t.bodySmall?.copyWith(color: muted))),
          Text(exerciseMediaCredit, style: t.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- sheets

void _showReview(BuildContext context, List<_Json> review) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('WHAT YOUR COACH FOUND', style: monoLabel(context)),
              const SizedBox(height: 12),
              for (final f in review) ...[FindingCard(f), const SizedBox(height: 10)],
            ],
          ),
        ),
      ),
    );

void _showFuel(BuildContext context, _Json plan, List<_Json> proteins) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: _fuelDetails(context, plan, proteins)),
        ),
      ),
    );

/// Daily targets, supplements and best protein sources; shared by the Fuel sheet and the Diet page.
List<Widget> _fuelDetails(BuildContext context, _Json plan, List<_Json> proteins) {
  final t = Theme.of(context).textTheme;
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  final food = plan['nutrition'] as _Json;
  final soya = food['maxSoyaChunksDryG'] as int;
  final supps = ((food['supplements'] as List?) ?? const []).cast<_Json>();
  Widget row(String a, String b, String v) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline))),
        child: Row(children: [
          Expanded(child: Text(a, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          Text(b, style: t.bodySmall?.copyWith(color: muted)),
          const SizedBox(width: 16),
          SizedBox(width: 60, child: Text(v, textAlign: TextAlign.right, style: monoNumber(context, size: 15))),
        ]),
      );
  return [
    Text('FUEL, DAILY', style: monoLabel(context)),
    const SizedBox(height: 6),
    Text('${food['energyKcal']} kcal', style: t.headlineMedium),
    const SizedBox(height: 12),
    row('Protein', '${food['proteinPerKg']} g per kg', '${food['proteinG']} g'),
    row('Soya chunks', 'dry weight, max', soya == 0 ? 'none' : '$soya g'),
    if ((food['customExclusions'] as List?)?.isNotEmpty ?? false)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Also kept out of your meals: ${(food['customExclusions'] as List).join(', ')}.', style: t.bodySmall?.copyWith(color: muted)),
      ),
    for (final x in supps) ...[
      const SizedBox(height: 14),
      Text(x['name'] as String, style: t.titleSmall),
      const SizedBox(height: 2),
      Text('${x['how']}', style: t.bodyMedium),
      Text('${x['why']}', style: t.bodySmall?.copyWith(color: muted)),
    ],
    if (proteins.isNotEmpty) ...[
      const SizedBox(height: 20),
      Text('BEST PROTEIN SOURCES FOR YOU', style: monoLabel(context)),
      const SizedBox(height: 4),
      for (final f in proteins) row(f['name_hi'] == null ? f['name'] as String : '${f['name']} (${f['name_hi']})', '${f['kcal']} kcal', '${(f['protein_g'] as num).round()} g'),
      const SizedBox(height: 8),
      Text('Protein per 100 g, filtered for your diet and allergies. Source: IFCT 2017, National Institute of Nutrition.', style: t.bodySmall?.copyWith(color: muted)),
    ],
  ];
}

/// Curriculum content for one goal at the user's current level.
void _showLevel(BuildContext context, String goalName, _Json row) {
  final t = Theme.of(context).textTheme;
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${goalName.toUpperCase()}  ·  LEVEL ${row['level']}', style: monoLabel(context)),
          const SizedBox(height: 6),
          Text(row['title'] as String, style: t.titleLarge),
          const SizedBox(height: 20),
          Text('PRACTISE', style: monoLabel(context)),
          const SizedBox(height: 8),
          for (final item in (row['practice'] as List).cast<String>())
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LvIcons.check, size: 16, color: muted)),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: t.bodyMedium)),
              ]),
            ),
          const SizedBox(height: 12),
          Text('MOVE UP WHEN', style: monoLabel(context)),
          const SizedBox(height: 8),
          Text(row['advance_when'] as String, style: t.bodyMedium),
          if (row['coach_recommended'] == true) ...[
            const SizedBox(height: 12),
            Text('A qualified coach is recommended at this level.', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          Text('Source: ${row['source']}, Self-Coaching Athlete Master Curriculum.', style: t.bodySmall?.copyWith(color: muted)),
        ]),
      ),
    ),
  );
}

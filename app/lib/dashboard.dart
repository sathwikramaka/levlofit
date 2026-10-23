// Dashboard v2: a bento of real numbers. Today first (one action), then the week, then fuel, body and coach,
// then goals and learning. Nothing here is decorative: every figure comes from the plan or the user's own logs.
import 'dart:async';
import 'dart:math' as math;


import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, kReleaseMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account.dart';
import 'avatar.dart';
import 'coach_chat.dart';
import 'diet_plan.dart';
import 'exercises.dart';
import 'food_diary.dart' show FoodDiaryScreen, matchesFoodQuery;
import 'handbook.dart';
import 'icons.dart';
import 'main.dart';
import 'mark.dart';
import 'onboarding.dart';
import 'dashboard_layout.dart';
import 'reminders.dart';
import 'rewards.dart';
import 'session.dart';
import 'steps.dart' show StepsCard, healthPermissionScreenRequested, onHealthRationale;
import 'swaps.dart';
import 'theme.dart';
import 'tools.dart';
import 'week_schedule.dart' show addOnLine, reminderSessions, weekPlan;

part 'dashboard_menu.dart';
part 'dashboard_tabs.dart';

typedef _Json = Map<String, dynamic>;

const _bmiLabels = {'underweight': 'Underweight', 'normal': 'Normal', 'overweight': 'Overweight', 'obese': 'Obese'};
const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monday(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1));
String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


/// Weekday (1 = Monday) to the session trained that day; rest days are absent.
/// Every planned session, including the engine's extra strength sessions, gets a day (week_schedule.dart).
Map<int, _Json?> _schedule(_Json plan) => weekPlan(plan).days;

typedef _Data = ({
  String? name,
  _Json profile,
  _Json plan,
  _Json input,
  Map<String, _Json> levels,
  List<_Json> proteins,
  Tier tier,
  Set<String> assessed, // goals with a level check on record
  Map<DateTime, int> water, // ml drunk per day, last 30 days (daily-goal streak)
  Set<(DateTime, String)> habits, // hand-ticked habits, last 30 days
  Map<String, String> swaps, // today's confirmed coach swaps, move id -> replacement (swaps.dart)
  bool lighter, // today's session made lighter with Levlofit AI (swaps.dart)
  List<(int, int)> moves, // this week's sessions moved with Levlofit AI, (from, to) weekday (swaps.dart)
});

/// Every place the side menu can take you. The shell swaps the body; the menu stays the same everywhere.
enum _Tab { home, workout, protocol, diet, hydration, habits, calendar, progress, foods, foodDiary, bmi, bodyFat, handbook, library, glossary, reminders, settings, profile }

final _shellKey = GlobalKey<ScaffoldState>();

/// The three-line menu button every tab shows in place of a back arrow; a back arrow instead when the tab was
/// opened from another page (Profile > Settings), so the way back is the way in.
class _ShellMenu extends StatelessWidget {
  const _ShellMenu();

  @override
  Widget build(BuildContext context) {
    final back = context.dependOnInheritedWidgetOfExactType<_BackScope>()?.onBack;
    return back != null ? BackButton(onPressed: back) : _MenuButton(onTap: () => _shellKey.currentState?.openDrawer());
  }
}

class _BackScope extends InheritedWidget {
  const _BackScope({required this.onBack, required super.child});
  final VoidCallback? onBack;

  @override
  bool updateShouldNotify(_BackScope old) => old.onBack != onBack;
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
  final _back = <_Tab>[]; // pages to return to, for tabs opened from another page rather than the menu

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    // Health Connect opens the app from its permission screens to show why steps are read: show the privacy policy.
    healthPermissionScreenRequested().then((asked) {
      if (asked && mounted) showPrivacyPolicy(context);
    });
    onHealthRationale(() {
      if (mounted) showPrivacyPolicy(context);
    });
    swapsChanged.addListener(_reloadForSwap);
  }

  // A swap confirmed in Levlofit AI changes today's session: load it again.
  void _reloadForSwap() {
    if (!mounted) return;
    setState(() {
      _data = _load();
    });
  }

  @override
  void dispose() {
    swapsChanged.removeListener(_reloadForSwap);
    super.dispose();
  }

  // Device-local, per user: card layout, the tasks that make up the daily goal, the last celebrated day.
  late List<CardPref> _layout = mergeLayout(decodeLayout(prefs.getString('dashboard_layout:$_uid')));
  late Set<String> _dailyTasks = {...?prefs.getStringList('daily_goal:$_uid')}.ifEmpty(defaultDailyTasks);
  late String? _celebrated = prefs.getString('celebrated_day:$_uid');

  Future<void> _customise() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DashboardCustomiser(
          initial: _layout,
          onChanged: (l) {
            prefs.setString('dashboard_layout:$_uid', encodeLayout(l));
            setState(() => _layout = l);
          },
        ),
      );

  Future<void> _chooseTasks() async {
    final d = _loaded;
    if (d == null) return;
    final habits = _habitList(d, _logged, d.habits, d.water);
    final chosen = await showModalBottomSheet<Set<String>>(context: context, showDragHandle: true, builder: (_) => _DailyGoalSheet(habits: habits, chosen: _dailyTasks));
    if (chosen == null || chosen.isEmpty) return;
    prefs.setStringList('daily_goal:$_uid', chosen.toList());
    setState(() => _dailyTasks = chosen);
  }

  void _onCelebrated(int streak) {
    final key = dayKey(DateTime.now());
    prefs.setString('celebrated_day:$_uid', key);
    _celebrated = key; // no rebuild needed: the card already showed it
  }

  Future<_Data> _load() async {
    final now = DateTime.now();
    final [profile, latest] = await Future.wait([
      supabase.from('profiles').select('display_name, sex, birth_year, height_cm, weight_kg, waist_cm, equipment, equipment_items, injuries, days_per_week, session_minutes, water_target_ml, avatar').eq('id', _uid).single(),
      supabase.from('generated_plans').select('plan, input').eq('user_id', _uid).order('created_at', ascending: false).limit(1).single(),
    ]);
    final plan = latest['plan'] as _Json;
    if (profile['avatar'] == 'photo') profile['avatar_url'] = await avatarPhotoUrl(_uid);
    final goals = (plan['goals'] as List).cast<_Json>();
    final results = await Future.wait<Object?>([
      supabase.from('curriculum_levels').select('goal, level, title, practice, advance_when, coach_recommended, source').inFilter('goal', [for (final g in goals) g['goal']]),
      _proteinSources(plan),
      supabase.from('workout_logs').select('performed_on, duration_min').eq('user_id', _uid).gte('performed_on', _iso(_monday(now).subtract(const Duration(days: 49)))),
      supabase.from('goal_levels').select('goal').eq('user_id', _uid),
      supabase.from('water_intake').select('taken_at, ml').eq('user_id', _uid).gte('taken_at', _day(now).subtract(const Duration(days: 29)).toUtc().toIso8601String()),
      supabase.from('habit_logs').select('day, habit').eq('user_id', _uid).gte('day', _iso(_day(now).subtract(const Duration(days: 29)))),
      loadSwaps(_iso(now)), // never fails: an empty map shows the session as planned
      loadLighter(_iso(now)), // never fails: false keeps the planned doses
      loadSessionMoves(_iso(_monday(now)), _iso(_monday(now).add(const Duration(days: 6)))), // never fails: empty keeps the plan's days
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
      swaps: results[6] as Map<String, String>,
      lighter: results[7] as bool,
      moves: results[8] as List<(int, int)>,
    );
    _scheduleReminders(_loaded!);
    return _loaded!;
  }

  /// Re-arms reminders for the current plan. Never blocks or breaks the dashboard.
  Future<void> _scheduleReminders(_Data d) async {
    try {
      // Training days, plus a rest day that carries an add-on session of its own (week_schedule.dart).
      final sessions = reminderSessions(
          weekPlan(d.plan, sessionMinutes: d.input['sessionMinutes'] as int?, estimate: sessionEstimator(d.tier, kitOf(d.profile))));
      // The user's own reminders are optional: a failed read (or the table not there yet) applies the built-in ones
      // and leaves any scheduled custom ones as they are (null), never cancelling them as if they were deleted.
      final custom = await loadCustomReminders().then<List<CustomReminder>?>((l) => l, onError: (Object _) => null);
      await Reminders.apply(await loadReminderPrefs(), sessions, custom: custom, inApp: _inApp);
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
  /// Returns whether the change was saved. Logging is idempotent: a day already logged elsewhere (the calendar) is
  /// not logged twice.
  Future<bool> _toggleToday(String goal, int? minutes) async {
    if (_saving) return false;
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
        final existing = await supabase.from('workout_logs').select('id').eq('user_id', _uid).eq('performed_on', _iso(today)).limit(1);
        if (existing.isEmpty) {
          await supabase.from('workout_logs').insert({'user_id': _uid, 'performed_on': _iso(today), 'goal': goal, 'duration_min': minutes});
        }
        setState(() {
          _logged = {..._logged, today};
          if (minutes != null) _minutes = {..._minutes, today: minutes};
        });
      }
      return true;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection and try again.')));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Menu navigation: a fresh start, so the back stack is cleared.
  void _go(_Tab tab) {
    _back.clear();
    _show(tab);
  }

  /// Opens [tab] from the current page; back (arrow or gesture) returns here.
  void _open(_Tab tab) {
    if (tab == _tab) return;
    _back.add(_tab);
    _show(tab);
  }

  void _pop() => _show(_back.removeLast());

  void _show(_Tab tab) {
    if (tab == _tab) return setState(() {});
    setState(() {
      // Coming home picks up anything logged on the other tabs.
      if (tab == _Tab.home) _data = _load();
      _tab = tab;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // The system back gesture returns to the dashboard instead of leaving the app.
        canPop: _tab == _Tab.home && _back.isEmpty,
        onPopInvokedWithResult: (didPop, _) => didPop ? null : (_back.isNotEmpty ? _pop() : _go(_Tab.home)),
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
            child: KeyedSubtree(key: ValueKey(_tab), child: _BackScope(onBack: _back.isEmpty ? null : _pop, child: _body(context))),
          ),
        ),
      );

  Widget _body(BuildContext context) {
    return switch (_tab) {
      _Tab.home => _home(context),
      _Tab.glossary => const _GlossaryScreen(),
      _Tab.settings => _AppSettingsScreen(onOpen: _open),
      // The calculators work without the plan, but prefill from the profile once it has loaded (keyed, so the
      // fields refill when the load finishes after the tab was opened).
      _Tab.bmi || _Tab.bodyFat => FutureBuilder(
          future: _data,
          builder: (context, snap) {
            final p = snap.data?.profile ?? const <String, dynamic>{};
            final key = ValueKey(snap.hasData);
            return _tab == _Tab.bmi
                ? BmiScreen(key: key, leading: const _ShellMenu(), heightCm: p['height_cm'] as num?, weightKg: p['weight_kg'] as num?, age: p['birth_year'] == null ? null : DateTime.now().year - (p['birth_year'] as int))
                : WaistScreen(key: key, leading: const _ShellMenu(), heightCm: p['height_cm'] as num?, waistCm: p['waist_cm'] as num?);
          },
        ),
      _Tab.handbook => const HandbookScreen(leading: _ShellMenu()),
      _Tab.library => const ExerciseLibraryScreen(leading: _ShellMenu()),
      _ => _withData((d) => switch (_tab) {
            _Tab.workout => _WorkoutScreen(
                data: d,
                logged: _logged,
                onEditGoals: () => _editGoals(context, d.plan),
                onToggleToday: _toggleToday,
                onPlanChanged: () => setState(() { _data = _load(); }),
              ),
            _Tab.diet => _DietScreen(data: d),
            _Tab.protocol => _ProtocolScreen(data: d, onEditGoals: () => _editGoals(context, d.plan), onSaved: () => setState(() { _data = _load(); })),
            _Tab.profile => _ProfileScreen(
                data: d,
                onOpen: _open,
                onSignOut: signOutAndClearReminders,
                onDelete: () => _confirmDelete(context),
                onEditDetails: () => _editDetails(context, d),
                onAvatarChanged: () => setState(() { _data = _load(); }),
              ),
            _Tab.hydration => _HydrationScreen(data: d),
            _Tab.habits => _HabitsScreen(data: d, logged: _logged),
            _Tab.calendar => _CalendarScreen(plan: d.plan),
            _Tab.progress => _ProgressScreen(data: d),
            _Tab.foods => _FoodsScreen(data: d),
            _Tab.foodDiary => FoodDiaryScreen(
                leading: const _ShellMenu(),
                kcalTarget: (d.plan['nutrition'] as _Json?)?['energyKcal'] as num?,
                proteinTarget: (d.plan['nutrition'] as _Json?)?['proteinG'] as num?,
              ),
            _Tab.reminders => _SettingsScreen(onRemindersChanged: () => _scheduleReminders(d)),
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
            FutureBuilder(
              future: _data,
              builder: (context, snap) => IconButton(
                tooltip: 'Profile',
                onPressed: () => _go(_Tab.profile),
                icon: snap.data == null
                    ? const Icon(LvIcons.userCircle, size: 24)
                    : UserAvatar(name: snap.data!.name ?? '', avatar: snap.data!.profile['avatar'] as String?, photoUrl: snap.data!.profile['avatar_url'] as String?, size: 30),
              ),
            ),
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
                  OutlinedButton(onPressed: () => setState(() { _data = _load(); }), child: const Text('Try again')),
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
              layout: _layout,
              dailyTasks: _dailyTasks,
              lastCelebrated: _celebrated,
              onCustomise: _customise,
              onChooseTasks: _chooseTasks,
              onCelebrated: _onCelebrated,
            );
          },
        ),
      );

  bool _addingWater = false; // one glass at a time: a double tap must not log two

  /// One glass from the dashboard tile.
  Future<void> _addWater() async {
    if (_addingWater) return;
    _addingWater = true;
    HapticFeedback.mediumImpact();
    try {
      await supabase.from('water_intake').insert({'ml': 250});
      if (mounted) setState(() { _data = _load(); });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection.')));
    } finally {
      _addingWater = false;
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
    if (ok != true) return;
    if (height == null || weight == null || height < bmiHeightCm.min || height > bmiHeightCm.max || weight < bmiWeightKg.min || weight > bmiWeightKg.max) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
            content: Text('Not saved: height must be ${bmiHeightCm.min} to ${bmiHeightCm.max} cm and weight ${bmiWeightKg.min} to ${bmiWeightKg.max} kg.')));
      }
      return;
    }
    try {
      await supabase.from('profiles').update({'display_name': display.isEmpty ? null : display, 'height_cm': height, 'weight_kg': weight}).eq('id', _uid);
      await supabase.functions.invoke('generate-plan');
      if (mounted) setState(() { _data = _load(); });
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
    if (updated == true && mounted) setState(() { _data = _load(); });
  }

  Future<void> _confirmDelete(BuildContext context) => confirmAndDeleteAccount(context);
}

// ---------------------------------------------------------------- the bento

/// Renders the dashboard body from a plan without Supabase, so layout can be tested at phone size.
@visibleForTesting
Widget dashboardBentoForTest(Map<String, dynamic> plan, {Set<DateTime> logged = const {}, List<CardPref>? layout, Set<String>? dailyTasks, ValueChanged<int>? onCelebrated}) => _Bento(
      data: (name: 'Asha Rao', profile: const {}, plan: plan, input: const {'sessionMinutes': 45}, levels: const {}, proteins: const [], tier: Tier.home, assessed: const {}, water: const {}, habits: const {}, swaps: const {}, lighter: false, moves: const []),
      logged: logged,
      minutes: {for (final d in logged) d: 45},
      saving: false,
      onToggleToday: (_, _) async => true,
      onCheckLevel: () {},
      onOpen: (_) {},
      onAddWater: () {},
      layout: layout ?? defaultLayout,
      dailyTasks: dailyTasks ?? defaultDailyTasks,
      lastCelebrated: null,
      onCustomise: () {},
      onChooseTasks: () {},
      onCelebrated: onCelebrated ?? (_) {},
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
    required this.layout,
    required this.dailyTasks,
    required this.lastCelebrated,
    required this.onCustomise,
    required this.onChooseTasks,
    required this.onCelebrated,
  });
  final List<CardPref> layout;
  final Set<String> dailyTasks;
  final String? lastCelebrated; // day the daily-goal celebration last played on this device
  final VoidCallback onCustomise, onChooseTasks;
  final ValueChanged<int> onCelebrated; // today's streak, once the celebration is shown
  final _Data data;
  final Set<DateTime> logged;
  final Map<DateTime, int> minutes;
  final bool saving;
  final Future<bool> Function(String goal, int? minutes) onToggleToday;
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
    // A session moved with Levlofit AI shows on its new day and leaves a rest day behind (swaps.dart).
    final sessionDay = sessionDayFor(now.weekday, dayGoal.keys.toSet(), data.moves);
    final todayGoal = dayGoal[sessionDay] ?? dayGoal[now.weekday] ?? goals.first;
    final isTrainingDay = sessionDay != null;
    final sessionMinutes = data.input['sessionMinutes'] as int?;
    final level = todayGoal['startLevel'] as int;
    // Which session of this goal it is, so A and B alternate through the week.
    final nth = [for (var d = 1; d < (sessionDay ?? now.weekday); d++) if (dayGoal[d]?['goal'] == todayGoal['goal']) d].length;
    final planned = sessionIds(todayGoal['kind'] as String? ?? 'strength', data.tier, level, nth, goal: todayGoal['goal'] as String?, kit: kitOf(data.profile));
    // Levlofit AI may offer swaps for today's planned moves (confirmed ones replace them), or a move of today's own
    // session to a later free day this week.
    final freeLater = [
      for (var d = now.weekday + 1; d <= 7; d++)
        if (!dayGoal.containsKey(d) && !data.moves.any((m) => m.$2 == d)) _iso(monday.add(Duration(days: d - 1))),
    ];
    todaySession = isTrainingDay ? (day: _iso(now), ids: planned, restDays: sessionDay == now.weekday ? freeLater : const <String>[]) : null;
    final ids = applySwaps(planned, data.swaps);
    // Add-on blocks today: joined to today's session, or today's own short session on a rest day (week_schedule.dart).
    final week = weekPlan(plan, sessionMinutes: sessionMinutes, estimate: sessionEstimator(data.tier, kitOf(data.profile)));
    final ownAddOn = isTrainingDay ? null : week.addOns.where((a) => a.day == now.weekday).firstOrNull;
    final todayBlocks = blocksFor(week, now.weekday, data.tier, kitOf(data.profile), isTrainingDay ? ids : const []);
    final ownBlock = ownAddOn == null ? null : todayBlocks.first;
    final cardGoal = ownAddOn == null ? todayGoal : {...ownAddOn.session, 'name': '${ownAddOn.name} add-on', 'startLevel': ownBlock!.level};

    final first = (data.name ?? '').split(' ').first;
    final hello = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final review = ((plan['review'] as List?) ?? const []).cast<_Json>();
    final important = review.where((f) => f['level'] == 'stop' || f['level'] == 'change').toList();
    final habits = _habitList(data, logged, data.habits, data.water);
    final tasks = {for (final h in habits) h.$1: h.$5};

    Widget card(String id) => switch (id) {
          'rings' => _Rings(days: doneThisWeek, daysTarget: perWeek, minutes: minutesThisWeek, minutesTarget: moveTarget, streak: streak),
          'today' => _TodayCard(
              isTrainingDay: isTrainingDay || ownAddOn != null,
              goal: cardGoal,
              levelRow: data.levels[cardGoal['goal']],
              minutes: sessionMinutes,
              ids: ownBlock?.ids ?? ids,
              blocks: ownAddOn == null ? todayBlocks : const [],
              injury: data.profile['injuries'] as String?,
              lighter: data.lighter,
              done: logged.contains(today),
              saving: saving,
              // An add-on day logs its own length (the block and a warm-up), not the full session setting.
              onToggle: () => onToggleToday(cardGoal['goal'] as String, ownBlock == null ? sessionMinutes : ownBlock.minutes + 5),
            ),
          'rewards' => _RewardsCard(
              tasks: [for (final h in habits) if (dailyTasks.contains(h.$1)) (label: h.$3, done: h.$5(today))],
              streak: dailyStreak(tasks, dailyTasks, today),
              complete: dayComplete(tasks, dailyTasks, today),
              celebrate: shouldCelebrate(todayComplete: dayComplete(tasks, dailyTasks, today), lastCelebrated: lastCelebrated, today: today),
              onCelebrated: onCelebrated,
              onChoose: onChooseTasks,
            ),
          'week' => _WeekStrip(monday: monday, today: today, dayGoal: dayGoal, logged: logged, streak: streak),
          'hydration' => _HydrationTile(ml: data.water[today] ?? 0, target: waterTarget(data.profile, training: isTrainingDay), onAdd: onAddWater, onOpen: () => onOpen(_Tab.hydration)),
          'habits' => _HabitsTile(
              done: habits.where((h) => h.$5(today)).length,
              total: habits.length,
              week: [for (var i = 6; i >= 0; i--) habits.where((h) => h.$5(today.subtract(Duration(days: i)))).length],
              onOpen: () => onOpen(_Tab.habits),
            ),
          'fuel' => _FuelTile(plan: plan, proteins: data.proteins),
          'body' => _BodyTile(plan: plan),
          _ => const SizedBox.shrink(),
        };

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
            for (final row in layoutRows(layout)) ...[
              if (row.length == 2) _Pair(left: card(row[0]), right: card(row[1])) else card(row.single),
              // Next steps and safety alerts are not customisable: they sit right under today's session.
              if (row.length == 1 && row.first == 'today') ...[
                if (!data.assessed.contains(goals.first['goal']) && data.levels.containsKey(goals.first['goal'])) ...[
                  const SizedBox(height: 12),
                  _LevelPrompt(goalName: (goals.first['name'] ?? goals.first['goal']) as String, onTap: onCheckLevel),
                ],
                if (important.isNotEmpty) ...[const SizedBox(height: 12), _ReviewRow(review: review, important: important)],
              ],
              const SizedBox(height: 12),
            ],
            Center(
              child: TextButton.icon(onPressed: onCustomise, icon: const Icon(Icons.tune, size: 18), label: const Text('Customise dashboard')),
            ),
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
    this.blocks = const [],
    this.injury,
    this.lighter = false,
    required this.done,
    required this.saving,
    required this.onToggle,
  });
  final bool isTrainingDay, done, saving, lighter;
  final _Json goal;
  final _Json? levelRow;
  final int? minutes;
  final List<String> ids;
  final List<AddOnBlock> blocks; // today's add-on blocks after the main session
  final String? injury; // the user's injury note, for the injury check
  final Future<bool> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = (goal['name'] ?? goal['goal']) as String;
    final level = goal['startLevel'] as int;
    final meta = ['Level $level', if (levelRow != null) levelRow!['title'] as String, if (minutes != null) '$minutes min'].join('  ·  ');
    void start() => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => SessionScreen(title: name, ids: ids, level: level, blocks: blocks, done: done, onFinish: done ? null : onToggle, injury: injury, sessionMinutes: minutes, lighter: lighter)),
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
        MoveStrip(ids: ids, level: level, tile: 112, injury: injury),
        for (final b in blocks) ...[
          const SizedBox(height: 12),
          Text(blockSummary(b).toUpperCase(), style: monoLabel(context)),
          if (b.ids.isNotEmpty) ...[
            const SizedBox(height: 8),
            MoveStrip(ids: b.ids, level: b.level, tile: 88, injury: injury),
          ],
        ],
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
        // Stacked on narrow phones (360 dp). Each tile gets its intrinsic height: tiles such as Fuel use a Spacer, which
        // has no height to fill in an unbounded scroll column and failed layout at 360 dp (found 2026-10-17).
        builder: (context, box) => box.maxWidth < 330
            ? Column(children: [IntrinsicHeight(child: left), const SizedBox(height: 12), IntrinsicHeight(child: right)])
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
                    // One word on one line, shrunk to fit: a seventh of a phone is narrower than "Strength" at 10 pt,
                    // which broke as "Strengt / h" on a 411 dp phone (2026-10-17).
                    SizedBox(
                      height: 28,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            goal == null ? '' : ((goal['name'] ?? goal['goal']) as String).split(' ').first,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            style: t.bodySmall?.copyWith(fontSize: 10, height: 1.2, color: c.onSurfaceVariant),
                          ),
                        ),
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

// ---------------------------------------------------------------- daily goal

/// The day's chosen tasks, the streak, and a one-off celebration when the last task is done.
class _RewardsCard extends StatefulWidget {
  const _RewardsCard({required this.tasks, required this.streak, required this.complete, required this.celebrate, required this.onCelebrated, required this.onChoose});
  final List<({String label, bool done})> tasks;
  final int streak;
  final bool complete, celebrate;
  final ValueChanged<int> onCelebrated;
  final VoidCallback onChoose;

  @override
  State<_RewardsCard> createState() => _RewardsCardState();
}

class _RewardsCardState extends State<_RewardsCard> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _maybeCelebrate();
  }

  @override
  void didUpdateWidget(_RewardsCard old) {
    super.didUpdateWidget(old);
    _maybeCelebrate();
  }

  void _maybeCelebrate() {
    if (!widget.celebrate || _shown) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      widget.onCelebrated(widget.streak);
      final overlay = Overlay.of(context);
      late OverlayEntry entry;
      entry = OverlayEntry(builder: (_) => _ReminderBanner(title: 'Daily goal done', body: celebrationLine(widget.streak), onDone: () => entry.remove()));
      overlay.insert(entry);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final done = widget.tasks.where((x) => x.done).length;
    return _Tile(
      onTap: widget.onChoose,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('DAILY GOAL', trailing: Text('Change', style: t.bodySmall?.copyWith(color: c.primary))),
        const SizedBox(height: 10),
        Row(children: [
          AnimatedScale(
            scale: widget.complete ? 1.15 : 1,
            duration: motion(context, 420),
            curve: spring,
            child: Icon(LvIcons.flame, size: 30, color: widget.streak > 0 ? c.primary : c.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          CountUp('${widget.streak}', style: monoNumber(context, size: 26)),
          const SizedBox(width: 6),
          Expanded(child: Text('day streak', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))),
          Flexible(
            child: Text(widget.complete ? 'Done today' : '$done of ${widget.tasks.length} today',
                overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(color: widget.complete ? c.primary : null)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final x in widget.tasks)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(x.done ? LvIcons.checkCircle : LvIcons.minus, size: 16, color: x.done ? c.primary : c.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(child: Text(x.label, style: t.bodySmall)),
            ]),
        ]),
        if (widget.tasks.isEmpty) Text('Pick the tasks that make a good day for you.', style: t.bodySmall),
        const SizedBox(height: 6),
        Text('Planned rest days count as done.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ]),
    );
  }
}

extension on Set<String> {
  Set<String> ifEmpty(Set<String> fallback) => isEmpty ? {...fallback} : this;
}

/// Pick the tasks that make up the daily goal. At least one.
class _DailyGoalSheet extends StatefulWidget {
  const _DailyGoalSheet({required this.habits, required this.chosen});
  final List<_Habit> habits;
  final Set<String> chosen;

  @override
  State<_DailyGoalSheet> createState() => _DailyGoalSheetState();
}

class _DailyGoalSheetState extends State<_DailyGoalSheet> {
  late final _on = {...widget.chosen};

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your daily goal', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('A day counts when every task you pick is done. Pick what is realistic most days.', style: t.bodySmall),
          const SizedBox(height: 12),
          for (final h in widget.habits)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _on.contains(h.$1),
              title: Text(h.$3),
              subtitle: h.$1 == 'train' ? const Text('Planned rest days count as done') : null,
              onChanged: (v) => setState(() => v == true ? _on.add(h.$1) : _on.remove(h.$1)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _on.isEmpty ? null : () => Navigator.pop(context, _on), child: Text(_on.isEmpty ? 'Pick at least one' : 'Save')),
          ),
        ]),
      ),
    );
  }
}

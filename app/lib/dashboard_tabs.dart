// Tabs added after the first menu: Hydration, Habits, Food library, Reminders, and the level check.
// A part of dashboard.dart so they share its page frame, tiles and plan helpers.
part of 'dashboard.dart';

/// Renders a tab from a plan without Supabase calls succeeding, so layouts can be tested at phone size.
@visibleForTesting
Widget tabForTest(String tab, Map<String, dynamic> plan, {VoidCallback? onBack, List<(int, int)> moves = const []}) =>
    _BackScope(onBack: onBack, child: _tabForTest(tab, plan, moves));

Widget _tabForTest(String tab, Map<String, dynamic> plan, List<(int, int)> moves) {
  final d = (
    name: 'Asha Rao',
    profile: const <String, dynamic>{'sex': 'female', 'birth_year': 1995, 'height_cm': 160, 'weight_kg': 58, 'days_per_week': 3, 'session_minutes': 45, 'equipment': 'home'},
    plan: plan,
    input: const <String, dynamic>{'sessionMinutes': 45},
    levels: const <String, _Json>{},
    proteins: const <_Json>[],
    tier: Tier.home,
    assessed: const <String>{},
    water: const <DateTime, int>{},
    habits: const <(DateTime, String)>{},
    swaps: const <String, String>{},
    lighter: false,
    moves: moves,
  );
  return switch (tab) {
    'hydration' => _HydrationScreen(data: d),
    'habits' => _HabitsScreen(data: d, logged: const {}),
    'foods' => _FoodsScreen(data: d),
    'reminders' => _SettingsScreen(onRemindersChanged: () {}),
    'settings' => _AppSettingsScreen(onOpen: (_) {}),
    'workout' => _WorkoutScreen(data: d, logged: const {}, onEditGoals: () {}, onToggleToday: (_, _) async => true, onPlanChanged: () {}),
    _ => throw ArgumentError(tab),
  };
}

// ---------------------------------------------------------------- hydration

/// Daily drinks target in ml. The user's own number from the protocol when set. Otherwise EFSA (2010): adequate
/// total water is 2.5 L a day for men and 2.0 L for women, about 80% of it from drinks; on training days add about
/// 6 ml per kg, since ACSM (Sawka 2007) advises 5 to 7 ml/kg in the hours before exercise.
int waterTarget(Map<String, dynamic> profile, {bool training = false}) {
  final own = profile['water_target_ml'] as int?;
  if (own != null) return own;
  final base = profile['sex'] == 'male' ? 2000 : 1600;
  final kg = (profile['weight_kg'] as num?)?.toDouble();
  return training && kg != null ? base + (kg * 6 / 50).round() * 50 : base;
}

typedef _Habit = (String id, IconData icon, String label, String why, bool Function(DateTime day) doneOn, bool manual);

/// The daily habits and how each is judged on a day. Shared by the Habits tab and the dashboard tile.
List<_Habit> _habitList(_Data data, Set<DateTime> logged, Set<(DateTime, String)> done, Map<DateTime, int> water) {
  final p = data.profile;
  final age = p['birth_year'] == null ? null : DateTime.now().year - (p['birth_year'] as int);
  final protein = ((data.plan['nutrition'] as _Json)['proteinG'] as num).round();
  final planned = _schedule(data.plan);
  final todayTarget = waterTarget(p, training: planned.containsKey(DateTime.now().weekday));
  return [
    ('train', LvIcons.barbell, 'Train or rest as planned', 'A logged session, or a planned rest day', (d) => logged.contains(d) || !planned.containsKey(d.weekday), false),
    ('water', LvIcons.drop, 'Drink ${(todayTarget / 1000).toStringAsFixed(1)} L', 'Counted from Hydration', (d) => (water[d] ?? 0) >= waterTarget(p, training: planned.containsKey(d.weekday)), false),
    ('protein', LvIcons.forkKnife, 'Eat $protein g protein', 'Your plan target', (d) => done.contains((d, 'protein')), true),
    ('sleep', LvIcons.brain, 'Sleep 7 hours or more', 'AASM and SRS consensus, 2015', (d) => done.contains((d, 'sleep')), true),
    ('steps', LvIcons.personSimpleRun, 'Walk ${age != null && age >= 60 ? '6,000' : '8,000'}+ steps', 'Where the benefit levels off (Paluch 2022)', (d) => done.contains((d, 'steps')), true),
    ('mobility', LvIcons.sparkle, 'Mobility or stretching', 'A few minutes most days', (d) => done.contains((d, 'mobility')), true),
    ('no_junk', LvIcons.checkCircle, 'Skip sugary drinks', 'Swap for water, chaas or lime water', (d) => done.contains((d, 'no_junk')), true),
  ];
}

class _HydrationScreen extends StatefulWidget {
  const _HydrationScreen({required this.data});
  final _Data data;

  @override
  State<_HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<_HydrationScreen> {
  List<_Json>? _drinks; // last 7 days, newest first
  bool _busy = false;

  String get _uid => supabase.auth.currentUser!.id;
  int get _target => waterTarget(widget.data.profile, training: _schedule(widget.data.plan).containsKey(DateTime.now().weekday));

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final since = _day(DateTime.now()).subtract(const Duration(days: 6));
      final rows = await supabase.from('water_intake').select('id, taken_at, ml').eq('user_id', _uid).gte('taken_at', since.toUtc().toIso8601String()).order('taken_at', ascending: false);
      if (mounted) setState(() => _drinks = rows);
    } catch (_) {
      if (mounted) setState(() => _drinks = const []);
    }
  }

  Future<void> _add(int ml) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final row = await supabase.from('water_intake').insert({'ml': ml}).select('id, taken_at, ml').single();
      if (mounted) setState(() => _drinks = [row, ...?_drinks]);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(_Json row) async {
    try {
      await supabase.from('water_intake').delete().eq('id', row['id'] as int);
      if (mounted) setState(() => _drinks = [...?_drinks]..remove(row));
    } catch (_) {}
  }

  Future<void> _custom() async {
    final field = TextEditingController();
    final ml = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('How much did you drink?'),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(field.text);
              if (v != null && v >= 50 && v <= 2000) Navigator.pop(d, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    field.dispose();
    if (ml != null) _add(ml);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final drinks = _drinks ?? const <_Json>[];
    final today = _day(DateTime.now());
    DateTime dayOf(_Json r) => _day(DateTime.parse(r['taken_at'] as String).toLocal());
    final todays = [for (final r in drinks) if (dayOf(r) == today) r];
    final total = todays.fold<int>(0, (s, r) => s + (r['ml'] as int));
    final week = [
      for (var i = 6; i >= 0; i--) drinks.where((r) => dayOf(r) == today.subtract(Duration(days: i))).fold<int>(0, (s, r) => s + (r['ml'] as int)),
    ];
    return _Page(
      eyebrow: 'HYDRATION',
      title: 'Water today',
      children: [
        _WaterGlass(ml: total, target: _target),
        const SizedBox(height: 14),
        Row(children: [
          for (final ml in const [150, 250, 500]) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _add(ml),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: FittedBox(child: Text('+$ml ml')),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : _custom,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: const FittedBox(child: Text('Other')),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        _Tile(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Label('LAST 7 DAYS', trailing: Text('TARGET ${(_target / 1000).toStringAsFixed(1)} L', style: monoLabel(context))),
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: _Grow(
                builder: (g) => CustomPaint(
                  painter: _WeeksPainter(weeks: [for (final ml in week) (ml / 250).round()], target: (_target / 250).round(), grow: g, bar: c.primary, track: c.surfaceContainerHighest, line: c.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Bars in glasses of 250 ml. The dashed line is your daily target.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
        ),
        if (todays.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Tile(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('TODAY'),
              for (final r in todays)
                Row(children: [
                  Icon(LvIcons.drop, size: 16, color: c.primary),
                  const SizedBox(width: 10),
                  Text('${r['ml']} ml', style: monoNumber(context, size: 15)),
                  const SizedBox(width: 10),
                  Text(TimeOfDay.fromDateTime(DateTime.parse(r['taken_at'] as String).toLocal()).format(context), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  const Spacer(),
                  IconButton(tooltip: 'Remove', icon: Icon(LvIcons.x, size: 16, color: c.onSurfaceVariant), onPressed: () => _remove(r)),
                ]),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Training hard or in heat? Weigh yourself before and after: losing more than 2% of body weight means drink more next time. '
          'Sources: EFSA dietary reference values for water (2010); ACSM exercise and fluid replacement (Sawka 2007).',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A glass that fills with a gently moving surface as the day's water adds up.
class _WaterGlass extends StatefulWidget {
  const _WaterGlass({required this.ml, required this.target});
  final int ml, target;

  @override
  State<_WaterGlass> createState() => _WaterGlassState();
}

class _WaterGlassState extends State<_WaterGlass> with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = (widget.ml / widget.target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(30), border: Border.all(color: c.outline)),
      child: Container(
        height: 220,
        decoration: BoxDecoration(color: dark ? c.surface : graphite, borderRadius: BorderRadius.circular(25)),
        clipBehavior: Clip.antiAlias,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fill),
          duration: motion(context, 900),
          curve: spring,
          builder: (_, v, _) => AnimatedBuilder(
            animation: _wave,
            builder: (_, _) => CustomPaint(
              painter: _WavePainter(level: v, phase: MediaQuery.disableAnimationsOf(context) ? 0 : _wave.value, color: c.primary),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TODAY', style: monoLabel(context).copyWith(color: cloud.withValues(alpha: 0.65))),
                  const Spacer(),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    CountUp('${widget.ml}', style: monoNumber(context, size: 48).copyWith(color: cloud)),
                    const SizedBox(width: 8),
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('of ${widget.target} ml', style: t.bodySmall?.copyWith(color: cloud.withValues(alpha: 0.75)))),
                  ]),
                  Text(fill >= 1 ? 'Target reached. Keep sipping with meals.' : '${widget.target - widget.ml} ml to go', style: t.bodyMedium?.copyWith(color: cloud)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.level, required this.phase, required this.color});
  final double level, phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    final top = size.height * (1 - level);
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 4) {
      path.lineTo(x, top + 6 * math.sin(2 * math.pi * (x / size.width + phase)));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.level != level || old.phase != phase;
}

// ---------------------------------------------------------------- habits

class _HabitsScreen extends StatefulWidget {
  const _HabitsScreen({required this.data, required this.logged});
  final _Data data;
  final Set<DateTime> logged;

  @override
  State<_HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<_HabitsScreen> {
  Set<(DateTime, String)> _done = {};
  Map<DateTime, int> _water = {};
  bool _loading = true;

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final since = _day(DateTime.now()).subtract(const Duration(days: 6));
    try {
      final [habits, water] = await Future.wait([
        supabase.from('habit_logs').select('day, habit').eq('user_id', _uid).gte('day', _iso(since)),
        supabase.from('water_intake').select('taken_at, ml').eq('user_id', _uid).gte('taken_at', since.toUtc().toIso8601String()),
      ]);
      final w = <DateTime, int>{};
      for (final r in water) {
        final d = _day(DateTime.parse(r['taken_at'] as String).toLocal());
        w[d] = (w[d] ?? 0) + (r['ml'] as int);
      }
      if (!mounted) return;
      setState(() {
        _done = {for (final r in habits) (DateTime.parse(r['day'] as String), r['habit'] as String)};
        _water = w;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String habit) async {
    final key = (_day(DateTime.now()), habit);
    final on = _done.contains(key);
    Set<(DateTime, String)> flip(bool add) => add ? {..._done, key} : ({..._done}..remove(key));
    HapticFeedback.selectionClick();
    setState(() => _done = flip(!on));
    try {
      if (on) {
        await supabase.from('habit_logs').delete().eq('user_id', _uid).eq('day', _iso(key.$1)).eq('habit', habit);
      } else {
        await supabase.from('habit_logs').insert({'day': _iso(key.$1), 'habit': habit});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _done = flip(on));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your connection.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final today = _day(DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final habits = _habitList(widget.data, widget.logged, _done, _water);
    final doneToday = habits.where((h) => h.$5(today)).length;

    return _Page(
      eyebrow: 'HABITS',
      title: 'Small things, every day',
      subtitle: 'Habits take about two months to feel automatic, and one missed day does not undo them (Lally 2010).',
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.outline)),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? c.surface : graphite, borderRadius: BorderRadius.circular(23)),
            child: Row(children: [
              SizedBox(
                width: 88,
                height: 88,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: doneToday / habits.length),
                  duration: motion(context, 900),
                  curve: spring,
                  builder: (_, v, _) => CustomPaint(painter: _RingsPainter(outer: v, inner: 0, outerColor: c.primary, innerColor: Colors.transparent, track: cloud.withValues(alpha: 0.12))),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TODAY', style: monoLabel(context).copyWith(color: cloud.withValues(alpha: 0.65))),
                  Text('$doneToday of ${habits.length}', style: monoNumber(context, size: 32).copyWith(color: cloud)),
                  Text(doneToday == habits.length ? 'A full day. Well done.' : 'Tick them off as you go.', style: t.bodySmall?.copyWith(color: cloud.withValues(alpha: 0.75))),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        for (final (id, icon, label, why, doneOn, manual) in habits) ...[
          _Tile(
            onTap: manual ? () => _toggle(id) : null,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(children: [
              Row(children: [
                AnimatedContainer(
                  duration: motion(context, 220),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: doneOn(today) ? c.primary : c.surface, shape: BoxShape.circle, border: Border.all(color: doneOn(today) ? c.primary : c.outline, width: 1.5)),
                  child: Icon(doneOn(today) ? LvIcons.check : icon, size: 17, color: doneOn(today) ? c.onPrimary : c.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: t.titleMedium?.copyWith(fontSize: 15)),
                    Text(manual ? why : '$why  ·  automatic', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              // The last 7 days, oldest first.
              Row(children: [
                const SizedBox(width: 46),
                for (final d in days) ...[
                  Expanded(
                    child: Column(children: [
                      Container(height: 6, decoration: BoxDecoration(color: doneOn(d) ? c.primary : c.surfaceContainerHighest, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 3),
                      Text(_days[d.weekday - 1].substring(0, 1), style: monoLabel(context).copyWith(fontSize: 9, color: d == today ? c.onSurface : null)),
                    ]),
                  ),
                  if (d != today) const SizedBox(width: 4),
                ],
              ]),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- food library

class _FoodsScreen extends StatefulWidget {
  const _FoodsScreen({required this.data});
  final _Data data;

  @override
  State<_FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<_FoodsScreen> {
  final _search = TextEditingController();
  late String _diet = (widget.data.input['diet'] as String?) ?? 'vegetarian';
  bool _hideAllergens = true;
  String? _group; // Protein, Fibre, Carbs, Fats; null for all
  List<_Json>? _rows;
  int _query = 0; // drops answers the user has already moved past

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final mine = ++_query;
    final food = widget.data.plan['nutrition'] as _Json;
    // The chosen diet's exclusions, never beef or pork, and (optionally) the user's own allergens from the plan.
    final ownDiet = _dietExcludes[(widget.data.input['diet'] as String?) ?? 'vegetarian'] ?? const <String>{};
    final allergens = {for (final t in (food['excludedFoodTags'] as List).cast<String>()) if (!ownDiet.contains(t)) t};
    final excluded = {'beef', 'pork', ...?_dietExcludes[_diet], if (_hideAllergens) ...allergens}.toList();
    final custom = _hideAllergens ? ((food['customExclusions'] as List?) ?? const []).cast<String>() : const <String>[];
    try {
      final rows = await supabase
          .from('foods')
          .select('code, name, name_hi, food_group, tags, kcal, protein_g, fat_g, carb_g, fiber_g')
          .inFilter('code', [for (final f in libraryFoods) f.$1])
          .not('tags', 'ov', '{${excluded.join(',')}}');
      final byCode = {for (final r in rows) r['code'] as String: r};
      // Library order, with the everyday name and its group added.
      final shown = [
        for (final (code, label, group) in libraryFoods)
          if (byCode[code] case final r?) {...r, 'label': label, 'group': group},
      ];
      bool mentions(_Json f, String term) => '${f['label']} ${f['name']} ${f['name_hi'] ?? ''}'.toLowerCase().contains(term);
      if (mounted && mine == _query) setState(() => _rows = [for (final f in shown) if (!custom.any((t) => mentions(f, t.toLowerCase()))) f]);
    } catch (_) {
      if (mounted && mine == _query) setState(() => _rows = const []);
    }
  }

  void _show(_Json f) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    num v(String k) => (f[k] as num?) ?? 0;
    final macros = [('Protein', v('protein_g'), 4), ('Carbs', v('carb_g'), 4), ('Fat', v('fat_g'), 9)];
    final energy = macros.fold<num>(0, (s, m) => s + m.$2 * m.$3);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GOOD FOR ${(f['group'] as String).toUpperCase()}', style: monoLabel(context)),
            const SizedBox(height: 4),
            Text(f['label'] as String, style: t.titleLarge),
            if (f['name_hi'] != null) Text(f['name_hi'] as String, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${f['kcal'] ?? '-'}', style: monoNumber(context, size: 36)),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('kcal per 100 g', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))),
            ]),
            const SizedBox(height: 14),
            // Bars show each macro's share of the energy.
            for (final (label, grams, kcalPerG) in macros)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(width: 70, child: Text(label, style: t.bodyMedium)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: energy == 0 ? 0 : (grams * kcalPerG / energy).toDouble(), minHeight: 8),
                    ),
                  ),
                  SizedBox(width: 64, child: Text('${grams.toStringAsFixed(1)} g', textAlign: TextAlign.right, style: monoNumber(context, size: 14))),
                ]),
              ),
            if (f['fiber_g'] != null) Text('Fibre ${(f['fiber_g'] as num).toStringAsFixed(1)} g', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: 10),
            f['code'] == 'X001'
                ? Text('Per 100 g dry. Source: USDA FoodData Central, defatted soy flour, which soya chunks are made from.',
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))
                : FoodCredit(lead: 'Per 100 g. ', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final q = _search.text.trim().toLowerCase();
    final rows = _rows?.where((f) => (_group == null || f['group'] == _group) && matchesFoodQuery('${f['label']} ${f['name_hi'] ?? ''}', q)).toList();
    // Each group is ranked by what it is for, so the best sources sit on top.
    final key = switch (_group) { 'Fibre' => 'fiber_g', 'Carbs' => 'carb_g', 'Fats' => 'fat_g', _ => 'protein_g' };
    final unit = switch (_group) { 'Fibre' => 'fibre', 'Carbs' => 'carbs', 'Fats' => 'fat', _ => 'protein' };
    if (_group != null) rows?.sort((a, b) => ((b[key] as num?) ?? 0).compareTo((a[key] as num?) ?? 0));
    return _Page(
      eyebrow: 'FOOD LIBRARY',
      title: 'Foods that matter',
      subtitle: 'Everyday foods for protein, fibre, good carbs and healthy fats, per 100 g.',
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Search dal, paneer, ragi...', prefixIcon: Icon(LvIcons.magnifyingGlass, size: 20)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (id, label) in const [('vegan', 'Vegan'), ('vegetarian', 'Vegetarian'), ('eggitarian', 'Eggitarian'), ('non_vegetarian', 'Non-veg')])
            ChoiceChip(
              label: Text(label),
              selected: _diet == id,
              onSelected: (_) {
                setState(() => _diet = id);
                _run();
              },
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          FilterChip(
            label: const Text('Hide my allergens'),
            selected: _hideAllergens,
            onSelected: (v) {
              setState(() => _hideAllergens = v);
              _run();
            },
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in const [null, 'Protein', 'Fibre', 'Carbs', 'Fats'])
            ChoiceChip(label: Text(g ?? 'All'), selected: _group == g, onSelected: (_) => setState(() => _group = g)),
        ]),
        const SizedBox(height: 12),
        if (rows == null)
          const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
        else if (rows.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 24), child: EmptyFoodsText('Nothing matches. Try a simpler word.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)))
        else
          for (final f in rows)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _show(f),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f['label'] as String, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      Text([if (f['name_hi'] != null) f['name_hi'], f['group']].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${((f[key] as num?) ?? 0).toStringAsFixed(1)} g $unit', style: monoNumber(context, size: 15).copyWith(color: c.tertiary)),
                    Text('${f['kcal'] ?? '-'} kcal', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  ]),
                ]),
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------- reminders

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen({required this.onRemindersChanged});
  final VoidCallback onRemindersChanged;

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  ReminderPrefs? _prefs;
  List<CustomReminder>? _custom; // null while loading
  bool _customFailed = false;
  bool _prefsFailed = false;
  ReminderTiming? _timing; // null on the web or until known: nothing about timing is shown
  bool? _notifications; // null on the web or until known
  // Coming back from Android's Alarms & reminders page: read the answer and reschedule if it changed.
  late final _lifecycle = AppLifecycleListener(onResume: _checkTiming);

  Future<void> _checkTiming() async {
    // Read independently: a slow answer about one never holds back the other.
    Reminders.notificationsEnabled().then((n) {
      if (mounted && n != _notifications) setState(() => _notifications = n);
    });
    final t = await Reminders.timing();
    if (!mounted || t == _timing) return;
    final changed = _timing != null;
    setState(() => _timing = t);
    if (changed) widget.onRemindersChanged(); // exact <-> inexact: alarms are re-registered in the new mode
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
    _checkTiming();
    _loadPrefs();
    loadCustomReminders().then(
      (l) => mounted ? setState(() => _custom = l) : null,
      onError: (Object _) => mounted ? setState(() {
        _custom = const [];
        _customFailed = true;
      }) : null,
    );
  }

  /// Adds, edits or deletes one of the user's own reminders, then re-arms every reminder.
  Future<void> _edit(CustomReminder? r) async {
    final result = await showModalBottomSheet<Object>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => CustomReminderEditor(initial: r));
    if (result == null || !mounted) return;
    try {
      if (result == 'delete') {
        await deleteCustomReminder(r!.id!);
        setState(() => _custom = [for (final x in _custom!) if (x.id != r.id) x]);
      } else {
        await _store(result as CustomReminder);
      }
      widget.onRemindersChanged();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save that reminder.')));
    }
  }

  Future<void> _store(CustomReminder r) async {
    if (r.enabled && (_prefs?.enabled ?? false)) await Reminders.requestPermissionOnce();
    final saved = await saveCustomReminder(r);
    if (!mounted) return;
    setState(() => _custom = r.id == null ? [..._custom!, saved] : [for (final x in _custom!) x.id == saved.id ? saved : x]);
  }

  Future<void> _toggle(CustomReminder r, bool on) async {
    try {
      await _store((id: r.id, name: r.name, at: r.at, weekdays: r.weekdays, enabled: on));
      widget.onRemindersChanged();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save that reminder.')));
    }
  }

  /// A failed read shows an error, never the defaults: one tap on a default would save it over the real settings.
  void _loadPrefs() {
    if (_prefsFailed) setState(() => _prefsFailed = false); // also runs from initState, where setState is not allowed
    loadReminderPrefs().then(
      (p) => mounted ? setState(() => _prefs = p) : null,
      onError: (Object _) => mounted ? setState(() => _prefsFailed = true) : null,
    );
  }

  Future<void> _save(ReminderPrefs p) async {
    final before = _prefs;
    setState(() => _prefs = p);
    try {
      if (p.enabled) await Reminders.requestPermissionOnce();
      await saveReminderPrefs(p);
      widget.onRemindersChanged();
    } catch (_) {
      // Show what is really saved, not the change that failed.
      if (mounted) setState(() => _prefs = before);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your reminders.')));
    }
  }

  void _banner(String title, String body) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ReminderBanner(title: title, body: body, onDone: () => entry.remove()));
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final prefs = _prefs;
    ReminderPrefs with_({bool? enabled, Object? workout = _keep, Object? water = _keep, Object? weighIn = _keep}) => (
          enabled: enabled ?? prefs!.enabled,
          workout: identical(workout, _keep) ? prefs!.workout : workout as TimeOfDay?,
          waterEveryH: identical(water, _keep) ? prefs!.waterEveryH : water as int?,
          weighInWeekday: identical(weighIn, _keep) ? prefs!.weighInWeekday : weighIn as int?,
        );
    return _Page(
      eyebrow: 'REMINDERS',
      title: 'Your reminders',
      subtitle: 'Choose when Levlofit nudges you.',
      children: [
        _Tile(
          child: prefs == null
              ? (_prefsFailed
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('Your reminder settings could not be loaded. Check your connection.', style: t.bodySmall?.copyWith(color: c.error))),
                        TextButton(onPressed: _loadPrefs, child: const Text('Retry')),
                      ]),
                      // The phone's notification and timing switches do not depend on the saved settings, so they still show.
                      if (_notifications == false)
                        _NotificationsOffRow(onTurnOn: () async {
                          await Reminders.requestPermission();
                          await _checkTiming();
                        }),
                      if (_timing != null) _ExactTimingRow(timing: _timing!, onAllow: Reminders.requestExactTiming),
                    ])
                  : const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 2)))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: _Label('REMINDERS')),
                    Semantics(label: 'Reminders', child: Switch(value: prefs.enabled, onChanged: (on) => _save(with_(enabled: on)))),
                  ]),
                  if (kIsWeb)
                    Text('On the web, reminders appear inside the app while it is open. The phone app sends them even when Levlofit is closed.',
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  if (_notifications == false && prefs.enabled)
                    _NotificationsOffRow(onTurnOn: () async {
                      await Reminders.requestPermission();
                      await _checkTiming();
                    }),
                  if (_timing != null && prefs.enabled) _ExactTimingRow(timing: _timing!, onAllow: Reminders.requestExactTiming),
                  AnimatedOpacity(
                    opacity: prefs.enabled ? 1 : 0.4,
                    duration: motion(context, 200),
                    child: IgnorePointer(
                      ignoring: !prefs.enabled,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 14),
                        Text('Training days', style: t.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, children: [
                          ChoiceChip(label: const Text('Off'), selected: prefs.workout == null, onSelected: (_) => _save(with_(workout: null))),
                          ActionChip(
                            avatar: const Icon(LvIcons.timer, size: 16),
                            label: Text(prefs.workout == null ? 'Pick a time' : prefs.workout!.format(context)),
                            onPressed: () async {
                              final at = await showTimePicker(context: context, initialTime: prefs.workout ?? const TimeOfDay(hour: 18, minute: 0));
                              if (at != null) _save(with_(workout: at));
                            },
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Text('Water, 9 am to 9 pm', style: t.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, children: [
                          for (final h in const [null, 1, 2, 3])
                            ChoiceChip(label: Text(h == null ? 'Off' : 'Every $h h'), selected: prefs.waterEveryH == h, onSelected: (_) => _save(with_(water: h))),
                        ]),
                        const SizedBox(height: 14),
                        Text('Weekly weigh-in, 8 am', style: t.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final d in const [null, 1, 2, 3, 4, 5, 6, 7])
                            ChoiceChip(label: Text(d == null ? 'Off' : _days[d - 1]), selected: prefs.weighInWeekday == d, onSelected: (_) => _save(with_(weighIn: d))),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await Reminders.requestPermission();
                        await Reminders.test(inApp: _banner);
                      },
                      child: const Text('Send a test reminder'),
                    ),
                  ),
                ]),
        ),
        // Timing experiment, test builds only: never in a release build, never touches saved reminders.
        if (!kReleaseMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
          const SizedBox(height: 14),
          const _AlarmClockTestTile(),
        ],
        const SizedBox(height: 14),
        _Tile(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('YOUR OWN'),
            const SizedBox(height: 6),
            if (_custom == null)
              const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 2))
            else if (_customFailed)
              Text('Your own reminders could not be loaded. Check your connection.', style: t.bodySmall?.copyWith(color: c.error))
            else ...[
              if (_custom!.isEmpty) Text('Add anything you want a nudge for: creatine, a stretch, a walk.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              if (prefs != null && !prefs.enabled && _custom!.isNotEmpty)
                Text('Reminders are off above, so these are paused too.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              for (final r in _custom!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.name),
                  subtitle: Text('${r.at.format(context)}  ·  ${describeDays(r.weekdays)}'),
                  onTap: () => _edit(r),
                  trailing: Semantics(label: 'Remind me: ${r.name}', child: Switch(value: r.enabled, onChanged: (on) => _toggle(r, on))),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(_custom!.length >= maxCustomReminders ? 'Limit of $maxCustomReminders reached' : 'Add a reminder'),
                onPressed: _custom!.length >= maxCustomReminders ? null : () => _edit(null),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

const _keep = Object(); // "leave this setting as it is" in _SettingsScreen

/// In-app reminder: a dark card that drops in from the top and leaves on its own after a few seconds.
class _ReminderBanner extends StatefulWidget {
  const _ReminderBanner({required this.title, required this.body, required this.onDone});
  final String title, body;
  final VoidCallback onDone;

  @override
  State<_ReminderBanner> createState() => _ReminderBannerState();
}

class _ReminderBannerState extends State<_ReminderBanner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _hide;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _hide = Timer(const Duration(seconds: 5), _leave);
  }

  Future<void> _leave() async {
    _hide?.cancel();
    if (!mounted || _gone) return;
    _gone = true;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final a = CurvedAnimation(parent: _c, curve: spring, reverseCurve: Curves.easeInCubic);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -1.4), end: Offset.zero).animate(a),
            child: FadeTransition(
              opacity: a,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Material(
                  color: graphite,
                  elevation: 12,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _leave,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(11)),
                          child: const Icon(LvIcons.timer, size: 19, color: graphite),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(widget.title, style: t.titleMedium?.copyWith(color: cloud)),
                            Text(widget.body, style: t.bodySmall?.copyWith(color: cloud.withValues(alpha: 0.75))),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- level check

/// Dashboard nudge until the main goal has a level check on record.
class _LevelPrompt extends StatelessWidget {
  const _LevelPrompt({required this.goalName, required this.onTap});
  final String goalName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Tile(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
          child: Icon(LvIcons.trendUp, size: 20, color: c.onPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Find your real level', style: t.titleMedium),
            Text('Two minutes on $goalName, so your plan starts exactly where you are.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
        ),
        Icon(LvIcons.caretRight, size: 16, color: c.onSurfaceVariant),
      ]),
    );
  }
}

/// Walks up the curriculum ladder from Level 0: at each level, can you already do what it takes to move up?
/// The first "not yet" is your level. Self-checks stop at Level 3; 4 and 5 need a tested pass (curriculum ch. 31).
class _LevelCheckScreen extends StatefulWidget {
  const _LevelCheckScreen({required this.goal, required this.goalName, required this.current});
  final String goal, goalName;
  final int current;

  @override
  State<_LevelCheckScreen> createState() => _LevelCheckScreenState();
}

class _LevelCheckScreenState extends State<_LevelCheckScreen> {
  static const _selfCheckMax = 3;
  late final Future<List<_Json>> _ladder = supabase.from('curriculum_levels').select('level, title, practice, advance_when').eq('goal', widget.goal).order('level', ascending: true);
  int _level = 0;
  bool _finished = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    var saved = false; // the level is stored; the plan rebuild comes after
    try {
      await supabase.from('goal_levels').upsert({'goal': widget.goal, 'level': _level, 'assessed_at': utcNow()});
      saved = true;
      await supabase.functions.invoke('generate-plan');
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved
              ? 'Your level is saved, but your plan could not be rebuilt. Tap save again to retry.'
              : 'Could not save. Check your connection and try again.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('LEVEL CHECK  ·  ${widget.goalName.toUpperCase()}', style: monoLabel(context))),
      body: FutureBuilder(
        future: _ladder,
        builder: (context, snap) {
          if (snap.hasError) return const Padding(padding: EdgeInsets.all(24), child: ErrorLine('Could not load the level checks. Check your connection.'));
          final ladder = snap.data;
          if (ladder == null) return const Center(child: CircularProgressIndicator());
          final row = ladder.firstWhere((r) => r['level'] == _level, orElse: () => const {});
          final settled = _finished || row.isEmpty;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 40), children: [
                // The ladder, filling as you climb.
                Row(children: [
                  for (var l = 0; l <= 5; l++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: motion(context, 300),
                        height: 6,
                        decoration: BoxDecoration(
                          color: l < _level || (settled && l == _level) ? c.primary : (l == _level ? c.onSurface : c.surfaceContainerHighest),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    if (l < 5) const SizedBox(width: 4),
                  ],
                ]),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: motion(context, 320),
                  switchInCurve: spring,
                  transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(a), child: child)),
                  child: settled ? _result(context, ladder) : _question(context, row),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _question(BuildContext context, _Json row) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(key: ValueKey(_level), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('LEVEL ${row['level']}  ·  ${(row['title'] as String).toUpperCase()}', style: monoLabel(context).copyWith(color: c.tertiary)),
      const SizedBox(height: 10),
      Text('Can you already do this?', style: t.headlineMedium),
      const SizedBox(height: 16),
      _Tile(child: Text(row['advance_when'] as String, style: t.bodyLarge?.copyWith(height: 1.5))),
      const SizedBox(height: 10),
      Text('Answer honestly. Starting a level too high is the fastest way to stall or get hurt.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => setState(() => _finished = true), child: const Text('Not yet'))),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _level++;
                if (_level >= _selfCheckMax) _finished = true;
              });
            },
            child: const Text('Yes, I can'),
          ),
        ),
      ]),
    ]);
  }

  Widget _result(BuildContext context, List<_Json> ladder) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final row = ladder.firstWhere((r) => r['level'] == _level, orElse: () => const {});
    final change = _level - widget.current;
    return Column(key: const ValueKey('result'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('YOUR LEVEL', style: monoLabel(context)),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('L', style: monoNumber(context, size: 28).copyWith(color: c.onSurfaceVariant)),
        CountUp('$_level', style: monoNumber(context, size: 72)),
        const SizedBox(width: 12),
        if (row.isNotEmpty) Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(row['title'] as String, style: t.titleLarge))),
      ]),
      const SizedBox(height: 8),
      Text(
        change == 0
            ? 'Same as your plan already uses.'
            : change > 0
                ? 'Up $change from your plan. It will be rebuilt from here.'
                : 'Down ${-change} from your plan. Building the right base first pays off.',
        style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
      ),
      if (_level >= _selfCheckMax) ...[
        const SizedBox(height: 8),
        Text('Levels 4 and 5 are earned with a tested pass, ideally with a coach watching, not a self-check.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
      if (row['practice'] is List) ...[
        const SizedBox(height: 20),
        Text('WHAT YOU WILL PRACTISE', style: monoLabel(context)),
        const SizedBox(height: 8),
        for (final p in (row['practice'] as List).cast<String>())
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 3), child: Icon(LvIcons.check, size: 16, color: c.primary)),
              const SizedBox(width: 10),
              Expanded(child: Text(p, style: t.bodyMedium)),
            ]),
          ),
      ],
      const SizedBox(height: 24),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Rebuilding your plan...' : 'Save and rebuild my plan')),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _saving
            ? null
            : () => setState(() {
                  _level = 0;
                  _finished = false;
                }),
        child: const Text('Start over'),
      ),
    ]);
  }
}

/// Foods each diet leaves out (same rules as the plan engine).
const _dietExcludes = {
  'vegetarian': {'meat', 'poultry', 'fish', 'shellfish', 'egg'},
  'eggitarian': {'meat', 'poultry', 'fish', 'shellfish'},
  'vegan': {'meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'honey'},
  'non_vegetarian': <String>{},
};

// ---------------------------------------------------------------- dashboard tiles

class _HydrationTile extends StatelessWidget {
  const _HydrationTile({required this.ml, required this.target, required this.onAdd, required this.onOpen});
  final int ml, target;
  final VoidCallback onAdd, onOpen;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fill = (ml / target).clamp(0.0, 1.0);
    return _Tile(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('WATER', trailing: Icon(LvIcons.drop, size: 16, color: c.primary)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CountUp((ml / 1000).toStringAsFixed(1), style: monoNumber(context, size: 26)),
          const SizedBox(width: 4),
          Flexible(child: Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('of ${(target / 1000).toStringAsFixed(1)} L', overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fill),
            duration: motion(context, 900),
            curve: spring,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: EdgeInsets.zero),
            child: const FittedBox(child: Text('+250 ml')),
          ),
        ),
      ]),
    );
  }
}

class _HabitsTile extends StatelessWidget {
  const _HabitsTile({required this.done, required this.total, required this.week, required this.onOpen});
  final int done, total;
  final List<int> week; // habits done on each of the last 7 days, oldest first
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Tile(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('HABITS', trailing: Icon(LvIcons.caretRight, size: 16, color: c.onSurfaceVariant)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CountUp('$done', style: monoNumber(context, size: 26)),
          const SizedBox(width: 4),
          Flexible(child: Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('of $total today', overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, n) in week.indexed) ...[
              Expanded(
                child: _Grow(
                  delay: i * 0.06,
                  builder: (v) => Container(
                    height: 6 + 38 * (n / total) * v,
                    decoration: BoxDecoration(color: i == week.length - 1 ? c.primary : c.primary.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
              if (i < week.length - 1) const SizedBox(width: 4),
            ],
          ]),
        ),
        const SizedBox(height: 6),
        Text('LAST 7 DAYS', style: monoLabel(context).copyWith(fontSize: 10)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- protocol editor

/// The levers behind the plan. Saving rebuilds the plan, so sessions, meals, reminders and what
/// Levlofit AI knows all follow at once.
class _ProtocolScreen extends StatefulWidget {
  const _ProtocolScreen({required this.data, required this.onEditGoals, required this.onSaved});
  final _Data data;
  final VoidCallback onEditGoals, onSaved;

  @override
  State<_ProtocolScreen> createState() => _ProtocolScreenState();
}

class _ProtocolScreenState extends State<_ProtocolScreen> {
  Map<String, dynamic>? _p; // profile fields being edited
  Map<String, dynamic>? _d; // diet fields being edited
  final _min = TextEditingController(), _max = TextEditingController(), _water = TextEditingController();
  bool _saving = false;
  String? _error;

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _water.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final [p, d] = await Future.wait<dynamic>([
        supabase.from('profiles').select('days_per_week, session_minutes, equipment, weight_goal, daily_activity, water_target_ml').eq('id', _uid).single(),
        supabase.from('dietary_profiles').select('diet_type, budget_tier, budget_min_inr, budget_max_inr, cuisine_region, diet_pace').eq('user_id', _uid).single(),
      ]);
      if (!mounted) return;
      setState(() {
        _p = Map.of(p as Map<String, dynamic>);
        _d = Map.of(d as Map<String, dynamic>);
        _min.text = '${_d!['budget_min_inr'] ?? ''}';
        _max.text = '${_d!['budget_max_inr'] ?? ''}';
        _water.text = '${_p!['water_target_ml'] ?? waterTarget(widget.data.profile)}';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your protocol. Check your connection.');
    }
  }

  Future<void> _save() async {
    final p = _p!, d = _d!;
    int? num(TextEditingController c) => int.tryParse(c.text.trim());
    if (d['budget_tier'] == 'custom') {
      final lo = num(_min), hi = num(_max);
      if (hi == null || (lo != null && lo > hi)) return setState(() => _error = 'Enter a daily budget range in rupees, lowest first.');
      d['budget_min_inr'] = lo;
      d['budget_max_inr'] = hi;
    } else {
      d['budget_min_inr'] = null;
      d['budget_max_inr'] = null;
    }
    if (p['water_target_ml'] != null) {
      final water = num(_water);
      if (water == null || water < 1000 || water > 6000) return setState(() => _error = 'Water target must be 1000 to 6000 ml.');
      p['water_target_ml'] = water;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false; // settings stored; the plan rebuild comes after
    try {
      await supabase.from('profiles').update(p).eq('id', _uid);
      await supabase.from('dietary_profiles').update(d).eq('user_id', _uid);
      saved = true;
      await supabase.functions.invoke('generate-plan');
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Protocol saved. Your plan, meals and Levlofit AI are updated.')));
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(() => _error = saved
            ? 'Your settings are saved, but your plan could not be rebuilt. Save again to retry.'
            : 'Could not save. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chips<T>(String title, String? help, T? value, List<(T, String)> options, ValueChanged<T> onPick) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: t.titleMedium),
        if (help != null) Text(help, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (v, label) in options) ChoiceChip(label: Text(label), selected: value == v, onSelected: (_) => setState(() => onPick(v))),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final p = _p, d = _d;
    if (p == null || d == null) {
      return _Page(eyebrow: 'PROTOCOL', title: 'Your protocol', children: [
        if (_error != null) ErrorLine(_error!) else const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: LevloMark(size: 48, animate: true))),
      ]);
    }
    final goals = (widget.data.plan['goals'] as List).cast<_Json>();
    return _Page(
      eyebrow: 'PROTOCOL',
      title: 'Your protocol',
      subtitle: 'The settings your plan is built from. Change any of them and the plan, sessions, meals, reminders and Levlofit AI all adapt.',
      children: [
        _Tile(
          onTap: widget.onEditGoals,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GOALS AND ORDER', style: monoLabel(context)),
                const SizedBox(height: 4),
                Text(goals.map((g) => '${g['name'] ?? g['goal']} (L${g['startLevel']})').join('  ·  '), style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
            Icon(LvIcons.pencilSimple, size: 18, color: c.onSurfaceVariant),
          ]),
        ),
        const SizedBox(height: 20),
        Text('TRAINING', style: monoLabel(context)),
        const SizedBox(height: 10),
        _chips<int>('Days a week', 'At least one full rest day is kept.', p['days_per_week'] as int?, [for (var i = 1; i <= 7; i++) (i, '$i')], (v) => p['days_per_week'] = v),
        _chips<int>('Minutes a session', null, p['session_minutes'] as int?, [for (final m in const [20, 30, 45, 60, 75, 90]) (m, '$m')], (v) => p['session_minutes'] = v),
        _chips<String>('Equipment', null, p['equipment'] as String?, [('none', 'None'), ('home', 'Home dumbbells'), ('gym', 'Gym'), if (p['equipment'] == 'custom') ('custom', 'My own kit')], (v) => p['equipment'] = v),
        _chips<String>('Body goal', 'The plan may still adjust this for safety, and will tell you why.', p['weight_goal'] as String?,
            const [('cut', 'Lose fat'), ('maintain', 'Maintain'), ('recomp', 'Recomposition'), ('bulk', 'Build muscle'), ('general', 'General fitness')], (v) => p['weight_goal'] = v),
        _chips<String>('Daily activity outside training', null, p['daily_activity'] as String?,
            const [('sedentary', 'Mostly sitting'), ('light', 'Light'), ('active', 'On my feet'), ('very_active', 'Very active')], (v) => p['daily_activity'] = v),
        const SizedBox(height: 4),
        Text('FOOD', style: monoLabel(context)),
        const SizedBox(height: 10),
        _chips<String>('Diet', null, d['diet_type'] as String?, const [('vegan', 'Vegan'), ('vegetarian', 'Vegetarian'), ('eggitarian', 'Eggitarian'), ('non_vegetarian', 'Non-veg')], (v) => d['diet_type'] = v),
        _chips<String>('Food budget', 'What you can spend on food a day. The lowest band keeps to dals, grains, eggs, milk and seasonal produce; the middle adds paneer, chicken and fish.',
            d['budget_tier'] as String?, [for (final (k, title, _) in budgetOptions) (k, title), ('custom', 'My own range')], (v) => d['budget_tier'] = v),
        AnimatedSize(
          duration: motion(context, 240),
          curve: spring,
          child: d['budget_tier'] != 'custom'
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _min,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'From, a day', prefixText: 'Rs '),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _max,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'To, a day', prefixText: 'Rs '),
                      ),
                    ),
                  ]),
                ),
        ),
        _chips<String>('Pace', 'How fast a cut or a bulk moves. Easy is gentler and easier to keep up; hard asks more and is harder to sustain. '
            'Maintenance and recomposition are not changed.', d['diet_pace'] as String? ?? 'balanced',
            const [('easy', 'Easy'), ('balanced', 'Balanced'), ('hard', 'Hard')], (v) => d['diet_pace'] = v),
        _chips<String>('Regional staples', 'The grains, dals and fish your meal plan leans on. A preference: other foods still appear to meet your targets.',
            d['cuisine_region'] as String? ?? 'any',
            [for (final (k, title, _) in regionOptions) (k, title)], (v) => d['cuisine_region'] = v),
        Text('WATER', style: monoLabel(context)),
        const SizedBox(height: 10),
        _chips<bool>('Daily water target', 'Auto follows EFSA guidance and adds water on training days.', p['water_target_ml'] != null, const [(false, 'Auto'), (true, 'My own')],
            (own) => p['water_target_ml'] = own ? (int.tryParse(_water.text) ?? waterTarget(widget.data.profile)) : null),
        if (p['water_target_ml'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: TextField(
              controller: _water,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Millilitres a day', suffixText: 'ml'),
            ),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: ErrorLine(_error!)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Rebuilding your plan...' : 'Save and rebuild my plan')),
        const SizedBox(height: 10),
        Text('Your training levels change through level checks in Workout, so progress stays earned.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

// ---------------------------------------------------------------- profile and settings

/// A tappable list row used by Profile and Settings.
Widget _row(BuildContext context, IconData icon, String label, VoidCallback onTap, {String? trailing, Color? color}) {
  final c = Theme.of(context).colorScheme;
  final t = Theme.of(context).textTheme;
  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: color ?? c.onSurface),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: color))),
        if (trailing != null) Flexible(child: Text(trailing, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))),
        const SizedBox(width: 6),
        Icon(LvIcons.caretRight, size: 16, color: c.onSurfaceVariant),
      ]),
    ),
  );
}

Widget _section(BuildContext context, String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _Tile(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (title.isNotEmpty) Text(title, style: monoLabel(context)), ...rows]),
      ),
    );

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({
    required this.data,
    required this.onOpen,
    required this.onSignOut,
    required this.onDelete,
    required this.onEditDetails,
    required this.onAvatarChanged,
  });
  final _Data data;
  final ValueChanged<_Tab> onOpen;
  final VoidCallback onSignOut, onDelete, onEditDetails, onAvatarChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = data.name ?? 'You';
    final email = supabase.auth.currentUser?.email ?? '';
    final avatar = data.profile['avatar'] as String?;
    Future<void> change() async {
      if (await pickAvatar(context, name: name, current: avatar)) onAvatarChanged();
    }

    return _Page(
      eyebrow: 'PROFILE',
      title: name,
      subtitle: email.isEmpty ? null : email,
      children: [
        _Tile(
          child: Row(children: [
            Semantics(
              button: true,
              label: 'Change profile picture',
              child: GestureDetector(
                onTap: change,
                child: Stack(clipBehavior: Clip.none, children: [
                  UserAvatar(name: name, avatar: avatar, photoUrl: data.profile['avatar_url'] as String?, size: 64),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.outline)),
                      child: Icon(LvIcons.camera, size: 13, color: c.onSurface),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(spacing: 18, runSpacing: 8, children: [
                for (final (label, value) in [
                  ('HEIGHT', data.profile['height_cm'] == null ? null : '${data.profile['height_cm']} cm'),
                  ('WEIGHT', data.profile['weight_kg'] == null ? null : '${data.profile['weight_kg']} kg'),
                  ('PHASE', (data.plan['phase'] as _Json?)?['title'] as String?),
                ])
                  if (value != null)
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: monoLabel(context).copyWith(fontSize: 10)), Text(value, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600))]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _section(context, 'YOU', [
          _row(context, LvIcons.userCircle, 'Profile picture', change, trailing: 'Avatar or your photo'),
          _row(context, LvIcons.pencilSimple, 'Edit name, height and weight', onEditDetails),
          _row(context, LvIcons.notePencil, 'Protocol', () => onOpen(_Tab.protocol), trailing: 'Goals, days, diet, budget'),
        ]),
        _section(context, 'MORE', [
          _row(context, LvIcons.gear, 'Settings', () => onOpen(_Tab.settings), trailing: 'Theme, help, privacy'),
        ]),
        _section(context, '', [
          _row(context, LvIcons.signOut, 'Sign out', onSignOut),
          _row(context, LvIcons.trash, 'Delete account', onDelete, color: c.error),
        ]),
      ],
    );
  }
}

class _AppSettingsScreen extends StatelessWidget {
  const _AppSettingsScreen({required this.onOpen});
  final ValueChanged<_Tab> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    void sheet(String title, List<(String, String)> points) => _policySheet(context, title, points);
    return _Page(
      eyebrow: 'SETTINGS',
      title: 'Settings',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _Tile(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('APPEARANCE', style: monoLabel(context)),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: themeMode,
                builder: (context, mode, _) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) {
                      HapticFeedback.selectionClick();
                      setThemeMode(s.first);
                    },
                  ),
                ),
              ),
            ]),
          ),
        ),
        _section(context, 'HELP', [
          _row(context, LvIcons.chatCircle, 'Contact support', _contactSupport, trailing: supportEmail),
          _row(context, LvIcons.notePencil, 'Send feedback', () => _sendFeedback(context), trailing: 'Ideas, bugs, praise'),
          _row(context, LvIcons.lightbulb, 'Glossary of training terms', () => onOpen(_Tab.glossary)),
          _row(context, LvIcons.timer, 'Notifications and reminders', () => onOpen(_Tab.reminders), trailing: 'Permissions, times'),
        ]),
        _section(context, 'PRIVACY', [
          _row(context, LvIcons.brain, 'How we use your data', () => sheet('How we use your data', _dataUse)),
          _row(context, LvIcons.bookOpen, 'Privacy policy', () => sheet('Privacy policy', _privacyPolicy)),
        ]),
        _section(context, 'ABOUT', [
          _row(context, LvIcons.sparkle, 'Levlofit 1.0', () => showLicensePage(context: context, applicationName: 'Levlofit', applicationVersion: '1.0.0'), trailing: 'Licences'),
        ]),
        FoodCredit(lead: '$exerciseMediaCredit. ', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}

const supportEmail = 'levlofit.app@gmail.com';

/// Opens a new Gmail message to support. On the web that is Gmail's compose page; on phones the mail link
/// opens the Gmail app (or the default mail app), falling back to Gmail on the web.
Future<void> _contactSupport() async {
  final gmail = Uri.https('mail.google.com', '/mail/', {'view': 'cm', 'fs': '1', 'to': supportEmail, 'su': 'Levlofit support'});
  if (kIsWeb) {
    await launchUrl(gmail, webOnlyWindowName: '_blank');
    return;
  }
  final mail = Uri(scheme: 'mailto', path: supportEmail, query: 'subject=Levlofit%20support');
  if (!await launchUrl(mail)) await launchUrl(gmail, mode: LaunchMode.externalApplication);
}

/// In-app feedback box: the message is saved to app_feedback, which only the Levlofit team can read.
Future<void> _sendFeedback(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = TextEditingController();
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      var sending = false;
      String? error;
      return StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Send feedback', style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Ideas, bugs, things you love. The Levlofit team reads every message.',
                    style: Theme.of(sheet).textTheme.bodyMedium?.copyWith(color: Theme.of(sheet).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                TextField(
                  controller: text,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: 'Tell us what you think...', errorText: error),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: sending
                        ? null
                        : () async {
                            final msg = text.text.trim();
                            if (msg.length < 3) return setSheet(() => error = 'Write a little more.');
                            setSheet(() => (sending, error) = (true, null));
                            try {
                              await supabase.from('app_feedback').insert({'message': msg});
                              if (sheet.mounted) Navigator.pop(sheet, true);
                            } catch (_) {
                              setSheet(() => (sending, error) = (false, 'Could not send. Check your connection.'));
                            }
                          },
                    child: Text(sending ? 'Sending...' : 'Send'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    },
  );
  text.dispose();
  if (sent == true) messenger.showSnackBar(const SnackBar(content: Text('Thanks! Your feedback reached the Levlofit team.')));
}

/// "How we use your data", in plain words.
const _dataUse = [
  ('What we keep', 'Your sign-up answers (age, height, weight, goals, diet, health check), your plans, the workouts, sets, water, habits, '
      'measurements, food diary and recipes you log, your progress photos, your chats with Levlofit AI (with a short summary of a long chat\'s '
      'older messages), the session changes Levlofit AI offered or you confirmed, and feedback you send.'),
  ('Why we keep it', 'Only to run the app for you: to build your plan, show your progress, send the reminders you switch on, and let '
      'Levlofit AI answer about you, not in general.'),
  ('Who can see it', 'No other user: your data is locked to your account by the database itself. The Levlofit team reads the feedback '
      'you send, and our AI provider receives what is listed under "What Levlofit AI sends". We never sell it and never use it for ads.'),
  ('Levlofit AI', 'When you send a message, your question and a summary of your plan and recent training go to our AI provider to write '
      'the reply. Your chats are saved in your account. Levlofit AI can suggest facts to remember (your schedule, equipment, likes, goals or an injury); '
      'it keeps one only if you confirm it, and you can edit or delete each one in Memory. Confirmed facts go to our AI provider with your messages; '
      'an injury fact only when you ask about training, movement or pain. In a long chat, a summary of its older messages is sent too. '
      'When you ask to change today\'s session it also gets today\'s moves and checked replacements, or this week\'s free days; when you ask to '
      'log a meal, the names of foods from your own diary. Swaps, lighter or moved sessions and meals change only after you confirm them. '
      'You can delete chats any time.'),
  ('Your photos', 'Progress photos are stored privately in your account. Nobody else can open them.'),
  ('You are in control', 'Edit most of your details in Profile and Protocol; email us to correct the rest. Delete your account in Profile (or '
      'from the account menu while you set up) and everything goes with it: answers, plans, logs, chats and photos.'),
];

/// The privacy policy, short and in plain words. Matches the website policy.
/// A titled list of points in a bottom sheet (privacy policy, data use).
Future<void> _policySheet(BuildContext context, String title, List<(String, String)> points) {
  final c = Theme.of(context).colorScheme;
  final t = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (s) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (s, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text(title, style: t.titleLarge),
          const SizedBox(height: 16),
          for (final (head, body) in points) ...[
            Text(head, style: t.titleMedium),
            const SizedBox(height: 4),
            Text(body, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant, height: 1.45)),
            const SizedBox(height: 16),
          ],
          Text('Questions? Write to $supportEmail.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
    ),
  );
}

/// Health Connect shows the app's privacy policy from its permission screens; that launch lands here.
Future<void> showPrivacyPolicy(BuildContext context) => _policySheet(context, 'Privacy policy', _privacyPolicy);

const _privacyPolicy = [
  ('Who we are', 'Levlofit is a fitness app made in India. This explains what happens to your information when you use it.'),
  ('What we collect', 'Your email to sign in and the name you give (Google fills it in if you sign in with Google). What you tell us at '
      'sign-up and in Protocol, including your weight goal, food budget and exclusions, equipment, water target and the health check. '
      'What you log: workouts and sets (reps and weight), body weight and measurements, water, habits, your level in each goal and your '
      'reminder settings (including the names you give your own reminders), the foods and weights you log in the food diary and the recipes you save, and how hard each session felt and whether pain stopped you, if you answer after a session. Progress photos, and your profile picture if you upload your own. Your chats with Levlofit AI, the facts you confirm in its Memory, '
      'and its suggestions waiting for your OK. Feedback you send. Error reports when the app hits an unexpected error while you are signed in (the error message, where in the app code it happened, app version and phone type; email addresses masked; kept up to 90 days). For abuse protection: when you send chat messages or rebuild your plan (times only, no content), and a random ID on each chat message so a resent one is not saved twice; feedback is limited by counting the feedback you have sent. On this phone only: your sign-in session, light or dark choice, dashboard layout and daily goals, which permission prompts you have seen, downloaded fonts and the reminders scheduled on the phone. We do not collect your location, contacts or '
      'data from other apps.'),
  ('How we use it', 'To build your plan, track your progress, send reminders you choose and answer your questions. Nothing else.'),
  ('Where it is stored', 'With Supabase, our database and file storage provider. Photos are kept in private storage only your account '
      'can open. Everything travels over encrypted connections.'),
  // REVIEW GATE: the next two sections describe the coach-chat code in this repository. Ship them only after the deployed
  // coach-chat function is confirmed to match it and LLM_BASE_URL is confirmed unset or pointing at Groq.
  ('What Levlofit AI sends', 'Groq runs Levlofit AI and may process your messages outside India. Each time you send a message, Groq gets: '
      'your message as you typed it (trimmed, up to 2,000 characters) and up to 12 earlier messages from that chat; your first name; your equipment, training days, '
      'session length, daily activity, sleep hours and water target; the date, goal and minutes of workouts logged in the last 14 days; a '
      'summary of your plan (phase, weight goal, goals and levels, sessions, next steps, calorie and protein targets); the facts you confirmed in Memory (an injury fact only when the chat is about training, movement or pain, at most three; '
      'suggestions you have not confirmed are never sent); and two yes-or-no flags: whether your '
      'health check asks you to see a doctor first, and whether you noted an injury (in the health check or as a confirmed Memory fact). Only when the chat is about food, or a reply has to be '
      'checked against your food settings: your diet type, allergies and intolerances, foods you exclude, food budget and suggested supplements, and your food diary totals '
      'for each of the last 7 days you logged (energy, protein, carbohydrate, fat and fibre; not the foods themselves). Only when the chat is '
      'about lifting: for each move you logged in the last 14 days, its name, how many days you trained it, the last day and your best set '
      '(reps and weight). Only when the chat is about steps or walking, and only if you switched on sharing in Progress: your daily step totals '
      'for the last 7 days from Health Connect.'),
  // REVIEW GATE (legal): a second AI provider is used only if the owner sets one up and approves its data terms.
  ('If Groq is unavailable', 'We may set up a second AI provider that answers when Groq is down or busy. It would receive exactly what Groq '
      'receives for that message. We name it here before it is switched on.'),
  ('What Groq does not get', 'Your email, account ID, year of birth, sex, height, weight, waist or other measurements, body type, health '
      'check answers, the injury you described in the health check (an injury fact you confirm in Memory is sent as above), photos, set logs outside lifting questions, water or habit logs, your effort or pain answers, or feedback. It does get '
      "passages from Levlofit's Handbook that match your question, which are our text, not yours. Your calorie and protein targets are "
      'worked out from your weight, height, age and sex, so your approximate weight can be calculated from them. Anything you type in a '
      'message is sent as written, so leave out details you do not want shared.'),
  ('Who else handles it', 'Supabase stores your data, and Google handles sign-in if you use Google. Google Fonts supplies the app\'s fonts; '
      'Google\'s servers may receive your IP address when the app loads them. ExerciseDB (AscendAPI) supplies the exercise animations; its '
      'servers may receive your IP address when the app loads them. Once per start the app asks the Levlofit website whether a newer version exists, so its host may receive your IP address too. Each is used only for its job. We never sell your data.'),
  ('Body check (optional)', 'Only if you use it and agree each time: the photo you choose is sent once to Groq, which may process it outside India, '
      'to write a few notes on posture and which areas to train. Levlofit does not store the photo or the notes. No body-fat, weight or health '
      'judgement is made. For adults only.'),
  ('Permissions', 'Notifications, only for the reminders you turn on. On Android, Alarms and reminders, only if you allow it, so reminders arrive at the time you set; without it they can arrive a few minutes late. Photos, only when you add a progress photo or profile picture.'),
  // REVIEW GATE (legal): Health Connect steps text; ships only with builds made with -Plevlofit.healthConnect=true.
  ('Steps from Health Connect', 'Only if you connect it in Progress, and only on Android builds that support it. Levlofit reads your daily step '
      'totals for the last 7 days while you look at Progress. They stay on this phone: they are not stored on our servers. If you switch on '
      '"Share step totals with Levlofit AI", those 7 totals are sent with your coach messages and pass to the AI provider like the rest of '
      'the chat context. Disconnect in Progress, or remove access in Health Connect, at any time.'),
  // REVIEW: backup and log retention periods at Supabase are not verified; replace "may" with the real periods once confirmed.
  ('How long we keep it', 'Until you delete your account. Every plan built for you is kept, each with a copy of the answers it used (including '
      'any injury you described); the app shows the latest. Deleting your account first removes your progress photos and profile picture; if that '
      'fails, your account is not deleted and you can try again. Then your account is deleted, along with the records linked to it in our '
      'database: profile and answers, goals, plans, logs, food diary and recipes, measurements, chats, AI notes, reminder settings, feedback and error reports. '
      'If deleting the account itself fails after the photos are gone, the photos stay deleted, the rest stays and you can try again. '
      'Reminders scheduled on this phone are cancelled when you delete your account or sign out. Copies may remain '
      'in our service providers\' backups and service logs after deletion, under their own retention practices. Messages already sent to '
      'Groq cannot be deleted by us; Groq handles them under its own terms. Website contact messages are not linked to your account; we '
      'delete them manually once the matter is handled.'),
  ('Your rights', "Under India's Digital Personal Data Protection Act, 2023, you can see, correct or erase your data, withdraw consent "
      'and raise a complaint. Most of this you can do in the app: edit most answers in Profile and Protocol, and delete your account in '
      'Profile. For the rest, email us and we reply within 30 days.'),
  ('Health', 'Levlofit gives general fitness guidance, not medical advice. See a doctor for pain, illness, or before hard training if you have a health condition.'),
  ('Age', 'Levlofit is for adults aged 18 to 80.'),
  ('Changes', 'If this policy changes in a way that affects your data, we tell you in the app first. Last updated 27 October 2026.'),
];

// ---------------------------------------------------------------- glossary

/// Plain-language meanings for the words the plan uses.
const _glossary = [
  ('BMI', 'Body mass index: weight in kg divided by height in metres squared. WHO normal range: 18.5 to under 25.'),
  ('BMR', 'Basal metabolic rate: the energy your body uses at complete rest. Your calorie target starts from it.'),
  ('Compound lift', 'A move using several joints at once, like a squat, deadlift, press or row.'),
  ('Deload', 'A lighter week that lets fatigue fall so progress can continue.'),
  ('Double progression', 'Add reps at the same weight until every set reaches the top of the range, then add weight and start again.'),
  ('Foundation phase', 'Training only your main goal and full-body basics until they are solid, before adding other goals.'),
  ('Hypertrophy', 'Muscle growth.'),
  ('kcal', 'Kilocalorie, the unit of food energy on labels and in your plan.'),
  ('Level', 'Where you stand on the Levlofit ladder for a goal, from 0 to 5. You move up by passing its check.'),
  ('Level check', 'A short test of what you can already do, used to place you on the ladder.'),
  ('Macros', 'Protein, carbohydrate and fat: the three nutrients that carry energy.'),
  ('Mobility', 'Moving joints through their full range with control.'),
  ('Progressive overload', 'Doing a little more over time: a rep, a set, a kilo or a minute.'),
  ('Recomposition', 'Losing fat and gaining muscle at the same time, usually at maintenance calories with high protein.'),
  ('Rep', 'One repetition of a movement.'),
  ('Rest interval', 'The pause between sets. Longer rests help strength; the session timer sets it for you.'),
  ('RIR', 'Reps in reserve: how many more good reps you could have done when you stopped a set.'),
  ('Set', 'A group of reps done without stopping.'),
  ('Warm-up', 'Easy movement and lighter sets that prepare you for the work sets.'),
];

class _GlossaryScreen extends StatefulWidget {
  const _GlossaryScreen();

  @override
  State<_GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<_GlossaryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final shown = [for (final e in _glossary) if ('${e.$1} ${e.$2}'.toLowerCase().contains(_q.toLowerCase())) e];
    return _Page(
      eyebrow: 'GLOSSARY',
      title: 'Words your plan uses',
      children: [
        TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Search a term', prefixIcon: Icon(LvIcons.magnifyingGlass, size: 20))),
        const SizedBox(height: 12),
        for (final (term, meaning) in shown)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(term, style: t.titleMedium),
              const SizedBox(height: 2),
              Text(meaning, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            ]),
          ),
      ],
    );
  }
}

/// Android only: whether reminders can arrive at the exact time. Asking happens only when the user taps; a "no"
/// leaves reminders working, just possibly a few minutes late.
class _ExactTimingRow extends StatelessWidget {
  const _ExactTimingRow({required this.timing, required this.onAllow});
  final ReminderTiming timing;
  final Future<void> Function() onAllow;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final exact = timing == ReminderTiming.exact;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(exact ? LvIcons.checkCircle : LvIcons.timer, size: 18, color: exact ? c.primary : c.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exact ? 'Exact timing: on' : 'Exact timing: off', style: t.titleSmall),
            const SizedBox(height: 2),
            Text(
              exact
                  ? 'Reminders are set for the exact minute. Some phones, including OnePlus, can still hold them for a minute or more to save battery.'
                  : 'Reminders may arrive a few minutes late. Allow "Alarms & reminders" for Levlofit to have them on time.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
            if (!exact) TextButton(onPressed: onAllow, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Allow exact timing')),
          ]),
        ),
      ]),
    );
  }
}

/// Shown when the phone is blocking Levlofit's notifications. One tap asks Android (it shows its prompt only while
/// it still allows one); after that the way back is the phone's own settings, said plainly.
class _NotificationsOffRow extends StatelessWidget {
  const _NotificationsOffRow({required this.onTurnOn});
  final Future<void> Function() onTurnOn;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LvIcons.warningCircle, size: 18, color: c.error),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notifications: off', style: t.titleSmall),
            const SizedBox(height: 2),
            Text('Reminders cannot appear until notifications are allowed. If no prompt appears, turn them on in your phone '
                'settings: Apps, Levlofit, Notifications.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            TextButton(onPressed: onTurnOn, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Turn on notifications')),
          ]),
        ),
      ]),
    );
  }
}

/// Test builds only: schedules one standalone alarm-clock notification at a time you pick, to compare its delivery
/// with normal reminders on this phone. Saved reminders and their schedules are not touched.
class _AlarmClockTestTile extends StatefulWidget {
  const _AlarmClockTestTile();

  @override
  State<_AlarmClockTestTile> createState() => _AlarmClockTestTileState();
}

class _AlarmClockTestTileState extends State<_AlarmClockTestTile> {
  String? _status;

  Future<void> _schedule() async {
    final soon = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 3)));
    final at = await showTimePicker(context: context, initialTime: soon);
    if (at == null || !mounted) return;
    String? error;
    final when = await Reminders.scheduleAlarmClockTest(at, onError: (m) => error = m);
    if (!mounted) return;
    setState(() => _status = when != null
        ? 'Test alarm set for ${at.format(context)} (alarm-clock mode). Until it fires, expect an alarm icon in the status bar and it may show as your next alarm.'
        : error ?? 'Not scheduled.');
  }

  Future<void> _cancel() async {
    await Reminders.cancelAlarmClockTest();
    if (mounted) setState(() => _status = 'Test alarm cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('TIMING EXPERIMENT  ·  TEST BUILDS ONLY'),
        const SizedBox(height: 6),
        Text('Schedules one alarm-clock notification, separate from your reminders, to measure on-time delivery.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        if (_status != null) ...[const SizedBox(height: 8), Text(_status!, style: t.bodySmall)],
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: _schedule, child: const Text('Schedule test alarm')),
          TextButton(onPressed: _cancel, child: const Text('Cancel test alarm')),
        ]),
      ]),
    );
  }
}

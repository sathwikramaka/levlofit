// Coach onboarding. Scripted questions (the LLM only adds tone later), answers saved
// with RLS as the user, then generate-plan builds the plan and opens the dashboard.
// Goals come from the goal_catalog table; other allowed values mirror plan-engine.ts.
// With goalsOnly, the same screens edit goals after onboarding and rebuild the plan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account.dart';
import 'diet_plan.dart' show budgetOptions, dailyFromMonthly, regionOptions;
import 'icons.dart';
import 'main.dart';
import 'mark.dart';
import 'theme.dart';

typedef _Goal = ({String id, String name, String category});

const _experience = {
  'none': ('None yet', 'Never trained it'),
  'beginner': ('Beginner', 'Learning the basics'),
  'intermediate': ('Intermediate', 'Train it with a plan'),
  'advanced': ('Advanced', 'Years of structured work'),
};

const _restrictions = {
  'lactose': 'Lactose intolerance',
  'gluten': 'Gluten (coeliac or sensitivity)',
  'peanut': 'Peanuts',
  'tree_nut': 'Tree nuts',
  'soy': 'Soy',
  'egg': 'Egg',
  'fish': 'Fish',
  'shellfish': 'Shellfish',
};

const _diets = {
  'vegetarian': ('Vegetarian', 'Dairy, no egg, meat or fish'),
  'eggitarian': ('Eggitarian', 'Vegetarian plus eggs'),
  'vegan': ('Vegan', 'No animal products'),
  'non_vegetarian': ('Non-vegetarian', 'Chicken, mutton, fish and eggs'),
};

const _sexes = {'male': 'Male', 'female': 'Female'};
// Training phase; the plan engine may change it after checking your numbers (coach review).
const _phases = {
  'cut': ('Cutting', 'Lose fat while keeping muscle'),
  'bulk': ('Bulking', 'Gain muscle with a small calorie surplus'),
  'recomp': ('Recomposition', 'Build muscle and lose fat at the same time'),
  'maintain': ('Maintenance', 'Keep your weight, get fitter and stronger'),
  'general': ('General fitness', 'Feel better and move well, no weight target'),
};

const _bodyTypes = {
  'lean': ('Lean', 'Slim with little body fat'),
  'average': ('Average', 'Neither slim nor heavy'),
  'slim_soft': ('Skinny-fat', 'Slim arms and legs, but a softer belly and chest'),
  'extra_fat': ('Carrying extra fat', 'Would like to lose some fat'),
  'muscular': ('Muscular', 'Visible muscle from training'),
};

const _activity = {
  'sedentary': ('Mostly sitting', 'Desk work, little walking'),
  'light': ('Lightly active', 'Some walking or standing'),
  'active': ('Active', 'On your feet most of the day'),
  'very_active': ('Very active', 'Physical work'),
};

// ACSM pre-participation screen (Riebe et al., 2015): any "yes" means medical clearance first.
const _healthScreen = {
  'heart_condition': 'Heart condition diagnosed by a doctor',
  'chest_pain': 'Chest pain during activity or at rest',
  'dizziness': 'Fainting or dizziness during activity',
  'pregnancy': 'Pregnant',
  'other_medical': 'Another condition a doctor said limits exercise',
};

const _equipment = {
  'none': ('No equipment', 'Bodyweight, anywhere'),
  'home': ('Home setup', 'Dumbbells, bands or a bar'),
  'gym': ('Gym', 'Full equipment'),
  'custom': ('Custom setup', 'Pick exactly what you have'),
};

const _equipmentItems = [
  'Push-up board',
  'Pull-up bar',
  'Dip bars',
  'Resistance bands',
  'Dumbbells',
  'Kettlebell',
  'Skipping rope',
  'Yoga mat',
  'Bench',
  'Barbell and plates',
];

const _supplements = {'protein_powder': ('Protein powder', 'Whey or plant protein, only to top up food'), 'creatine': ('Creatine', 'Creatine monohydrate')};

const _minuteOptions = [20, 30, 45, 60, 75, 90];

enum _Step { name, primary, extras, experience, body, phase, schedule, health, equipment, restrictions, diet, assess, build, review }

const _maxExtras = 5; // plan engine MAX_GOALS = 6 including the primary

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone, this.goalsOnly = false, this.initialGoals = const [], this.initialLevels = const {}});
  final VoidCallback onDone;
  final bool goalsOnly;
  final List<String> initialGoals; // priority order, first is primary
  final Map<String, String> initialLevels;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  late final List<_Step> _steps = widget.goalsOnly
      ? const [_Step.primary, _Step.extras, _Step.experience, _Step.build]
      : _Step.values.where((s) => s != _Step.review).toList();
  late var _step = _steps.first;
  List<_Goal>? _catalog;
  bool _catalogFailed = false;
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _birthYear = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _bodyForm = GlobalKey<FormState>();
  final _scheduleForm = GlobalKey<FormState>();
  String? _bodyType, _activityLevel;
  int? _days, _minutes;
  final _sleep = TextEditingController();
  final _injuries = TextEditingController();
  final _health = <String>{};
  bool _noHealth = false;
  final _items = <String>{}; // custom equipment
  final _itemInput = TextEditingController();
  final _supp = <String>{};
  bool _noSupp = false;
  Map<String, dynamic>? _plan; // returned by generate-plan, explained on the review step
  final _goals = <String>[]; // order = priority, first is primary
  final _level = <String, String>{};
  final _avoid = <String>{};
  final _other = <String>[]; // free-text allergies, saved to dietary_profiles.other_restrictions
  final _otherInput = TextEditingController();
  bool _noRestrictions = false;
  String? _diet, _sex, _weightGoal, _gear, _budget;
  String _region = 'any';
  final _monthly = TextEditingController(); // own monthly food budget, when _budget is 'custom'
  // Level check with Levlofit AI (coach-chat assess): the chat so far, the levels it proposed, or a skip.
  final _assessTurns = <({String role, String content})>[];
  final _assessInput = TextEditingController();
  Map<String, int>? _assessLevels;
  bool _assessBusy = false, _assessSkipped = false;
  String? _assessError;
  bool _busy = false;
  String? _error;

  static final _thisYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    // Google sign-in provides the name; the user can still edit it.
    _name.text = (supabase.auth.currentUser?.userMetadata?['full_name'] as String?) ?? '';
    _goals.addAll(widget.initialGoals);
    _level.addAll(widget.initialLevels);
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() => _catalogFailed = false);
    try {
      final rows = await supabase.from('goal_catalog').select('id, name, category').order('sort', ascending: true); // postgrest-dart defaults to descending
      if (mounted) {
        setState(() => _catalog = [for (final r in rows) (id: r['id'] as String, name: r['name'] as String, category: r['category'] as String)]);
      }
    } catch (_) {
      if (mounted) setState(() => _catalogFailed = true);
    }
  }

  String _nameOf(String id) => _catalog?.firstWhere((g) => g.id == id, orElse: () => (id: id, name: id, category: '')).name ?? id;

  @override
  void dispose() {
    for (final c in [_name, _birthYear, _height, _weight, _otherInput, _search, _sleep, _injuries, _itemInput, _monthly, _assessInput]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _first => _name.text.trim().split(' ').first;

  bool get _canContinue => switch (_step) {
    _Step.name => _name.text.trim().isNotEmpty,
    _Step.primary => _goals.isNotEmpty,
    _Step.extras => true, // optional
    _Step.experience => _goals.every(_level.containsKey),
    _Step.restrictions => _noRestrictions || _avoid.isNotEmpty || _other.isNotEmpty,
    _Step.diet => _diet != null && _budget != null && (_budget != 'custom' || (int.tryParse(_monthly.text) ?? 0) >= 900) && (_noSupp || _supp.isNotEmpty),
    _Step.assess => !_assessBusy && (_assessLevels != null || _assessSkipped),
    _Step.body => _sex != null && _bodyType != null,
    _Step.phase => _weightGoal != null,
    _Step.schedule => _days != null && _minutes != null && _activityLevel != null,
    _Step.health => _noHealth || _health.isNotEmpty,
    _Step.equipment => _gear != null && (_gear != 'custom' || _items.isNotEmpty),
    _Step.build || _Step.review => false,
  };

  String get _coachLine => switch (_step) {
    _Step.name => "Hi, I'm your Levlofit coach. What should I call you?",
    _Step.primary =>
      widget.goalsOnly
          ? 'What is your main goal now? Your plan is rebuilt around it.'
          : 'Good to meet you, $_first. What is your main goal? Your plan is built around it.',
    _Step.extras => 'Anything else you want to train? You can add up to five, but the curriculum recommends one or two for real progress. Extras get fewer sessions so your main goal keeps moving.',
    _Step.experience => 'How much have you trained for each? You start where you are, and move up by passing tests.',
    _Step.restrictions => 'Before we talk food: any allergies or intolerances? I keep these out of every meal.',
    _Step.diet => 'How do you eat, what can you spend on food, and are you open to supplements? Levlofit never suggests beef or pork.',
    _Step.assess => "Last step. Before I build anything, let me check where you really are, not just where you rated yourself.",
    _Step.body => 'A few numbers and how you see your body today. Only you can see them.',
    _Step.phase => 'What do you want your body to do right now? I check this against your numbers before building anything.',
    _Step.schedule => 'How much time can you give training? The plan fits your week, not the other way round.',
    _Step.health => 'Quick safety check. Has any of these applied to you?',
    _Step.equipment => 'Where will you train?',
    _Step.build => _error == null ? 'Checking your answers and building your plan.' : 'That did not work. Your answers are safe.',
    _Step.review =>
      ((_plan?['review'] as List?) ?? const []).isEmpty
          ? 'I checked everything you told me. Your choices fit your numbers, so nothing needed changing.'
          : 'I checked everything you told me before building your plan. Here is what I found, and why.',
  };

  int get _index => _steps.indexOf(_step);
  bool get _lastQuestion => _index == _steps.length - 2; // the step before build

  void _next() {
    if (_step == _Step.body && !_bodyForm.currentState!.validate()) return;
    if (_step == _Step.schedule && !_scheduleForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_lastQuestion) {
      _submit();
    } else {
      setState(() {
        _step = _steps[_index + 1];
        _search.clear();
      });
      if (_step == _Step.assess && _assessTurns.isEmpty && _assessLevels == null) _assessSend(null);
    }
  }

  /// One turn of the level check: the answers so far go to coach-chat (assess), which replies with its next question
  /// or, at the end, a verdict with a level 0 to 3 for each goal.
  Future<void> _assessSend(String? answer) async {
    if (answer != null) _assessTurns.add((role: 'user', content: answer));
    setState(() {
      _assessBusy = true;
      _assessError = null;
    });
    final birth = int.tryParse(_birthYear.text);
    try {
      final res = await supabase.functions.invoke('coach-chat', body: {
        'assess': {
          'goals': [for (final g in _goals) {'id': g, 'name': _nameOf(g), 'experience': _level[g]}],
          'body': {
            'sex': _sex,
            if (birth != null) 'age': _thisYear - birth,
            'heightCm': double.tryParse(_height.text),
            'weightKg': double.tryParse(_weight.text),
            'bodyType': _bodyType,
            'weightGoal': _weightGoal,
            'activity': _activityLevel,
            'daysPerWeek': _days,
            'minutes': _minutes,
            'equipment': _gear,
            'healthFlag': _health.isNotEmpty,
            'injury': _injuries.text.trim().isNotEmpty,
          },
          'turns': [for (final t in _assessTurns) {'role': t.role, 'content': t.content}],
        },
      });
      final data = (res.data as Map).cast<String, dynamic>();
      _assessTurns.add((role: 'assistant', content: data['reply'] as String));
      final levels = data['levels'];
      if (levels is Map) _assessLevels = {for (final e in levels.entries) e.key as String: (e.value as num).toInt()};
    } on FunctionException catch (e) {
      final d = e.details;
      _assessError = d is Map && d['error'] is String ? d['error'] as String : 'Levlofit AI could not answer. Try again, or skip.';
      if (answer != null) _assessTurns.removeLast(); // keep the answer in the box to resend
      if (answer != null) _assessInput.text = answer;
    } catch (_) {
      _assessError = 'Could not reach Levlofit AI. Check your connection, or skip.';
      if (answer != null) {
        _assessTurns.removeLast();
        _assessInput.text = answer;
      }
    } finally {
      if (mounted) setState(() => _assessBusy = false);
    }
  }

  void _addOther() {
    final v = _otherInput.text.trim();
    if (v.length < 2 || _other.length >= 10) return;
    setState(() {
      if (!_other.any((o) => o.toLowerCase() == v.toLowerCase())) _other.add(v);
      _noRestrictions = false;
      _otherInput.clear();
    });
  }

  void _addItem() {
    final v = _itemInput.text.trim();
    if (v.length < 2 || _items.length >= 20) return;
    setState(() {
      _items.add(v);
      _itemInput.clear();
    });
  }

  /// Coach review: where you are now, and what the engine found or changed, with sources.
  List<Widget> _reviewAnswers(BuildContext context) {
    final plan = _plan ?? const <String, dynamic>{};
    final snap = (plan['snapshot'] as Map?) ?? const {};
    final bmi = snap['bmi'] as Map?;
    final strengths = ((snap['strengths'] as List?) ?? const []).cast<String>();
    final gaps = ((snap['gaps'] as List?) ?? const []).cast<String>();
    final findings = ((plan['review'] as List?) ?? const []).cast<Map<String, dynamic>>();
    String phase(Object? k) => _phases[k]?.$1 ?? '$k';
    return [
      Text('WHERE YOU ARE NOW', style: monoLabel(context)),
      const SizedBox(height: 8),
      if (bmi != null) _Fact('BMI', '${bmi['value']}, ${bmi['category']}'),
      if (strengths.isNotEmpty) _Fact('Strengths', strengths.join(', ')),
      if (gaps.isNotEmpty) _Fact('Starting points', gaps.join(', ')),
      _Fact(
        'Plan phase',
        plan['chosenWeightGoal'] == plan['weightGoal']
            ? phase(plan['weightGoal'])
            : '${phase(plan['weightGoal'])} (you chose ${phase(plan['chosenWeightGoal'])})',
      ),
      if (findings.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('WHAT I FOUND', style: monoLabel(context)),
        const SizedBox(height: 8),
        for (final f in findings) ...[FindingCard(f), const SizedBox(height: 10)],
      ],
    ];
  }

  void _back() => setState(() {
    _step = _steps[_index - 1];
    _error = null;
    _search.clear();
  });

  Future<void> _submit() async {
    setState(() {
      _step = _Step.build;
      _busy = true;
      _error = null;
    });
    final uid = supabase.auth.currentUser!.id;
    try {
      if (!widget.goalsOnly) await _saveProfileAndDiet(uid);
      // ponytail: delete + insert is not atomic; a failed insert is fixed by retrying. Move to an RPC if it bites.
      await supabase.from('user_goals').delete().eq('user_id', uid);
      await supabase.from('user_goals').insert([
        for (final (i, g) in _goals.indexed) {'user_id': uid, 'goal': g, 'experience': _level[g], 'priority': i + 1},
      ]);
      // Levels from the level check replace the self-rating (0 to 3, as the goal_levels policy allows).
      final assessed = _assessLevels;
      if (assessed != null && !_assessSkipped) {
        await supabase.from('goal_levels').upsert([
          for (final g in _goals)
            if (assessed[g] != null) {'goal': g, 'level': assessed[g]!.clamp(0, 3), 'assessed_at': DateTime.now().toUtc().toIso8601String()},
        ]);
      }
      final res = await supabase.functions.invoke('generate-plan');
      _plan = ((res.data as Map)['plan'] as Map).cast<String, dynamic>();
      _step = _Step.review; // explain the plan before showing it
    } on FunctionException catch (e) {
      final details = e.details;
      _error = details is Map && details['error'] is String ? details['error'] as String : 'Could not build your plan. Try again.';
    } catch (_) {
      _error = 'Could not save your answers. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfileAndDiet(String uid) async {
    await supabase
        .from('profiles')
        .update({
          'display_name': _name.text.trim(),
          'birth_year': int.parse(_birthYear.text),
          'sex': _sex,
          'height_cm': double.parse(_height.text),
          'weight_kg': double.parse(_weight.text),
          'weight_goal': _weightGoal,
          'equipment': _gear,
          'equipment_items': _gear == 'custom' ? _items.toList() : <String>[],
          'body_type': _bodyType,
          'days_per_week': _days,
          'session_minutes': _minutes,
          'daily_activity': _activityLevel,
          'sleep_hours': double.tryParse(_sleep.text),
          'health_flags': _health.toList(),
          'injuries': _injuries.text.trim().isEmpty ? null : _injuries.text.trim(),
        })
        .eq('id', uid);
    await supabase.from('dietary_profiles').upsert({
      'user_id': uid,
      'diet_type': _diet,
      'budget_tier': _budget,
      'budget_max_inr': _budget == 'custom' ? dailyFromMonthly(int.parse(_monthly.text)) : null,
      'cuisine_region': _region,
      'restrictions': _avoid.toList(),
      'other_restrictions': _other,
      'supplements': _supp.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = _steps.length - 1;
    final canGoBack = _index > 0 && !_busy && _step != _Step.review;
    final canClose = widget.goalsOnly && _index == 0; // editing goals: leave without changes

    return PopScope(
      canPop: _index == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canGoBack) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: canGoBack
              ? IconButton(tooltip: 'Back', icon: const Icon(LvIcons.arrowLeft), onPressed: _back)
              : canClose
              ? IconButton(tooltip: 'Close', icon: const Icon(LvIcons.x), onPressed: () => Navigator.pop(context))
              : null,
          automaticallyImplyLeading: false,
          titleSpacing: canGoBack || canClose ? 0 : 24,
          title: Semantics(
            label: _step == _Step.review ? 'Plan review' : 'Question ${_index + 1} of $questions',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _step == _Step.review ? 1.0 : (_index + 1) / questions),
                duration: motion(context, 250),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(value: v.clamp(0, 1), minHeight: 4),
              ),
            ),
          ),
          actions: [
            // First run only: a way out before the plan exists (Profile, with the same actions, comes after it).
            if (!widget.goalsOnly)
              PopupMenuButton<_AccountAction>(
                tooltip: 'Account',
                icon: const Icon(LvIcons.userCircle),
                enabled: !_busy,
                onSelected: (a) => a == _AccountAction.signOut ? signOutAndClearReminders() : confirmAndDeleteAccount(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _AccountAction.signOut, child: Text('Sign out')),
                  PopupMenuItem(value: _AccountAction.delete, child: Text('Delete account')),
                ],
              ),
            SizedBox(width: widget.goalsOnly ? 24 : 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: motion(context),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: ListView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: staggered([
                      _CoachBubble(_coachLine, thinking: _busy),
                      const SizedBox(height: 24),
                      ..._answers(context),
                    ]),
                  ),
                ),
              ),
              if (_step == _Step.review)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: widget.onDone, child: const Text('See my plan')),
                  ),
                )
              else if (_step != _Step.build)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canContinue ? _next : null,
                      child: Text(switch (_step) {
                        _ when _lastQuestion => widget.goalsOnly ? 'Update my plan' : 'Build my plan',
                        _Step.extras when _goals.length == 1 => 'Skip',
                        _ => 'Continue',
                      }),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Searchable goal catalog, grouped by category in catalog order.
  List<Widget> _goalList(BuildContext context, {required String? header, required String? exclude, required Widget Function(_Goal) tileFor}) {
    final catalog = _catalog;
    if (catalog == null) {
      return [
        if (_catalogFailed) ...[
          const ErrorLine('Could not load the list of sports. Check your connection.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadCatalog, child: const Text('Try again')),
        ] else
          const LinearProgressIndicator(minHeight: 4),
      ];
    }
    final q = _search.text.trim().toLowerCase();
    final shown = catalog.where((g) => g.id != exclude && (q.isEmpty || g.name.toLowerCase().contains(q) || g.category.toLowerCase().contains(q)));
    final widgets = <Widget>[
      if (header != null) ...[Text(header, style: monoLabel(context)), const SizedBox(height: 12)],
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search ${catalog.length} sports and activities',
          prefixIcon: const Icon(LvIcons.magnifyingGlass, size: 20),
          suffixIcon: q.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(LvIcons.x, size: 18), onPressed: () => setState(_search.clear)),
        ),
      ),
    ];
    String? category;
    for (final g in shown) {
      if (g.category != category) {
        category = g.category;
        widgets.addAll([const SizedBox(height: 20), Text(category.toUpperCase(), style: monoLabel(context)), const SizedBox(height: 10)]);
      }
      widgets.addAll([tileFor(g), const SizedBox(height: 10)]);
    }
    if (shown.isEmpty) {
      widgets.addAll([const SizedBox(height: 20), Text('Nothing matches "$q". Try a shorter word.', style: Theme.of(context).textTheme.bodySmall)]);
    }
    return widgets;
  }

  List<Widget> _answers(BuildContext context) {
    const gap = SizedBox(height: 10);
    switch (_step) {
      case _Step.name:
        return [
          const FieldLabel('Your name'),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _canContinue ? _next() : null,
            decoration: const InputDecoration(counterText: ''),
          ),
        ];

      case _Step.primary:
        return _goalList(
          context,
          header: null,
          exclude: null,
          tileFor: (g) => ChoiceTile(
            title: g.name,
            selected: _goals.isNotEmpty && _goals.first == g.id,
            tag: _goals.isNotEmpty && _goals.first == g.id ? 'PRIMARY' : null,
            onTap: () => setState(() {
              if (_goals.isNotEmpty) _goals.removeAt(0); // replace the old primary
              _goals.remove(g.id); // if it was an extra, it moves up
              _goals.insert(0, g.id);
            }),
          ),
        );

      case _Step.extras:
        final extras = _goals.skip(1).toList();
        return _goalList(
          context,
          header: '${extras.length} OF $_maxExtras ADDED  ·  OPTIONAL',
          exclude: _goals.first,
          tileFor: (g) => ChoiceTile(
            title: g.name,
            selected: extras.contains(g.id),
            enabled: extras.contains(g.id) || extras.length < _maxExtras,
            onTap: () => setState(() => extras.contains(g.id) ? _goals.remove(g.id) : _goals.add(g.id)),
          ),
        );

      case _Step.experience:
        return [
          for (final g in _goals) ...[
            Text(_nameOf(g), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _Grid2([
              for (final MapEntry(key: e, value: (title, sub)) in _experience.entries)
                ChoiceTile(title: title, subtitle: sub, selected: _level[g] == e, onTap: () => setState(() => _level[g] = e)),
            ]),
            const SizedBox(height: 24),
          ],
        ];

      case _Step.restrictions:
        return [
          ChoiceTile(
            title: 'None',
            subtitle: 'No allergies or intolerances',
            selected: _noRestrictions,
            onTap: () => setState(() {
              _noRestrictions = !_noRestrictions;
              if (_noRestrictions) {
                _avoid.clear();
                _other.clear();
              }
            }),
          ),
          const SizedBox(height: 20),
          Text('OR PICK ALL THAT APPLY', style: monoLabel(context)),
          const SizedBox(height: 12),
          for (final MapEntry(key: r, value: label) in _restrictions.entries) ...[
            ChoiceTile(
              title: label,
              selected: _avoid.contains(r),
              onTap: () => setState(() {
                _avoid.contains(r) ? _avoid.remove(r) : _avoid.add(r);
                _noRestrictions = false;
                if (r == 'egg' && _diet == 'eggitarian') _diet = null;
              }),
            ),
            gap,
          ],
          const SizedBox(height: 10),
          const FieldLabel('Something else?'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _otherInput,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  enabled: _other.length < 10,
                  onSubmitted: (_) => _addOther(),
                  decoration: const InputDecoration(hintText: 'e.g. sesame, mustard, kiwi', counterText: ''),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(onPressed: _addOther, child: const Text('Add')),
              ),
            ],
          ),
          if (_other.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in _other)
                  InputChip(
                    label: Text(o),
                    onDeleted: () => setState(() => _other.remove(o)),
                    deleteButtonTooltipMessage: 'Remove $o',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
              ],
            ),
          ],
        ];

      case _Step.assess:
        final t = Theme.of(context).textTheme;
        final c = Theme.of(context).colorScheme;
        return [
          for (final turn in _assessTurns)
            Align(
              alignment: turn.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: turn.role == 'user' ? c.secondary : c.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(turn.content, style: t.bodyMedium?.copyWith(color: turn.role == 'user' ? c.onSecondary : c.onSurface, height: 1.4)),
              ),
            ),
          if (_assessBusy) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 3)),
          if (_assessError != null) ...[ErrorLine(_assessError!), gap],
          if (_assessLevels != null) ...[
            Text('YOUR STARTING LEVELS', style: monoLabel(context)),
            const SizedBox(height: 6),
            for (final g in _goals) Text('${_nameOf(g)}: Level ${_assessLevels![g]}', style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('You can move up any time by passing the level check in Workout.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ] else if (!_assessSkipped) ...[
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _assessInput,
                  enabled: !_assessBusy && _assessTurns.isNotEmpty,
                  textInputAction: TextInputAction.send,
                  maxLength: 600,
                  decoration: const InputDecoration(hintText: 'Your answer', counterText: ''),
                  onSubmitted: (v) {
                    if (v.trim().isEmpty || _assessBusy) return;
                    _assessInput.clear();
                    _assessSend(v.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: _assessBusy
                    ? null
                    : () {
                        if (_assessTurns.isEmpty) {
                          _assessSend(null);
                          return;
                        }
                        final v = _assessInput.text.trim();
                        if (v.isEmpty) return;
                        _assessInput.clear();
                        _assessSend(v);
                      },
                icon: Icon(_assessTurns.isEmpty ? LvIcons.arrowsClockwise : LvIcons.arrowUp),
              ),
            ]),
            TextButton(
              onPressed: _assessBusy ? null : () => setState(() => _assessSkipped = true),
              child: const Text('Skip and use my own ratings'),
            ),
          ] else
            Text('Your own ratings will be used. The plan still checks your body numbers.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        ];

      case _Step.diet:
        return [
          for (final MapEntry(key: d, value: (title, sub)) in _diets.entries) ...[
            ChoiceTile(
              title: title,
              subtitle: sub,
              selected: _diet == d,
              enabled: !(d == 'eggitarian' && _avoid.contains('egg')),
              disabledNote: 'Not available with an egg allergy',
              onTap: () => setState(() => _diet = d),
            ),
            gap,
          ],
          const SizedBox(height: 16),
          const FieldLabel('Food budget'),
          for (final (k, title, sub) in [...budgetOptions, ('custom', 'My own amount', 'Enter what you spend on food in a month')]) ...[
            ChoiceTile(title: title, subtitle: sub, selected: _budget == k, onTap: () => setState(() => _budget = k)),
            gap,
          ],
          if (_budget == 'custom') ...[
            TextField(
              controller: _monthly,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Food budget for a month', prefixText: 'Rs ', suffixText: 'a month', helperText: 'At least Rs 900'),
            ),
            gap,
          ],
          const SizedBox(height: 16),
          const FieldLabel('Your regional food'),
          for (final (k, title, sub) in regionOptions) ...[
            ChoiceTile(title: title, subtitle: sub, selected: _region == k, onTap: () => setState(() => _region = k)),
            gap,
          ],
          const SizedBox(height: 16),
          const FieldLabel('Open to supplements?'),
          ChoiceTile(
            title: 'No supplements',
            subtitle: 'Food only',
            selected: _noSupp,
            onTap: () => setState(() {
              _noSupp = !_noSupp;
              if (_noSupp) _supp.clear();
            }),
          ),
          gap,
          for (final MapEntry(key: k, value: (title, sub)) in _supplements.entries) ...[
            ChoiceTile(
              title: title,
              subtitle: sub,
              selected: _supp.contains(k),
              onTap: () => setState(() {
                _supp.contains(k) ? _supp.remove(k) : _supp.add(k);
                _noSupp = false;
              }),
            ),
            gap,
          ],
          Text(
            'I only suggest what the evidence supports for your goals, with the dose and the reason.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ];

      case _Step.body:
        final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
        String? range(String? v, num min, num max, String what) {
          final n = num.tryParse(v ?? '');
          return n == null || n < min || n > max ? 'Enter $what between $min and $max' : null;
        }
        return [
          Form(
            key: _bodyForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Year of birth'),
                TextFormField(
                  controller: _birthYear,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  decoration: InputDecoration(hintText: '${_thisYear - 25}', helperText: 'Levlofit plans are for adults, 18 to 80'),
                  validator: (v) => range(v, _thisYear - 80, _thisYear - 18, 'a year'),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FieldLabel('Height'),
                          TextFormField(
                            controller: _height,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: digits,
                            decoration: const InputDecoration(suffixText: 'cm'),
                            validator: (v) => range(v, 120, 230, 'cm'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FieldLabel('Weight'),
                          TextFormField(
                            controller: _weight,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: digits,
                            decoration: const InputDecoration(suffixText: 'kg'),
                            validator: (v) => range(v, 30, 250, 'kg'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Sex, for the energy formula'),
          _Grid2([
            for (final MapEntry(key: s, value: label) in _sexes.entries) ChoiceTile(title: label, selected: _sex == s, onTap: () => setState(() => _sex = s)),
          ]),
          const SizedBox(height: 20),
          const FieldLabel('How would you describe your body today?'),
          for (final MapEntry(key: b, value: (title, sub)) in _bodyTypes.entries) ...[
            ChoiceTile(title: title, subtitle: sub, selected: _bodyType == b, onTap: () => setState(() => _bodyType = b)),
            gap,
          ],
        ];

      case _Step.phase:
        return [
          for (final MapEntry(key: w, value: (title, sub)) in _phases.entries) ...[
            ChoiceTile(title: title, subtitle: sub, selected: _weightGoal == w, onTap: () => setState(() => _weightGoal = w)),
            gap,
          ],
        ];

      case _Step.schedule:
        return [
          const FieldLabel('Days a week you can train'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (var d = 1; d <= 7; d++) _Pill('$d', selected: _days == d, onTap: () => setState(() => _days = d))],
          ),
          const SizedBox(height: 20),
          const FieldLabel('Time per session'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final m in _minuteOptions) _Pill('$m min', selected: _minutes == m, onTap: () => setState(() => _minutes = m))],
          ),
          const SizedBox(height: 20),
          const FieldLabel('Outside training, your day is'),
          for (final MapEntry(key: a, value: (title, sub)) in _activity.entries) ...[
            ChoiceTile(title: title, subtitle: sub, selected: _activityLevel == a, onTap: () => setState(() => _activityLevel = a)),
            gap,
          ],
          const SizedBox(height: 10),
          Form(
            key: _scheduleForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Sleep on a normal night (optional)'),
                TextFormField(
                  controller: _sleep,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(suffixText: 'hours'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final n = num.tryParse(v);
                    return n == null || n < 3 || n > 12 ? 'Enter hours between 3 and 12' : null;
                  },
                ),
              ],
            ),
          ),
        ];

      case _Step.health:
        return [
          ChoiceTile(
            title: 'None of these',
            selected: _noHealth,
            onTap: () => setState(() {
              _noHealth = !_noHealth;
              if (_noHealth) _health.clear();
            }),
          ),
          const SizedBox(height: 16),
          for (final MapEntry(key: h, value: label) in _healthScreen.entries) ...[
            ChoiceTile(
              title: label,
              selected: _health.contains(h),
              onTap: () => setState(() {
                _health.contains(h) ? _health.remove(h) : _health.add(h);
                _noHealth = false;
              }),
            ),
            gap,
          ],
          const SizedBox(height: 10),
          const FieldLabel('Any injury or pain to work around? (optional)'),
          TextField(
            controller: _injuries,
            maxLength: 300,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. left knee hurts on stairs'),
          ),
        ];

      case _Step.equipment:
        return [
          for (final MapEntry(key: e, value: (title, sub)) in _equipment.entries) ...[
            ChoiceTile(title: title, subtitle: sub, selected: _gear == e, onTap: () => setState(() => _gear = e)),
            gap,
          ],
          if (_gear == 'custom') ...[
            const SizedBox(height: 10),
            const FieldLabel('What do you have?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in {..._equipmentItems, ..._items})
                  _Pill(item, selected: _items.contains(item), onTap: () => setState(() => _items.contains(item) ? _items.remove(item) : _items.add(item))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemInput,
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                    decoration: const InputDecoration(hintText: 'Something else, e.g. parallettes', counterText: ''),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(onPressed: _addItem, child: const Text('Add')),
                ),
              ],
            ),
          ],
        ];

      case _Step.review:
        return _reviewAnswers(context);

      case _Step.build:
        return [
          if (_busy) const LinearProgressIndicator(minHeight: 4),
          if (_error != null) ...[
            ErrorLine(_error!),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Try again')),
            const SizedBox(height: 8),
            TextButton(onPressed: () => setState(() => _step = _steps[_steps.length - 2]), child: const Text('Review my answers')),
          ],
        ];
    }
  }
}

enum _AccountAction { signOut, delete }

class _CoachBubble extends StatelessWidget {
  const _CoachBubble(this.text, {this.thinking = false});
  final String text;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LevloMark(size: 32, animate: thinking),
        const SizedBox(width: 12),
        Flexible(
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.outline),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ),
      ],
    );
  }
}

class _Grid2 extends StatelessWidget {
  const _Grid2(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 10),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ),
      ],
    ],
  );
}

/// DESIGN.md choice: radius 10, 52 px min, selected = ink fill with a check.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.tag,
    this.enabled = true,
    this.disabledNote,
  });
  final String title;
  final String? subtitle, tag, disabledNote;
  final bool selected, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fg = selected ? c.onSecondary : c.onSurface;
    final sub = selected ? c.onSecondary.withValues(alpha: 0.75) : c.onSurfaceVariant;
    final note = !enabled ? disabledNote : null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Pressable(
          child: Material(
            color: selected ? c.secondary : c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: selected ? c.secondary : c.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap();
                    }
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: t.titleMedium?.copyWith(color: fg)),
                            if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: sub)),
                            if (note != null) Text(note, style: t.bodySmall?.copyWith(color: sub)),
                          ],
                        ),
                      ),
                      if (tag != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                          child: Text(tag!, style: monoLabel(context).copyWith(color: graphite)),
                        ),
                      // The check pops in on the brand ease instead of appearing.
                      AnimatedScale(
                        scale: selected ? 1 : 0,
                        duration: motion(context, 320),
                        curve: selected ? spring : Curves.easeInCubic,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(LvIcons.check, size: 20, color: fg),
                        ),
                      ),
                    ],
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

/// One coach-review finding: level tag, title, reason and source. Also used on the dashboard.
class FindingCard extends StatelessWidget {
  const FindingCard(this.finding, {super.key});
  final Map<String, dynamic> finding;

  static const _labels = {'stop': 'SEE A DOCTOR FIRST', 'change': 'CHANGED', 'advice': 'ADVICE', 'info': 'NOTE'};

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final level = finding['level'] as String? ?? 'info';
    final strong = level == 'stop' || level == 'change';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level == 'stop' ? c.error : (strong ? c.onSurface : c.outline), width: strong ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_labels[level] ?? 'NOTE', style: monoLabel(context).copyWith(color: level == 'stop' ? c.error : null)),
          const SizedBox(height: 6),
          Text(finding['title'] as String? ?? '', style: t.titleMedium),
          const SizedBox(height: 6),
          Text(finding['why'] as String? ?? '', style: t.bodyMedium),
          const SizedBox(height: 8),
          Text('Source: ${finding['source'] ?? ''}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Compact choice for short options (days, minutes, equipment items). Min 44 px touch target.
class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.secondary : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? c.secondary : c.outline),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? c.onSecondary : c.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

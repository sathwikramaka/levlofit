// The training week: which planned session falls on which weekday, plus the engine's 20-minute add-on blocks.
// Deterministic and pure, so the dashboard, reminders, calendar and tests all see the same week.
// It places what the plan engine (supabase/functions/_shared/plan-engine.ts) asked for and never invents or drops
// a session: goal sessions, the extra strength sessions that reach the WHO minimum of two strength days, and
// add-on blocks. When the requested load cannot fit the week with recovery between hard days, it says so.

typedef Json = Map<String, dynamic>;

/// Suggested training weekdays (1 = Monday) for each number of days a week: spread out, rest between hard days.
const weekPattern = {
  1: [3],
  2: [2, 5],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 5, 6],
  6: [1, 2, 3, 4, 5, 6],
  7: [1, 2, 3, 4, 5, 6, 7],
};

/// profiles.training_time, as the Protocol tab offers it (B6).
const trainingTimeOptions = [
  ('early_morning', 'Early morning'), ('morning', 'Morning'), ('midday', 'Midday'), ('evening', 'Evening'), ('night', 'Night'),
  ('varies', 'It varies (shifts)'),
];

/// The time of day the plan's sessions are for, or null when it varies or was never set.
String? trainingTimeLabel(Json plan) {
  final t = (plan['schedule'] as Map?)?['trainingTime'];
  if (t == null || t == 'varies') return null;
  return trainingTimeOptions.where((o) => o.$1 == t).firstOrNull?.$2;
}

/// The weekdays for [n] sessions (B6). Without chosen weekdays: [weekPattern]. With them: the [n] chosen days with the
/// fewest back-to-back pairs (earliest first on a tie), so sessions keep rest between them where the days allow. More
/// sessions than chosen days (an older plan): every chosen day, then the pattern's other days to fill.
List<int> trainingDaysFor(int n, List<int> preferred) {
  n = n.clamp(1, 7);
  final chosen = {...preferred.where((d) => d >= 1 && d <= 7)}.toList()..sort();
  if (chosen.isEmpty) return weekPattern[n]!;
  if (chosen.length <= n) {
    final fill = [for (var d = 1; d <= 7; d++) if (!chosen.contains(d)) d]
      ..sort((a, b) => (weekPattern[n]!.contains(b) ? 1 : 0) - (weekPattern[n]!.contains(a) ? 1 : 0));
    return ([...chosen, ...fill.take(n - chosen.length)])..sort();
  }
  int pairs(List<int> days) {
    final set = days.toSet();
    return days.where((d) => set.contains(d == 7 ? 1 : d + 1)).length; // Sunday then Monday counts too
  }
  List<int>? best;
  void pick(int from, List<int> sofar) {
    if (sofar.length == n) {
      if (best == null || pairs(sofar) < pairs(best!)) best = [...sofar];
      return;
    }
    for (var i = from; i < chosen.length; i++) {
      pick(i + 1, [...sofar, chosen[i]]);
    }
  }
  pick(0, []);
  return best!;
}

/// Session kinds that load the whole body hard enough to want a day between them (ACSM: about 48 h before
/// training the same muscles hard again). Endurance sessions here are easy-pace runs; mobility is light.
const hardKinds = {'strength', 'hybrid', 'skill'};

const addOnMinutes = 20;
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// An add-on block on [day]. [session] is the goal (or extra-strength session) whose moves it uses. [standalone]: a
/// short session of its own on a rest day, because no training day had room for it.
typedef AddOn = ({int day, String name, String kind, Json session, bool standalone});
typedef WeekPlan = ({Map<int, Json> days, List<AddOn> addOns, List<String> notices});

bool _isHard(Json s) => hardKinds.contains(s['kind'] ?? 'strength');

/// The session used for the engine's extra strength days. It reuses the person's own strength goal (name, level)
/// when they have one; otherwise the level is unknown, so it starts at the lightest dose and says so.
Json _extraStrength(List<Json> goals) {
  final strength = goals.where((g) => g['kind'] == 'strength').toList();
  final active = strength.where((g) => g['status'] != 'queued').firstOrNull;
  if (active != null) return {...active, 'extra': true};
  final levels = strength.map((g) => g['startLevel'] as int? ?? 0);
  return {
    'goal': 'strength',
    'name': 'Full-body strength',
    'kind': 'strength',
    'status': 'active',
    'startLevel': levels.isEmpty ? 0 : levels.reduce((a, b) => a > b ? a : b),
    'levelAssessed': levels.isNotEmpty,
    'extra': true,
  };
}

int _hardPairs(List<int> days, List<Json> order) {
  final hardOn = {for (final (i, d) in days.indexed) if (_isHard(order[i])) d};
  var pairs = 0;
  for (final d in hardOn) {
    if (hardOn.contains(d == 7 ? 1 : d + 1)) pairs++; // Sunday to Monday counts: the week repeats
  }
  return pairs;
}

int _sameGoalPairs(List<int> days, List<Json> order) {
  var pairs = 0;
  for (var i = 1; i < days.length; i++) {
    if (days[i] == days[i - 1] + 1 && order[i]['goal'] == order[i - 1]['goal']) pairs++;
  }
  return pairs;
}

/// Orders [queue] over [days] with the fewest back-to-back hard days, then the fewest back-to-back repeats of a
/// goal. Ties keep the round-robin order (primary goal first), so the result is stable for the same plan.
List<Json> _arrange(List<int> days, List<Json> queue) {
  var best = queue;
  var bestCost = (_hardPairs(days, queue), _sameGoalPairs(days, queue));
  final seen = <String>{};
  void search(List<Json> picked, List<Json> rest) {
    if (rest.isEmpty) {
      final key = picked.map((s) => s['goal']).join('|');
      if (!seen.add(key)) return;
      final cost = (_hardPairs(days, picked), _sameGoalPairs(days, picked));
      if (cost.$1 < bestCost.$1 || (cost.$1 == bestCost.$1 && cost.$2 < bestCost.$2)) {
        best = picked;
        bestCost = cost;
      }
      return;
    }
    final tried = <Object?>{};
    for (var i = 0; i < rest.length; i++) {
      if (!tried.add(rest[i]['goal'])) continue; // identical sessions give identical weeks
      search([...picked, rest[i]], [...rest]..removeAt(i));
    }
  }

  search(const [], queue);
  return best;
}

/// Builds the week from a stored plan. [sessionMinutes] is the person's session length. [estimate] gives a main
/// session's minutes (null when it cannot be estimated, such as a run); with both, add-on blocks are placed by time:
/// on a training day with room, else as a short session of their own on a rest day that keeps recovery spacing, else
/// on the best training day with the overrun reported. Without them the blocks go by recovery and spread only. The
/// training days themselves never depend on add-ons, so reminders and the calendar see the same days either way.
WeekPlan weekPlan(Json plan, {int? sessionMinutes, int? Function(Json session, int nth)? estimate}) {
  final goals = ((plan['goals'] as List?) ?? const []).cast<Json>();
  final notices = <String>[];

  // Every planned session, round-robin in priority order: primary goal first.
  final remaining = {for (final g in goals) g['goal']: (g['sessionsPerWeek'] as int?) ?? 0};
  final queue = <Json>[];
  while (remaining.values.any((n) => n > 0)) {
    for (final g in goals) {
      if (remaining[g['goal']]! > 0) {
        queue.add(g);
        remaining[g['goal']] = remaining[g['goal']]! - 1;
      }
    }
  }
  final extra = (plan['extraStrengthSessions'] as int?) ?? 0;
  for (var i = 0; i < extra; i++) {
    queue.add(_extraStrength(goals));
  }

  final planned = (plan['trainingDaysPerWeek'] as int?) ?? queue.length;
  if (planned != queue.length) {
    notices.add('Your plan counts $planned training days but lists ${queue.length} sessions. The week below shows every listed session.');
  }
  if (queue.isEmpty) return (days: const {}, addOns: const [], notices: notices);
  if (queue.length > 7) {
    notices.add('Your plan lists ${queue.length} sessions, more than the 7 days in a week. Rebuild the plan from Edit goals.');
  }
  // B6: the weekdays the person can train (plan.schedule.preferredDays, plan engine 3.4), else the usual pattern.
  final preferred = ((plan['schedule'] as Map?)?['preferredDays'] as List?)?.whereType<int>().toList() ?? const <int>[];
  final dayList = trainingDaysFor(queue.length, preferred);
  if (preferred.isNotEmpty && queue.length > preferred.toSet().length) {
    notices.add('Your plan has ${queue.length} sessions but you chose ${preferred.toSet().length} weekdays, so some sessions are on other days. '
        'Save your Protocol to rebuild the plan for your days.');
  }
  final placed = _arrange(dayList, queue.take(dayList.length).toList());
  final days = {for (final (i, d) in dayList.indexed) d: placed[i]};

  final hardPairs = <String>[];
  for (final d in dayList) {
    final next = d == 7 ? 1 : d + 1;
    if (_isHard(days[d]!) && days[next] != null && _isHard(days[next]!)) hardPairs.add('${_dayNames[d - 1]}–${_dayNames[next - 1]}');
  }
  if (hardPairs.isNotEmpty) {
    final hard = placed.where(_isHard).length;
    notices.add('Back-to-back hard days: ${hardPairs.join(', ')}. Your plan has $hard hard sessions in ${dayList.length} days, '
        'more than fit with a day between them, so those muscles get under 48 hours to recover. '
        'Go lighter on the second day: stop every set with 3 or more reps left.');
  }

  // Add-on blocks: the engine's strength blocks, then extra goals that only fit as blocks.
  final blocks = <({String name, String kind, Json session})>[
    for (var i = 0; i < ((plan['strengthAddOns'] as int?) ?? 0); i++) (name: 'Strength', kind: 'strength', session: _extraStrength(goals)),
    for (final g in goals)
      for (var i = 0; i < ((g['addOnBlocksPerWeek'] as int?) ?? 0); i++)
        (name: (g['name'] ?? g['goal']) as String, kind: (g['kind'] ?? 'strength') as String, session: g),
  ];
  final timed = sessionMinutes != null && estimate != null;
  // Each training day's main session estimate (A and B alternate per goal, as on the dashboard).
  final mainMinutes = <int, int?>{};
  if (timed) {
    for (final d in dayList) {
      final nth = [for (final x in dayList) if (x < d && days[x]!['goal'] == days[d]!['goal']) x].length;
      mainMinutes[d] = estimate(days[d]!, nth);
    }
  }
  final addOns = <AddOn>[];
  final used = <int, int>{};
  final overDays = <int, String>{}; // day -> why the add-on could not go elsewhere
  final recoveryDays = <int, String>{}; // day -> the hard block that made it hard next to hard work
  bool hardDay(int x) => (days[x] != null && _isHard(days[x]!)) || addOns.any((a) => a.day == x && hardKinds.contains(a.kind));
  for (final b in blocks) {
    final blockHard = hardKinds.contains(b.kind);
    int score(int d) {
      final s = days[d]!;
      final p = d == 1 ? 7 : d - 1, n = d == 7 ? 1 : d + 1;
      return (used[d] ?? 0) * 10 + // spread blocks over different days first
          (s['kind'] == b.kind ? 4 : 0) + // a block of the same kind adds little to that session
          (blockHard && _isHard(s) ? 2 : 0) + // keep hard blocks off hard days
          (blockHard && (hardDay(p) || hardDay(n)) ? 3 : 0); // and off days next to hard work
    }

    // Room on a training day: its main session plus the blocks already there plus this one. A session that cannot be
    // estimated (a run, whose main block has no set length) is taken to fill the whole setting.
    bool room(int d) => (mainMinutes[d] ?? sessionMinutes!) + addOnMinutes * ((used[d] ?? 0) + 1) <= sessionMinutes! + 5;

    final fitting = timed ? dayList.where(room).toList() : dayList;
    // A rest day can carry one block as its own session (5 min warm-up + the block); a hard block only where neither
    // neighbour is a hard day, so the 48-hour spacing holds.
    final restDays = !timed || fitting.isNotEmpty || addOnMinutes > sessionMinutes
        ? const <int>[]
        : [
            for (var d = 1; d <= 7; d++)
              if (!days.containsKey(d) && !addOns.any((a) => a.day == d) && !(blockHard && (hardDay(d == 1 ? 7 : d - 1) || hardDay(d == 7 ? 1 : d + 1)))) d
          ];
    if (restDays.isNotEmpty) {
      // Furthest from hard work first: a light block on the quietest rest day, ties to the earliest day.
      int near(int d) => (hardDay(d == 1 ? 7 : d - 1) ? 1 : 0) + (hardDay(d == 7 ? 1 : d + 1) ? 1 : 0);
      final day = restDays.reduce((a, c) => near(c) < near(a) ? c : a);
      used[day] = 1;
      addOns.add((day: day, name: b.name, kind: b.kind, session: b.session, standalone: true));
      continue;
    }
    var pool = fitting.isEmpty ? dayList : fitting;
    // With the time check, a hard block never makes a light day hard next to hard work when another day avoids it.
    bool breaksRecovery(int d) => blockHard && !hardDay(d) && (hardDay(d == 1 ? 7 : d - 1) || hardDay(d == 7 ? 1 : d + 1));
    if (timed && pool.any((d) => !breaksRecovery(d))) pool = pool.where((d) => !breaksRecovery(d)).toList();
    final day = pool.reduce((a, b) => score(b) < score(a) ? b : a); // first lowest score wins
    if (timed && breaksRecovery(day)) recoveryDays[day] = b.name;
    if (timed && !room(day)) {
      overDays[day] = addOnMinutes > sessionMinutes
          ? 'a $addOnMinutes-minute add-on does not fit a $sessionMinutes-minute session of its own either'
          : days.length == 7
              ? 'there is no rest day to take it'
              : 'no rest day could take it without breaking recovery or doubling up';
    }
    used[day] = (used[day] ?? 0) + 1;
    addOns.add((day: day, name: b.name, kind: b.kind, session: b.session, standalone: false));
  }
  for (final a in addOns.where((a) => a.standalone)) {
    notices.add('${_dayNames[a.day - 1]}: the ${a.name} add-on is its own short session (about ${addOnMinutes + 5} min with a warm-up), '
        'because no training day had room for it in $sessionMinutes minutes.');
  }
  for (final d in overDays.keys.toList()..sort()) {
    final total = (mainMinutes[d] ?? sessionMinutes!) + addOnMinutes * used[d]!;
    notices.add('${_dayNames[d - 1]}: the session with its add-on runs about $total min, over your $sessionMinutes-minute setting, '
        'because ${overDays[d]}. Accessory moves are left out first; the session shows what still fits.');
  }
  for (final d in recoveryDays.keys.toList()..sort()) {
    notices.add('${_dayNames[d - 1]}: the ${recoveryDays[d]} add-on makes this a hard day next to another hard day, because no other day '
        'had room. Go lighter: stop every set with 3 or more reps left.');
  }
  if (!timed && addOns.isNotEmpty && sessionMinutes != null) {
    notices.add('Days with an add-on run about ${sessionMinutes + addOnMinutes} min, '
        '$addOnMinutes min longer than your $sessionMinutes-minute sessions.');
  }
  if (used.values.any((n) => n > 1)) {
    notices.add('Some days carry more than one add-on block. If that is too long, keep one and move on.');
  }
  return (days: days, addOns: addOns, notices: notices);
}

/// Reminder sessions: each training weekday's session name, plus a rest day that carries an add-on session of its own.
Map<int, String> reminderSessions(WeekPlan w) => {
      for (final e in w.days.entries) e.key: (e.value['name'] ?? e.value['goal'] ?? 'Your session') as String,
      for (final a in w.addOns)
        if (a.standalone) a.day: '${a.name} add-on',
    };

/// One line per add-on, for the week header: "+20 min Strength on Tue", or "Strength, own 25-min session on Thu".
String addOnLine(AddOn a) => a.standalone
    ? '${a.name}, own ${addOnMinutes + 5}-min session on ${_dayNames[a.day - 1]}'
    : '+$addOnMinutes min ${a.name} on ${_dayNames[a.day - 1]}';

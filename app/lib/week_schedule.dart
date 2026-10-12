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

/// Session kinds that load the whole body hard enough to want a day between them (ACSM: about 48 h before
/// training the same muscles hard again). Endurance sessions here are easy-pace runs; mobility is light.
const hardKinds = {'strength', 'hybrid', 'skill'};

const addOnMinutes = 20;
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

typedef AddOn = ({int day, String name, String kind});
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

/// Builds the week from a stored plan. [sessionMinutes] is the person's session length, for the add-on notice.
WeekPlan weekPlan(Json plan, {int? sessionMinutes}) {
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
  final dayList = weekPattern[queue.length.clamp(1, 7)]!;
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
  final blocks = <({String name, String kind})>[
    for (var i = 0; i < ((plan['strengthAddOns'] as int?) ?? 0); i++) (name: 'Strength', kind: 'strength'),
    for (final g in goals)
      for (var i = 0; i < ((g['addOnBlocksPerWeek'] as int?) ?? 0); i++) (name: (g['name'] ?? g['goal']) as String, kind: (g['kind'] ?? 'strength') as String),
  ];
  final addOns = <AddOn>[];
  final used = <int, int>{};
  for (final b in blocks) {
    final blockHard = hardKinds.contains(b.kind);
    int score(int d) {
      final s = days[d]!;
      final p = d == 1 ? 7 : d - 1, n = d == 7 ? 1 : d + 1;
      bool hardDay(int x) => (days[x] != null && _isHard(days[x]!)) || addOns.any((a) => a.day == x && hardKinds.contains(a.kind));
      return (used[d] ?? 0) * 10 + // spread blocks over different days first
          (s['kind'] == b.kind ? 4 : 0) + // a block of the same kind adds little to that session
          (blockHard && _isHard(s) ? 2 : 0) + // keep hard blocks off hard days
          (blockHard && (hardDay(p) || hardDay(n)) ? 3 : 0); // and off days next to hard work
    }

    final day = dayList.reduce((a, b) => score(b) < score(a) ? b : a); // first lowest score wins
    used[day] = (used[day] ?? 0) + 1;
    addOns.add((day: day, name: b.name, kind: b.kind));
  }
  if (addOns.isNotEmpty && sessionMinutes != null) {
    notices.add('Days with an add-on run about ${sessionMinutes + addOnMinutes} min, '
        '$addOnMinutes min longer than your $sessionMinutes-minute sessions.');
  }
  if (used.values.any((n) => n > 1)) {
    notices.add('Some days carry more than one add-on block. If that is too long, keep one and move on.');
  }
  return (days: days, addOns: addOns, notices: notices);
}

/// One line per add-on, for the week header: "+20 min Strength on Tue".
String addOnLine(AddOn a) => '+$addOnMinutes min ${a.name} on ${_dayNames[a.day - 1]}';

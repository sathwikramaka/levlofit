import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/week_schedule.dart';

// Plans are real plan-engine output (supabase/functions/_shared/plan-engine.ts, generatePlan) for synthetic users,
// trimmed to the fields the scheduler reads. Regenerate them if the engine changes.
Json _plan(int days, int extra, int addOns, List<Json> goals) =>
    {'trainingDaysPerWeek': days, 'extraStrengthSessions': extra, 'strengthAddOns': addOns, 'goals': goals};
Json _goal(String goal, String kind, int level, int sessions, {String status = 'active', int addOnBlocks = 0}) => {
      'goal': goal,
      'name': goal[0].toUpperCase() + goal.substring(1),
      'kind': kind,
      'startLevel': level,
      'sessionsPerWeek': sessions,
      'addOnBlocksPerWeek': addOnBlocks,
      'status': status,
    };

final running6 = _plan(6, 2, 0, [_goal('running', 'endurance', 2, 4)]);
final running4 = _plan(4, 0, 2, [_goal('running', 'endurance', 2, 4)]);
final mixed6 = _plan(6, 0, 0, [_goal('strength', 'strength', 3, 4), _goal('running', 'endurance', 1, 1), _goal('mobility', 'mobility', 1, 1)]);
final runningFoundation = _plan(5, 2, 0, [_goal('running', 'endurance', 1, 3), _goal('strength', 'strength', 2, 0, status: 'queued')]);
final strength3 = _plan(3, 0, 0, [_goal('strength', 'strength', 1, 3)]);

int count(WeekPlan w, String goal) => w.days.values.where((s) => s['goal'] == goal).length;

/// Back-to-back hard days in the repeating week (Sunday to Monday included).
int hardPairs(WeekPlan w) {
  final hard = {for (final e in w.days.entries) if (hardKinds.contains(e.value['kind'])) e.key};
  return hard.where((d) => hard.contains(d == 7 ? 1 : d + 1)).length;
}

void main() {
  test('running, level 2, 6 days: the 2 extra strength sessions get days, none back to back', () {
    final w = weekPlan(running6);
    expect(w.days.length, 6, reason: 'one session per training day');
    expect(count(w, 'running'), 4);
    expect(count(w, 'strength'), 2);
    expect(hardPairs(w), 0);
    expect(w.notices, isEmpty);
  });

  test('extra strength with no strength goal starts at the lightest dose and says the level is unknown', () {
    final s = weekPlan(running6).days.values.firstWhere((s) => s['goal'] == 'strength');
    expect(s['levelAssessed'], isFalse);
    expect(s['startLevel'], 0);
    expect(s['kind'], 'strength');
  });

  test('extra strength reuses the person\'s own strength level when they have one (even if that goal is queued)', () {
    final w = weekPlan(runningFoundation);
    expect(w.days.length, 5);
    expect(count(w, 'running'), 3);
    final extras = w.days.values.where((s) => s['extra'] == true).toList();
    expect(extras.length, 2);
    expect(extras.every((s) => s['startLevel'] == 2 && s['levelAssessed'] == true), isTrue);
    expect(hardPairs(w), 0);
  });

  test('running, level 2, 4 days: both strength add-on blocks are placed on different days, with the time cost stated', () {
    final w = weekPlan(running4, sessionMinutes: 45);
    expect(w.days.length, 4);
    expect(count(w, 'running'), 4);
    expect(w.addOns.length, 2);
    expect(w.addOns.map((a) => a.day).toSet().length, 2, reason: 'spread over different days');
    final blockDays = w.addOns.map((a) => a.day).toSet();
    expect(blockDays.any((d) => blockDays.contains(d == 7 ? 1 : d + 1)), isFalse, reason: 'strength blocks back to back');
    expect(w.addOns.every((a) => a.kind == 'strength' && w.days.containsKey(a.day)), isTrue);
    expect(w.notices.single, contains('about 65 min'));
  });

  test('strength 4 + running + mobility on 6 days: every session placed, unavoidable back-to-back day reported', () {
    final w = weekPlan(mixed6);
    expect(w.days.length, 6);
    expect([count(w, 'strength'), count(w, 'running'), count(w, 'mobility')], [4, 1, 1]);
    // 4 full-body sessions over Mon to Sat cannot all have a day between them: the best order leaves one pair.
    expect(hardPairs(w), 1);
    expect(w.notices.single, startsWith('Back-to-back hard days:'));
  });

  test('3 strength days are spread Mon, Wed, Fri with no notice', () {
    final w = weekPlan(strength3);
    expect(w.days.keys.toList(), [1, 3, 5]);
    expect(hardPairs(w), 0);
    expect(w.notices, isEmpty);
  });

  test('no profile gets an empty training day or loses a session', () {
    for (final p in [running6, running4, mixed6, runningFoundation, strength3]) {
      final w = weekPlan(p);
      final planned = (p['goals'] as List).cast<Json>().fold<int>(0, (s, g) => s + (g['sessionsPerWeek'] as int)) + (p['extraStrengthSessions'] as int);
      expect(w.days.length, planned);
      expect(w.days.length, p['trainingDaysPerWeek']);
    }
  });

  test('a plan whose day count disagrees with its sessions is reported, not silently padded', () {
    final w = weekPlan(_plan(5, 0, 0, [_goal('strength', 'strength', 1, 3)]));
    expect(w.days.length, 3);
    expect(w.notices.first, contains('counts 5 training days but lists 3 sessions'));
  });

  test('the same plan always gives the same week', () {
    String key(WeekPlan w) => [for (final e in w.days.entries) '${e.key}:${e.value['goal']}', for (final a in w.addOns) 'a${a.day}'].join(',');
    for (final p in [running6, running4, mixed6]) {
      expect(key(weekPlan(p)), key(weekPlan(p)));
    }
  });
}

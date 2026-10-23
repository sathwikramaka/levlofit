import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/session.dart';
import 'package:levlo/week_schedule.dart';

// The integrated multi-goal week: add-on blocks get real moves, join a session day that has room or become a short
// session of their own on a rest day, and the day's time fit counts every add-on minute. Levlofit rules, COACH REVIEW
// PENDING (block size, placement order, trimming order).

Json _plan(List<Json> goals, {int extra = 0, int strengthAddOns = 0}) => {
      'trainingDaysPerWeek': goals.fold<int>(0, (s, g) => s + (g['sessionsPerWeek'] as int)) + extra,
      'extraStrengthSessions': extra,
      'strengthAddOns': strengthAddOns,
      'goals': goals,
    };
Json _goal(String goal, String kind, int level, int sessions, {int addOnBlocks = 0, String status = 'active'}) => {
      'goal': goal,
      'name': goal[0].toUpperCase() + goal.substring(1),
      'kind': kind,
      'startLevel': level,
      'sessionsPerWeek': sessions,
      'addOnBlocksPerWeek': addOnBlocks,
      'status': status,
    };

bool _hardKind(String? k) => hardKinds.contains(k ?? 'strength');
int _next(int d) => d == 7 ? 1 : d + 1;
int _prev(int d) => d == 1 ? 7 : d - 1;
bool _protected(String id) => restFor(id) == 120;

/// Every move a goal's sessions can use, both weekly variants, after kit swaps.
Set<String> _goalMoves(Json s, Tier tier, Set<Kit>? kit) => {
      for (var i = 0; i < 2; i++) ...sessionIds(s['kind'] as String? ?? 'strength', tier, s['startLevel'] as int? ?? 0, i, goal: s['goal'] as String?, kit: kit),
    };

/// The main session of [day] the way the dashboard builds it (A and B alternate per goal).
List<String> _mainIds(WeekPlan w, int day, Tier tier, Set<Kit>? kit) {
  final s = w.days[day]!;
  final nth = [for (var d = 1; d < day; d++) if (w.days[d]?['goal'] == s['goal']) d].length;
  return sessionIds(s['kind'] as String? ?? 'strength', tier, s['startLevel'] as int, nth, goal: s['goal'] as String?, kit: kit);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('add-on blocks have real moves', () {
    test('a strength block uses the strength session\'s own first-listed moves and fits 20 minutes', () {
      final b = addOnBlock(_goal('strength', 'strength', 0, 0), Tier.gym);
      expect(b.ids, isNotEmpty);
      expect(_goalMoves(_goal('strength', 'strength', 0, 0), Tier.gym, null).containsAll(b.ids), isTrue);
      expect(b.ids.first, sessionIds('strength', Tier.gym, 0, 0).first, reason: 'main lift first');
      expect(b.minutes, lessThanOrEqualTo(addOnMinutes));
      expect(b.minutes, blockMinutes(b.ids, 0));
    });

    test('the dose follows the person\'s level: level 3 lifts take 3 sets, so fewer moves fit than at level 0', () {
      final low = addOnBlock(_goal('strength', 'strength', 0, 0), Tier.home);
      final high = addOnBlock(_goal('strength', 'strength', 3, 0), Tier.home);
      expect(high.ids.length, lessThan(low.ids.length));
      expect(high.level, 3);
      expect(high.minutes, lessThanOrEqualTo(addOnMinutes));
    });

    test('an endurance block is a warm-up drill and an easy run that fill the 20 minutes', () {
      final b = addOnBlock(_goal('running', 'endurance', 2, 0), Tier.none);
      expect(b.ids.length, 2);
      expect(doseFor(b.ids.last, 2), contains('easy'));
      expect(b.minutes, addOnMinutes);
    });

    test('a yoga block is the pose flow, holds only', () {
      final b = addOnBlock(_goal('yoga', 'mobility', 1, 0), Tier.none);
      expect(b.ids, isNotEmpty);
      expect(b.ids.every((id) => setsFor(id, 1) == 0), isTrue);
      expect(b.minutes, lessThanOrEqualTo(addOnMinutes));
    });

    test('kit swaps apply: without a pull-up bar a skill block has no pull-up', () {
      final b = addOnBlock(_goal('calisthenics', 'skill', 3, 0), Tier.none, kit: const {});
      expect(b.ids, isNot(contains('lBDjFxJ')));
      expect(_goalMoves(_goal('calisthenics', 'skill', 3, 0), Tier.none, const {}).containsAll(b.ids), isTrue);
    });

    test('moves already in the day\'s main session are not repeated; the other weekly variant fills in', () {
      final main = sessionIds('strength', Tier.none, 0, 0);
      final b = addOnBlock(_goal('strength', 'strength', 0, 0), Tier.none, exclude: main);
      expect(b.ids, isNotEmpty);
      expect(b.ids.where(main.contains), isEmpty);
    });

    test('missing moves: when every candidate is already in the session, the block is empty and costs no time', () {
      final all = _goalMoves(_goal('hybrid', 'hybrid', 1, 0), Tier.gym, null).toList();
      final b = addOnBlock(_goal('hybrid', 'hybrid', 1, 0), Tier.gym, exclude: all);
      expect(b.ids, isEmpty);
      expect(b.minutes, 0);
      expect(blockSummary(b), contains('already covered'));
    });
  });

  group('the day\'s time fit counts every add-on minute', () {
    final strength3 = sessionIds('strength', Tier.gym, 3, 0);
    final strengthBlock = addOnBlock(_goal('strength', 'strength', 0, 0), Tier.gym, exclude: sessionIds('endurance', Tier.gym, 2, 0));
    final runBlock = addOnBlock(_goal('running', 'endurance', 1, 0), Tier.gym);

    test('the day estimate is the main session plus each block', () {
      final f = fitDay(strength3, 3, [runBlock], null);
      expect(f.estimate, estimateMinutes(strength3, 3)! + runBlock.minutes);
      expect(f.main.leftOut, isEmpty);
    });

    test('over time: main accessories go first, then block moves (last first, one move per block kept), never a main lift', () {
      for (final minutes in [20, 30, 45, 60, 75, 90]) {
        final f = fitDay(strength3, 3, [runBlock], minutes);
        expect(f.main.leftOut.where(_protected), isEmpty, reason: '$minutes');
        expect(f.blocks.every((b) => b.ids.isNotEmpty), isTrue, reason: '$minutes');
        final fits = overTimeNotice(f.estimate, minutes) == null;
        final exhausted = f.main.ids.where((id) => !_protected(id)).isEmpty || f.main.ids.length <= minMovesWhenShortened;
        expect(fits || exhausted, isTrue, reason: 'stops trimming only when it fits or nothing more may go: $minutes');
        expect(f.estimate, f.main.estimate! + f.blocks.fold<int>(0, (s, b) => s + b.minutes), reason: '$minutes');
      }
    });

    test('block moves are trimmed only after the main session has nothing left to give', () {
      final f = fitDay(sessionIds('strength', Tier.home, 0, 0), 0, [strengthBlock], 30);
      if (f.blockLeftOut.isNotEmpty) {
        expect(f.main.ids.where((id) => !_protected(id)).isEmpty || f.main.ids.length <= minMovesWhenShortened, isTrue);
      }
    });

    test('a run session cannot be estimated: nothing is trimmed and blocks keep their own minutes', () {
      final run = sessionIds('endurance', Tier.none, 2, 0);
      final f = fitDay(run, 2, [strengthBlock], 30);
      expect(f.estimate, isNull);
      expect(f.main.ids, run);
      expect(f.blocks.single.ids, strengthBlock.ids);
    });

    test('infeasible: 20 minutes cannot hold a level-3 strength session and a block; the notice says so', () {
      final f = fitDay(strength3, 3, [runBlock], 20);
      expect(overTimeNotice(f.estimate, 20), isNotNull);
    });
  });

  group('placement in the week', () {
    // Strength primary, 4 days, level 3; running as a 20-minute add-on block.
    final strengthPlusRun = _plan([_goal('strength', 'strength', 3, 4), _goal('running', 'endurance', 1, 0, addOnBlocks: 1)]);

    test('a block joins a session day that has room', () {
      final w = weekPlan(strengthPlusRun, sessionMinutes: 75, estimate: sessionEstimator(Tier.gym, null));
      final a = w.addOns.single;
      expect(a.standalone, isFalse);
      expect(w.days.containsKey(a.day), isTrue);
    });

    test('no session day has room: the block becomes its own short session on a rest day', () {
      final w = weekPlan(strengthPlusRun, sessionMinutes: 45, estimate: sessionEstimator(Tier.gym, null));
      final a = w.addOns.single;
      expect(a.standalone, isTrue);
      expect(w.days.containsKey(a.day), isFalse);
      expect(w.notices.join(' '), contains('its own short session'));
    });

    test('recovery conflict: a hard block is never a standalone session next to a hard day; it joins a day instead', () {
      // Skill on Mon, Tue, Thu, Fri: every rest day touches a hard day.
      final p = _plan([_goal('calisthenics', 'skill', 2, 4)], strengthAddOns: 1);
      final w = weekPlan(p, sessionMinutes: 30, estimate: sessionEstimator(Tier.none, null));
      final a = w.addOns.single;
      expect(a.standalone, isFalse);
      expect(w.days.containsKey(a.day), isTrue);
      expect(w.notices.join(' '), contains('over your 30-minute'));
    });

    test('the sessions, their days and priorities are the same with or without the time check', () {
      for (final minutes in [20, 30, 45, 60, 90]) {
        final plain = weekPlan(strengthPlusRun);
        final timed = weekPlan(strengthPlusRun, sessionMinutes: minutes, estimate: sessionEstimator(Tier.gym, null));
        expect(timed.days.map((d, s) => MapEntry(d, s['goal'])), plain.days.map((d, s) => MapEntry(d, s['goal'])));
      }
    });

    test('7 training days, no rest day: the block joins a day and the notice says why it runs over', () {
      final p = _plan([_goal('strength', 'strength', 3, 7), _goal('running', 'endurance', 1, 0, addOnBlocks: 1)]);
      final w = weekPlan(p, sessionMinutes: 30, estimate: sessionEstimator(Tier.gym, null));
      expect(w.addOns.single.standalone, isFalse);
      expect(w.notices.join(' '), contains('there is no rest day'));
    });

    test('20-minute setting: a light block still fits as its own 25-minute session on a rest day (5 min slack)', () {
      final p = _plan([_goal('strength', 'strength', 1, 3), _goal('mobility', 'mobility', 1, 0, addOnBlocks: 1)]);
      final w = weekPlan(p, sessionMinutes: 20, estimate: sessionEstimator(Tier.home, null));
      final a = w.addOns.single;
      expect(a.standalone, isTrue);
      expect(addOnLine(a), contains('own 25-min session'));
      expect(blocksFor(w, a.day, Tier.home, null, const []).single.minutes, lessThanOrEqualTo(20));
    });

    test('two blocks on one day: no move repeats, and over time the last block gives up moves first', () {
      final p = _plan([_goal('strength', 'strength', 0, 1), _goal('hyrox', 'hybrid', 1, 0, addOnBlocks: 1), _goal('calisthenics', 'skill', 1, 0, addOnBlocks: 1)]);
      final w = weekPlan(p);
      expect(w.addOns.map((a) => a.day).toSet().length, 1, reason: 'one training day takes both');
      final day = w.addOns.first.day;
      final main = _mainIds(w, day, Tier.none, null);
      final blocks = blocksFor(w, day, Tier.none, null, main);
      final all = [...main, for (final b in blocks) ...b.ids];
      expect(all.toSet().length, all.length);
      expect(blocks.every((b) => b.ids.isNotEmpty), isTrue);
      final f = fitDay(main, 0, blocks, 45);
      if (f.blockLeftOut.isNotEmpty) {
        expect(blocks.last.ids, containsAll(f.blockLeftOut.take(1)), reason: 'last block first');
      }
    });

    test('a goal\'s two blocks in a week alternate its session variants', () {
      final w = weekPlan(_plan([_goal('running', 'endurance', 2, 4)], strengthAddOns: 2));
      final days = w.addOns.map((a) => a.day).toList();
      final first = blocksFor(w, days[0], Tier.gym, null, const []).single;
      final second = blocksFor(w, days[1], Tier.gym, null, const []).single;
      expect(first.ids.first, isNot(second.ids.first));
    });

    test('a run session is taken to fill the whole setting, so a block goes to a rest day instead of after the run', () {
      final p = _plan([_goal('running', 'endurance', 2, 4)], strengthAddOns: 1);
      final w = weekPlan(p, sessionMinutes: 45, estimate: sessionEstimator(Tier.gym, null));
      final a = w.addOns.single;
      expect(a.standalone, isTrue);
      expect(w.days.containsKey(a.day), isFalse);
    });

    test('reminders: training days by session name, plus a rest day that carries an add-on session', () {
      final p = _plan([_goal('strength', 'strength', 3, 4), _goal('running', 'endurance', 1, 0, addOnBlocks: 1)]);
      final w = weekPlan(p, sessionMinutes: 45, estimate: sessionEstimator(Tier.gym, null));
      final r = reminderSessions(w);
      final own = w.addOns.single;
      expect(r[own.day], 'Running add-on');
      for (final e in w.days.entries) {
        expect(r[e.key], e.value['name']);
      }
      expect(r.length, w.days.length + 1);
      expect(reminderSessions(weekPlan(p)), {for (final e in weekPlan(p).days.entries) e.key: e.value['name']}, reason: 'no time check: training days only');
    });

    test('without a time check the week keeps the old placement and the old time notice', () {
      final w = weekPlan(_plan([_goal('running', 'endurance', 2, 4)], strengthAddOns: 2), sessionMinutes: 45);
      expect(w.addOns.every((a) => !a.standalone && w.days.containsKey(a.day)), isTrue);
      expect(w.notices.single, contains('about 65 min'));
    });
  });

  test('every combination: real moves, no repeats in a day, recovery kept, time counted or the overrun reported', () {
    const kinds = [('strength', 'strength'), ('calisthenics', 'skill'), ('running', 'endurance'), ('hyrox', 'hybrid'), ('mobility', 'mobility'), ('yoga', 'mobility')];
    final kits = <Set<Kit>?>[null, const {}, const {Kit.dumbbells}];
    var checked = 0, standalone = 0, attached = 0, over = 0;
    for (final (pg, pk) in kinds) {
      for (final (xg, xk) in kinds) {
        if (xg == pg) continue;
        for (final sessions in [2, 3, 4, 5]) {
          for (final level in [0, 2, 4]) {
            for (final strengthAddOns in [0, 1]) {
              final plan = _plan([_goal(pg, pk, level, sessions), _goal(xg, xk, level, 0, addOnBlocks: 1)], strengthAddOns: strengthAddOns);
              final plain = weekPlan(plan);
              for (final tier in Tier.values) {
                for (final kit in kits) {
                  for (final minutes in [20, 30, 45, 60, 90]) {
                    final w = weekPlan(plan, sessionMinutes: minutes, estimate: sessionEstimator(tier, kit));
                    final why = '$pg+$xg s$sessions L$level a$strengthAddOns $tier $kit ${minutes}min';
                    expect(w.days.map((d, s) => MapEntry(d, s['goal'])), plain.days.map((d, s) => MapEntry(d, s['goal'])), reason: why);
                    expect(w.addOns.length, 1 + strengthAddOns, reason: why);
                    bool hardOn(int d) =>
                        (w.days[d] != null && _hardKind(w.days[d]!['kind'] as String?)) ||
                        w.addOns.any((a) => a.day == d && a.standalone && _hardKind(a.kind));
                    for (final a in w.addOns.where((a) => a.standalone)) {
                      standalone++;
                      expect(w.days.containsKey(a.day), isFalse, reason: why);
                      if (_hardKind(a.kind)) expect(hardOn(_prev(a.day)) || hardOn(_next(a.day)), isFalse, reason: 'recovery: $why');
                      final b = blocksFor(w, a.day, tier, kit, const []).single;
                      expect(b.ids, isNotEmpty, reason: why);
                      expect(b.minutes + 5, lessThanOrEqualTo(minutes + 5), reason: why);
                    }
                    for (final a in w.addOns.where((a) => !a.standalone && _hardKind(a.kind))) {
                      // A hard block that makes a light day hard next to hard work is reported.
                      final mainHard = _hardKind(w.days[a.day]!['kind'] as String?);
                      if (!mainHard && (hardOn(_prev(a.day)) || hardOn(_next(a.day)))) {
                        expect(w.notices.join(' '), contains('makes this a hard day'), reason: 'recovery: $why');
                      }
                    }
                    for (final day in w.days.keys) {
                      final main = _mainIds(w, day, tier, kit);
                      final blocks = blocksFor(w, day, tier, kit, main);
                      if (blocks.isEmpty) continue;
                      attached++;
                      final all = [...main, for (final b in blocks) ...b.ids];
                      expect(all.toSet().length, all.length, reason: 'no repeated move: $why');
                      for (final (i, b) in blocks.indexed) {
                        final spec = w.addOns.where((a) => a.day == day && !a.standalone).elementAt(i).session;
                        expect(_goalMoves(spec, tier, kit).containsAll(b.ids), isTrue, reason: 'real moves of that goal: $why');
                        expect(b.minutes, lessThanOrEqualTo(addOnMinutes), reason: why);
                      }
                      final f = fitDay(main, w.days[day]!['startLevel'] as int, blocks, minutes);
                      expect(f.main.leftOut.where(_protected), isEmpty, reason: why);
                      if (f.estimate != null) {
                        expect(f.estimate, f.main.estimate! + f.blocks.fold<int>(0, (s, b) => s + b.minutes), reason: why);
                        if (overTimeNotice(f.estimate, minutes) != null) over++;
                      }
                    }
                    checked++;
                  }
                }
              }
            }
          }
        }
      }
    }
    expect(checked, greaterThan(10000));
    expect(standalone, greaterThan(0));
    expect(attached, greaterThan(0));
    expect(over, greaterThan(0), reason: 'some combinations cannot fit and must be reported');
  });

  testWidgets('the session screen shows the add-on as its own section, at its own dose, and counts its sets', (tester) async {
    tester.view.physicalSize = const Size(390, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final main = sessionIds('strength', Tier.gym, 3, 0);
    final block = addOnBlock(_goal('strength', 'strength', 0, 0), Tier.gym, exclude: main);
    final rows = {for (final id in [...main, ...block.ids]) id: {'id': id, 'name': 'move $id', 'gif_url': 'https://media.invalid/$id.gif', 'target_muscles': <String>[]}};
    final missingId = block.ids.last;
    rows.remove(missingId); // one block move has no catalogue row
    final named = (name: 'Extra strength', goal: block.goal, kind: block.kind, level: block.level, ids: block.ids, minutes: block.minutes);
    await tester.pumpWidget(MaterialApp(
      home: SessionScreen(title: 'Strength', ids: main, level: 3, blocks: [named], moves: (ids) async => resolveMoves(ids, rows)),
    ));
    await tester.pump(const Duration(seconds: 2));
    final mainSets = main.fold<int>(0, (s, id) => s + setsFor(id, 3));
    final blockSets = block.ids.where((id) => id != missingId).fold<int>(0, (s, id) => s + setsFor(id, 0));
    expect(find.textContaining('OF ${mainSets + blockSets} SETS'), findsOneWidget, reason: 'main sets at level 3, block sets at level 0, missing move not counted');
    await tester.scrollUntilVisible(find.textContaining('ADD-ON: EXTRA STRENGTH'), 300);
    expect(find.textContaining('ADD-ON: EXTRA STRENGTH'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('1 move could not be loaded'), 300);
    expect(find.textContaining('1 move could not be loaded'), findsOneWidget);
  });
}

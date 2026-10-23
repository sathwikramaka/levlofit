import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/session.dart';

// Equipment-aware sessions and visible missing moves. The snapshot below is the session lists exactly as they were
// before kit swaps existed (copied from session.dart in backup levlo-b2-workout-20261013): with no kit information,
// every session must still match it.

const _before = {
  'strength/gym/A': ['qXTaZnJ', 'EIeI8Vf', 'fUBheHs', 'wQ2c4XD', 'iny3m5y'],
  'strength/gym/B': ['ila4NZS', 'znQUdHY', 'RVwzP10', 'RRWFUcw', 'qPEzJjA'],
  'strength/home/A': ['yn8yg1r', 'SpYC0Kp', 'BJ0Hz5L', 'rR0LJzx', 'iny3m5y'],
  'strength/home/B': ['aXtJhlg', 'A6wtbuL', 'I4hDWkc', 'qPEzJjA', 'RKjH6Lt'],
  'strength/none/A': ['QChZi3x', 'I4hDWkc', 'bZGHsAZ', 'u0cNiij', 'iny3m5y'],
  'strength/none/B': ['9E25EOx', 'B1EVP9F', 'wd4ds3s', 'IZVHb27', 'RKjH6Lt'],
  'skill/basics': ['bZGHsAZ', 'B1EVP9F', '9RT8oQW', 'QChZi3x', 'iny3m5y'],
  'skill/built': ['lBDjFxJ', 'I4hDWkc', '9WTm7dq', '9E25EOx', 'I3tsCnC'],
  'endurance': ['ealLwvX', 'DFGXwZr', 'oLrKqDH', 'bJYHBIN', '0mB6wHO'],
  'hybrid/kit': ['UHJlbu3', 'IZVHb27', 'dK9394r', 'qPEzJjA', 'oLrKqDH'],
  'hybrid/body': ['LIlE5Tn', 'IZVHb27', 'dK9394r', 'RJgzwny', 'oLrKqDH'],
  'mobility': ['DFGXwZr', '0mB6wHO', '99rWm7w', 'DeDThfG', 'f38OEuO', 'JbC2iaV'],
  'yoga': ['DIVyqrU', '01qpYSe', 'bWlZvXh', 'HIgYKAB', '2Dk4xQV', 'K5xgdvI', '2jl9K55', '6sYyrRX'],
};

List<String> _expectedBefore(String kind, Tier tier, int level, int index, String? goal) {
  if (goal == 'yoga') return _before['yoga']!;
  return switch (kind) {
    'skill' => _before[level <= 1 ? 'skill/basics' : 'skill/built']!,
    'endurance' => _before['endurance']!,
    'hybrid' => _before[tier == Tier.none ? 'hybrid/body' : 'hybrid/kit']!,
    'mobility' => _before['mobility']!,
    _ => _before['strength/${tier.name}/${index.isEven ? 'A' : 'B'}']!,
  };
}

const _kinds = ['strength', 'skill', 'endurance', 'hybrid', 'mobility'];

void main() {
  group('backward compatibility', () {
    test('with no kit information, every session is exactly what it was before', () {
      for (final kind in _kinds) {
        for (final tier in Tier.values) {
          for (var level = 0; level <= 5; level++) {
            for (var index = 0; index < 4; index++) {
              for (final goal in [null, 'yoga', 'strength']) {
                final want = _expectedBefore(kind, tier, level, index, goal);
                final why = '$kind/${tier.name}/L$level/#$index/$goal';
                expect(sessionIds(kind, tier, level, index, goal: goal), want, reason: why);
                expect(sessionIds(kind, tier, level, index, goal: goal, kit: null), want, reason: why);
              }
            }
          }
        }
      }
    });

    test('gym and the home preset carry no kit list, so their sessions do not change', () {
      expect(kitFor('gym', const []), isNull);
      expect(kitFor('home', const []), isNull);
      expect(kitFor(null, null), isNull);
      expect(kitOf(const {'equipment': 'home'}), isNull);
      expect(sessionIds('strength', Tier.home, 0, 0, kit: kitOf(const {'equipment': 'home'})), _before['strength/home/A']);
      expect(sessionIds('skill', Tier.gym, 3, 0, kit: kitOf(const {'equipment': 'gym'})), _before['skill/built']);
    });

    test('tiers for gym, home and none are unchanged', () {
      expect(tierFor('gym', null), Tier.gym);
      expect(tierFor('home', null), Tier.home);
      expect(tierFor('none', null), Tier.none);
      expect(tierFor(null, null), Tier.none);
    });
  });

  group('equipment', () {
    test('custom kit from onboarding (capitalised) is recognised; this used to fall back to bodyweight', () {
      expect(tierFor('custom', const ['Dumbbells']), Tier.home);
      expect(tierFor('custom', const ['Kettlebell']), Tier.home);
      expect(tierFor('custom', const ['dumbbells']), Tier.home);
      expect(tierFor('custom', const ['Pull-up bar', 'Yoga mat']), Tier.none);
      expect(tierFor('custom', const []), Tier.none);
    });

    test('kit list: onboarding items and free text map to kit, unknown items are ignored', () {
      expect(
        kitFor('custom', const ['Push-up board', 'Pull-up bar', 'Dip bars', 'Resistance bands', 'Dumbbells', 'Kettlebell', 'Skipping rope', 'Yoga mat', 'Bench', 'Barbell and plates']),
        {Kit.pullUpBar, Kit.dipBars, Kit.bands, Kit.dumbbells, Kit.kettlebell, Kit.bench, Kit.barbell},
      );
      expect(kitFor('custom', const ['chin up bar', 'adjustable bench']), {Kit.pullUpBar, Kit.bench});
      expect(kitFor('custom', const ['foam roller']), isEmpty);
      expect(kitFor('none', null), isEmpty);
    });

    test('no pull-up bar or dip bars: built skill sessions swap pull-ups and dips for moves done without them', () {
      for (final kit in [<Kit>{}, kitFor('custom', const ['Yoga mat'])!, kitFor('none', null)!]) {
        final ids = sessionIds('skill', Tier.none, 2, 0, kit: kit);
        expect(ids, isNot(contains('lBDjFxJ')), reason: 'pull-up needs a bar');
        expect(ids, isNot(contains('9WTm7dq')), reason: 'dip needs dip bars');
        // I3tsCnC is the catalogue's hanging leg raise (looked up 2026-10-17): it needs the bar too.
        expect(ids, isNot(contains('I3tsCnC')), reason: 'hanging leg raise needs a bar');
        expect(ids, ['bZGHsAZ', 'I4hDWkc', 'B1EVP9F', '9E25EOx', 'iny3m5y']);
      }
    });

    test('with a pull-up bar and dip bars, pull-ups and dips stay; each piece of kit counts on its own', () {
      expect(sessionIds('skill', Tier.none, 2, 0, kit: kitFor('custom', const ['Pull-up bar', 'Dip bars'])), _before['skill/built']);
      final barOnly = sessionIds('skill', Tier.none, 2, 0, kit: kitFor('custom', const ['Pull-up bar']));
      expect(barOnly, contains('lBDjFxJ'));
      expect(barOnly, isNot(contains('9WTm7dq')));
    });

    test('custom dumbbells without a bench: the dumbbell bench press becomes a push-up; with a bench it stays', () {
      final noBench = kitFor('custom', const ['Dumbbells']);
      final tier = tierFor('custom', const ['Dumbbells']);
      expect(sessionIds('strength', tier, 1, 0, kit: noBench), ['yn8yg1r', 'I4hDWkc', 'BJ0Hz5L', 'rR0LJzx', 'iny3m5y']);
      expect(sessionIds('strength', tier, 1, 0, kit: kitFor('custom', const ['Dumbbells', 'Bench'])), _before['strength/home/A']);
    });

    test('a swap never repeats a move and keeps the session length or shortens it by a duplicate only', () {
      final kits = [<Kit>{}, {Kit.pullUpBar}, {Kit.dipBars}, {Kit.bench}, Kit.values.toSet()];
      for (final kit in kits) {
        for (final kind in _kinds) {
          for (final tier in Tier.values) {
            for (var level = 0; level <= 5; level++) {
              for (var index = 0; index < 2; index++) {
                final ids = sessionIds(kind, tier, level, index, kit: kit);
                expect(ids.toSet().length, ids.length, reason: 'repeat in $kind/${tier.name}/L$level with $kit');
                expect(ids.length, _expectedBefore(kind, tier, level, index, null).length, reason: '$kind/${tier.name}/L$level with $kit');
              }
            }
          }
        }
      }
    });

    test('every swap target is a move the sessions already use, so it has a working animation', () {
      final known = _before.values.expand((l) => l).toSet();
      for (final MapEntry(:key, :value) in kitSwaps.entries) {
        expect(known, contains(key));
        expect(known, contains(value.$2), reason: 'swap for $key');
      }
    });
  });

  group('missing exercise ids', () {
    final rows = <String, Map<String, dynamic>>{
      'qXTaZnJ': {'id': 'qXTaZnJ', 'name': 'barbell squat', 'gif_url': 'a'},
      'wQ2c4XD': {'id': 'wQ2c4XD', 'name': 'romanian deadlift', 'gif_url': 'b'},
    };

    test('ids without a catalogue row are reported in order, not dropped silently', () {
      final m = resolveMoves(const ['qXTaZnJ', 'EIeI8Vf', 'wQ2c4XD', 'zzzzzzz'], rows);
      expect([for (final f in m.found) f['id']], ['qXTaZnJ', 'wQ2c4XD']);
      expect(m.missing, ['EIeI8Vf', 'zzzzzzz']);
      final all = resolveMoves(const ['qXTaZnJ', 'wQ2c4XD'], rows);
      expect(all.missing, isEmpty);
      expect(all.found, hasLength(2));
    });

    test('a missing move does not count toward the sets to finish, so the session can still reach 100%', () {
      const ids = ['qXTaZnJ', 'EIeI8Vf', 'wQ2c4XD'];
      expect(totalSets(ids, const [], 2), 9);
      expect(totalSets(ids, const ['EIeI8Vf'], 2), 6);
      expect(totalSets(ids, ids, 2), 0);
    });

    test('the notice says how many moves were left out', () {
      expect(missingMovesText(1), '1 move could not be loaded, so it is left out of this session.');
      expect(missingMovesText(2), '2 moves could not be loaded, so they are left out of this session.');
    });
  });
}

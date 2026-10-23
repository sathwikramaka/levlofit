import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/session.dart';

// Injury check: what the free-text note is read as, which moves are set aside or flagged, what is reported as not
// checked, and that sessions without a note are unchanged.

const _kinds = ['strength', 'skill', 'endurance', 'hybrid', 'mobility'];

/// Every move id the sessions can produce, with or without kit swaps.
Set<String> _allIds() => {
      for (final kind in _kinds)
        for (final tier in Tier.values)
          for (var level = 0; level <= 5; level++)
            for (var i = 0; i < 2; i++)
              for (final kit in [null, <Kit>{}]) ...sessionIds(kind, tier, level, i, kit: kit),
      ...sessionIds('mobility', Tier.none, 0, 0, goal: 'yoga'),
    };

void main() {
  group('reading the note', () {
    test('no note, a blank note or a plain "none" means no injury', () {
      for (final t in [null, '', '   ', 'none', 'None.', 'no', 'N/A', 'nil', 'nothing', 'no injuries', 'No pain', '-']) {
        expect(readInjury(t), isNull, reason: '"$t"');
      }
    });

    test('the five areas are recognised in everyday wording', () {
      expect(readInjury('Torn left ACL in 2019')!.areas, {BodyArea.knee});
      expect(readInjury('sprained my ankle last month')!.areas, {BodyArea.ankle});
      expect(readInjury('wrist pain when doing push-ups')!.areas, {BodyArea.wrist});
      expect(readInjury('rotator cuff tear, right side')!.areas, {BodyArea.shoulder});
      expect(readInjury('slipped disc, lower back pain')!.areas, {BodyArea.lowerBack});
      expect(readInjury('bad back')!.areas, {BodyArea.lowerBack});
      expect(readInjury('knee and shoulder both sore')!.areas, {BodyArea.knee, BodyArea.shoulder});
    });

    test('a note naming nothing the check covers is unmatched, never treated as safe', () {
      for (final t in ['hip impingement', 'tennis elbow', 'stiff neck', 'upper back tightness', 'recovering from surgery', 'asthma']) {
        final n = readInjury(t)!;
        expect(n.areas, isEmpty, reason: t);
        expect(n.unmatched, isTrue, reason: t);
      }
    });

    test('a note with a covered area and something else is flagged as only partly checked', () {
      final n = readInjury('knee pain and a sore hip')!;
      expect(n.areas, {BodyArea.knee});
      expect(n.unmatched, isTrue);
      expect(readInjury('knee pain')!.unmatched, isFalse);
    });

    test('a negated area still counts, so the check errs toward caution', () {
      expect(readInjury('no knee problems but a sore wrist')!.areas, {BodyArea.knee, BodyArea.wrist});
    });
  });

  group('known injury cases', () {
    test('knee: jump squats and burpees are set aside; squats, lunges and runs stay with a care note', () {
      final c = checkInjury(sessionIds('hybrid', Tier.none, 2, 0), 'torn ACL');
      expect(c.setAside, ['LIlE5Tn', 'dK9394r']);
      expect(c.ids, isNot(contains('LIlE5Tn')));
      expect(c.care['IZVHb27'], {BodyArea.knee});
      expect(c.care['oLrKqDH'], {BodyArea.knee});
      expect(careNote(c.care['IZVHb27']!), 'Loads your knee: use a pain-free range, or skip it.');
    });

    test('wrist: push-ups leave the session; the incline push-up stays with a care note', () {
      final c = checkInjury(sessionIds('skill', Tier.none, 2, 0), 'wrist sprain');
      expect(c.setAside, ['I4hDWkc']);
      expect(c.care['9WTm7dq'], {BodyArea.wrist}, reason: 'dip loads the wrist less directly');
      final basics = checkInjury(sessionIds('skill', Tier.none, 0, 0), 'wrist sprain');
      // The floor bench dip (identified 2026-10-16) bears body weight on bent-back wrists.
      expect(basics.setAside, ['9RT8oQW']);
      expect(basics.care['B1EVP9F'], {BodyArea.wrist});
    });

    test('shoulder: overhead pressing, dips and pull-ups are set aside; bench pressing is flagged', () {
      final gymB = checkInjury(sessionIds('strength', Tier.gym, 1, 1), 'shoulder impingement');
      expect(gymB.setAside, ['znQUdHY']);
      expect(gymB.care['RVwzP10'], {BodyArea.shoulder});
      final gymA = checkInjury(sessionIds('strength', Tier.gym, 1, 0), 'shoulder impingement');
      expect(gymA.setAside, isEmpty);
      expect(gymA.care['EIeI8Vf'], {BodyArea.shoulder});
      // The hanging leg raise (catalogue identity, 2026-10-17) hangs from the shoulders like the pull-up.
      expect(checkInjury(sessionIds('skill', Tier.gym, 3, 0), 'shoulder').setAside, ['lBDjFxJ', '9WTm7dq', 'I3tsCnC']);
    });

    test('lower back: loaded hinges are set aside; the squat and the carry are flagged', () {
      final gymA = checkInjury(sessionIds('strength', Tier.gym, 1, 0), 'lower back pain');
      expect(gymA.setAside, ['wQ2c4XD']);
      expect(gymA.care['qXTaZnJ'], {BodyArea.lowerBack});
      final gymB = checkInjury(sessionIds('strength', Tier.gym, 1, 1), 'sciatica');
      expect(gymB.setAside, ['ila4NZS']);
      expect(gymB.care['qPEzJjA'], {BodyArea.lowerBack});
      expect(checkInjury(sessionIds('hybrid', Tier.home, 2, 0), 'herniated disc').setAside, ['UHJlbu3']);
    });

    test('ankle: jumping moves are set aside; the run and the calf raise are flagged', () {
      final c = checkInjury(sessionIds('endurance', Tier.none, 1, 0), 'achilles tendinopathy');
      expect(c.setAside, isEmpty);
      expect(c.care['oLrKqDH'], {BodyArea.ankle});
      expect(c.care['bJYHBIN'], {BodyArea.ankle});
      expect(checkInjury(sessionIds('hybrid', Tier.none, 2, 0), 'ankle sprain').setAside, ['LIlE5Tn', 'dK9394r']);
    });
  });

  group('unaffected moves and missing metadata', () {
    test('moves that do not load the reported area are kept without a note', () {
      final c = checkInjury(sessionIds('strength', Tier.gym, 1, 0), 'wrist pain');
      expect(c.ids, contains('fUBheHs'));
      expect(c.care.containsKey('fUBheHs'), isFalse);
      expect(c.ids, contains('wQ2c4XD'), reason: 'a hinge is not set aside for a wrist note');
    });

    test('moves the check has no information on are kept and reported as not checked', () {
      // Every prescribed move is in the table since 2026-10-17, so the mobility session is fully checked.
      final c = checkInjury(sessionIds('mobility', Tier.none, 0, 0), 'knee pain');
      expect(c.ids, sessionIds('mobility', Tier.none, 0, 0));
      expect(c.notAssessed, isEmpty);
      final unknown = checkInjury(const ['qXTaZnJ', 'zzUnknown', 'zzOther'], 'knee');
      expect(unknown.notAssessed, ['zzUnknown', 'zzOther']);
      expect(unknown.ids, ['qXTaZnJ', 'zzUnknown', 'zzOther']);
      expect(injuryNotice(unknown).join(' '), contains('2 moves were not checked against your injury'));
    });

    test('an unmatched note keeps every move and says nothing was checked', () {
      final c = checkInjury(sessionIds('strength', Tier.gym, 1, 1), 'tennis elbow');
      expect(c.ids, sessionIds('strength', Tier.gym, 1, 1));
      expect(c.setAside, isEmpty);
      expect(c.care, isEmpty);
      final notice = injuryNotice(c);
      expect(notice.first, contains('does not name a body part Levlofit can check'));
      expect(notice.last, contains('see a physiotherapist or doctor'));
    });

    test('the notice never calls the session safe, and names what was set aside', () {
      final c = checkInjury(sessionIds('hybrid', Tier.none, 2, 0), 'knee pain and a sore hip');
      final text = injuryNotice(c).join(' ');
      expect(text, contains('not medical advice'));
      expect(text, contains('Set aside today: Jump squat, Burpee.'));
      expect(text, contains('not every risk is covered'));
      expect(text.toLowerCase(), isNot(contains('safe')));
    });

    test('every loaded move is assessed: only moves outside the five areas stay unlisted', () {
      // Hanging from a bar loads the shoulders like a pull-up.
      expect(moveLoads['I3tsCnC']!.$2, {BodyArea.shoulder});
      // The rows, side bridge and the floor and kneeling stretches carry care notes, never removal.
      for (final id in ['bZGHsAZ', 'BJ0Hz5L', 'RKjH6Lt', '01qpYSe', 'DIVyqrU', '2Dk4xQV', 'DFGXwZr', 'f38OEuO']) {
        expect(moveLoads[id], isNotNull, reason: id);
        expect(moveLoads[id]!.$2, isEmpty, reason: '$id: care only');
      }
      final c = checkInjury(sessionIds('mobility', Tier.none, 1, 0, goal: 'yoga'), 'sore wrist');
      expect(c.care['01qpYSe'], {BodyArea.wrist}, reason: 'upward-facing dog bears weight on the hands');
      expect(c.setAside, isEmpty);
    });

    test('every id in the injury table is a move the sessions use', () {
      expect(_allIds(), containsAll(moveLoads.keys));
    });

    test('a move is never both set aside and flagged for the same area', () {
      for (final MapEntry(:key, :value) in moveLoads.entries) {
        expect(value.$2.intersection(value.$3), isEmpty, reason: key);
      }
    });
  });

  group('backward compatibility', () {
    test('with no injury note every session is unchanged and nothing is shown', () {
      for (final id in [null, '', 'none']) {
        for (final kind in _kinds) {
          for (final tier in Tier.values) {
            final ids = sessionIds(kind, tier, 2, 0);
            final c = checkInjury(ids, id);
            expect(c.ids, ids);
            expect(c.setAside, isEmpty);
            expect(c.care, isEmpty);
            expect(c.notAssessed, isEmpty);
            expect(injuryNotice(c), isEmpty);
          }
        }
      }
    });

    test('kit swaps and the injury check combine: a swapped-in move is checked too', () {
      final ids = sessionIds('skill', Tier.none, 2, 0, kit: <Kit>{}); // pull-up and dip swapped out
      final c = checkInjury(ids, 'shoulder');
      expect(c.setAside, isEmpty, reason: 'the overhead moves are already gone');
      expect(c.care['B1EVP9F'], {BodyArea.shoulder});
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/food_diary.dart';

// Fixes for the two findings of the controlled visual test (PROGRESS batch BF).
void main() {
  group('food search pattern', () {
    test('an exact name with commas matches word by word', () {
      expect(foodSearchPattern('rice, raw, brown'), '*rice*raw*brown*');
      expect(foodSearchPattern('Rice, raw, brown'), '*Rice*raw*brown*'); // ilike ignores case
    });

    test('commas, brackets and repeated or surrounding spaces are normalised the same way', () {
      for (final q in ['rice raw brown', ' rice,raw,brown ', 'rice  ,  raw\tbrown', 'rice (raw) brown', 'rice, raw, brown,']) {
        expect(foodSearchPattern(q), '*rice*raw*brown*', reason: q);
      }
    });

    test('partial and single-word searches keep working as before', () {
      expect(foodSearchPattern('paneer'), '*paneer*');
      expect(foodSearchPattern('dal'), '*dal*');
      expect(foodSearchPattern('rice brown'), '*rice*brown*');
      expect(foodSearchPattern('Chana dal'), '*Chana*dal*'); // Hindi names use the same pattern
    });

    test('characters the filter syntax reserves never reach it', () {
      for (final q in ['rice%', 'rice*', 'ri"ce', r'rice\', 'rice)', '(rice']) {
        final p = foodSearchPattern(q)!;
        expect(p, isNot(matches(RegExp(r'[%,()"\\]'))), reason: q); // '*' only as Levlofit's own wildcards
      }
    });

    test('too short or only punctuation: no search', () {
      for (final q in ['', ' ', 'r', ', ,', '  r  ', '%*']) {
        expect(foodSearchPattern(q), isNull, reason: q);
      }
      expect(foodSearchPattern('r i'), '*r*i*', reason: 'two characters with a space still search');
    });
  });

  group('diary order', () {
    Map<String, dynamic> row(String id, String at) => {'id': id, 'created_at': at};

    test('newest first', () {
      final out = newestFirst([row('a', '2026-10-15T15:38:00.56093+00:00'), row('b', '2026-10-15T15:40:30.44204+00:00')]);
      expect(out.map((r) => r['id']), ['b', 'a']);
    });

    test('rows saved in the same instant always come out in the same order, whatever order they arrive in', () {
      const t = '2026-10-15T15:38:00.56093+00:00';
      final rows = [row('15bc5800', t), row('d5a293e2', t), row('eac12d47', t), row('d4c426c0', '2026-10-15T15:40:30.44204+00:00')];
      final expected = ['d4c426c0', 'eac12d47', 'd5a293e2', '15bc5800'];
      expect(newestFirst(rows).map((r) => r['id']), expected);
      expect(newestFirst(rows.reversed.toList()).map((r) => r['id']), expected);
      expect(newestFirst([rows[2], rows[0], rows[3], rows[1]]).map((r) => r['id']), expected);
    });

    test('time zones are compared as instants, not as text', () {
      final out = newestFirst([row('utc', '2026-10-15T15:00:00+00:00'), row('ist', '2026-10-15T20:00:00+05:30')]);
      expect(out.map((r) => r['id']), ['utc', 'ist'], reason: '20:00 IST is 14:30 UTC, older than 15:00 UTC (text order would say the opposite)');
    });

    test('does not change the rows it is given', () {
      final rows = [row('a', '2026-10-15T10:00:00Z'), row('b', '2026-10-15T11:00:00Z')];
      newestFirst(rows);
      expect(rows.map((r) => r['id']), ['a', 'b']);
    });
  });

  group('food library filter (client side)', () {
    test('same normalisation: commas, brackets, spacing and case are ignored; words in order', () {
      expect(matchesFoodQuery('Spinach (palak) Palak', 'spinach palak'), isTrue);
      expect(matchesFoodQuery('Egg, boiled ', 'egg boiled'), isTrue);
      expect(matchesFoodQuery('Egg, boiled ', 'Egg, boiled'), isTrue);
      expect(matchesFoodQuery('Egg, boiled ', 'egg   ,boiled'), isTrue);
      expect(matchesFoodQuery('Wheat atta (roti) Gehun ka atta', 'atta'), isTrue, reason: 'partial word');
      expect(matchesFoodQuery('Wheat atta (roti) Gehun ka atta', 'gehun'), isTrue, reason: 'Hindi name');
    });

    test('no match and empty query behave as before', () {
      expect(matchesFoodQuery('Egg, boiled ', 'paneer'), isFalse);
      expect(matchesFoodQuery('Egg, boiled ', 'boiled egg'), isFalse, reason: 'words must appear in order');
      expect(matchesFoodQuery('Egg, boiled ', ''), isTrue);
      expect(matchesFoodQuery('Egg, boiled ', '  '), isTrue);
    });
  });
}

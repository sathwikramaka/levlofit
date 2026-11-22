import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/handbook.dart' show searchChapters;

void main() {
  test('Handbook search: every word, title first, word starts, all chapters when empty', () {
    final rows = [
      {'id': 1, 'title': 'Warm-up and mobility', 'summary': 'Preparing to perform.', 'body_md': 'A warm-up raises temperature.'},
      {'id': 2, 'title': 'Protein', 'summary': 'How much, from what.', 'body_md': 'Whey and dal give protein.'},
      {'id': 3, 'title': 'Supplements', 'summary': 'What works.', 'body_md': 'Creatine monohydrate and protein powder.'},
    ];
    expect(searchChapters(rows, '').length, 3);
    expect(searchChapters(rows, 'protein').map((r) => r['id']), [2, 3], reason: 'title match first, then text');
    expect(searchChapters(rows, 'WARM').map((r) => r['id']), [1]);
    expect(searchChapters(rows, 'warm-up').map((r) => r['id']), [1]);
    expect(searchChapters(rows, 'creatine powder').map((r) => r['id']), [3]);
    expect(searchChapters(rows, 'rein'), isEmpty, reason: 'a word matches from its start, not inside another');
    expect(searchChapters(rows, 'xyzzy'), isEmpty);
  });
}

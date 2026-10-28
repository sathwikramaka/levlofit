import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart' show offlineLine;
import 'package:levlo/main.dart';
import 'package:levlo/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'keep': 1});
    prefs = await SharedPreferences.getInstance();
  });

  test('rows round-trip per account and are all cleared on sign-out; other settings stay', () async {
    expect(readOfflineRows('a'), isNull);
    await saveOfflineRows('a', {'profile': {'display_name': 'Asha'}, 'results': [[], [{'name': 'dal'}]]});
    await saveOfflineRows('b', {'profile': {}});
    final a = readOfflineRows('a')!;
    expect((a.rows['profile'] as Map)['display_name'], 'Asha');
    expect(((a.rows['results'] as List)[1] as List).cast<Map<String, dynamic>>().first['name'], 'dal');
    expect(hasOfflineRows('b'), isTrue);
    await clearOfflineRows();
    expect(hasOfflineRows('a') || hasOfflineRows('b'), isFalse);
    expect(prefs.getInt('keep'), 1);
  });

  test('a broken saved copy reads as none', () async {
    await prefs.setString('offline_dashboard_c', '{not json');
    expect(readOfflineRows('c'), isNull);
  });

  test('banner says how old the copy is', () {
    final now = DateTime(2026, 10, 29, 12);
    expect(offlineLine(now.subtract(const Duration(minutes: 5)), now), contains('5 min ago'));
    expect(offlineLine(now.subtract(const Duration(hours: 3)), now), contains('3 h ago'));
    expect(offlineLine(now.subtract(const Duration(days: 4)), now), contains('4 days ago'));
  });
}

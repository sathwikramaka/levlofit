import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart' show offlineLine;
import 'package:levlo/main.dart';
import 'package:levlo/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store whose reads fail, as when the Keystore key is lost and the ciphertext no longer decrypts.
class _BrokenStore extends FlutterSecureStorage {
  const _BrokenStore();
  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => throw Exception('bad padding');
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'keep': 1});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    await prefs.setString('offline_dashboard_old', '{"rows":{"weight":80}}'); // plain-text copy from 1.0.2 and older
    FlutterSecureStorage.setMockInitialValues({});
    offlineStore = const FlutterSecureStorage();
  });

  test('rows round-trip for their own account, stored in the secure store, not SharedPreferences', () async {
    expect(await readOfflineRows('a'), isNull);
    await saveOfflineRows('a', {'profile': {'display_name': 'Asha'}, 'results': [[], [{'name': 'dal'}]]});
    final a = (await readOfflineRows('a'))!;
    expect((a.rows['profile'] as Map)['display_name'], 'Asha');
    expect(((a.rows['results'] as List)[1] as List).cast<Map<String, dynamic>>().first['name'], 'dal');
    expect(prefs.getKeys().where((k) => k.contains('Asha') || (prefs.get(k)?.toString().contains('Asha') ?? false)), isEmpty);
    expect(await offlineStore.read(key: 'offline_dashboard'), contains('Asha'));
  });

  test("user A's copy is never shown to user B on the same phone, and is dropped when B asks", () async {
    await saveOfflineRows('a', {'profile': {'weight_kg': 80}});
    expect(await readOfflineRows('b'), isNull);
    expect(await hasOfflineRows('b'), isFalse);
    expect(await readOfflineRows('a'), isNull, reason: 'the mismatched read deleted it');
  });

  test('saving for B replaces A', () async {
    await saveOfflineRows('a', {'profile': {}});
    await saveOfflineRows('b', {'profile': {}});
    expect(await hasOfflineRows('b'), isTrue);
    expect(await hasOfflineRows('a'), isFalse);
  });

  test('expired copies are not shown and are deleted; a fresh one at the limit still is', () async {
    await saveOfflineRows('a', {'profile': {}});
    final now = DateTime.now();
    expect(await readOfflineRows('a', now: now.add(offlineMaxAge - const Duration(minutes: 1))), isNotNull);
    expect(await readOfflineRows('a', now: now.add(offlineMaxAge + const Duration(minutes: 1))), isNull);
    expect(await offlineStore.read(key: 'offline_dashboard'), isNull);
  });

  test('a copy dated in the future (clock moved) is not shown', () async {
    await saveOfflineRows('a', {'profile': {}});
    expect(await readOfflineRows('a', now: DateTime.now().subtract(const Duration(days: 1))), isNull);
  });

  test('corrupt, wrong-shape or old-format copies read as none and are deleted', () async {
    for (final raw in [
      '{not json',
      '[]',
      '{"v":1,"uid":"a","at":"yesterday","rows":{}}',
      '{"v":1,"uid":"a","at":"${DateTime.now().toIso8601String()}","rows":[]}',
      '{"v":0,"uid":"a","at":"${DateTime.now().toIso8601String()}","rows":{}}',
      '{"uid":"a","at":"${DateTime.now().toIso8601String()}","rows":{}}',
    ]) {
      await offlineStore.write(key: 'offline_dashboard', value: raw);
      expect(await readOfflineRows('a'), isNull, reason: raw);
      expect(await offlineStore.read(key: 'offline_dashboard'), isNull, reason: raw);
    }
  });

  test('a store that cannot decrypt reads as none instead of throwing', () async {
    offlineStore = const _BrokenStore();
    expect(await readOfflineRows('a'), isNull);
  });

  test('clearing removes the secure copy and any plain-text copy an older version left; other settings stay', () async {
    await saveOfflineRows('a', {'profile': {}});
    await clearOfflineRows();
    expect(await hasOfflineRows('a'), isFalse);
    expect(prefs.getKeys().where((k) => k.startsWith('offline_dashboard_')), isEmpty);
    expect(prefs.getInt('keep'), 1);
  });

  test('banner says how old the copy is', () {
    final now = DateTime(2026, 10, 29, 12);
    expect(offlineLine(now.subtract(const Duration(minutes: 5)), now), contains('5 min ago'));
    expect(offlineLine(now.subtract(const Duration(hours: 3)), now), contains('3 h ago'));
    expect(offlineLine(now.subtract(const Duration(days: 4)), now), contains('4 days ago'));
  });
}

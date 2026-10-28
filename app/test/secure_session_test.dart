import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/main.dart';
import 'package:levlo/secure_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'sb-abc-auth-token';

  test('key matches the SDK default', () => expect(sessionKeyFor('https://abc.supabase.co'), key));

  test('an old plain-text session moves to the secure store once and leaves SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({key: '{"access_token":"old"}', 'theme': 'dark'});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final s = SecureSessionStorage(key);
    await s.initialize();
    expect(prefs.getString(key), isNull);
    expect(prefs.getString('theme'), 'dark');
    expect(await s.accessToken(), '{"access_token":"old"}');
    await s.persistSession('{"access_token":"new"}');
    await s.initialize(); // nothing left to move: the newer session stays
    expect(await s.accessToken(), '{"access_token":"new"}');
    await s.removePersistedSession();
    expect(await s.hasAccessToken(), isFalse);
  });
}

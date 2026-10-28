// Where the Supabase sign-in session (access and refresh tokens) lives on the phone: the platform's secure store
// (Android Keystore-backed, iOS Keychain) instead of plain SharedPreferences. A session saved by an older version
// under the same key in SharedPreferences is moved over once and then removed. Web keeps the SDK default.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';

class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this.key, {this.store = const FlutterSecureStorage()});

  /// The SDK's own key, so a session from SharedPreferencesLocalStorage is found and moved.
  final String key;
  final FlutterSecureStorage store;

  @override
  Future<void> initialize() async {
    final old = prefs.getString(key);
    if (old == null) return;
    if (!await store.containsKey(key: key)) await store.write(key: key, value: old);
    await prefs.remove(key);
  }

  @override
  Future<bool> hasAccessToken() => store.containsKey(key: key);

  @override
  Future<String?> accessToken() => store.read(key: key);

  @override
  Future<void> removePersistedSession() => store.delete(key: key);

  @override
  Future<void> persistSession(String persistSessionString) => store.write(key: key, value: persistSessionString);
}

/// The SDK's default key for [url]: `sb-<project ref>-auth-token`.
String sessionKeyFor(String url) => 'sb-${Uri.parse(url).host.split('.').first}-auth-token';

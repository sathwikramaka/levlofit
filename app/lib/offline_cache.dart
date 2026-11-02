// The last dashboard data the server sent, kept on the phone so the plan, today's session and the move guides still
// open without a connection. Read-only: nothing is queued while offline, so a log always needs the server (no stale or
// duplicate writes).
//
// It holds health data (weight, measurements, plan, health flags), so it lives in the platform's secure store (Android
// Keystore-backed AES, iOS Keychain), the same one as the sign-in session (secure_session.dart), never in plain
// SharedPreferences. One copy per phone, tagged with the account it belongs to: a read for any other account, a copy
// older than [offlineMaxAge], a different format version or anything that fails to decrypt or parse is deleted and
// reads as none. Cleared on sign-out, account switch, session loss and account deletion (main.dart, account.dart).
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'main.dart';

const _key = 'offline_dashboard';
const _version = 1;

/// How long a saved copy may still be shown offline. Older plans and logs are more misleading than helpful.
const offlineMaxAge = Duration(days: 14);

FlutterSecureStorage offlineStore = const FlutterSecureStorage();

/// Saves [rows] (plain JSON from Supabase) for [uid], with the time they were read. Replaces any other account's copy.
Future<void> saveOfflineRows(String uid, Map<String, Object?> rows) async {
  try {
    await offlineStore.write(
      key: _key,
      value: jsonEncode({'v': _version, 'uid': uid, 'at': DateTime.now().toUtc().toIso8601String(), 'rows': rows}),
    );
  } catch (_) {} // a full or broken store only loses the offline copy
}

/// The saved rows for [uid] and when they were read, or null when there is no usable copy for this account.
Future<({DateTime at, Map<String, dynamic> rows})?> readOfflineRows(String uid, {DateTime? now}) async {
  try {
    final raw = await offlineStore.read(key: _key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final at = DateTime.parse(j['at'] as String).toLocal();
    final age = (now ?? DateTime.now()).difference(at);
    if (j['v'] == _version && j['uid'] == uid && !age.isNegative && age <= offlineMaxAge) {
      return (at: at, rows: (j['rows'] as Map).cast<String, dynamic>());
    }
  } catch (_) {} // undecryptable (key lost), corrupt or wrong shape: fall through and drop it
  await clearOfflineRows();
  return null;
}

Future<bool> hasOfflineRows(String uid) async => await readOfflineRows(uid) != null;

/// Removes the offline copy from this phone, plus any plain-text copy an older version left in SharedPreferences.
Future<void> clearOfflineRows() async {
  try {
    await offlineStore.delete(key: _key);
  } catch (_) {}
  for (final k in prefs.getKeys().where((k) => k.startsWith('offline_dashboard_')).toList()) {
    await prefs.remove(k);
  }
}

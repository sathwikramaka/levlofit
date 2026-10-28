// The last dashboard data the server sent, kept on the phone so the plan, today's session and the move guides still
// open without a connection. Read-only: nothing is queued while offline, so a log always needs the server (no stale or
// duplicate writes). Cleared on sign-out and account deletion. Lives in app-private storage, excluded from backups
// (android:allowBackup false).
import 'dart:convert';

import 'main.dart';

String _key(String uid) => 'offline_dashboard_$uid';

/// Saves [rows] (plain JSON from Supabase) for [uid], with the time they were read.
Future<void> saveOfflineRows(String uid, Map<String, Object?> rows) async {
  try {
    await prefs.setString(_key(uid), jsonEncode({'at': DateTime.now().toIso8601String(), 'rows': rows}));
  } catch (_) {} // a full or broken store only loses the offline copy
}

/// The saved rows and when they were read, or null.
({DateTime at, Map<String, dynamic> rows})? readOfflineRows(String uid) {
  try {
    final raw = prefs.getString(_key(uid));
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (at: DateTime.parse(j['at'] as String), rows: (j['rows'] as Map).cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

bool hasOfflineRows(String uid) => prefs.containsKey(_key(uid));

/// Removes every account's offline copy from this phone.
Future<void> clearOfflineRows() async {
  for (final k in prefs.getKeys().where((k) => k.startsWith('offline_dashboard_')).toList()) {
    await prefs.remove(k);
  }
}

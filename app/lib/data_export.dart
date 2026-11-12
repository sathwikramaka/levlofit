// "Export my data" (owner request 2026-11-12): every row the person's account holds, read with their own sign-in (row
// security returns only their rows), as one JSON file handed to the share sheet. Nothing goes anywhere else.
import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'main.dart' show supabase;

/// Tables with the person's own rows, by the column that holds their id.
const exportTables = <String, String>{
  'profiles': 'id',
  'dietary_profiles': 'user_id',
  'user_goals': 'user_id',
  'goal_levels': 'user_id',
  'generated_plans': 'user_id',
  'workout_logs': 'user_id',
  'set_logs': 'user_id',
  'food_log': 'user_id',
  'body_metrics': 'user_id',
  'water_intake': 'user_id',
  'habit_logs': 'user_id',
  'daily_checkins': 'user_id',
  'coach_threads': 'user_id',
  'coach_messages': 'user_id',
  'coach_facts': 'user_id',
  'custom_reminders': 'user_id',
  'reminder_prefs': 'user_id',
  'progress_photos': 'user_id',
  'recipes': 'user_id',
  'exercise_swaps': 'user_id',
  'session_changes': 'user_id',
  'plan_changes': 'user_id',
};

/// The file's content: when it was made, each table's rows, and the tables that could not be read (named, never
/// silently left out).
String exportJson(DateTime at, Map<String, List<Map<String, dynamic>>> tables, List<String> failed) =>
    const JsonEncoder.withIndent('  ').convert({
      'exported_at': at.toUtc().toIso8601String(),
      'app': 'Levlofit',
      'note': 'Your Levlofit data. Progress photos are listed by file name; save the pictures from the app.',
      'tables': tables,
      if (failed.isNotEmpty) 'not_exported': failed,
    });

/// Reads every table and opens the share sheet with the file. Returns the number of rows exported.
Future<int> exportMyData() async {
  final uid = supabase.auth.currentUser!.id;
  final tables = <String, List<Map<String, dynamic>>>{};
  final failed = <String>[];
  for (final MapEntry(key: table, value: column) in exportTables.entries) {
    try {
      tables[table] = List<Map<String, dynamic>>.from(await supabase.from(table).select().eq(column, uid).limit(20000));
    } catch (_) {
      failed.add(table);
    }
  }
  final now = DateTime.now();
  final name = 'levlofit-data-${now.toIso8601String().substring(0, 10)}.json';
  final bytes = Uint8List.fromList(utf8.encode(exportJson(now, tables, failed)));
  await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)], fileNameOverrides: [name]));
  return tables.values.fold<int>(0, (s, rows) => s + rows.length);
}

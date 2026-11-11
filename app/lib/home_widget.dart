// The Android home screen widget (android/.../TodayWidget.kt) shows two lines the app writes here: today's session
// and the week so far. It reads them from shared_preferences, so nothing leaves the phone.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'main.dart' show prefs;

const _channel = MethodChannel('levlofit/widget');

/// The widget's two lines for a day.
({String today, String week}) widgetLines({required String? session, required bool done, int? minutes, required int doneThisWeek, required int perWeek, required int streakWeeks}) => (
      today: session == null ? 'Rest day' : done ? '$session, done' : [session, if (minutes != null) '$minutes min'].join('  ·  '),
      week: '$doneThisWeek of $perWeek sessions this week${streakWeeks > 0 ? '  ·  $streakWeeks-week streak' : ''}',
    );

/// Saves the lines and redraws the widget when they changed. Android only.
Future<void> updateHomeWidget(({String today, String week}) lines) async {
  if (kIsWeb || !Platform.isAndroid) return; // the real platform: widget tests run on the desktop host
  if (prefs.getString('widget_today') == lines.today && prefs.getString('widget_week') == lines.week) return;
  await prefs.setString('widget_today', lines.today);
  await prefs.setString('widget_week', lines.week);
  try {
    await _channel.invokeMethod<void>('refresh');
  } on PlatformException catch (_) {} on MissingPluginException catch (_) {} // no widget host: nothing to redraw
}

// Reminders with Levlofit's own sound. Phones get real scheduled notifications (Android channel and iOS
// both play levlo_chime); the web cannot schedule, so while the app is open a quiet ticker shows an in-app
// banner and plays the same chime. Settings live in reminder_prefs so every device schedules the same.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'main.dart';

typedef ReminderPrefs = ({bool enabled, TimeOfDay? workout, int? waterEveryH, int? weighInWeekday});

const defaultPrefs = (enabled: true, workout: TimeOfDay(hour: 18, minute: 0), waterEveryH: 2, weighInWeekday: 1);

/// One reminder at a time of day: weekday 1 to 7, or null for every day.
typedef Slot = ({int id, int? weekday, int hour, int minute, String title, String body});

/// Every reminder the settings produce. Pure, so it can be tested.
/// [sessions] maps training weekdays (1 = Monday) to that day's session name.
List<Slot> slotsFor(ReminderPrefs p, Map<int, String> sessions) {
  if (!p.enabled) return const [];
  final w = p.workout;
  return [
    if (w != null)
      for (final e in sessions.entries)
        (id: 100 + e.key, weekday: e.key, hour: w.hour, minute: w.minute, title: 'Time to train', body: '${e.value} is on today. Your moves are ready in Levlofit.'),
    // Water through the waking day, 09:00 to 21:00.
    if (p.waterEveryH case final every?)
      for (var h = 9; h <= 21; h += every) (id: 200 + h, weekday: null, hour: h, minute: 0, title: 'Water check', body: 'A glass now keeps you on track for today.'),
    if (p.weighInWeekday case final day?) (id: 300, weekday: day, hour: 8, minute: 0, title: 'Weekly weigh-in', body: 'Before breakfast, after the toilet. Log it in Progress.'),
  ];
}

abstract final class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _player = AudioPlayer();
  static bool _ready = false;
  static Timer? _ticker;

  static const _android = AndroidNotificationDetails(
    'levlo_reminders_v1', // a channel's sound is fixed once created; bump the id to change it
    'Reminders',
    channelDescription: 'Training, water and weigh-in reminders',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('levlo_chime'),
    color: Color(0xFFFF6A1A),
  );
  static const _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(sound: 'levlo_chime.wav', presentAlert: true, presentSound: true, presentBanner: true),
  );

  /// The Levlofit sound, also used by the rest timer.
  static Future<void> chime() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/levlo_chime.wav'));
    } catch (_) {
      // Sound is a nicety; a blocked autoplay must never break the screen.
    }
  }

  static Future<void> _init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // India-first default
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestSoundPermission: false, requestBadgePermission: false),
      ),
    );
    _ready = true;
  }

  /// Asks the OS for permission. Returns false when the user says no (or on the web, where it is in-app only).
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _init();
    final android = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    final ios = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: false);
    return android ?? ios ?? false;
  }

  /// Replaces every scheduled reminder with the ones these settings produce.
  static Future<void> apply(ReminderPrefs p, Map<int, String> sessions, {void Function(String title, String body)? inApp}) async {
    final slots = slotsFor(p, sessions);
    _ticker?.cancel();
    if (kIsWeb) {
      if (inApp != null && slots.isNotEmpty) _startTicker(slots, inApp);
      return;
    }
    await _init();
    await _plugin.cancelAll();
    for (final s in slots) {
      await _plugin.zonedSchedule(
        id: s.id,
        scheduledDate: _next(s),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // no exact-alarm permission needed
        title: s.title,
        body: s.body,
        matchDateTimeComponents: s.weekday == null ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Fires one right now, to hear the sound and check permissions.
  static Future<void> test({void Function(String title, String body)? inApp}) async {
    const title = 'Levlofit reminder', body = 'This is how your reminders will sound.';
    if (kIsWeb) {
      inApp?.call(title, body);
      await chime();
      return;
    }
    await _init();
    await _plugin.show(id: 1, title: title, body: body, notificationDetails: _details);
  }

  static tz.TZDateTime _next(Slot s) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, s.hour, s.minute);
    while (!at.isAfter(now) || (s.weekday != null && at.weekday != s.weekday)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  // Web: check a few times a minute while the app is open.
  static void _startTicker(List<Slot> slots, void Function(String, String) inApp) {
    var last = '';
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      final now = DateTime.now();
      final key = '${now.day}-${now.hour}-${now.minute}';
      if (key == last) return;
      for (final s in slots) {
        if (s.hour == now.hour && s.minute == now.minute && (s.weekday == null || s.weekday == now.weekday)) {
          last = key;
          inApp(s.title, s.body);
          chime();
          break;
        }
      }
    });
  }
}

/// Loads saved settings, or the defaults for someone who has never opened them.
Future<ReminderPrefs> loadReminderPrefs() async {
  final row = await supabase.from('reminder_prefs').select().eq('user_id', supabase.auth.currentUser!.id).maybeSingle();
  if (row == null) return defaultPrefs;
  TimeOfDay? time(Object? v) {
    if (v is! String) return null;
    final parts = v.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  return (enabled: row['enabled'] as bool, workout: time(row['workout_at']), waterEveryH: row['water_every_h'] as int?, weighInWeekday: row['weigh_in_weekday'] as int?);
}

Future<void> saveReminderPrefs(ReminderPrefs p) => supabase.from('reminder_prefs').upsert({
      'enabled': p.enabled,
      'workout_at': p.workout == null ? null : '${p.workout!.hour.toString().padLeft(2, '0')}:${p.workout!.minute.toString().padLeft(2, '0')}',
      'water_every_h': p.waterEveryH,
      'weigh_in_weekday': p.weighInWeekday,
      'updated_at': DateTime.now().toIso8601String(),
    });

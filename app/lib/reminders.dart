// Reminders with Levlofit's own sound. Phones get real scheduled notifications (Android channel and iOS
// both play levlo_chime); the web cannot schedule, so while the app is open a quiet ticker shows an in-app
// banner and plays the same chime. Settings live in reminder_prefs so every device schedules the same.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'main.dart';

typedef ReminderPrefs = ({bool enabled, TimeOfDay? workout, int? waterEveryH, int? weighInWeekday});

const defaultPrefs = (enabled: true, workout: TimeOfDay(hour: 18, minute: 0), waterEveryH: 2, weighInWeekday: 1);

/// Everything off: applying it cancels every Levlofit reminder on this phone and nothing else.
const remindersOff = (enabled: false, workout: null, waterEveryH: null, weighInWeekday: null);

/// One reminder at a time of day: weekday 1 to 7, or null for every day.
typedef Slot = ({int id, int? weekday, int hour, int minute, String title, String body});

/// A reminder the user made: name, time, days (empty = every day), on/off. [id] is null until saved.
typedef CustomReminder = ({String? id, String name, TimeOfDay at, Set<int> weekdays, bool enabled});

/// At most 20 per user (enforced by the database too); keeps iOS under its 64 pending notifications.
const maxCustomReminders = 20;

/// "Every day", "Weekdays", "Weekends" or "Mon, Wed, Fri".
String describeDays(Set<int> days) {
  if (days.isEmpty || days.length == 7) return 'Every day';
  if (days.length == 5 && days.containsAll(const [1, 2, 3, 4, 5])) return 'Weekdays';
  if (days.length == 2 && days.containsAll(const [6, 7])) return 'Weekends';
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return [for (final d in days.toList()..sort()) names[d - 1]].join(', ');
}

/// Every reminder the settings produce. Pure, so it can be tested.
/// [sessions] maps training weekdays (1 = Monday) to that day's session name. The master switch silences
/// [custom] reminders too. Custom ids are 1000 + 8 x position + weekday (0 = every day): unique, and clear of the
/// built-in 100-300 range and the test notification (1).
List<Slot> slotsFor(ReminderPrefs p, Map<int, String> sessions, {List<CustomReminder> custom = const []}) {
  if (!p.enabled) return const [];
  final w = p.workout;
  final own = custom.take(maxCustomReminders).toList();
  return [
    if (w != null)
      for (final e in sessions.entries)
        (id: 100 + e.key, weekday: e.key, hour: w.hour, minute: w.minute, title: 'Time to train', body: '${e.value} is on today. Your moves are ready in Levlofit.'),
    // Water through the waking day, 09:00 to 21:00.
    if (p.waterEveryH case final every?)
      for (var h = 9; h <= 21; h += every) (id: 200 + h, weekday: null, hour: h, minute: 0, title: 'Water check', body: 'A glass now keeps you on track for today.'),
    if (p.weighInWeekday case final day?) (id: 300, weekday: day, hour: 8, minute: 0, title: 'Weekly weigh-in', body: 'Before breakfast, after the toilet. Log it in Progress.'),
    for (final (i, r) in own.indexed)
      if (r.enabled)
        for (final day in r.weekdays.isEmpty || r.weekdays.length == 7 ? const <int?>[null] : (r.weekdays.toList()..sort()))
          (id: 1000 + 8 * i + (day ?? 0), weekday: day, hour: r.at.hour, minute: r.at.minute, title: r.name, body: 'Your Levlofit reminder.'),
  ];
}

/// How Android will deliver scheduled reminders. Exact needs the user's "Alarms & reminders" permission on
/// Android 12+ (denied by default on 14+ for new installs); inexact needs nothing but may arrive minutes late.
enum ReminderTiming { exact, inexact }

/// What a scheduled alarm stands for. Stored as the notification payload, so the next apply can see whether a
/// pending alarm still matches the settings without cancelling and rebuilding everything. lv2 (2026-10-28): exact alarms
/// moved to the alarm-clock type, so every lv1 alarm is re-registered once.
String slotKey(Slot s, ReminderTiming timing, String zone) => 'lv2|${s.weekday ?? 0}|${s.hour}|${s.minute}|${timing.name}|$zone|${s.title}|${s.body}';

/// Ids owned by the reminder schedule (built-in 100-300, custom 1000+). The test notification (1) and anything
/// else are never cancelled by it.
bool isReminderId(int id) => id >= 100;

/// Ids of the user's own reminders (see [slotsFor]).
bool isCustomReminderId(int id) => id >= 1000;

/// The smallest set of changes from [pending] (id -> payload) to [desired]. Pure, so it can be tested.
/// - cancel: reminder ids that are pending but no longer wanted. Cancelling also clears that id's notification
///   if it is on screen, which is right for a reminder that was removed or switched off.
/// - schedule: wanted slots whose pending alarm is missing or different. Scheduling an existing id replaces its
///   alarm without touching a notification already on screen, so changed slots are not cancelled first.
/// Unchanged reminders are left alone, unless [refreshAll]: then every wanted slot is registered again (still
/// without cancelling it). The pending list is the plugin's own record, which survives a force-stop that wipes the
/// real Android alarms, so the app re-registers everything once per launch.
/// With [keepCustom] (the user's own reminders could not be read) pending custom ids are left exactly as they are.
({List<int> cancel, List<Slot> schedule}) planReminderChanges(List<Slot> desired, Map<int, String?> pending, ReminderTiming timing, String zone,
    {bool refreshAll = false, bool keepCustom = false}) {
  final wanted = {for (final s in desired) s.id};
  return (
    cancel: [for (final id in pending.keys) if (isReminderId(id) && !wanted.contains(id) && !(keepCustom && isCustomReminderId(id))) id]..sort(),
    schedule: [for (final s in desired) if (refreshAll || pending[s.id] != slotKey(s, timing, zone)) s],
  );
}

/// Timing experiment (non-release builds only): one standalone, one-off notification scheduled with Android's
/// alarm-clock API, to measure whether this phone delivers it without the window it applies to permission-based
/// exact alarms. It is not a reminder: its id sits below the reminder range, so [planReminderChanges] never
/// schedules, cancels or duplicates it, and saved reminders keep their own mode.
const alarmClockTestId = 90;

/// The test alarm for [at]: today if still ahead, otherwise tomorrow. One-off, so it never repeats.
Slot alarmClockTestSlot(TimeOfDay at) => (
      id: alarmClockTestId,
      weekday: null,
      hour: at.hour,
      minute: at.minute,
      title: 'Levlofit timing test',
      body: 'Alarm-clock test, set for ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}.',
    );

/// Timestamps for timestamptz columns: UTC with a Z, so the database does not read phone-local time as UTC.
String utcNow([DateTime? now]) => (now ?? DateTime.now()).toUtc().toIso8601String();

abstract final class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _player = AudioPlayer();
  static bool _ready = false;
  static Timer? _ticker;
  // ponytail: the first apply after launch re-registers every reminder to recover from a force-stop. An inexact
  // alarm already inside its delivery window at that moment moves to its next occurrence; with exact timing
  // there is no window. A per-alarm "fired" record would remove that edge if it ever matters.
  static bool _refreshedThisLaunch = false;

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
    if (requestOverride case final f?) return f();
    if (kIsWeb) return false;
    try {
      await prefs.setBool('notifications_asked', true);
    } catch (_) {}
    await _init();
    final android = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    final ios = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: false);
    return android ?? ios ?? false;
  }

  /// Tests replace the platform checks; the app never sets these.
  @visibleForTesting
  static Future<ReminderTiming?> Function()? timingOverride;
  @visibleForTesting
  static Future<bool?> Function()? notificationsOverride;
  @visibleForTesting
  static Future<bool> Function()? requestOverride;

  /// Whether the phone will show Levlofit's notifications right now. Null on the web and where it cannot be read.
  /// Below Android 13 there is no permission to ask for: this reads the app's notification switch instead.
  static Future<bool?> notificationsEnabled() async {
    if (notificationsOverride case final f?) return f();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      await _init();
      return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  /// Asks for notification permission only the first time it is needed (onboarding or the first saved reminder).
  /// After that it never prompts by itself: someone who said no is not asked again on every save. The explicit
  /// buttons (onboarding, Reminders, the test reminder) call [requestPermission] directly.
  static Future<void> requestPermissionOnce() async {
    const key = 'notifications_asked';
    try {
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
    } catch (_) {
      return; // no device storage (tests): never prompt implicitly
    }
    await requestPermission();
  }

  /// Exact when Android allows it (always below Android 12), otherwise inexact. Null on the web and when the
  /// platform cannot be asked; callers then show nothing about timing.
  static Future<ReminderTiming?> timing() async {
    if (timingOverride case final f?) return f();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      await _init();
      final can = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.canScheduleExactNotifications();
      return can == true ? ReminderTiming.exact : ReminderTiming.inexact;
    } catch (_) {
      return null;
    }
  }

  /// Opens Android's "Alarms & reminders" page for Levlofit. Only ever called from the user's own tap; the
  /// answer is read back with [timing] when they return.
  static Future<void> requestExactTiming() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _init();
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
    } catch (_) {
      // The settings page could not open; reminders keep working inexactly and the row still offers the button.
    }
  }

  /// Brings the scheduled reminders in line with these settings, changing only what differs (see
  /// [planReminderChanges]). Uses exact alarms when allowed and falls back to inexact per alarm if Android refuses
  /// (permission revoked between the check and the call), so a reminder is never dropped for lack of permission.
  /// [custom] null means the user's own reminders could not be read: the built-in ones are applied and the pending
  /// custom ones are kept as they are, instead of being cancelled as if the user had deleted them.
  static Future<void> apply(ReminderPrefs p, Map<int, String> sessions, {List<CustomReminder>? custom = const [], void Function(String title, String body)? inApp}) {
    // One apply at a time: two overlapping runs (a dashboard reload and a reminders edit) would each read the pending
    // list before the other's changes and could cancel what the other just scheduled. Each caller still gets its own
    // error; a failed run does not stop the next one.
    final run = _lastApply.catchError((Object _) {}).then((_) => _apply(p, sessions, custom: custom, inApp: inApp));
    _lastApply = run;
    return run;
  }

  static Future<void> _lastApply = Future.value();

  static Future<void> _apply(ReminderPrefs p, Map<int, String> sessions, {List<CustomReminder>? custom, void Function(String title, String body)? inApp}) async {
    var slots = slotsFor(p, sessions, custom: custom ?? const []);
    _ticker?.cancel();
    if (kIsWeb) {
      if (inApp != null && slots.isNotEmpty) _startTicker(slots, inApp);
      return;
    }
    await _init();
    // ponytail: iOS keeps only 64 pending notifications; built-in ones come first, so later custom days are dropped.
    if (defaultTargetPlatform == TargetPlatform.iOS && slots.length > 64) slots = slots.take(64).toList();
    final timing = await Reminders.timing() ?? ReminderTiming.inexact;
    final zone = tz.local.name;
    final pending = {for (final r in await _plugin.pendingNotificationRequests()) r.id: r.payload};
    final plan = planReminderChanges(slots, pending, timing, zone, refreshAll: !_refreshedThisLaunch, keepCustom: custom == null && p.enabled);
    for (final id in plan.cancel) {
      await _plugin.cancel(id: id);
    }
    for (final s in plan.schedule) {
      await _schedule(s, timing, zone);
    }
    _refreshedThisLaunch = true;
  }

  /// Cancels every Levlofit reminder on this phone (built-in and custom ids; never the test or anyone else's), for
  /// when the account is deleted or the person signs out: the alarms live in Android, not in the account, so without
  /// this they keep firing for an account that is gone, or for whoever signs in next.
  static Future<void> clearAll() => apply(remindersOff, const {});

  static Future<void> _schedule(Slot s, ReminderTiming timing, String zone) async {
    Future<void> at(ReminderTiming t) => _plugin.zonedSchedule(
          id: s.id,
          scheduledDate: _next(s),
          notificationDetails: _details,
          // Exact: Android's alarm-clock alarm (setAlarmClock), the one type power saving never delays; owner choice
          // 2026-10-28 after exact-while-idle reminders arrived about 24 s late on ColorOS. Shows the status-bar alarm icon.
          androidScheduleMode: t == ReminderTiming.exact ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle,
          title: s.title,
          body: s.body,
          payload: slotKey(s, t, zone),
          matchDateTimeComponents: s.weekday == null ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
        );
    if (timing == ReminderTiming.inexact) return at(ReminderTiming.inexact);
    try {
      await at(ReminderTiming.exact);
    } on PlatformException {
      // Exact alarms were refused (permission revoked since the check): keep the reminder, just inexact.
      await at(ReminderTiming.inexact);
    }
  }

  /// Tests replace the plugin calls of the timing experiment; the app never sets these.
  @visibleForTesting
  static Future<void> Function(Slot slot, tz.TZDateTime at)? alarmClockScheduleOverride;
  @visibleForTesting
  static Future<void> Function(int id)? alarmClockCancelOverride;

  /// Schedules (or replaces: same id) the one-off alarm-clock test for [at]. Returns when it will fire, or null
  /// with [onError] called when Android refuses (alarm-clock alarms need the same Alarms & reminders access).
  static Future<tz.TZDateTime?> scheduleAlarmClockTest(TimeOfDay at, {void Function(String message)? onError}) async {
    final slot = alarmClockTestSlot(at);
    try {
      if (alarmClockScheduleOverride case final f?) {
        final when = nextOccurrence(slot, tz.TZDateTime.now(tz.local));
        await f(slot, when);
        return when;
      }
      if (kReleaseMode || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
      await _init();
      final when = _next(slot);
      await _plugin.zonedSchedule(
        id: slot.id,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        title: slot.title,
        body: slot.body,
        payload: 'lvtest|alarmClock|${slot.hour}|${slot.minute}',
        // no matchDateTimeComponents: fires once, never repeats
      );
      return when;
    } on PlatformException {
      onError?.call('Android did not allow it. Alarm-clock timing needs Alarms & reminders access for Levlofit.');
      return null;
    }
  }

  /// Cancels the test alarm only; reminders are untouched.
  static Future<void> cancelAlarmClockTest() async {
    if (alarmClockCancelOverride case final f?) return f(alarmClockTestId);
    if (kIsWeb) return;
    await _init();
    await _plugin.cancel(id: alarmClockTestId);
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

  static tz.TZDateTime _next(Slot s) => nextOccurrence(s, tz.TZDateTime.now(tz.local));

  /// The next wall-clock [s.hour]:[s.minute] after [now], in [now]'s timezone, on [s.weekday] if set. Steps by
  /// calendar day, not 24 hours, so a daylight-saving change keeps 18:00 at 18:00. Android repeats it from there
  /// by matching the local day and time (matchDateTimeComponents).
  @visibleForTesting
  static tz.TZDateTime nextOccurrence(Slot s, tz.TZDateTime now) {
    for (var d = 0; d <= 8; d++) {
      final at = tz.TZDateTime(now.location, now.year, now.month, now.day + d, s.hour, s.minute);
      if (at.isAfter(now) && (s.weekday == null || at.weekday == s.weekday)) return at;
    }
    throw StateError('no occurrence within 8 days'); // unreachable: every weekday occurs within 7 days
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
      'updated_at': utcNow(),
    });

/// The user's own reminders, oldest first.
Future<List<CustomReminder>> loadCustomReminders() async {
  final rows = await supabase.from('custom_reminders').select('id, name, remind_at, weekdays, enabled').order('created_at').order('id'); // stable order: slot ids follow it
  return [for (final r in rows) customFromRow(r)];
}

CustomReminder customFromRow(Map<String, dynamic> r) {
  final t = (r['remind_at'] as String).split(':');
  return (
    id: r['id'] as String,
    name: r['name'] as String,
    at: TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1])),
    weekdays: {for (final d in r['weekdays'] as List) d as int},
    enabled: r['enabled'] as bool,
  );
}

Map<String, dynamic> customToRow(CustomReminder r) => {
      'name': r.name.trim(),
      'remind_at': '${r.at.hour.toString().padLeft(2, '0')}:${r.at.minute.toString().padLeft(2, '0')}',
      'weekdays': r.weekdays.length == 7 ? <int>[] : (r.weekdays.toList()..sort()),
      'enabled': r.enabled,
    };

/// Creates or updates one reminder and returns it as saved.
Future<CustomReminder> saveCustomReminder(CustomReminder r) async {
  final row = customToRow(r);
  final saved = r.id == null
      ? await supabase.from('custom_reminders').insert(row).select().single()
      : await supabase.from('custom_reminders').update({...row, 'updated_at': utcNow()}).eq('id', r.id!).select().single();
  return customFromRow(saved);
}

Future<void> deleteCustomReminder(String id) => supabase.from('custom_reminders').delete().eq('id', id);

/// Edit sheet for one reminder. Pops with the edited reminder, or with the string 'delete'.
class CustomReminderEditor extends StatefulWidget {
  const CustomReminderEditor({super.key, this.initial});
  final CustomReminder? initial;

  @override
  State<CustomReminderEditor> createState() => _CustomReminderEditorState();
}

class _CustomReminderEditorState extends State<CustomReminderEditor> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late TimeOfDay _at = widget.initial?.at ?? const TimeOfDay(hour: 8, minute: 0);
  late final Set<int> _days = {...?widget.initial?.weekdays};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete this reminder?'),
        content: Text('"${widget.initial!.name}" will stop and be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure == true && mounted) Navigator.pop(context, 'delete');
  }

  @override
  Widget build(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final t = Theme.of(context).textTheme;
    final ok = _name.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.initial == null ? 'New reminder' : 'Edit reminder', style: t.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: widget.initial == null,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'Creatine, stretch, walk'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule, size: 18),
          label: Text(_at.format(context)),
          onPressed: () async {
            final at = await showTimePicker(context: context, initialTime: _at);
            if (at != null) setState(() => _at = at);
          },
        ),
        const SizedBox(height: 16),
        Text('Repeat: ${describeDays(_days)}', style: t.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(names[d - 1]),
              selected: _days.contains(d),
              onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
            ),
        ]),
        const SizedBox(height: 4),
        Text('No day picked means every day.', style: t.bodySmall),
        const SizedBox(height: 20),
        Row(children: [
          if (widget.initial?.id != null) TextButton(onPressed: _delete, child: const Text('Delete')),
          const Spacer(),
          FilledButton(
            onPressed: ok
                ? () => Navigator.pop<Object>(context, (id: widget.initial?.id, name: _name.text.trim(), at: _at, weekdays: {..._days}, enabled: widget.initial?.enabled ?? true))
                : null,
            child: const Text('Save'),
          ),
        ]),
      ]),
    );
  }
}

// Phone steps from Health Connect (Android). Daily totals only, last 7 days, read when the person opens Progress;
// never in the background. Steps stay on this phone (no table, no upload); only when the person switches on
// "Share with Levlofit AI" are the 7 daily totals sent with a coach message. The Android side is compiled only into
// builds made with -Plevlofit.healthConnect=true (android/healthconnect); every other build reports "unsupported" and
// requests nothing. Checked on an Android 16 phone 2026-10-17 (grant, revoke and re-allow in Health Connect, totals
// equal to Health Connect's own, account switch, disconnect, privacy links, denial, reboot, R8 release build); the
// 30-minute stale label on a phone and Android 13 or older were not run (docs/STEP_COUNTER_DEVICE_CHECKLIST.md).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show prefs;
import 'theme.dart';

enum StepsAvailability { unsupported, notInstalled, updateRequired, available }

/// One day's total. [steps] is null when Health Connect has nothing for that day: never shown or sent as zero.
typedef StepDay = ({DateTime day, int? steps});

/// Platform access, as a parameter so tests can supply their own.
typedef StepsApi = ({
  Future<StepsAvailability> Function() availability,
  Future<bool> Function() hasPermission,
  Future<bool> Function() requestPermission,
  Future<Map<String, int>> Function(DateTime firstDay, int days) readDaily, // 'yyyy-mm-dd' -> steps
  Future<void> Function() openSettings,
});

const healthConnectChannel = MethodChannel('levlofit/health_connect');

/// The Health Connect bridge. A build without it (no plugin) is unsupported, not an error.
final StepsApi healthConnectSteps = (
  availability: () async {
    try {
      return switch (await healthConnectChannel.invokeMethod<String>('availability')) {
        'available' => StepsAvailability.available,
        'not_installed' => StepsAvailability.notInstalled,
        'update_required' => StepsAvailability.updateRequired,
        _ => StepsAvailability.unsupported,
      };
    } on MissingPluginException {
      return StepsAvailability.unsupported;
    }
  },
  hasPermission: () async => await healthConnectChannel.invokeMethod<bool>('hasPermission') ?? false,
  requestPermission: () async => await healthConnectChannel.invokeMethod<bool>('requestPermission') ?? false,
  readDaily: (first, days) async {
    final raw = await healthConnectChannel.invokeMapMethod<String, dynamic>('readDaily', {'firstDay': isoDate(first), 'days': days});
    return {for (final e in (raw ?? const {}).entries) if (e.value is int) e.key: e.value as int};
  },
  openSettings: () async => healthConnectChannel.invokeMethod<void>('openSettings'),
);

/// Whether Health Connect opened the app to show why it reads steps (its permission screens link here); asks once.
Future<bool> healthPermissionScreenRequested() async {
  try {
    return await healthConnectChannel.invokeMethod<bool>('consumeRationaleLaunch') ?? false;
  } on MissingPluginException {
    return false;
  }
}

/// The same request while the app is already open (the bridge calls back instead of relaunching).
void onHealthRationale(void Function() show) => healthConnectChannel.setMethodCallHandler((call) async {
      if (call.method == 'showRationale') show();
    });

String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// More than this in one day is treated as a sensor or import error and left out (an ultramarathon is about 60,000).
const maxPlausibleSteps = 100000;

/// The last [days] days ending [today], oldest first. Days Health Connect did not report, and implausible totals
/// (negative or above [maxPlausibleSteps]), are null.
List<StepDay> lastDays(Map<String, int> totals, DateTime today, {int days = 7}) => [
      for (var i = days - 1; i >= 0; i--)
        if (DateTime(today.year, today.month, today.day - i) case final d)
          (day: d, steps: switch (totals[isoDate(d)]) { final s? when s >= 0 && s <= maxPlausibleSteps => s, _ => null }),
    ];

/// Average over the days that have data (today is partial, so it is left out); null with no complete day.
int? dailyAverage(List<StepDay> days, DateTime today) {
  final full = [for (final d in days) if (d.steps != null && d.day.isBefore(DateTime(today.year, today.month, today.day))) d.steps!];
  return full.isEmpty ? null : (full.reduce((a, b) => a + b) / full.length).round();
}

/// Totals read longer ago than this are labelled as not current.
const stepsStaleAfter = Duration(minutes: 30);
bool stepsStale(DateTime readAt, DateTime now) => now.difference(readAt) > stepsStaleAfter;

// ---- the person's choices on this phone ---------------------------------------------------------------------

const _connectedKey = 'steps.connected', _shareKey = 'steps.shareWithCoach';
bool stepsConnected() => prefs.getBool(_connectedKey) ?? false;
bool stepsShareWithCoach() => stepsConnected() && (prefs.getBool(_shareKey) ?? false);
Future<void> setStepsConnected(bool on) async {
  await prefs.setBool(_connectedKey, on);
  if (!on) await prefs.setBool(_shareKey, false); // disconnecting also stops sharing
}

Future<void> setStepsShareWithCoach(bool on) => prefs.setBool(_shareKey, on);

/// Another account (or none) on this phone: forget the totals and the choices, which belong to whoever made them.
Future<void> forgetSteps() async {
  latestSteps = null;
  await setStepsConnected(false);
}

/// What a coach message may carry: the 7 daily totals and when they were read, only with the person's consent and
/// only when read in the last 24 hours. Days without data stay null.
Map<String, dynamic>? coachStepsPayload(List<StepDay>? days, DateTime? readAt, DateTime now, {required bool consent}) {
  if (!consent || days == null || readAt == null || now.difference(readAt) > const Duration(hours: 24)) return null;
  return {
    'readAt': readAt.toUtc().toIso8601String(),
    'days': [for (final d in days) {'date': isoDate(d.day), 'steps': d.steps}],
  };
}

/// The latest totals read on this phone in this app session, for the coach. Never stored.
({List<StepDay> days, DateTime readAt})? latestSteps;

// ---- the card -----------------------------------------------------------------------------------------------

enum _State { loading, unsupported, notInstalled, updateRequired, notConnected, denied, connected, error }

class StepsCard extends StatefulWidget {
  const StepsCard({super.key, this.api, this.now});
  final StepsApi? api; // tests only
  final DateTime Function()? now; // tests only

  @override
  State<StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<StepsCard> with WidgetsBindingObserver {
  late final StepsApi _api = widget.api ?? healthConnectSteps;
  DateTime _now() => (widget.now ?? DateTime.now)();
  _State _state = _State.loading;
  List<StepDay>? _days;
  DateTime? _readAt;
  bool _busy = false;
  Timer? _staleTimer; // shows the 'may be out of date' line when the read turns 30 minutes old on screen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _staleTimer?.cancel();
    super.dispose();
  }

  /// Back in the app (often from Health Connect's settings, where access may have been granted or removed): check
  /// again. Not while a permission request is open, which itself leaves and returns to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final a = await _api.availability();
      if (!mounted) return;
      if (a != StepsAvailability.available) {
        return setState(() => _state = switch (a) {
              StepsAvailability.notInstalled => _State.notInstalled,
              StepsAvailability.updateRequired => _State.updateRequired,
              _ => _State.unsupported,
            });
      }
      if (!stepsConnected()) return setState(() => _state = _State.notConnected);
      if (!await _api.hasPermission()) {
        // Revoked in Health Connect since: stop reading, stop sharing what was read, and say so; the person can
        // reconnect.
        latestSteps = null;
        if (mounted) setState(() => _state = _State.denied);
        return;
      }
      await _read();
    } catch (_) {
      latestSteps = null; // nothing current to share
      if (mounted) setState(() => _state = _State.error);
    }
  }

  Future<void> _read() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final totals = await _api.readDaily(DateTime(today.year, today.month, today.day - 6), 7);
    final days = lastDays(totals, today);
    latestSteps = (days: days, readAt: now);
    _staleTimer?.cancel();
    // Nothing else rebuilds the card while it stays on screen, so without this the line would never appear.
    _staleTimer = Timer(stepsStaleAfter + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
    if (mounted) {
      setState(() {
        _days = days;
        _readAt = now;
        _state = _State.connected;
      });
    }
  }

  Future<void> _connect() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Connect Health Connect?'),
        content: const Text('Levlofit reads your daily step totals for the last 7 days, only while you look at Progress. '
            'They stay on this phone. Levlofit AI sees them only if you switch on sharing below. '
            'You can disconnect here or remove access in Health Connect at any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Continue')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final granted = await _api.requestPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() => _state = _State.denied);
        return;
      }
      await setStepsConnected(true);
      await _read();
    } catch (_) {
      if (mounted) setState(() => _state = _State.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await setStepsConnected(false);
    latestSteps = null;
    _staleTimer?.cancel();
    if (mounted) {
      setState(() {
        _days = null;
        _readAt = null;
        _state = _State.notConnected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: c.onSurfaceVariant);
    Widget line(String s) => Text(s, style: muted);
    final children = <Widget>[
      Text('STEPS  ·  HEALTH CONNECT', style: monoLabel(context)),
      const SizedBox(height: 8),
      ...switch (_state) {
        _State.loading => [const LinearProgressIndicator(minHeight: 2)],
        _State.unsupported => [line('Step counting is not available in this version of the app.')],
        _State.notInstalled => [
            line('Steps come from Health Connect, which is not on this phone.'),
            TextButton(onPressed: _api.openSettings, child: const Text('Get Health Connect')),
          ],
        _State.updateRequired => [
            line('Health Connect needs an update before Levlofit can read steps.'),
            TextButton(onPressed: _api.openSettings, child: const Text('Update Health Connect')),
          ],
        _State.notConnected => [
            line('See your daily steps next to your training. Read only while you look at this page.'),
            Align(alignment: Alignment.centerLeft, child: FilledButton.tonal(onPressed: _busy ? null : _connect, child: const Text('Connect'))),
          ],
        _State.denied => [
            line('Levlofit does not have access to your steps. Nothing is read.'),
            Wrap(spacing: 8, children: [
              TextButton(onPressed: _busy ? null : _connect, child: const Text('Try again')),
              TextButton(onPressed: _api.openSettings, child: const Text('Open Health Connect')),
              if (stepsConnected()) TextButton(onPressed: _disconnect, child: const Text('Disconnect')),
            ]),
          ],
        _State.error => [
            line('Could not read your steps just now.'),
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        _State.connected => _connected(context, muted),
      },
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  List<Widget> _connected(BuildContext context, TextStyle? muted) {
    final days = _days!;
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final avg = dailyAverage(days, today);
    final todaySteps = days.last.steps;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return [
      Text(todaySteps == null ? 'No steps recorded today yet' : '$todaySteps steps today', style: Theme.of(context).textTheme.titleMedium),
      Text(avg == null ? 'No full day recorded in the last 6 days.' : 'About $avg a day over the days recorded.', style: muted),
      const SizedBox(height: 6),
      Text([for (final d in days) '${names[d.day.weekday - 1]} ${d.steps ?? '–'}'].join('   '), style: muted),
      if (stepsStale(_readAt!, now)) Text('Read at ${_readAt!.hour.toString().padLeft(2, '0')}:${_readAt!.minute.toString().padLeft(2, '0')}; may be out of date.', style: muted),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Share step totals with Levlofit AI'),
        subtitle: const Text('Sends these 7 daily totals with your coach messages. Off by default.'),
        value: stepsShareWithCoach(),
        onChanged: (v) async {
          await setStepsShareWithCoach(v);
          if (mounted) setState(() {});
        },
      ),
      Wrap(spacing: 8, children: [
        TextButton(onPressed: _refresh, child: const Text('Refresh')),
        TextButton(onPressed: _disconnect, child: const Text('Disconnect')),
      ]),
    ];
  }
}

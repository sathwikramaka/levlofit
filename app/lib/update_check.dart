// Update notice (2026-10-27): Levlofit ships outside the Play Store, so the app asks the website's /version.json for
// the newest build once per app start and offers it when it is newer than this one. Production builds ask the live
// site unless --dart-define=LEVLOFIT_UPDATE_URL overrides it (1.0.0 and 1.0.1 shipped without the define, so they never
// checked). Other builds, the web app (it cannot install an APK) and offline starts show nothing.
// Update installs inside the app on Android (installUpdate, android/.../UpdateInstaller.kt); the browser is the fallback.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'app_version.dart';
import 'main.dart' show backendChoice, prefs;
import 'theme.dart';

const updateUrl = String.fromEnvironment('LEVLOFIT_UPDATE_URL',
    defaultValue: backendChoice == 'production' ? 'https://levlofit.pages.dev/version.json' : '');
const _dismissedKey = 'update_dismissed_build';

/// [required]: this build is below the site's min_build, so the card has no Later button and cannot be dismissed.
/// [sha256]: the APK's checksum from the site ('' when absent), checked before the in-app install.
typedef Update = ({String version, int build, String url, bool required, String sha256});

/// The offered update from a /version.json body, or null when there is none newer than [currentBuild].
Update? parseUpdate(String body, {int currentBuild = appBuild}) {
  try {
    final j = jsonDecode(body);
    if (j is! Map) return null;
    final build = j['build'], url = j['url'], version = j['version'], minBuild = j['min_build'], sha = j['sha256'];
    if (build is! int || url is! String || version is! String || build <= currentBuild) return null;
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https') return null;
    final checksum = sha is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) ? sha : '';
    return (version: version, build: build, url: url, required: minBuild is int && currentBuild < minBuild, sha256: checksum);
  } catch (_) {
    return null;
  }
}

Future<Update?>? _check;

Future<Update?> checkForUpdate({http.Client? client}) => _check ??= () async {
      if (updateUrl.isEmpty || kIsWeb) return null;
      unawaited(_watchForUpdates());
      try {
        final res = await (client ?? http.Client()).get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return null;
        final u = parseUpdate(res.body);
        if (u == null) return null;
        int? dismissed;
        try {
          dismissed = prefs.getInt(_dismissedKey);
        } catch (_) {}
        return dismissed == u.build && !u.required ? null : u;
      } catch (_) {
        return null;
      }
    }();

// ---- notification when a new version is out ------------------------------------------------------------------------
// Levlofit has no push service, so the phone asks: Android runs this about every 12 hours with a network, even when the
// app is closed, and notifies once per version. The timing is Android's: it can be late, and battery savers can delay it.

const _notifiedKey = 'update_notified_build';
const _watchTask = 'levlofit_update_watch';

/// The update to notify about: only a newer version, and only once for each one.
Update? updateToNotify(String body, {int currentBuild = appBuild, int? alreadyNotified}) {
  final u = parseUpdate(body, currentBuild: currentBuild);
  return u == null || u.build == alreadyNotified ? null : u;
}

Future<void> _watchForUpdates() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(updateWatchDispatcher);
    await Workmanager().registerPeriodicTask(_watchTask, _watchTask,
        frequency: const Duration(hours: 12),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
  } catch (_) {} // the card on the dashboard still offers the update
}

/// Runs in Android's background worker, apart from the app: nothing from main() is set up here.
@pragma('vm:entry-point')
void updateWatchDispatcher() {
  Workmanager().executeTask((_, _) async {
    final res = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return true;
    final saved = await SharedPreferences.getInstance();
    final u = updateToNotify(res.body, alreadyNotified: saved.getInt(_notifiedKey));
    if (u == null) return true;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await plugin.show(
      id: 2, // below the reminder ids, so the reminder schedule never cancels it
      title: 'Levlofit ${u.version} is ready',
      body: 'Open Levlofit to install the update.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('levlo_updates_v1', 'App updates', channelDescription: 'When a new version of Levlofit is out', color: Color(0xFFFF6A1A)),
      ),
    );
    await saved.setInt(_notifiedKey, u.build);
    return true;
  });
}

const _installer = MethodChannel('levlofit/update');

/// Installs [u] inside the app on Android: download, checksum check, then Android's installer. Returns a note for the
/// card when the person must act first (allow installs from Levlofit), or null. Anything else that fails, and other
/// platforms, open the download in the browser instead. [install] and [open] replace the platform calls in tests.
Future<String?> installUpdate(Update u, {Future<Object?> Function(Map<String, String> args)? install, Future<void> Function(Uri)? open}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && u.sha256.isNotEmpty) {
    try {
      final args = {'url': u.url, 'sha256': u.sha256};
      final r = await (install?.call(args) ?? _installer.invokeMethod<String>('install', args));
      if (r == 'installing') return null;
      if (r == 'permission') return 'Allow Levlofit to install updates in the screen that opened, then tap Update again.';
    } catch (_) {}
  }
  await (open ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(Uri.parse(u.url));
  return null;
}

/// A small card on the dashboard when a newer version exists; dismissing hides it until the next version.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, this.check});
  final Future<Update?> Function()? check; // tests

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  late final Future<Update?> _future = (widget.check ?? checkForUpdate)();
  bool _hidden = false;
  bool _installing = false;
  String? _note;

  @override
  Widget build(BuildContext context) => FutureBuilder<Update?>(
        future: _future,
        builder: (context, snap) {
          final u = snap.data;
          if (u == null || _hidden) return const SizedBox.shrink();
          final c = Theme.of(context).colorScheme;
          final t = Theme.of(context).textTheme;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.primary)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.required ? 'UPDATE NEEDED' : 'UPDATE READY', style: monoLabel(context)),
                    const SizedBox(height: 2),
                    Text(u.required ? 'Install Levlofit ${u.version} to keep using the coach.' : 'Levlofit ${u.version} is available.',
                        style: t.bodyMedium),
                    if (_note != null) ...[const SizedBox(height: 4), Text(_note!, style: t.bodySmall)],
                  ]),
                ),
                if (!u.required) TextButton(
                  onPressed: () {
                    setState(() => _hidden = true);
                    try {
                      prefs.setInt(_dismissedKey, u.build);
                    } catch (_) {}
                  },
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: _installing
                      ? null
                      : () async {
                          setState(() {
                            _installing = true;
                            _note = null;
                          });
                          final note = await installUpdate(u);
                          if (mounted) {
                            setState(() {
                              _installing = false;
                              _note = note;
                            });
                          }
                        },
                  child: Text(_installing ? 'Downloading...' : 'Update'),
                ),
              ]),
            ),
          );
        },
      );
}

// Update notice (2026-10-27): Levlofit ships outside the Play Store, so the app asks the website's /version.json for
// the newest build once per app start and offers it when it is newer than this one. Production builds ask the live
// site unless --dart-define=LEVLOFIT_UPDATE_URL overrides it (1.0.0 and 1.0.1 shipped without the define, so they never
// checked). Other builds, the web app (it cannot install an APK) and offline starts show nothing.
// Update installs inside the app on Android (installUpdate, android/.../UpdateInstaller.kt); the browser is the fallback.
import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

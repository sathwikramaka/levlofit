// Update notice (2026-10-27): Levlofit ships outside the Play Store, so the app asks the website's /version.json for
// the newest build once per app start and offers it when it is newer than this one. The address comes from
// --dart-define=LEVLOFIT_UPDATE_URL at build time; without it, or offline, nothing is shown.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_version.dart';
import 'main.dart' show prefs;
import 'theme.dart';

const updateUrl = String.fromEnvironment('LEVLOFIT_UPDATE_URL');
const _dismissedKey = 'update_dismissed_build';

typedef Update = ({String version, int build, String url});

/// The offered update from a /version.json body, or null when there is none newer than [currentBuild].
Update? parseUpdate(String body, {int currentBuild = appBuild}) {
  try {
    final j = jsonDecode(body);
    if (j is! Map) return null;
    final build = j['build'], url = j['url'], version = j['version'];
    if (build is! int || url is! String || version is! String || build <= currentBuild) return null;
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https') return null;
    return (version: version, build: build, url: url);
  } catch (_) {
    return null;
  }
}

Future<Update?>? _check;

Future<Update?> checkForUpdate({http.Client? client}) => _check ??= () async {
      if (updateUrl.isEmpty) return null;
      try {
        final res = await (client ?? http.Client()).get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return null;
        final u = parseUpdate(res.body);
        if (u == null) return null;
        int? dismissed;
        try {
          dismissed = prefs.getInt(_dismissedKey);
        } catch (_) {}
        return dismissed == u.build ? null : u;
      } catch (_) {
        return null;
      }
    }();

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
                    Text('UPDATE READY', style: monoLabel(context)),
                    const SizedBox(height: 2),
                    Text('Levlofit ${u.version} is available.', style: t.bodyMedium),
                  ]),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _hidden = true);
                    try {
                      prefs.setInt(_dismissedKey, u.build);
                    } catch (_) {}
                  },
                  child: const Text('Later'),
                ),
                FilledButton(onPressed: () => launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication), child: const Text('Update')),
              ]),
            ),
          );
        },
      );
}

import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/app_version.dart';
import 'package:levlo/error_report.dart';
import 'package:levlo/main.dart';
import 'package:levlo/update_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('app_version.dart matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.trim(), 'version: $appVersion+$appBuild');
  });

  test('update: only a newer build with an https link is offered', () {
    expect(parseUpdate('{"version":"1.0.1","build":2,"url":"https://x.test/a.apk"}', currentBuild: 1)?.version, '1.0.1');
    expect(parseUpdate('{"version":"1.0.0","build":1,"url":"https://x.test/a.apk"}', currentBuild: 1), isNull);
    expect(parseUpdate('{"version":"","build":0,"url":""}', currentBuild: 1), isNull); // site without a release
    expect(parseUpdate('{"version":"9","build":9,"url":"http://x.test/a.apk"}', currentBuild: 1), isNull);
    expect(parseUpdate('not json'), isNull);
    expect(parseUpdate('{"version":"1.0.4","build":6,"url":"https://x.test/a.apk","min_build":6}', currentBuild: 5)?.required, isTrue);
    expect(parseUpdate('{"version":"1.0.4","build":6,"url":"https://x.test/a.apk","min_build":5}', currentBuild: 5)?.required, isFalse);
    expect(parseUpdate('{"version":"1.0.4","build":6,"url":"https://x.test/a.apk"}', currentBuild: 5)?.required, isFalse);
  });

  test('in-app update: checksum parsed, installer used on Android, browser otherwise', () async {
    final sha = 'a' * 64;
    expect(parseUpdate('{"version":"1.0.6","build":8,"url":"https://x.test/a.apk","sha256":"$sha"}', currentBuild: 7)?.sha256, sha);
    expect(parseUpdate('{"version":"1.0.6","build":8,"url":"https://x.test/a.apk","sha256":"nope"}', currentBuild: 7)?.sha256, '');
    final u = (version: '1.0.6', build: 8, url: 'https://x.test/a.apk', required: true, sha256: sha);
    Map<String, String>? sent;
    Uri? opened;
    Future<void> open(Uri uri) async => opened = uri;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      expect(await installUpdate(u, install: (a) async => (sent = a, 'installing').$2, open: open), isNull);
      expect(sent, {'url': 'https://x.test/a.apk', 'sha256': sha});
      expect(opened, isNull);
      expect(await installUpdate(u, install: (_) async => 'permission', open: open), contains('Allow Levlofit'));
      expect(opened, isNull);
      expect(await installUpdate(u, install: (_) async => throw Exception('checksum mismatch'), open: open), isNull);
      expect(opened, Uri.parse('https://x.test/a.apk'), reason: 'a failed download falls back to the browser');
      opened = null;
      final noSum = (version: '1.0.6', build: 8, url: 'https://x.test/a.apk', required: true, sha256: '');
      await installUpdate(noSum, install: (_) async => fail('no checksum: never installs in the app'), open: open);
      expect(opened, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a required update has no Later button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: UpdateBanner(check: () async => (version: '1.0.4', build: 6, url: 'https://x.test/a.apk', required: true, sha256: ''))),
    ));
    await tester.pump();
    expect(find.text('Install Levlofit 1.0.4 to keep using the coach.'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('update card shows, and Later hides it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: UpdateBanner(check: () async => (version: '1.0.1', build: 2, url: 'https://x.test/a.apk', required: false, sha256: ''))),
    ));
    await tester.pump();
    expect(find.text('Levlofit 1.0.1 is available.'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pump();
    expect(find.text('Levlofit 1.0.1 is available.'), findsNothing);
    expect(prefs.getInt('update_dismissed_build'), 2);
  });

  test('error rows: emails masked, long text cut, platform named', () {
    final row = errorRow(Exception('failed for ravi@example.com ${'x' * 2000}'), StackTrace.current, platform: TargetPlatform.android, web: false)!;
    expect(row['message'], contains('<email>'));
    expect(row['message'], isNot(contains('ravi@example.com')));
    expect(row['message']!.length, 1000);
    expect(row['platform'], 'android');
    expect(row['app_version'], appVersion);
    expect(errorRow('x', null, platform: TargetPlatform.windows, web: true)!['platform'], 'web');
    expect(errorRow('   ', null, platform: TargetPlatform.android, web: false), isNull);
  });

  test('update notification: a newer version once, never for this version or a failed read', () {
    const body = '{"version":"1.0.9","build":11,"url":"https://x.test/a.apk"}';
    expect(updateToNotify(body, currentBuild: 10)?.version, '1.0.9');
    expect(updateToNotify(body, currentBuild: 10, alreadyNotified: 11), isNull);
    expect(updateToNotify(body, currentBuild: 10, alreadyNotified: 10)?.build, 11);
    expect(updateToNotify(body, currentBuild: 11), isNull);
    expect(updateToNotify('not json', currentBuild: 10), isNull);
  });
}

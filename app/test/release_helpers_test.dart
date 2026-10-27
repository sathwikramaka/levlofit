import 'dart:io';

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
  });

  testWidgets('update card shows, and Later hides it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: UpdateBanner(check: () async => (version: '1.0.1', build: 2, url: 'https://x.test/a.apk'))),
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
}

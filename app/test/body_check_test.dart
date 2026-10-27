import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/body_check.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> show(WidgetTester tester, {required Future<Object?> Function(Map<String, String>) send, List<Map<String, String>>? sent}) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BodyCheckCard(pick: () async => Uint8List.fromList([1, 2, 3]), send: (b) {
            sent?.add(b);
            return send(b);
          }),
        ),
      ),
    ));
  }

  test('result parsing keeps only known focus areas; prompt names them', () {
    final r = parseResult({'observations': ['Stance is even.'], 'focus': ['core', 'arms']})!;
    expect(r.focus, ['core']);
    expect(coachPromptFor(r), contains('core'));
    expect(parseResult('nope'), isNull);
  });

  testWidgets('nothing is sent unless the person agrees', (tester) async {
    final sent = <Map<String, String>>[];
    await show(tester, send: (_) async => null, sent: sent);
    await tester.tap(find.text('Check a photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not saved by Levlofit'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  });

  testWidgets('after agreeing: photo sent as base64 JPEG, notes and focus shown', (tester) async {
    final sent = <Map<String, String>>[];
    await show(tester, sent: sent, send: (_) async => {'observations': ['Shoulders sit level.'], 'focus': ['upper body']});
    await tester.tap(find.text('Check a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree, choose photo'));
    await tester.pumpAndSettle();
    expect(sent.single, {'image': 'AQID', 'mime': 'image/jpeg'});
    expect(find.text('·  Shoulders sit level.'), findsOneWidget);
    expect(find.text(focusAdvice['upper body']!), findsOneWidget);
    expect(find.text('Adjust my plan with Levlofit AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

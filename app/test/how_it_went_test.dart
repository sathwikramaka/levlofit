import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/progression.dart';
import 'package:levlo/session.dart';

// The optional effort and pain question after a session (session.dart). UI behaviour only.

Future<({int? rpe, Pain? pain})?> _open(WidgetTester tester, Future<void> Function() act) async {
  ({int? rpe, Pain? pain})? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result = await showModalBottomSheet<({int? rpe, Pain? pain})>(context: context, builder: (_) => const HowItWentSheet()),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act();
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Save stays disabled until something is chosen', (tester) async {
    await _open(tester, () async {});
    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(save.onPressed, isNull);
  });

  testWidgets('effort and pain answers are returned on Save', (tester) async {
    final r = await _open(tester, () async {
      await tester.tap(find.widgetWithText(ChoiceChip, '8'));
      await tester.pump();
      await tester.tap(find.text('Pain made me stop'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    expect(r, (rpe: 8, pain: Pain.stopped));
  });

  testWidgets('choosing only pain is enough, and tapping a chip again clears it', (tester) async {
    final r = await _open(tester, () async {
      await tester.tap(find.widgetWithText(ChoiceChip, '5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '5'));
      await tester.pump();
      await tester.tap(find.text('None'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    expect(r, (rpe: null, pain: Pain.none));
  });

  testWidgets('Skip saves nothing', (tester) async {
    final r = await _open(tester, () async => tester.tap(find.text('Skip')));
    expect(r, isNull);
  });
}

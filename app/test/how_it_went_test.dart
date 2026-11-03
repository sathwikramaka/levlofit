import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/progression.dart';
import 'package:levlo/session.dart';

// The optional effort and pain question after a session (session.dart). UI behaviour only.

Future<({int? rpe, Pain? pain, int? minutes})?> _open(WidgetTester tester, Future<void> Function() act) async {
  ({int? rpe, Pain? pain, int? minutes})? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result = await showModalBottomSheet<({int? rpe, Pain? pain, int? minutes})>(context: context, builder: (_) => const HowItWentSheet()),
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
    expect(r, (rpe: 8, pain: Pain.stopped, minutes: null));
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
    expect(r, (rpe: null, pain: Pain.none, minutes: null));
  });

  testWidgets('Skip saves nothing', (tester) async {
    final r = await _open(tester, () async => tester.tap(find.text('Skip')));
    expect(r, isNull);
  });

  Future<({int? rpe, Pain? pain, int? minutes})?> openEdit(WidgetTester tester, Future<void> Function() act) async {
    ({int? rpe, Pain? pain, int? minutes})? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showModalBottomSheet<({int? rpe, Pain? pain, int? minutes})>(
                context: context, isScrollControlled: true, builder: (_) => const HowItWentSheet(rpe: 6, minutes: 45, askMinutes: true)),
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

  testWidgets('editing a logged day: length is prefilled and can be changed, earlier answers kept', (tester) async {
    final r = await openEdit(tester, () async {
      expect(find.text('45'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '70');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    expect(r, (rpe: 6, pain: null, minutes: 70));
  });

  testWidgets('editing: an impossible length blocks Save', (tester) async {
    await openEdit(tester, () async {
      await tester.enterText(find.byType(TextField), '900');
      await tester.pump();
      expect(find.text('1 to 600 minutes'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
    });
  });

  testWidgets('editing: an empty length clears it', (tester) async {
    final r = await openEdit(tester, () async {
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    });
    expect(r!.minutes, isNull);
    expect(r.rpe, 6);
  });

  testWidgets('after a session the length question is not asked', (tester) async {
    await _open(tester, () async {});
    expect(find.text('How long was it?'), findsNothing);
  });
}

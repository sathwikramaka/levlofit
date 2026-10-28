import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart';

// Batch B3: real weigh-ins propose a new plan weight; the plan changes only after the person confirms.
void main() {
  final d = DateTime(2026, 10, 28);
  ({DateTime day, double kg}) w(int daysAgo, double kg) => (day: d.subtract(Duration(days: daysAgo)), kg: kg);

  test('proposes the 7-day average when it is 2 % or more from the plan weight', () {
    expect(proposedPlanWeight(72, [w(6, 70.6), w(3, 70.4), w(0, 70.2)]), 70.4);
    expect(proposedPlanWeight(72, [w(0, 73.5)]), 73.5, reason: '2.1 % up');
  });

  test('no proposal under 2 %, without a plan weight, or without weigh-ins', () {
    expect(proposedPlanWeight(72, [w(0, 71.0)]), isNull, reason: '1.4 %');
    expect(proposedPlanWeight(null, [w(0, 60)]), isNull);
    expect(proposedPlanWeight(72, const []), isNull);
  });

  test('a single heavy day inside a steady week does not trigger it; readings older than 7 days are ignored', () {
    expect(proposedPlanWeight(72, [w(5, 72.0), w(3, 72.1), w(0, 74.0)]), isNull, reason: 'average 72.7, under 2 %');
    expect(proposedPlanWeight(72, [w(20, 60), w(10, 60), w(0, 71.8)]), isNull);
  });

  test('never proposes a weight outside what the plan engine accepts', () {
    expect(proposedPlanWeight(35, [w(0, 29)]), isNull);
  });

  testWidgets('confirm dialog: Not now returns false, Update plan returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) => TextButton(onPressed: () async => result = await confirmPlanWeight(c, fromKg: 72, toKg: 70.4), child: const Text('go'))),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Update your plan to 70.4 kg?'), findsOneWidget);
    expect(find.textContaining('still uses 72 kg'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update plan'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

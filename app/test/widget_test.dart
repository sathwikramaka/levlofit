import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/onboarding.dart';

void main() {
  testWidgets('ChoiceTile taps only when enabled (4-goal cap, egg allergy rule)', (tester) async {
    var taps = 0;
    Future<void> pump({required bool enabled}) => tester.pumpWidget(MaterialApp(
          home: Material(
            child: ChoiceTile(title: 'Eggitarian', selected: false, enabled: enabled, disabledNote: 'Blocked', onTap: () => taps++),
          ),
        ));

    await pump(enabled: true);
    await tester.tap(find.text('Eggitarian'));
    expect(taps, 1);

    await pump(enabled: false);
    await tester.tap(find.text('Eggitarian'));
    expect(taps, 1);
    expect(find.text('Blocked'), findsOneWidget);
  });
}

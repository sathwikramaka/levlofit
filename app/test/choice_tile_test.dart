// Found on a phone (2026-11-07): "Intermediate" broke mid-word in the two-column experience tiles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/onboarding.dart';
import 'package:levlo/theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a one-word tile title stays on one line in a narrow tile', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(body: Center(child: SizedBox(width: 120, child: ChoiceTile(title: 'Intermediate', subtitle: 'Train it with a plan', selected: false, onTap: () {})))),
    ));
    final line = tester.getSize(find.text('Intermediate')).height;
    expect(line, lessThan(30), reason: 'two lines would be about twice one line');
    expect(tester.takeException(), isNull);
  });
}

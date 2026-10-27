import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/handbook_book.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('front and back matter: introduction, objectives, conclusion, each with sections', () {
    expect([bookIntroduction.label, bookObjectives.label, bookConclusion.label], ['INTRODUCTION', 'OBJECTIVES', 'CONCLUSION']);
    for (final p in [bookIntroduction, bookObjectives, bookConclusion]) {
      expect(p.sections, isNotEmpty);
    }
    expect(bookIntroduction.sections.map((s) => s.body).join(), contains('not medical advice'));
  });

  testWidgets('a tile opens its page, readable at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [BookPageTile(bookObjectives)]))));
    await tester.tap(find.text(bookObjectives.title));
    await tester.pumpAndSettle();
    expect(find.text('1. Start safely'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

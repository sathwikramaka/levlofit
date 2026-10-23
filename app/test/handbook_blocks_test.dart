import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/handbook.dart';

// Handbook v4 book-structure blocks (part opener, key points, up next) and the fallback for unknown blocks.

Future<void> _show(WidgetTester tester, Map<String, dynamic> block) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Builder(builder: (context) => SingleChildScrollView(child: handbookBlock(context, block, (_) => null)))),
  ));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('part opener shows the part title and what the part covers', (tester) async {
    await _show(tester, {'t': 'part', 'title': 'Part B. Getting better', 'text': 'Progress comes from doing the basics for months.'});
    expect(find.text('PART B. GETTING BETTER'), findsOneWidget);
    expect(find.text('Progress comes from doing the basics for months.'), findsOneWidget);
  });

  testWidgets('key points list every point', (tester) async {
    await _show(tester, {'t': 'keypoints', 'title': 'Key points', 'items': ['First point.', 'Second point.', 'Third point.']});
    expect(find.text('KEY POINTS'), findsOneWidget);
    for (final p in ['First point.', 'Second point.', 'Third point.']) {
      expect(find.text(p), findsOneWidget);
    }
  });

  testWidgets('up next shows each linked chapter with its reason, not the slug', (tester) async {
    await _show(tester, {
      't': 'next',
      'title': 'Up next',
      'items': [
        {'ref': 'warm-up', 'title': 'Warming up', 'why': 'Every session starts by preparing for the first lift.'},
        {'ref': 'running', 'title': 'Running', 'why': 'For endurance, jump to Running.'},
      ],
    });
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('Warming up'), findsOneWidget);
    expect(find.text('For endurance, jump to Running.'), findsOneWidget);
    expect(find.text('warm-up'), findsNothing);
    expect(find.byType(InkWell), findsNWidgets(2));
  });

  testWidgets('a chapter opened by slug (Up next) shows its chapter number once loaded', (tester) async {
    Future<Map<String, dynamic>> load() async => {
          'id': 8,
          'title': 'Warming up',
          'minutes': 3,
          'blocks': {
            'sources': <String, String>{},
            'blocks': [
              {'t': 'lead', 'text': 'A short warm-up.'},
            ],
          },
        };
    await tester.pumpWidget(MaterialApp(home: ChapterScreen(slug: 'warm-up', load: load)));
    await tester.pumpAndSettle();
    expect(find.text('CHAPTER 08'), findsOneWidget);
    expect(find.text('Warming up'), findsOneWidget);
  });

  testWidgets('a chapter opened by id keeps its number in the title bar', (tester) async {
    Future<Map<String, dynamic>> load() async => {
          'id': 3,
          'title': 'How Levlofit builds your plan',
          'minutes': 3,
          'blocks': {'sources': <String, String>{}, 'blocks': <Map<String, dynamic>>[]},
        };
    await tester.pumpWidget(MaterialApp(home: ChapterScreen(id: 3, load: load)));
    expect(find.text('CHAPTER 03'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  test('chapter label pads the number and has a plain fallback', () {
    expect(ChapterScreen.label(7), 'CHAPTER 07');
    expect(ChapterScreen.label(43), 'CHAPTER 43');
    expect(ChapterScreen.label(null), 'CHAPTER');
  });

  testWidgets('evidence grades: unverified shows NOT YET VERIFIED; strong, moderate and consensus are unchanged', (tester) async {
    const labels = {
      'strong': 'STRONG EVIDENCE',
      'moderate': 'MODERATE EVIDENCE',
      'consensus': 'EXPERT CONSENSUS',
      'unverified': 'NOT YET VERIFIED',
    };
    const filled = {'strong': 3, 'moderate': 2, 'consensus': 1, 'unverified': 0};
    for (final grade in labels.keys) {
      await _show(tester, {'t': 'evidence', 'text': 'Note $grade.', 'source': 'x', 'grade': grade});
      expect(find.text('EVIDENCE'), findsOneWidget, reason: grade);
      expect(find.text(labels[grade]!), findsOneWidget, reason: grade);
      // The signal meter: three bars, the first [filled] in the primary colour.
      final primary = Theme.of(tester.element(find.text('EVIDENCE'))).colorScheme.primary;
      final bars = tester.widgetList<Container>(find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 14 && w.constraints?.maxHeight == 6));
      expect(bars.length, 3, reason: grade);
      final on = bars.where((c) => (c.decoration as BoxDecoration).color == primary).length;
      expect(on, filled[grade], reason: grade);
    }
  });

  testWidgets('an evidence note with an unknown grade shows no grade label', (tester) async {
    await _show(tester, {'t': 'evidence', 'text': 'No grade.', 'source': 'x', 'grade': 'something-else'});
    expect(find.text('No grade.'), findsOneWidget);
    expect(find.text('NOT YET VERIFIED'), findsNothing);
  });

  testWidgets('an unknown block type falls back to its text', (tester) async {
    await _show(tester, {'t': 'future-type', 'text': 'Plain fallback.'});
    expect(find.text('Plain fallback.'), findsOneWidget);
  });
}

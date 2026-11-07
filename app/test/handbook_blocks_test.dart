import 'dart:convert';
import 'dart:io';

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

  group('book blocks', () {
    String richText(WidgetTester tester, String contains) =>
        tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText()).firstWhere((s) => s.contains(contains));

    Future<void> showCiting(WidgetTester tester, Map<String, dynamic> block) => tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Builder(builder: (context) => SingleChildScrollView(child: handbookBlock(context, block, (k) => k == 'known' ? '[1]' : null)))),
        ));

    testWidgets('paragraph strips bold marks, numbers known sources and drops unknown ones', (tester) async {
      await showCiting(tester, {'t': 'p', 'text': 'Eat **enough** food. {known} Really. {missing}'});
      expect(richText(tester, 'food'), 'Eat enough food. [1] Really. ');
    });

    testWidgets('a chapter link shows its title, not the slug, and is tappable', (tester) async {
      await showCiting(tester, {'t': 'p', 'text': 'See [[recovery|Recovery]] next.'});
      expect(richText(tester, 'See'), 'See Recovery next.');
      final spans = <TextSpan>[];
      tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((s) {
        if (s is TextSpan && s.recognizer != null) spans.add(s);
        return true;
      });
      expect(spans.single.text, 'Recovery');
    });

    testWidgets('notes show their title and every paragraph', (tester) async {
      await showCiting(tester, {'t': 'note', 'kind': 'warn', 'title': 'See a clinician', 'paras': ['First.', 'Second.']});
      expect(find.text('See a clinician'), findsOneWidget);
      expect(richText(tester, 'First'), 'First.');
      expect(richText(tester, 'Second'), 'Second.');
    });

    testWidgets('a three column table stays a table', (tester) async {
      await showCiting(tester, {'t': 'rows', 'head': ['A', 'B', 'C'], 'rows': [['one', 'two', 'three']]});
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets('a wide table stacks, labels each value and names a bare first value', (tester) async {
      await showCiting(tester, {'t': 'rows', 'head': ['Week', 'Load', 'Sets', 'Decision'], 'rows': [['1', '20 kg', '8, 8, 8', 'Keep the load.']]});
      expect(find.byType(Table), findsNothing);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Decision'), findsOneWidget);
      expect(richText(tester, 'Keep'), 'Keep the load.');
    });

    testWidgets('tables do not overflow a small phone', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await showCiting(tester, {'t': 'rows', 'head': ['Slot', 'Exercise', 'Sets', 'Repetitions', 'Rest'], 'rows': [['Main press', 'Overhead cable triceps extension', '4', '6 to 8', '2 to 3 min']]});
      expect(tester.takeException(), isNull);
      await showCiting(tester, {'t': 'rows', 'head': ['Situation', 'Daily intake', 'Standing'], 'rows': [['Already lean, resistance training', '2.3 to 3.1 g per kg of **fat-free** mass', 'A long sentence about what this means for you. {known}']]});
      expect(tester.takeException(), isNull);
    });

    testWidgets('a book chapter opens with its sections and numbers its inline sources', (tester) async {
      tester.view.physicalSize = const Size(800, 2000); // the list builds lazily; the references are at the end
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ChapterScreen(
          id: 2,
          load: () async => {
            'id': 2,
            'part': 'I',
            'part_title': 'Training',
            'title': 'Exercise science',
            'summary': 'Why training works.',
            'minutes': 7,
            'blocks': {
              'sources': {'first': 'First paper.', 'second': 'Second paper.', 'unused': 'Unused paper.'},
              'blocks': [
                {'t': 'h2', 'text': 'The dose'},
                {'t': 'p', 'text': 'Volume matters. {second}'},
                {'t': 'h2', 'text': 'Rest'},
                {'t': 'rows', 'head': ['A', 'B'], 'rows': [['x', 'y {first}']]},
              ],
            },
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('VOLUME I  ·  TRAINING'), findsOneWidget);
      expect(find.text('7 min  ·  3 sources'), findsOneWidget);
      expect(find.text('The dose'), findsNWidgets(2)); // contents line and heading
      expect(find.text('Why training works.'), findsOneWidget);
      expect(richText(tester, 'Volume'), 'Volume matters. [1]');
      expect(find.text('Second paper.'), findsOneWidget);
    });

    testWidgets('every chapter of the real book draws on a small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final book = (jsonDecode(File('../website/src/lib/handbook_book.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
      expect(book, isNotEmpty);
      for (final c in book) {
        final sources = (c['sources'] as Map).cast<String, dynamic>();
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: Column(children: [
                  for (final b in (c['blocks'] as List).cast<Map<String, dynamic>>())
                    handbookBlock(context, b, (k) => sources.containsKey(k) ? '[1]' : null),
                ]),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull, reason: c['slug'] as String);
        final shown = tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText()).join(' ');
        expect(shown, isNot(contains('**')), reason: c['slug'] as String);
        expect(shown, isNot(contains('[[')), reason: c['slug'] as String);
        expect(RegExp(r'\{[a-z0-9-]+\}').hasMatch(shown), isFalse, reason: c['slug'] as String);
      }
    });

    test('part labels: Roman numerals are volumes, letters are parts', () {
      expect(partLabel('II'), 'VOLUME II');
      expect(partLabel('C'), 'PART C');
    });
  });

  testWidgets('an unknown block type falls back to its text', (tester) async {
    await _show(tester, {'t': 'future-type', 'text': 'Plain fallback.'});
    expect(find.text('Plain fallback.'), findsOneWidget);
  });
}

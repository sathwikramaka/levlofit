import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/exercise_guide.dart';
import 'package:levlo/exercises.dart';
import 'package:levlo/move_animation.dart';
import 'package:levlo/move_animations.dart';
import 'package:levlo/session.dart' show loadMoves, moveName;

void main() {
  // Every catalogue id session.dart prescribes (7-character ExerciseDB ids in quotes).
  final prescribed = RegExp(r"'([A-Za-z0-9]{7})'").allMatches(File('lib/session.dart').readAsStringSync()).map((m) => m.group(1)!).toSet()
    ..removeAll({'barbell'}); // a word in _kitWord, not an id

  test('every prescribed move has a guide entry or is listed as missing, never both', () {
    final unaccounted = prescribed.where((id) => !moveGuide.containsKey(id) && !missingGuide.containsKey(id)).toList();
    expect(unaccounted, isEmpty);
    expect(moveGuide.keys.toSet().intersection(missingGuide.keys.toSet()), isEmpty);
    expect(moveGuide.keys.every(prescribed.contains), isTrue, reason: 'the guide covers prescribed moves only');
  });

  test('guide entries use known groups, link only to other guide moves, and never claim isolation', () {
    for (final MapEntry(key: id, value: g) in moveGuide.entries) {
      expect(muscleRegions.containsKey(g.group), isTrue, reason: id);
      expect(g.versions, isNot(contains(id)), reason: id);
      expect(g.versions.every(moveGuide.containsKey), isTrue, reason: id);
      expect('${g.name} ${g.main} ${g.assist}'.toLowerCase(), isNot(contains('isolat')), reason: id);
    }
    expect(regionNote, contains('no exercise isolates'));
  });

  test('versions are symmetric within a movement family', () {
    for (final id in ['I4hDWkc', 'fUBheHs', 'QChZi3x', 'wQ2c4XD', 'znQUdHY', '9E25EOx']) {
      for (final other in moveGuide[id]!.versions) {
        if (moveGuide[other]!.group == moveGuide[id]!.group) expect(moveGuide[other]!.versions, contains(id), reason: '$id <-> $other');
      }
    }
  });

  test('yoga poses and stretches are in the guide as stretches; the frog id is the catalogue\'s rocking frog stretch', () {
    final poses = movesIn('Mobility').map((e) => e.$2.name).toList();
    expect(poses, containsAll(['Sphinx pose', 'Butterfly pose', 'Reclining big toe pose', 'Seated twist', 'Rocking frog stretch', "Runner's stretch", 'Spine stretch']));
    expect(poses.length, 14);
    expect(moveGuide['2Dk4xQV']!.name, isNot(contains('Mandukasana')));
    expect(moveGuide['K5xgdvI']!.equipment, 'A strap or towel'); // as session.dart says
  });

  test('evidence notes stay within their study and cite it; the unsourced incline claim is still not shown', () {
    final calves = evidenceNotes['Calves']!.single;
    expect(calves.text, contains('soleus grew about the same'), reason: 'the study found no soleus difference');
    expect(calves.text, isNot(contains('emphasise soleus')));
    expect(calves.source, contains('PMC10753835'));
    final back = evidenceNotes['Back']!.single;
    expect(back.text, contains('did not change'), reason: 'the study found no grip effect on the latissimus dorsi');
    expect(back.source, contains('PMC12452428'));
    expect(needsSource.single, contains('Incline'));
    for (final notes in evidenceNotes.values) {
      for (final n in notes) {
        expect(n.text.toLowerCase(), isNot(contains('isolat')));
      }
    }
  });

  testWidgets('a muscle group shows its evidence note with the study', (tester) async {
    tester.view.physicalSize = const Size(390, 3200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Calves').first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('grew the gastrocnemius far more'), findsOneWidget);
    expect(find.textContaining('PMC10753835'), findsOneWidget);
  });

  test('every prescribed id now has an identity from the catalogue; none is left unaccounted', () {
    expect(missingGuide, isEmpty);
    for (final id in ['9RT8oQW', 'wd4ds3s', 'ealLwvX', 'DFGXwZr', '0mB6wHO', '99rWm7w', 'DeDThfG', 'f38OEuO', 'JbC2iaV', '2Dk4xQV']) {
      expect(moveGuide.containsKey(id), isTrue, reason: id);
    }
    expect(moveGuide['wd4ds3s']!.versions, contains('bZGHsAZ'));
    expect(moveGuide['bZGHsAZ']!.versions, contains('wd4ds3s'), reason: 'the row family stays symmetric');
  });

  test('movesIn lists each named move once', () {
    final thighs = movesIn('Thighs').map((e) => e.$2.name).toList();
    expect(thighs.where((n) => n == 'Lunge').length, 1);
    expect(movesIn('Chest').map((e) => e.$2.name), containsAll(['Push-up', 'Bench press']));
  });

  testWidgets('library shows regions and moves for a muscle group', (tester) async {
    tester.view.physicalSize = const Size(390, 3200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Chest').first); // the guide chips come before the catalogue filter
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('clavicular head (upper chest)'), findsOneWidget);
    expect(find.text(regionNote), findsOneWidget);
    expect(find.text('Push-up'), findsOneWidget);
  });

  test('every guide move has 2 to 4 short Levlofit cues; stretches carry the gentle-stretch note', () {
    expect(moveCues.keys.toSet(), moveGuide.keys.toSet());
    for (final MapEntry(key: id, value: cues) in moveCues.entries) {
      expect(cues.length, inInclusiveRange(2, 4), reason: id);
      expect(cues.every((c) => c.length <= 140 && c.endsWith('.')), isTrue, reason: id);
      if (moveGuide[id]!.group == 'Mobility') expect(cues.join(' '), contains('never feel sharp or painful'), reason: id);
    }
  });

  testWidgets('a long version name wraps at phone width instead of being cut off', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    exerciseDbContent = false;
    addTearDown(() => exerciseDbContent = true);
    tester.view
      ..physicalSize = const Size(360, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ExerciseScreen(id: 'ila4NZS')));
    await tester.pump(const Duration(seconds: 1));
    final label = find.text('Dumbbell Romanian deadlift');
    final box = find.ancestor(of: label, matching: find.byType(InkWell)).first;
    expect(tester.getRect(label).right, lessThanOrEqualTo(360 - 24));
    expect(tester.getRect(box).contains(tester.getRect(label).bottomRight - const Offset(1, 1)), isTrue, reason: 'the box holds every line');
    expect(find.byType(ActionChip), findsNothing, reason: 'chips have a fixed height and clip a second line');
  });

  test('ExerciseDB is on by default and both privacy texts name it (the app loads its animations)', () {
    expect(exerciseDbContent, isTrue);
    expect(File('lib/dashboard_tabs.dart').readAsStringSync(), contains('ExerciseDB (AscendAPI) supplies the exercise animations'));
    expect(File('../website/src/app/privacy/page.tsx').readAsStringSync(), contains('<strong>ExerciseDB</strong> (AscendAPI)'));
  });

  group('licensed mode (LEVLOFIT_EXERCISEDB=false)', () {
    setUp(() => exerciseDbContent = false);
    tearDown(() => exerciseDbContent = true);

    test('moves come from the Levlofit guide with no animation, unknown ids are reported missing', () async {
      final m = await loadMoves(['I4hDWkc', 'zzzzzzz']); // no catalogue read: no Supabase client in tests
      expect(m.found.single['name'], 'Push-up');
      expect(m.found.single['gif_url'], isNull);
      expect(m.missing, ['zzzzzzz']);
      expect(moveName(m.found.single), 'Push-up');
      expect(exerciseMediaCredit, isNot(contains('ExerciseDB')));
    });

    testWidgets('library shows the guide only; a move page shows guide notes without catalogue steps', (tester) async {
      tester.view
        ..physicalSize = const Size(800, 3000) // the whole move page, drawings included
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TextField), findsNothing, reason: 'no catalogue search');
      expect(find.textContaining('ExerciseDB'), findsNothing);
      await tester.pumpWidget(MaterialApp(home: ExerciseScreen(id: 'I4hDWkc', load: () => throw StateError('catalogue read'))));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Push-up'), findsOneWidget);
      expect(find.text('HOW TO DO IT'), findsOneWidget, reason: 'Levlofit cues, not catalogue steps');
      expect(find.text(moveCues['I4hDWkc']!.first), findsOneWidget);
      expect(find.textContaining('ExerciseDB'), findsNothing);
      await tester.pumpWidget(const MaterialApp(home: ExerciseScreen(id: 'zzzzzzz')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('This move is not in the Levlofit guide yet.'), findsOneWidget);
    });

    testWidgets('the picture tile never loads a network image', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExerciseGif('https://example.invalid/a.gif', size: 100)));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a move with a licensed drawing shows its two positions in turn with the credit; others keep the icon', (tester) async {
      tester.view
        ..physicalSize = const Size(800, 3000) // the whole move page, drawings included
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(const MaterialApp(home: ExerciseScreen(id: '9WTm7dq')));
      await tester.pump(const Duration(seconds: 1));
      String shown() => ((tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader) as SvgAssetLoader).assetName;
      expect(shown(), drawingAsset('0054'), reason: 'starts on the tension drawing');
      await tester.pump(const Duration(milliseconds: 400)); // the swap at 1.2 s after the page opened
      await tester.pump(const Duration(milliseconds: 300)); // and its 250 ms cross-fade
      expect(shown(), drawingAsset('0054', end: false), reason: 'then shows the other position: a two-frame animation');
      expect(find.text('Two positions of the move, shown in turn.'), findsOneWidget);
      expect(find.textContaining(drawingCredit), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: ExerciseGif(null, id: '9WTm7dq', size: 100)));
      expect(find.byType(SvgPicture), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: ExerciseGif(null, id: 'iny3m5y', size: 100)));
      expect(find.byType(SvgPicture), findsNothing, reason: 'dead bug has no exact drawing');
    });
  });

  testWidgets('with the system setting to remove animations, the drawing holds one position', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(data: MediaQueryData(disableAnimations: true), child: MoveDemo('9WTm7dq'))));
    String shown() => ((tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader) as SvgAssetLoader).assetName;
    await tester.pump(const Duration(seconds: 3));
    expect(shown(), drawingAsset('0054'));
  });

  testWidgets('a move without any licensed picture shows the icon and starts no timer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MoveDemo('iny3m5y')));
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  test('every animation is a bundled animated GIF of a guide move, recorded with its licence in SOURCE.md', () {
    final source = File('assets/animations/SOURCE.md').readAsStringSync();
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/animations/cdc/'));
    expect(moveAnimations, hasLength(6));
    for (final MapEntry(key: id, value: a) in moveAnimations.entries) {
      expect(moveGuide.containsKey(id), isTrue, reason: id);
      final bytes = File(a).readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(6)), 'GIF89a', reason: a);
      expect(source, contains('| ${a.split('/').last} |'), reason: a);
      expect(source, contains(id), reason: a);
    }
    expect(moveAnimationNotes.keys.every(moveAnimations.containsKey), isTrue);
    expect(source, contains('Hamstring_stretch'), reason: 'excluded files are recorded with the reason');
    expect(exerciseDbContent ? true : exerciseMediaCredit.contains(animationCredit), isTrue);
    expect(animationNotice, allOf(contains('does not imply endorsement'), contains('free of charge'), contains('unmodified')));
  });

  testWidgets('a move with a licensed animation plays the bundled GIF, with its caption, and starts no drawing timer', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    exerciseDbContent = false;
    addTearDown(() => exerciseDbContent = true);
    tester.view
      ..physicalSize = const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ExerciseScreen(id: 'B1EVP9F')));
    await tester.pump(const Duration(seconds: 1));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, moveAnimations['B1EVP9F']);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.text('Shown against a wall; a bench or table works the same way.'), findsOneWidget);
    expect(find.textContaining(animationCredit), findsOneWidget);
  });

  testWidgets("a move with Levlofit's own animation plays it from code, with the figure choice, and no image or drawing", (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    exerciseDbContent = false;
    addTearDown(() => exerciseDbContent = true);
    addTearDown(() => demoFigure.value = DemoFigure.man);
    tester.view
      ..physicalSize = const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ExerciseScreen(id: 'QChZi3x')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MoveAnimationView), findsOneWidget);
    expect(find.byType(Image), findsNothing, reason: 'the squat GIF stays bundled but the own animation takes its place');
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.text(moveCues['QChZi3x']!.first), findsOneWidget, reason: 'instructions stay');
    expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'it animates');
    await tester.tap(find.text('Woman'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(demoFigure.value, DemoFigure.woman);
    expect(find.textContaining('figure animations: Levlofit'), findsOneWidget);
    // The library tile and session cards use the same widget.
    await tester.pumpWidget(const MaterialApp(home: ExerciseGif(null, id: 'EIeI8Vf', size: 100)));
    expect(find.byType(MoveAnimationView), findsOneWidget);
    // A move with none of the three falls back to its icon, and the instructions remain on its page.
    await tester.pumpWidget(const MaterialApp(home: ExerciseGif(null, id: 'iny3m5y', size: 100)));
    expect(find.byType(MoveAnimationView), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
  });

  test('every own animation is linked to an exact guide move; the CDC files it replaces stay bundled', () {
    for (final id in moveVectorAnimations.keys) {
      expect(moveGuide.containsKey(id), isTrue, reason: id);
    }
    for (final gif in moveAnimations.values) {
      expect(File(gif).existsSync(), isTrue, reason: gif);
    }
  });

  test('every drawing is a guide move, both files are bundled plain SVGs, and SOURCE.md records it', () {
    final source = File('assets/drawings/everkinetic/SOURCE.md').readAsStringSync();
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/drawings/everkinetic/'));
    expect(moveDrawings.length, 15);
    for (final MapEntry(key: id, value: n) in moveDrawings.entries) {
      expect(moveGuide.containsKey(id), isTrue, reason: id);
      expect(source, contains('| $id |'), reason: id);
      for (final end in [false, true]) {
        final svg = File(drawingAsset(n, end: end)).readAsStringSync();
        expect(svg, startsWith('<svg'), reason: n);
        expect(RegExp(r'<script|<image|<foreignObject|href="http', caseSensitive: false).hasMatch(svg), isFalse, reason: n);
      }
    }
    expect(File('assets/drawings/everkinetic/LICENSE').readAsStringSync(), contains('Attribution-ShareAlike 4.0'));
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/exercise_guide.dart';
import 'package:levlo/exercises.dart';

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
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Chest').first); // the guide chips come before the catalogue filter
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('clavicular head (upper chest)'), findsOneWidget);
    expect(find.text(regionNote), findsOneWidget);
    expect(find.text('Push-up'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/exercise_guide.dart';
import 'package:levlo/exercises.dart';
import 'package:levlo/muscle_map.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('every map region is a guide muscle group', () {
    for (final r in [...frontRegions, ...backRegions]) {
      expect(muscleRegions.keys, contains(r.group));
    }
  });

  test('filters combine and every guide move gets an equipment kind and a difficulty', () {
    for (final e in moveGuide.entries) {
      expect(equipmentKinds, contains(equipmentKind(e.value)));
      expect(difficultyLevels, contains(difficultyOf(e.key)));
    }
    final chestBodyweight = filteredMoves(group: 'Chest', equipment: 'Bodyweight');
    expect(chestBodyweight.map((m) => m.$2.name), containsAll(['Push-up', 'Incline push-up']));
    expect(chestBodyweight.map((m) => m.$2.name), isNot(contains('Bench press')));
    expect(filteredMoves(group: 'Back', difficulty: 'Advanced').map((m) => m.$2.name), ['Pull-up']);
    expect(filteredMoves(group: 'Chest', equipment: 'Kettlebell'), isEmpty);
  });

  testWidgets('tapping the chest on the body map selects Chest; back view offers Back', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 200, child: MuscleMap(selected: null, onGroup: (g) => picked = g))),
    ));
    await tester.tap(find.bySemanticsLabel('Chest'));
    expect(picked, 'Chest');
    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back').last); // the region, after the toggle
    expect(picked, 'Back');
  });

  testWidgets('library at phone width: map, filters and filtered list fit', (tester) async {
    exerciseDbContent = false; // no network catalogue in tests
    addTearDown(() => exerciseDbContent = true);
    tester.view.physicalSize = const Size(390, 2600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel('Chest').first); // the body-map region (the chip also reads Chest)
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bodyweight'));
    await tester.pump();
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Bench press'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

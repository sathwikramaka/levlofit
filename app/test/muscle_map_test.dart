import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/exercise_guide.dart';
import 'package:levlo/exercises.dart';
import 'package:levlo/muscle_map.dart';
import 'package:levlo/muscle_shapes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('every selectable muscle belongs to a guide group; both views cover the main groups', () {
    for (final s in [...frontMuscles, ...backMuscles]) {
      if (s.group != null) expect(muscleRegions.keys, contains(s.group));
      for (final p in s.polygons) {
        expect(p.length.isEven && p.length >= 6, isTrue, reason: s.label);
      }
    }
    expect(frontMuscles.map((s) => s.group).toSet(), containsAll(['Chest', 'Shoulders', 'Arms', 'Core', 'Thighs', 'Calves']));
    expect(backMuscles.map((s) => s.group).toSet(), containsAll(['Back', 'Shoulders', 'Arms', 'Hips and glutes', 'Thighs', 'Calves']));
  });

  test('tap detection follows the outlines', () {
    expect(groupAt(frontMuscles, const Offset(60, 48)), 'Chest'); // right pectoral
    expect(groupAt(frontMuscles, const Offset(50, 80)), 'Core'); // abdomen
    expect(groupAt(frontMuscles, const Offset(50, 12)), isNull); // head
    expect(groupAt(frontMuscles, const Offset(2, 2)), isNull); // empty corner
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

  testWidgets('tapping the chest on the body map selects Chest; back view offers Back; groups are labelled', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 200, child: MuscleMap(selected: null, onGroup: (g) => picked = g)))),
    ));
    final figure = find.byType(CustomPaint).last;
    Offset at(double x, double y) => tester.getTopLeft(figure) + Offset(x, y) * (tester.getSize(figure).width / 100);
    expect(find.semantics.byLabel('Chest'), findsOne);
    await tester.tapAt(at(60, 48));
    expect(picked, 'Chest');
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.semantics.byLabel('Hips and glutes'), findsOne);
    await tester.tapAt(at(38, 58)); // left upper back
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
    final figure = find.byType(CustomPaint).at(1); // the body figure (after the toggle's)
    await tester.ensureVisible(figure);
    await tester.tapAt(tester.getTopLeft(figure) + const Offset(60, 48) * (tester.getSize(figure).width / 100));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bodyweight'));
    await tester.pump();
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Bench press'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

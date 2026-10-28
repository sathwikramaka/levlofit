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
    expect(groupAt(frontMuscles, const Offset(58, 52)), 'Chest'); // right pectoral
    expect(groupAt(frontMuscles, const Offset(46, 70)), 'Core'); // abdomen
    expect(groupAt(frontMuscles, const Offset(50, 26)), isNull); // head
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
    await tester.tapAt(at(58, 52));
    expect(picked, 'Chest');
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.semantics.byLabel('Hips and glutes'), findsOne);
    await tester.tapAt(at(40, 68)); // left upper back
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
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Chest').first);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Chest').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bodyweight'));
    await tester.pump();
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Bench press'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('every map muscle has matches, and trapezius finds real moves', () {
    for (final m in [...frontMuscles, ...backMuscles].where((m) => m.group != null)) {
      expect(muscleMatch.keys, contains(m.label), reason: m.label);
    }
    final traps = movesForMuscle('Trapezius');
    expect(traps, isNotEmpty);
    // Only moves where the muscle is a main mover: no bench press under triceps-only, no squats under calves.
    for (final m in muscleMatch.keys) {
      final words = muscleMatch[m]!.guide;
      for (final (_, g) in movesForMuscle(m)) {
        expect(g.main.any((x) => words.any((w) => x.startsWith(w))), isTrue, reason: '$m: ${g.name}');
      }
    }
  });

  testWidgets('tapping a muscle on the body opens its exercises; the muscle screen lists guide and catalogue moves', (tester) async {
    tester.view.physicalSize = const Size(390, 2600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MuscleExercisesScreen(
        muscle: 'Trapezius',
        loadCatalogue: (names) async => [
          {'id': 'X000001', 'name': 'barbell shrug', 'gif_url': null, 'target_muscles': names},
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('Trapezius'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    expect(find.text('MORE EXERCISES  ·  1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    String? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 200, child: MuscleMap(selected: null, onGroup: (_) {}, onMuscle: (m) => opened = m)))),
    ));
    final figure = find.byType(CustomPaint).last;
    await tester.tapAt(tester.getTopLeft(figure) + const Offset(58, 52) * (tester.getSize(figure).width / 100));
    expect(opened, 'Chest');
  });

  testWidgets('rear and front shoulders split by name (the pattern had stray control characters, so "rear" never matched)', (tester) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Future<List<Map<String, dynamic>>> catalogue(List<String> names) async => [
          {'id': 'X000101', 'name': 'dumbbell rear delt raise', 'gif_url': null, 'target_muscles': names},
          {'id': 'X000102', 'name': 'dumbbell front raise', 'gif_url': null, 'target_muscles': names},
        ];
    await tester.pumpWidget(MaterialApp(home: MuscleExercisesScreen(muscle: 'Rear shoulders', loadCatalogue: catalogue)));
    await tester.pump();
    expect(find.text('MORE EXERCISES  ·  1'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: MuscleExercisesScreen(muscle: 'Front shoulders', loadCatalogue: catalogue)));
    await tester.pump();
    expect(find.text('MORE EXERCISES  ·  1'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';
import 'package:levlo/diet_view.dart';

import 'diet_plan_test.dart' show foodsForTest;

// Supplements on the plate and the pre- and post-workout meals (owner request 2026-11-07).
void main() {
  group('effective scoops', () {
    test('protein powder chosen means one scoop; Build my plate wins; nothing without the choice', () {
      expect(effectiveScoops(saved: 0, supplements: ['protein_powder'], conditions: []), 1);
      expect(effectiveScoops(saved: 3, supplements: ['protein_powder'], conditions: []), 3);
      expect(effectiveScoops(saved: 2, supplements: [], conditions: []), 2);
      expect(effectiveScoops(saved: 0, supplements: ['creatine'], conditions: []), 0);
    });
    test('never by default with kidney disease or in pregnancy', () {
      expect(effectiveScoops(saved: 0, supplements: ['protein_powder'], conditions: ['kidney']), 0);
      expect(effectiveScoops(saved: 0, supplements: ['protein_powder'], conditions: ['pregnancy']), 0);
    });
  });

  group('supplement lines', () {
    const creatine = {'name': 'Creatine monohydrate', 'how': '3–5 g a day, any time', 'why': 'x'};
    test('chosen supplements are listed with their dose; own ones say they are not checked', () {
      final l = supplementLines(advice: [creatine], chosen: ['protein_powder', 'creatine'], own: ['Vitamin D'], scoops: 1, plant: false);
      expect(l.map((x) => x.name), ['Whey protein', 'Creatine monohydrate', 'Vitamin D']);
      expect(l[0].how, contains('1 scoop a day, about 30 g'));
      expect(l[1].how, '3–5 g a day, any time');
      expect(l[2].how, contains('has not checked'));
    });
    test('vegan shake is plant protein; 2 scoops read as plural', () {
      expect(supplementLines(advice: [], chosen: [], own: [], scoops: 2, plant: true).single.name, 'Plant protein powder');
      expect(supplementLines(advice: [], chosen: [], own: [], scoops: 2, plant: true).single.how, contains('2 scoops a day, about 60 g'));
    });
    test('chosen but not advised says why, rather than silently vanishing', () {
      final l = supplementLines(advice: [], chosen: ['creatine', 'protein_powder'], own: [], scoops: 0, plant: false);
      expect(l.map((x) => x.name), ['Protein powder', 'Creatine']);
      expect(l[0].how, contains('Ask your doctor'));
      expect(l[1].how, contains('No dose in your plan'));
    });
    test('nothing chosen: no card content', () {
      expect(supplementLines(advice: [], chosen: [], own: [], scoops: 0, plant: false), isEmpty);
    });
  });

  group('workout meals', () {
    PlanItem item(String code, String unit) => (code: code, name: code, grams: 30.0, unit: unit, kcal: 100.0, protein: 10.0, carb: 0.0, fat: 0.0, fiber: 0.0);
    final day = <PlanMeal>[
      (name: 'Breakfast', time: '8 am', items: [item('A011', 'dry')]),
      (name: 'Lunch', time: '1 pm', items: [item('A019', 'dry')]),
      (name: 'Evening snack', time: '5 pm', items: [item('supp:whey', 'scoop'), item('E012', 'raw')]),
      (name: 'Dinner', time: '8 pm', items: [item('A019', 'dry')]),
    ];

    test('every training time marks both meals, including "It varies" and older plans', () {
      for (final time in ['early_morning', 'morning', 'midday', 'evening', 'night', 'varies', null]) {
        final w = workoutDay(day, time);
        expect(w.pre, isNotNull, reason: '$time');
        expect(w.post, isNotNull, reason: '$time');
        expect(w.pre, isNot(w.post), reason: '$time');
      }
    });

    test('an evening session: the shake moves after training, no food is lost', () {
      final w = workoutDay(day, 'evening');
      expect(w.meals[w.pre!].items.map((i) => i.code), ['E012']);
      expect(w.meals[w.post!].items.first.code, 'supp:whey');
      double kcal(List<PlanMeal> m) => m.expand((x) => x.items).fold(0.0, (s, i) => s + i.kcal);
      expect(kcal(w.meals), kcal(day));
    });

    test('summary line: training day names the meals and times; rest day says so', () {
      final s = trainingSummary(workoutDay(day, 'evening'));
      expect(s.title, 'TRAINING DAY');
      expect(s.lines, ['Pre-workout: Evening snack, 5 pm', 'Post-workout: Dinner, 8 pm']);
      expect(trainingSummary(null).title, 'REST DAY');
    });

    test('a shake is never lost when a day has no snack: it is still counted and shown', () {
      final plan = planDay(foods: foodsForTest, kcal: 2000, protein: 100, excluded: const {});
      final noSnack = (meals: plan.meals.where((m) => m.name != 'Evening snack').toList(), kcal: plan.kcal, protein: plan.protein, carb: plan.carb, fat: plan.fat, fiber: plan.fiber, check: plan.check);
      final d = addShake(noSnack, 1, kcal: 2000, protein: 100, plant: false);
      expect(d.meals.expand((m) => m.items).where((i) => i.unit == 'scoop'), hasLength(1));
    });
  });

  testWidgets('plate info card lays out at phone width with long own text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lines = supplementLines(advice: [], chosen: ['creatine'], own: ['A very long supplement name from a tub'], scoops: 3, plant: false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: PlateInfoCard(title: 'SUPPLEMENTS', lines: [for (final l in lines) (name: l.name, text: l.how)]))),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('SUPPLEMENTS'), findsOneWidget);
    expect(find.text('Whey protein'), findsOneWidget);
    expect(find.text('Creatine'), findsOneWidget);
  });
}

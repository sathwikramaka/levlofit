import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';
import 'package:levlo/session.dart';

import 'diet_plan_test.dart' show foodsForTest;

// Owner request 2026-10-29: custom kitchen equipment and mess meals, pre- and post-workout meals, protein powder only
// for people open to it, plain English food words, and a warm-up before every session.
void main() {
  const veg = {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg'};
  WeekRequest req({Map<int, Set<String>>? meals, bool topUp = false, double protein = 110, Set<String> excluded = veg, int tier = 2}) => (
        foods: foodsForTest, kcal: 2200.0, protein: protein, excluded: excluded, custom: const <String>[], tier: tier, soyaCapG: 50.0,
        proteinPowder: topUp, region: null, mealCodes: meals, topUpScoop: topUp,
      );
  Set<String> codesOf(PlanMeal m) => {for (final i in m.items) i.code};

  group('equipment', () {
    test('older answers keep their meaning; an explicit list wins; none means nothing', () {
      expect(equipmentOf('full'), {'stove', 'pressure_cooker'});
      expect(equipmentOf('stove_only'), {'stove'});
      expect(equipmentOf('no_stove'), isEmpty);
      expect(equipmentOf('full', ['kettle', 'blender']), {'kettle', 'blender'});
      expect(equipmentOf('full', ['none']), isEmpty);
      expect(legacyKitchen({'induction', 'pressure_cooker'}), 'full');
      expect(equipmentList({}), ['none']);
    });

    test('never assumes equipment: a kettle soaks poha and soya; rice needs a stove, microwave or multi-purpose kettle', () {
      expect(canMake('dish:poha', {'kettle'}), isTrue);
      expect(canMake('X001', {'kettle'}), isTrue);
      expect(canMake('A015', {'kettle'}), isFalse);
      expect(canMake('A015', {'multi_kettle'}), isTrue);
      expect(canMake('M004', {'multi_kettle'}), isTrue);
      expect(canMake('A019', {'microwave', 'kettle', 'blender'}), isFalse, reason: 'rotis need a stove or induction');
      expect(canMake('B021', {'induction'}), isFalse, reason: 'toor dal needs a pressure cooker');
      expect(canMake('B021', {'induction', 'pressure_cooker'}), isTrue);
      expect(canMake('L002', {}), isTrue);
    });

    test('minimal time: only no-cook, kettle or microwave foods, and nothing made ahead', () {
      final have = {'stove', 'pressure_cooker', 'kettle', 'microwave'};
      expect(canMake('A019', have, cookTime: 'minimal'), isFalse);
      expect(canMake('A015', have, cookTime: 'minimal'), isTrue, reason: 'microwave rice');
      expect(canMake('dish:sprouts', have, cookTime: 'minimal'), isFalse);
    });

    test('a full kitchen with no mess changes nothing (same week as before)', () {
      expect(mealCodes(foodsForTest.keys, have: {'stove', 'pressure_cooker'}), isNull);
      expect(weekKey(req()), weekKey(req(meals: mealCodes(foodsForTest.keys, have: equipmentOf('full')))));
    });

    test('kettle and blender at home, lunch and dinner from the mess: home meals use only kettle-made or no-cook food', () {
      final meals = mealCodes(foodsForTest.keys, have: {'kettle', 'blender'}, messMeals: ['lunch', 'dinner'])!;
      expect(meals.keys.toSet(), {0, 2}, reason: 'breakfast and the snack are made at home; mess meals are not limited');
      final week = planWeek(req(meals: meals));
      for (final d in week) {
        for (final m in d.meals.where((m) => m.name == 'Breakfast' || m.name == 'Evening snack')) {
          for (final c in codesOf(m)) {
            expect(canMake(c, {'kettle', 'blender'}), isTrue, reason: '${m.name} has $c');
          }
          expect(m.items.any((i) => i.unit == 'oil'), isFalse, reason: 'no oil where nothing is cooked');
        }
      }
      expect(week.any((d) => d.meals.any((m) => m.name == 'Lunch' && codesOf(m).intersection({'A015', 'A019', 'A005'}).isNotEmpty)), isTrue,
          reason: 'mess lunches still have rice or roti');
    });

    test('notes and prep tips say what the kitchen means', () {
      expect(kitchenNote({'kettle'}, 'minimal', ['lunch']), allOf(contains('your electric kettle'), contains('under 10 minutes'), contains('lunch comes from the mess')));
      expect(kitchenNote({'stove', 'pressure_cooker'}, 'plenty'), isNull);
      final poha = (name: 'Breakfast', time: '8 am', items: <PlanItem>[(code: 'dish:poha', name: 'Poha', grams: 60, unit: 'dry', kcal: 1, protein: 1, carb: 1, fat: 1, fiber: 1)]);
      expect(prepNote(poha, {'kettle'}), contains('just-boiled water'));
      expect(prepNote(poha, {'stove', 'kettle'}), isNull);
    });
  });

  group('protein powder', () {
    test('never added unless the person is open to it', () {
      for (final d in planWeek(req(protein: 160))) {
        expect(d.meals.expand((m) => m.items).any((i) => i.unit == 'scoop'), isFalse);
      }
    });

    test('open to it: a day short of protein gets one scoop, and the day still lands on its calorie target', () {
      final plain = planWeek(req(protein: 160));
      final topped = planWeek(req(protein: 160, topUp: true));
      for (var i = 0; i < 7; i++) {
        final scoop = topped[i].meals.expand((m) => m.items).where((it) => it.unit == 'scoop');
        if (plain[i].check.proteinShare >= minProteinShare) {
          expect(scoop, isEmpty, reason: 'day $i already met protein');
        } else if (scoop.isNotEmpty) {
          expect(scoop.length, 1);
          expect(topped[i].check.proteinShare, greaterThan(plain[i].check.proteinShare));
          expect(topped[i].check.kcalDeviation.abs(), lessThanOrEqualTo(kcalTolerance + 0.02));
        }
      }
      expect(topped.expand((d) => d.meals).expand((m) => m.items).any((i) => i.unit == 'scoop'), isTrue);
    });

    test('dairy excluded: the shake is plant protein', () {
      final week = planWeek(req(protein: 160, topUp: true, excluded: {...veg, 'dairy'}));
      final scoops = week.expand((d) => d.meals).expand((m) => m.items).where((i) => i.unit == 'scoop').toList();
      expect(scoops.every((i) => i.code == 'supp:plant-protein'), isTrue);
    });
  });

  group('pre- and post-workout', () {
    List<PlanMeal> day() => planWeek(req()).first.meals;
    double kcal(List<PlanMeal> ms) => ms.expand((m) => m.items).fold(0.0, (s, i) => s + i.kcal);

    test('evening training: the 5 pm snack is pre-workout and dinner post-workout; no food added', () {
      final meals = day();
      final w = workoutDay(meals, 'evening');
      expect(w.meals[w.pre!].name, 'Evening snack');
      expect(w.meals[w.post!].name, 'Dinner');
      expect(kcal(w.meals), closeTo(kcal(meals), 0.001));
      expect(w.note, contains('not extra'));
    });

    test('early-morning training: a fruit from the plan moves before the session; breakfast is post-workout', () {
      final meals = day();
      final w = workoutDay(meals, 'early_morning');
      expect(w.meals[w.pre!].name, 'Before training');
      expect(w.meals[w.pre!].items.single.code, startsWith('E'));
      expect(w.meals[w.post!].name, 'Breakfast');
      expect(kcal(w.meals), closeTo(kcal(meals), 0.001), reason: 'moved, not added');
    });

    test('night training: the last meal is post-workout and says to eat it after; no time set gives general advice only', () {
      final w = workoutDay(day(), 'night');
      expect(w.meals[w.post!].name, 'Dinner');
      expect(w.note, contains('eat it after training'));
      final v = workoutDay(day(), 'varies');
      expect([v.pre, v.post], [null, null]);
    });
  });

  test('plain English food words: no katori or sabzi anywhere in a week of meals', () {
    for (final d in planWeek(req())) {
      for (final m in d.meals) {
        final text = '${mealTitle(m)} ${mealSummary(m)} ${m.items.map(exactLabel).join(' ')}'.toLowerCase();
        expect(text, isNot(contains('katori')));
        expect(text, isNot(contains('sabzi')));
      }
    }
    final dal = (code: 'B010', name: 'Moong dal', grams: 60.0, unit: 'dry', kcal: 1.0, protein: 1.0, carb: 1.0, fat: 1.0, fiber: 1.0);
    expect(servingLabel(dal), '2 bowls (150 ml each) moong dal');
  });

  group('warm-up', () {
    test('every session kind gets pulse, joints and a specific step; strength ramp-ups are not counted sets', () {
      for (final kind in ['strength', 'hybrid', 'endurance', 'mobility', 'skill']) {
        final w = warmUpFor(kind: kind, level: 1);
        expect(w.length, greaterThanOrEqualTo(5), reason: kind);
        expect(w.first.move, 'Easy cardio');
      }
      expect(warmUpFor(kind: 'strength', level: 2).last.how, contains('not counted in your sets'));
      expect(warmUpFor(kind: 'endurance', level: 2).last.move, 'Very easy jog');
    });

    test('adapts to injuries, equipment and level', () {
      final knee = warmUpFor(kind: 'strength', level: 2, injury: 'left knee pain');
      expect(knee.map((s) => s.move), allOf(contains('Glute bridge'), isNot(contains('Bodyweight squat'))));
      final shoulder = warmUpFor(kind: 'strength', level: 2, injury: 'Shoulder impingement');
      expect(shoulder.map((s) => s.move), allOf(contains('Shoulder blade squeezes'), isNot(contains('Wall push-up'))));
      expect(warmUpFor(kind: 'strength', level: 1, gym: true).first.how, contains('bike, rower or treadmill'));
      expect(warmUpFor(kind: 'strength', level: 0).firstWhere((s) => s.move == 'Bodyweight squat').dose, '6 slow reps');
      expect(warmUpFor(kind: 'strength', level: 2, light: true).last.dose, '1 light set of 5 reps');
    });
  });
}

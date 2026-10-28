import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';
import 'package:levlo/week_schedule.dart';

import 'diet_plan_test.dart' show foodsForTest;

// B6: meals only from foods the person's kitchen and cooking time can make; sessions on the weekdays they can train.
void main() {
  List<DayPlan> week({String? kitchen, String? cookTime, Set<String> excluded = const {'beef', 'pork'}, int tier = 2}) => planWeek((
        foods: foodsForKitchen(foodsForTest, kitchen: kitchen, cookTime: cookTime),
        kcal: 2200.0, protein: 110.0, excluded: excluded, custom: const <String>[], tier: tier, soyaCapG: 50.0, proteinPowder: false, region: null, mealCodes: null, topUpScoop: false,
      ));
  Set<String> codes(List<DayPlan> w) => {for (final d in w) for (final m in d.meals) for (final i in m.items) i.code};

  test('defaults change nothing: the full kitchen plans the same week as before B6', () {
    expect(foodsForKitchen(foodsForTest).length, foodsForTest.length);
    expect(weekKey((foods: foodsForKitchen(foodsForTest, kitchen: 'full', cookTime: 'plenty'), kcal: 2200.0, protein: 110.0, excluded: const {'beef'}, custom: const <String>[], tier: 2, soyaCapG: 50.0, proteinPowder: false, region: null, mealCodes: null, topUpScoop: false)),
        weekKey((foods: foodsForTest, kcal: 2200.0, protein: 110.0, excluded: const {'beef'}, custom: const <String>[], tier: 2, soyaCapG: 50.0, proteinPowder: false, region: null, mealCodes: null, topUpScoop: false)));
  });

  test('stove only: no toor dal, rajma or kala chana in any meal', () {
    final used = codes(week(kitchen: 'stove_only'));
    expect(used.intersection({'B021', 'B020', 'B002'}), isEmpty);
    expect(used.where((c) => !fitsKitchen(c, kitchen: 'stove_only')), isEmpty);
  });

  test('short cooking time: no soaked pulses or batters made ahead', () {
    final used = codes(week(cookTime: 'short'));
    expect(used.intersection({'dish:idli', 'dish:dosa', 'dish:ragi-dosa', 'dish:moong-chilla', 'dish:sprouts', 'B020', 'B002'}), isEmpty);
  });

  test('no cooking: only foods eaten as they are, no oil; diet exclusions still hold', () {
    final w = week(kitchen: 'no_stove', excluded: const {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'honey'});
    final used = codes(w);
    expect(used.where((c) => !fitsKitchen(c, kitchen: 'no_stove')), isEmpty);
    expect(w.every((d) => dayOilGrams(d) == 0), isTrue);
    expect(used.intersection({'L002', 'L003'}), isEmpty, reason: 'vegan: no milk or paneer even when nothing is cooked');
    // So little can be made without cooking that the day says so rather than pretending to meet the targets.
    expect(w.any((d) => !d.check.feasible), isTrue);
  });

  test('budget still applies on top of the kitchen: the lowest tier never plans paneer or chicken', () {
    final used = codes(week(kitchen: 'stove_only', tier: 1));
    expect(used.intersection({'L003', 'N003', 'S006', 'E001', 'E047'}), isEmpty);
  });

  test('kitchen note says what was left out, only when something was', () {
    expect(kitchenNote(equipmentOf('full'), 'plenty'), isNull);
    expect(kitchenNote(equipmentOf(null), null), isNull);
    expect(kitchenNote(equipmentOf('stove_only'), 'short'), contains('your gas stove and about 30 minutes'));
  });

  test('training days: the chosen weekdays, spread out; none chosen keeps the usual pattern', () {
    expect(trainingDaysFor(3, const []), weekPattern[3]);
    expect(trainingDaysFor(2, const [6, 7, 1]), [1, 6], reason: 'fewest back-to-back days, Sunday-Monday counted');
    expect(trainingDaysFor(3, const [2, 4, 6]), [2, 4, 6]);
    expect(trainingDaysFor(3, const [1, 2, 3, 4]), [1, 2, 4]);
    expect(trainingDaysFor(4, const [6, 7]), containsAll([6, 7]), reason: 'an older plan with more sessions keeps every chosen day');
    expect(trainingDaysFor(4, const [6, 7]).length, 4);
  });

  test('week plan: sessions land only on the chosen weekdays, with the time of day shown', () {
    final plan = {
      'trainingDaysPerWeek': 3,
      'extraStrengthSessions': 0,
      'goals': [{'goal': 'strength', 'name': 'Strength', 'kind': 'strength', 'startLevel': 1, 'sessionsPerWeek': 3, 'addOnBlocksPerWeek': 0, 'status': 'active'}],
      'schedule': {'preferredDays': [2, 4, 6, 7], 'trainingTime': 'evening'},
    };
    final w = weekPlan(plan);
    expect(w.days.keys.toSet(), {2, 4, 6});
    expect(trainingTimeLabel(plan), 'Evening');
    expect(trainingTimeLabel({...plan, 'schedule': {'preferredDays': <int>[], 'trainingTime': 'varies'}}), isNull);
    expect(weekPlan({...plan}..remove('schedule')).days.keys.toList()..sort(), weekPattern[3]);
  });
}

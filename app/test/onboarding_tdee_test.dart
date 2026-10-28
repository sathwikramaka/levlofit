import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/diet_plan.dart';
import 'package:levlo/onboarding.dart';

// Coaching-spec gaps: onboarding saves the B6 constraints; the plan's energy working is shown, never recalculated.
void main() {
  test('onboarding saves training days, time, kitchen and cooking time to the B6 columns', () {
    final f = constraintFields(trainingDays: {6, 2, 9}, trainingTime: 'evening', equipment: {'stove'}, cookTime: 'short', messMeals: ['dinner', 'lunch']);
    expect(f.profile, {'training_days': [2, 6], 'training_time': 'evening'}, reason: 'sorted, weekdays only');
    expect(f.diet, {'kitchen': 'stove_only', 'kitchen_equipment': ['stove'], 'mess_meals': ['lunch', 'dinner'], 'cook_time': 'short'});
    final none = constraintFields(trainingDays: {}, trainingTime: 'varies', equipment: {}, cookTime: 'minimal');
    expect(none.diet['kitchen_equipment'], ['none'], reason: 'no equipment is saved explicitly, never as unanswered');
    expect(none.diet['kitchen'], 'no_stove');
    final d = constraintFields(trainingDays: {}, trainingTime: 'varies', equipment: {'stove', 'pressure_cooker'}, cookTime: 'plenty');
    expect(d.profile['training_days'], isEmpty, reason: 'none picked = any day, the column default');
  });

  final nutrition = {
    'bmrKcal': 1690,
    'energyKcal': 2230,
    'energy': {
      'maintenanceKcal': 2620,
      'activity': {'factor': 1.55, 'from': 'training_days', 'trainingDaysPerWeek': 4, 'dailyActivity': 'light'},
      'goalFactor': 0.85,
      'floor': null,
    },
  };

  test('energy working shows maintenance and the target apart, with the stored factors', () {
    final rows = energyWorking(nutrition)!;
    expect(rows.map((r) => r.$1), ['BMR', 'Activity factor', 'Maintenance (TDEE)', 'Goal adjustment', 'Your daily target']);
    expect(rows[1], ('Activity factor', 'set by 4 training days a week', '× 1.55'));
    expect(rows[2].$3, '2620 kcal');
    expect(rows[3], ('Goal adjustment', '15 % below maintenance', '× 0.85'));
    expect(rows[4].$3, '2230 kcal', reason: 'the stored target, not maintenance x factor recomputed here');
  });

  test('energy working names a floor and a day-set factor; older plans show nothing', () {
    final floored = energyWorking({
      ...nutrition,
      'energy': {...nutrition['energy'] as Map, 'floor': 'cut_minimum', 'activity': {'factor': 1.725, 'from': 'daily_activity', 'trainingDaysPerWeek': 2, 'dailyActivity': 'very_active'}},
    })!;
    expect(floored[1].$2, 'set by your day: very active');
    expect(floored.last.$2, 'raised to the minimum for a cut');
    expect(energyWorking({'energyKcal': 2000, 'bmrKcal': 1500}), isNull);
  });
}

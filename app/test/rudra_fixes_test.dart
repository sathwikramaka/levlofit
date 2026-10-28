import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/diet_plan.dart';
import 'package:levlo/session.dart';

import 'diet_plan_test.dart' show foodsForTest;

// Owner report 2026-10-29: allergies and dislikes, practical breakfasts, visible workout meals, custom equipment and
// a warm-up/cooldown on the real session screen.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  const veg = {'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg'};
  WeekRequest req({Set<String> excluded = veg, List<String> custom = const [], Map<int, Set<String>>? meals, bool topUp = false, double protein = 110}) => (
        foods: foodsForTest, kcal: 2200.0, protein: protein, excluded: excluded, custom: custom, tier: 2, soyaCapG: 50.0,
        proteinPowder: topUp, region: null, mealCodes: meals, topUpScoop: topUp,
      );
  const dairyCodes = {'L002', 'L003', 'supp:whey'};

  test('milk allergy (dairy excluded): no milk, paneer, whey or dairy-made dish anywhere, including shakes and workout meals', () {
    final week = planWeek(req(excluded: {...veg, 'dairy'}, protein: 160, topUp: true));
    for (final d in week) {
      for (final m in [...d.meals, ...workoutDay(d.meals, 'evening').meals, ...workoutDay(d.meals, 'early_morning').meals]) {
        for (final i in m.items) {
          expect(dairyCodes.contains(i.code), isFalse, reason: '${m.name}: ${i.code}');
          expect(foodsForTest[i.code]?.tags.contains('dairy') ?? false, isFalse, reason: '${m.name}: ${i.name}');
        }
      }
    }
    expect(week.expand((d) => d.meals).expand((m) => m.items).where((i) => i.unit == 'scoop').every((i) => i.code == 'supp:plant-protein'), isTrue);
  });

  test('milk dislike typed as "milk": the plan engine turns it into the dairy group, and the name match alone already drops milk', () {
    // The engine maps the word to the dairy tag (plan-engine.test.ts); the planner also matches the word in food names.
    for (final d in planWeek(req(custom: ['milk']))) {
      expect(d.meals.expand((m) => m.items).any((i) => i.code == 'L002'), isFalse);
    }
  });

  test('breakfast is never fruit alone: without a way to cook, sprouted mung or peanuts come with it; normal kitchens unchanged', () {
    final noCook = mealCodes(foodsForTest.keys, have: {})!;
    for (final d in planWeek(req(meals: noCook))) {
      final b = d.meals.first;
      expect(b.name, 'Breakfast');
      expect(b.items.any((i) => !i.code.startsWith('E')), isTrue, reason: mealSummary(b));
      expect(b.items.any((i) => i.code == 'dish:sprouts' || i.code == 'H012' || i.code == 'L002' || i.code == 'L003'), isTrue, reason: mealSummary(b));
    }
    for (final d in planWeek(req())) {
      expect(d.meals.first.items.first.code, startsWith('dish:'), reason: 'a kitchen that can cook still gets a breakfast dish');
      expect(d.meals.first.items.any((i) => i.code == 'H012'), isFalse);
    }
  });

  test('custom equipment: optional, understood items used, the rest never assumed', () {
    expect(customEquipment(null).used, isEmpty);
    expect(customEquipmentNote(''), isNull);
    final c = customEquipment('Rice cooker, toaster; hot plate');
    expect(c.used, {'Rice cooker': 'multi_kettle', 'hot plate': 'induction'});
    expect(c.unused, ['toaster']);
    expect(customEquipmentNote('rice cooker, air fryer'), allOf(contains('rice cooker (as multi-purpose'), contains('Not used for planning'), contains('air fryer')));
    final have = equipmentOf('full', ['kettle'], 'rice cooker');
    expect(have, {'kettle', 'multi_kettle'});
    expect(canMake('A015', have), isTrue, reason: 'rice in the rice cooker');
    expect(canMake('A019', have), isFalse, reason: 'still no rotis without a stove');
  });

  testWidgets('the session screen shows warm-up, then the main session, then the cooldown', (tester) async {
    tester.view.physicalSize = const Size(390, 3600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ids = sessionIds('strength', Tier.home, 1, 0);
    final rows = {for (final id in ids) id: {'id': id, 'name': 'move $id', 'gif_url': 'https://media.invalid/$id.gif', 'target_muscles': <String>[]}};
    await tester.pumpWidget(MaterialApp(home: SessionScreen(title: 'Strength', ids: ids, level: 1, moves: (x) async => resolveMoves(x, rows))));
    await tester.pump(const Duration(seconds: 2));
    final warm = tester.getTopLeft(find.text('WARM-UP  ·  ABOUT 5 MIN')).dy;
    final main = tester.getTopLeft(find.text('MAIN SESSION')).dy;
    final cool = tester.getTopLeft(find.text('COOLDOWN  ·  ABOUT 5 MIN')).dy;
    expect(warm < main && main < cool, isTrue);
    expect(find.textContaining('Easy cardio'), findsOneWidget);
    expect(find.textContaining('Gentle stretches'), findsOneWidget);
  });

  test('mess protein hint names only foods the person can eat (found on the phone: paneer shown with a milk allergy)', () {
    expect(messProteinHint({'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy'}), 'dal or soya chunks');
    expect(messProteinHint({'beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'soy'}), 'dal');
    expect(messProteinHint({'beef', 'pork'}), 'dal, paneer, curd, eggs, chicken, fish or soya chunks');
    expect(messProteinHint({'egg'}, ['chicken']), isNot(contains('chicken')));
  });

  test('a multi-purpose kettle boils water too: poha is a breakfast option (found on the phone: breakfast fell back to peanuts)', () {
    expect(canMake('dish:poha', {'multi_kettle'}), isTrue);
    final meals = mealCodes(foodsForTest.keys, have: {'multi_kettle', 'blender'}, cookTime: 'short', messMeals: ['lunch', 'dinner'])!;
    for (final d in planWeek(req(excluded: {...veg, 'dairy'}, meals: meals))) {
      expect(d.meals.first.items.first.code, 'dish:poha', reason: mealSummary(d.meals.first));
    }
  });
}

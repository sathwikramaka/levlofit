import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/supplement_guide.dart';

// The supplement reference (owner request 2026-11-12): one file for the app and Levlofit AI, matched to what people type.
void main() {
  final raw = File('assets/supplements.json').readAsStringSync();
  final g = parseSuppGuide(raw);

  test('the app and coach-chat read the same reference file', () {
    expect(raw, File('../supabase/functions/_shared/supplements.json').readAsStringSync());
  });

  test('every entry has timing, an amount line, a caution and a source', () {
    expect(g.items.length, greaterThanOrEqualTo(20));
    for (final s in g.items) {
      expect(g.timings.containsKey(s.timing), isTrue, reason: s.id);
      expect([s.what, s.when, s.reference, s.caution, s.who].every((x) => x.length > 20), isTrue, reason: s.id);
      expect(s.sources, isNotEmpty, reason: s.id);
      expect(const {'strong', 'moderate', 'limited', 'weak'}.contains(s.evidence), isTrue, reason: s.id);
    }
    expect(g.items.map((s) => s.id).toSet().length, g.items.length);
  });

  test('what people type is matched to the right entry', () {
    String? id(String typed) => matchSupp(typed, g)?.id;
    expect(id('Vitamin D'), 'vitamin_d');
    expect(id('Vit D3 60k weekly'), 'vitamin_d');
    expect(id('B12'), 'b12');
    expect(id('Methylcobalamin 1500'), 'b12');
    expect(id('Omega 3 capsules'), 'omega3');
    expect(id('fish oil'), 'omega3');
    expect(id('Creatine monohydrate'), 'creatine');
    expect(id('ORS'), 'electrolytes');
    expect(id('Folic acid'), 'folate');
    expect(id('Shilajit'), isNull, reason: 'not in the reference: shown as the person\'s own, unchecked');
  });

  test('timing picks a meal: the fattiest later meal for vitamin D, breakfast for B12, training meals for pre and post', () {
    final fats = [8.0, 22.0, 10.0, 30.0]; // breakfast, lunch, snack, dinner
    expect(mealFor('fat_meal', fats), 3);
    expect(mealFor('morning', fats), 0);
    expect(mealFor('evening', fats), 3);
    expect(mealFor('pre', fats, pre: 2, post: 3), 2);
    expect(mealFor('post', fats), isNull, reason: 'a rest day has no post-workout meal');
    expect(mealFor('empty', fats), isNull);
  });

  test('suggestions are optional and fit the person: B12 for vegetarians, creatine for strength, nothing already taken', () {
    List<String> ids(String? diet, List<String> goals, Set<String> taking) =>
        [for (final x in suggestSupps(dietType: diet, goals: goals, taking: taking, guide: g)) x.item.id];
    expect(ids('vegetarian', ['bodybuilding'], {}), ['vitamin_d', 'b12', 'omega3', 'creatine']);
    expect(ids('non_vegetarian', ['running'], {}), ['vitamin_d', 'omega3']);
    expect(ids('vegan', ['strength'], {'vitamin_d', 'b12', 'omega3', 'creatine'}), isEmpty);
  });
}

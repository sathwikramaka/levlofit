import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/food_diary.dart';

void main() {
  Future<void> pump(WidgetTester tester, Future<bool> Function() probe) async {
    foodDataProbe = probe;
    resetFoodDataForTest();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: EmptyFoodsText('No matching foods.'))));
    await tester.pump();
  }

  testWidgets('no visible food row: the licence note, not "nothing found"', (tester) async {
    await pump(tester, () async => false);
    expect(find.text(foodDataPendingText), findsOneWidget);
    expect(find.text('No matching foods.'), findsNothing);
  });

  testWidgets('food rows visible: the normal empty-search text', (tester) async {
    await pump(tester, () async => true);
    expect(find.text('No matching foods.'), findsOneWidget);
  });

  testWidgets('a failed check never claims a licence gap', (tester) async {
    await pump(tester, () async => throw Exception('offline'));
    expect(find.text('No matching foods.'), findsOneWidget);
  });

  test('the note promises nothing it cannot keep and names no restricted source', () {
    expect(foodDataPendingText, isNot(contains('IFCT')));
    expect(foodDataPendingText, contains('calorie and protein targets still apply'));
  });

  Future<void> credit(WidgetTester tester, Future<Set<String>> Function() probe) async {
    foodSourcesProbe = probe;
    resetFoodSourcesForTest();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FoodCredit(lead: 'Per 100 g. ', trail: 'Weigh as eaten.'))));
    await tester.pump();
  }

  testWidgets('the credit names only sources whose foods are visible', (tester) async {
    await credit(tester, () async => {'usda_fdc'});
    expect(find.text('Per 100 g. ${foodSourceCredits['usda_fdc']}. Weigh as eaten.'), findsOneWidget);
    expect(find.textContaining('IFCT'), findsNothing);
  });

  testWidgets('development data with IFCT allowed credits both', (tester) async {
    await credit(tester, () async => {'ifct2017', 'usda_fdc'});
    expect(find.textContaining('IFCT 2017'), findsOneWidget);
    expect(find.textContaining('FoodData Central'), findsOneWidget);
  });

  testWidgets('nothing visible or a failed check: no source is claimed', (tester) async {
    await credit(tester, () async => <String>{});
    expect(find.text('Per 100 g. Weigh as eaten.'), findsOneWidget);
    await credit(tester, () async => throw Exception('offline'));
    expect(find.text('Per 100 g. Weigh as eaten.'), findsOneWidget);
  });

  test('no screen hard-codes the IFCT credit any more', () {
    for (final f in ['dashboard.dart', 'dashboard_menu.dart', 'dashboard_tabs.dart', 'food_diary.dart']) {
      final src = File('lib/$f').readAsLinesSync().where((l) => !l.trimLeft().startsWith('//'));
      expect(src.where((l) => l.contains("'") && l.contains('IFCT 2017') && !l.contains('foodSourceCredits') && !l.contains("'ifct2017':")), isEmpty, reason: f);
    }
  });
}

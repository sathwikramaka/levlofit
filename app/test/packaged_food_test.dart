import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/barcode.dart';
import 'package:levlo/food_diary.dart';
import 'package:levlo/packaged_food.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('barcode lengths: EAN-8, UPC-A, EAN-13, GTIN-14 only', () {
    for (final ok in ['12345670', '012345678905', '8901058000290', '18901058000297']) {
      expect(validBarcode(ok), isTrue, reason: ok);
    }
    for (final bad in ['1234567', '1234567890', 'abc12345', '890105800029012']) {
      expect(validBarcode(bad), isFalse, reason: bad);
    }
  });

  test('Open Food Facts reply: values per 100 g, kJ fallback, missing stays null, not found is null', () {
    final p = packagedFromOff('8901058000290', {
      'status': 1,
      'product': {
        'product_name': 'Masala oats ',
        'brands': 'Brand A, Brand B',
        'last_modified_t': 1790000000,
        'nutriments': {'energy-kj_100g': 1590, 'proteins_100g': 12.5, 'fat_100g': '7', 'carbohydrates_100g': 65},
      },
    })!;
    expect(p.name, 'Masala oats');
    expect(p.brand, 'Brand A');
    expect(p.kcal, closeTo(380.0, 0.1));
    expect(p.fat, 7);
    expect(p.fiber, isNull); // unknown, not 0
    expect(p.source, 'open_food_facts');
    expect(packagedFromOff('1', {'status': 0}), isNull);
  });

  test('label check matches the database bounds', () {
    Packaged p({double? kcal = 100, double? protein = 10, double? fat = 5, double? carb = 20, String name = 'Oats'}) =>
        (barcode: null, name: name, brand: null, kcal: kcal, protein: protein, fat: fat, carb: carb, fiber: null, source: 'manual', sourceDate: null);
    expect(packagedProblem(p()), isNull);
    expect(packagedProblem(p(protein: null)), contains('Protein per 100 g is missing'));
    expect(packagedProblem(p(kcal: 950)), contains('Energy'));
    expect(packagedProblem(p(protein: 50, fat: 30, carb: 30)), contains('more than 100 g'));
    expect(packagedProblem(p(name: 'x')), 'Enter the product name');
  });

  test('diary keys a packaged entry as pkg:<id>', () {
    final e = entryFromRow({'id': 'e1', 'meal': 'snack', 'food_code': null, 'packaged_food_id': 'abc', 'grams': 30});
    expect(e.foodCode, 'pkg:abc');
    final f = foodFromPackaged({'id': 'abc', 'name': 'Oats', 'brand': 'X', 'kcal': 380, 'protein_g': 12, 'fat_g': 7, 'carb_g': 65, 'fiber_g': null});
    expect(diaryTotals([e], {f.code: f}).kcal, closeTo(114, 0.01));
    expect(diaryTotals([e], {f.code: f}).micros['iron_mg']!.missing, 1); // not on the label: missing, not zero
  });

  testWidgets('form: a missing value blocks saving; filled in, it saves as from the label and returns the diary food', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Packaged? saved;
    (FoodRow, double)? result;
    final initial = (barcode: '8901058000290', name: 'Oats', brand: null, kcal: 380.0, protein: 12.0, fat: null, carb: 65.0, fiber: null, source: 'open_food_facts', sourceDate: null) as Packaged;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.push<(FoodRow, double)>(context, MaterialPageRoute(
            builder: (_) => PackagedFoodForm(initial: initial, save: (p, {id}) async {
              saved = p;
              return 'new-id';
            }),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open Food Facts'), findsOneWidget);
    await tester.tap(find.text('Save and add'));
    await tester.pump();
    expect(find.textContaining('Fat per 100 g is missing'), findsOneWidget);
    expect(saved, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Fat'), '7');
    await tester.ensureVisible(find.text('Save and add'));
    await tester.tap(find.text('Save and add'));
    await tester.pumpAndSettle();
    expect(saved!.fat, 7);
    expect(saved!.source, 'label'); // edited by the person, so the label is the source
    expect(result!.$1.code, 'pkg:new-id');
    expect(result!.$2, 30);
  });
}

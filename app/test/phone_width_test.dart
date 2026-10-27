import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/dashboard.dart';
import 'package:levlo/exercises.dart';
import 'package:levlo/tools.dart';

// Phone width (375 x 812, a common small Android size). The in-app browser cannot take input under mobile
// emulation, so these interactions are checked here; a real device pass is still in the plan.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('BMI at phone width: units, a bad value and the result, without overflow', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: BmiScreen(heightCm: 160, weightKg: 58, age: 30)));
    await tester.pumpAndSettle();
    expect(find.text('22.7'), findsOneWidget);
    await tester.tap(find.text('ft in, lb'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '5'), '2');
    await tester.pumpAndSettle();
    expect(find.text('Enter a height between 4 ft 0 in and 7 ft 6 in'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reminders at phone width: built-in settings and the own-reminders section lay out', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(home: tabForTest('reminders', const {'trainingDaysPerWeek': 3, 'goals': []})));
    await tester.pump(const Duration(seconds: 2));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('YOUR OWN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise detail without the catalogue shows guide, equipment wording and versions', (tester) async {
    phone(tester);
    // The catalogue read fails, as with the empty local catalogue.
    await tester.pumpWidget(MaterialApp(home: ExerciseScreen(id: 'I4hDWkc', load: () async => throw Exception('offline'))));
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400)); // past the demonstration picture
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('No equipment'), findsOneWidget); // guide wording kept as written (catalogue tags are title-cased)
    expect(find.text('None'), findsNothing);
    for (final v in ['Incline push-up', 'Bench press', 'Dumbbell bench press']) {
      expect(find.widgetWithText(InkWell, v), findsOneWidget, reason: v);
    }
    final pushed = <Route<dynamic>>[];
    // Rebuild with an observer to see the version chip open another exercise page.
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [_Pushes(pushed)],
      home: ExerciseScreen(id: 'I4hDWkc', load: () async => throw Exception('offline')),
    ));
    await tester.pump(const Duration(seconds: 1));
    pushed.clear();
    await tester.tap(find.widgetWithText(InkWell, 'Incline push-up'));
    await tester.pump();
    expect(pushed, hasLength(1));
    tester.takeException(); // the pushed page reads the real catalogue, which tests cannot reach
  });
}

class _Pushes extends NavigatorObserver {
  _Pushes(this.log);
  final List<Route<dynamic>> log;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => log.add(route);
}

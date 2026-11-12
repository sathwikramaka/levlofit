import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/coach_chat.dart' show Markdown;
import 'package:levlo/dashboard.dart' show weekSheetForTest;

// Levlofit AI sees the week as the app shows it, and its tables render in the chat (2026-11-12).
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('week sheet: seven days, sessions with numbered moves, targets, doses and rest; rest days named', () {
    final s = weekSheetForTest({
      'trainingDaysPerWeek': 3,
      'goals': [
        {'goal': 'strength', 'name': 'Strength', 'kind': 'strength', 'startLevel': 2, 'sessionsPerWeek': 3, 'experience': 'beginner'},
      ],
    });
    final lines = s.split('\n');
    expect(lines.first, startsWith('Week of '));
    for (final d in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
      expect(lines.where((l) => l.startsWith('$d ')), hasLength(1), reason: d);
    }
    expect(lines.where((l) => l.contains(': rest day')), hasLength(4));
    expect(lines.where((l) => l.trimLeft().startsWith('Warm-up: ')), hasLength(3));
    expect(lines.where((l) => RegExp(r'^  1\. .+ \| .*sets × 8–12 reps').hasMatch(l)), hasLength(3));
    expect(s, contains('targets '));
    expect(s, contains('rest 2 min'));
  });

  testWidgets('chat tables: header, rows, bold cells; the |---| line is not a row', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Markdown('Today:\n\n| Exercise | Sets × reps | Rest |\n|---|---|---|\n| **Squat** | 3 × 8–12 | 2 min |\n| Push-up | 3 × 8–12 | 90 s |\n\nKeep 1–3 reps in reserve.'),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(Table), findsOneWidget);
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(3));
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.textContaining('---'), findsNothing);
    expect(find.text('Keep 1–3 reps in reserve.'), findsOneWidget);
  });
}

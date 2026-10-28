import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/onboarding.dart';
import 'package:levlo/swaps.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// B7: goals are replaced in one transaction (F3); the coach is sent this phone's calendar day (F7).
void main() {
  final goals = [
    {'goal': 'strength', 'experience': 'beginner'},
    {'goal': 'running', 'experience': 'none'},
  ];

  test('F3: the atomic function is used; the old delete-then-insert never runs when it exists', () async {
    final calls = <String>[];
    await replaceGoals(goals, rpc: (g) async => calls.add('rpc ${g.length}'), legacy: (_) async => calls.add('legacy'));
    expect(calls, ['rpc 2']);
  });

  test('F3: a failed replace is reported and nothing else is tried, so the old goals stay', () async {
    final calls = <String>[];
    await expectLater(
      replaceGoals(goals, rpc: (_) async => throw const PostgrestException(message: 'violates foreign key', code: '23503'), legacy: (_) async => calls.add('legacy')),
      throwsA(isA<PostgrestException>()),
    );
    expect(calls, isEmpty);
  });

  test('F3: before the migration (function missing) the old path still saves the goals', () async {
    final calls = <String>[];
    await replaceGoals(goals, rpc: (_) async => throw const PostgrestException(message: 'Could not find the function', code: 'PGRST202'), legacy: (g) async => calls.add('legacy ${g.length}'));
    expect(calls, ['legacy 2']);
  });

  test('F7: the day sent is the phone\'s calendar day, also just after midnight', () {
    expect(localDayNow(DateTime(2026, 10, 29, 0, 30)), '2026-10-29');
    expect(localDayNow(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });
}

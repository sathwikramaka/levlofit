import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('emailed: the user is told it reached the team', () async {
    final sent = <Map<String, Object>>[];
    final r = await submitFeedback('Great app', send: (b) async => (sent..add(b), {'saved': true, 'emailed': true}).$2);
    expect(r, (true, 'Thanks! Your feedback reached the Levlofit team.'));
    expect(sent, [{'message': 'Great app'}]);
  });

  test('saved but not emailed: the user is told honestly, the sheet still closes', () async {
    final (ok, note) = await submitFeedback('Great app', send: (_) async => {'saved': true, 'emailed': false});
    expect(ok, isTrue);
    expect(note, contains('saved, but we could not email it'));
    expect(note, isNot(contains('reached')));
  });

  test('server refusal shows its message in the sheet (daily limit)', () async {
    final r = await submitFeedback('x', send: (_) async => throw const FunctionException(status: 429, details: {'error': 'You can send 5 feedback messages a day. Try again tomorrow.'}));
    expect(r, (false, 'You can send 5 feedback messages a day. Try again tomorrow.'));
  });

  test('server error without a message, and no connection, keep the sheet open', () async {
    expect((await submitFeedback('x', send: (_) async => throw const FunctionException(status: 500))).$1, isFalse);
    final r = await submitFeedback('x', send: (_) async => throw Exception('offline'));
    expect(r, (false, 'Could not send. Check your connection.'));
  });
}

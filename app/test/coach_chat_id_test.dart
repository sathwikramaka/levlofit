import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/coach_chat.dart';

void main() {
  test('client message ids are version-4 UUIDs the server accepts, and differ per message', () {
    final server = RegExp(r'^[0-9a-f-]{36}$'); // coach-chat UUID check
    final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = {for (var i = 0; i < 200; i++) newClientMsgId()};
    expect(ids, hasLength(200));
    for (final id in ids) {
      expect(server.hasMatch(id), isTrue, reason: id);
      expect(v4.hasMatch(id), isTrue, reason: id);
    }
    expect(newClientMsgId(math.Random(1)), newClientMsgId(math.Random(1)), reason: 'deterministic with a seeded source');
  });
}

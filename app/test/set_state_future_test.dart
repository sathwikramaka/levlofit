import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// `setState(() => _future = load())` returns the Future from the closure, which Flutter rejects with an assertion in
// debug builds: the tap does nothing. Found on the phone 2026-10-17 ("See my plan" after onboarding). Release builds
// skip the assertion, so only a debug run shows it. Every Future-typed state field must be set in a block body.
void main() {
  test('no setState closure returns a Future by assigning a Future-typed field', () {
    final field = RegExp(r'Future<[^;=]*>\??\s+(_\w+)\s*[=;]');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = file.readAsStringSync();
      for (final name in {for (final m in field.allMatches(src)) m.group(1)!}) {
        if (RegExp('setState\\(\\(\\) => ${RegExp.escape(name)} =').hasMatch(src)) offenders.add('${file.path}: $name');
      }
    }
    expect(offenders, isEmpty);
  });

  test('the guard sees the fields it is meant to protect', () {
    // If a refactor renames these, the scan above would pass vacuously.
    expect(File('lib/main.dart').readAsStringSync(), contains('Future<bool>? _onboarded;'));
    expect(File('lib/dashboard.dart').readAsStringSync(), contains('late Future<_Data> _data'));
  });
}

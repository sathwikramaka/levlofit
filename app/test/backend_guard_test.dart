import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('debug and profile builds only start against the local stack', () {
    const local = 'sb_publishable_local_example';
    expect(devBackendProblem('http://127.0.0.1:54321', local, release: false), isNull);
    expect(devBackendProblem('http://localhost:54321', local, release: false), isNull);
    expect(devBackendProblem('http://10.0.2.2:54321', local, release: false), isNull);
    // The silent fallback this guards against: no defines means the cloud URL.
    expect(devBackendProblem('https://ndeozgxowggkljluaccz.supabase.co', local, release: false), isNotNull);
    expect(devBackendProblem('https://127.0.0.1:54321', local, release: false), isNotNull); // wrong scheme
    expect(devBackendProblem('http://127.0.0.1:5432', local, release: false), isNotNull); // wrong port
    expect(devBackendProblem('http://192.168.1.5:54321', local, release: false), isNotNull); // LAN, not allowed
    expect(devBackendProblem('', local, release: false), isNotNull);
    expect(devBackendProblem('not a url', local, release: false), isNotNull);
    // A local URL with the cloud key, or no key, is refused too.
    expect(devBackendProblem('http://127.0.0.1:54321', 'sb_publishable_RDQ5eDXSYQn8vuBLZ5agFA_4wUGVi2r', release: false), isNotNull);
    expect(devBackendProblem('http://127.0.0.1:54321', '', release: false), isNotNull);
    // A release build with an explicit backend starts: the store build (LEVLOFIT_BACKEND=production) or a local test.
    expect(devBackendProblem('https://ndeozgxowggkljluaccz.supabase.co', 'anything', release: true), isNull);
    expect(devBackendProblem('http://127.0.0.1:54321', local, release: true), isNull);
  });

  test('a release build with no backend chosen refuses to start instead of reaching production', () {
    expect(devBackendProblem('', '', release: true), contains('LEVLOFIT_BACKEND=production'));
    expect(devBackendProblem('https://ndeozgxowggkljluaccz.supabase.co', '', release: true), isNotNull);
  });

  test('without defines the build has no backend at all; the cloud project is only an opt-in', () {
    // flutter test passes no --dart-define, like an ordinary build.
    expect(backendChoice, isEmpty);
    expect(supabaseUrl, isEmpty);
    expect(supabaseKey, isEmpty);
  });

  test('start screen: a server refusal is not called a connection problem', () {
    // An account deleted elsewhere keeps a valid token; loading its profile fails with a foreign-key error (23503).
    const gone = PostgrestException(message: 'violates foreign key constraint', code: '23503');
    expect(gateLoadError(gone), contains('sign out and sign in again'));
    expect(gateLoadError(const AuthException('session not found')), contains('sign out'));
    expect(gateLoadError(Exception('SocketException: Connection refused')), 'Could not reach Levlofit. Check your connection.');
  });

  test('the bundled Phosphor icon font licence is on the licence page', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerBundledLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final phosphor = entries.where((e) => e.packages.contains('Phosphor Icons (font)')).toList();
    expect(phosphor, hasLength(1));
    expect(phosphor.single.paragraphs.map((p) => p.text).join(' '), contains('Permission is hereby granted'));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levlo/onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A new user can leave onboarding: sign out or delete the account before a plan exists (Play's in-app deletion
// rule). No request reaches a real server: the URL is unreachable and nothing is confirmed.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://levlofit-test.invalid', publishableKey: 'test-publishable-key');
  });

  testWidgets('first-run onboarding offers Sign out and Delete account; delete asks first and Cancel does nothing', (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(home: Onboarding(onDone: () => done = true)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('profile, answers, plans, logs and photos'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
    expect(done, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing goals from the dashboard has no account menu', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Onboarding(goalsOnly: true, onDone: () {})));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Account'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

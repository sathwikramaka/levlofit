import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb, kReleaseMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account.dart' show signOutEverywhereOrLocally;
import 'auth_screen.dart';
import 'dashboard.dart';
import 'error_report.dart';
import 'exercises.dart' show animationNotice, drawingNotice;
import 'mark.dart';
import 'move_animation.dart' show DemoFigure, demoFigure;
import 'onboarding.dart';
import 'reminders.dart';
import 'steps.dart' show forgetSteps;
import 'theme.dart';

// Cloud project "levlo" (ap-south-1). The publishable key is public by design; RLS protects data.
// No build reaches it by default. Store build: --dart-define=LEVLOFIT_BACKEND=production. Local stack:
// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=... (an explicit URL and key always win).
const _cloudUrl = 'https://ndeozgxowggkljluaccz.supabase.co';
const _cloudKey = 'sb_publishable_RDQ5eDXSYQn8vuBLZ5agFA_4wUGVi2r';
const backendChoice = String.fromEnvironment('LEVLOFIT_BACKEND');
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: backendChoice == 'production' ? _cloudUrl : '');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: backendChoice == 'production' ? _cloudKey : '');

/// Debug and profile builds may only use the local stack (USB tunnel 127.0.0.1, or 10.0.2.2 from an emulator):
/// a missing or mistyped --dart-define would otherwise fall back to the cloud project without a word.
/// A release build must name its backend (no defines = no backend), so a local release test build cannot reach the
/// cloud project by accident. Returns why the app must not start, or null.
@visibleForTesting
String? devBackendProblem(String url, String key, {required bool release}) {
  if (release) {
    return url.isEmpty || key.isEmpty
        ? 'This build has no backend. Store build: --dart-define=LEVLOFIT_BACKEND=production. '
            'Local test build: --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_PUBLISHABLE_KEY=...'
        : null;
  }
  final u = Uri.tryParse(url);
  if (u == null || u.scheme != 'http' || !const {'127.0.0.1', 'localhost', '10.0.2.2'}.contains(u.host) || u.port != 54321) {
    return 'Debug and profile builds only run against the local Supabase stack (http://127.0.0.1:54321). '
        'SUPABASE_URL is "$url". Pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_PUBLISHABLE_KEY=...';
  }
  if (key.isEmpty || key == _cloudKey) return 'SUPABASE_PUBLISHABLE_KEY must be the local key from `supabase status`.';
  return null;
}

SupabaseClient get supabase => Supabase.instance.client;

/// The Phosphor icon font ships inside the app under the MIT licence, whose notice must travel with it; Flutter lists
/// package licences on its own, but not bundled font files, so this adds it to the licence page (Settings). The same
/// goes for the bundled exercise drawings.
void registerBundledLicenses() => LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(['Phosphor Icons (font)'], await rootBundle.loadString('assets/fonts/PHOSPHOR-LICENSE'));
      // Body-map outlines (muscle_shapes.dart), converted from react-native-body-highlighter 3.2.0; its MIT notice, unchanged.
      yield LicenseEntryWithLineBreaks(['Muscle map outlines: react-native-body-highlighter'], await rootBundle.loadString('assets/licenses/react-native-body-highlighter-LICENSE'));
      // Exercise drawings, CC BY-SA 4.0 (assets/drawings/everkinetic/SOURCE.md). Section 3(a): creator, a link to the
      // material, that it is unmodified, and the licence text (which carries the disclaimer).
      yield const LicenseEntryWithLineBreaks(['Exercise animations: CDC Growing Stronger (public domain)'], animationNotice);
      yield LicenseEntryWithLineBreaks(['Exercise drawings: Everkinetic by Greg Priday (CC BY-SA 4.0)'],
          '$drawingNotice\n\n${await rootBundle.loadString('assets/drawings/everkinetic/LICENSE')}');
    });

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  // Refuse to start, before any network call, rather than reach the cloud from a test build.
  if (devBackendProblem(supabaseUrl, supabaseKey, release: kReleaseMode) case final problem?) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(problem))))));
    return;
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  installErrorReporting();
  prefs = await SharedPreferences.getInstance();
  themeMode.value = ThemeMode.values.asNameMap()[prefs.getString('theme')] ?? ThemeMode.system;
  demoFigure.value = DemoFigure.values.asNameMap()[prefs.getString(demoFigureKey)] ?? DemoFigure.man;
  runApp(const LevloApp());
}

/// Device settings: theme choice and which one-time screens were seen.
late final SharedPreferences prefs;

/// Which figure demonstrates moves: chosen on a move page, else from the profile's sex (dashboard), on this device.
const demoFigureKey = 'demo_figure';

/// Light, dark or follow the phone. Changed from Profile, remembered on this device.
final themeMode = ValueNotifier(ThemeMode.system);

void setThemeMode(ThemeMode mode) {
  themeMode.value = mode;
  prefs.setString('theme', mode.name);
}

class LevloApp extends StatelessWidget {
  const LevloApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'Levlofit',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          // The splash sits over the app while the Gate loads underneath, so it never adds waiting time.
          builder: (context, child) => Splash(child: child!),
          home: const Gate(),
        ),
      );
}

/// First run after sign-in: what Levlofit asks for and why, like any well-made app. Notifications are requested
/// with Android's own prompt, only when the button is tapped. Exact timing for reminders is a system setting, not a
/// prompt: the button opens Android's Alarms & reminders page and the status is read again on return. Nothing here
/// blocks the app; photos and camera are asked the first time you add one.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool? _notifications; // null until known (or on the web)
  bool _asked = false; // asked once on this screen: no second prompt
  ReminderTiming? _timing; // null where exact timing does not apply (web, iOS) or cannot be read
  late final _lifecycle = AppLifecycleListener(onResume: _refresh);

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening: returning from the phone's settings re-reads both
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Each status shows as soon as it is known, so a slow read of one never hides the other.
  Future<void> _refresh() => Future.wait([
        Reminders.notificationsEnabled().then((n) => mounted ? setState(() => _notifications = n) : null),
        Reminders.timing().then((t) => mounted ? setState(() => _timing = t) : null),
      ]);

  Future<void> _finish() async {
    await prefs.setBool('permissions_seen', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    Widget row(IconData icon, String title, String body, Widget action) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.outline)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: c.onPrimary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(body, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  action,
                ]),
              ),
            ]),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: staggered([
              const Align(alignment: Alignment.centerLeft, child: LevloMark(size: 48, animate: true)),
              const SizedBox(height: 20),
              Text('A few permissions', style: t.headlineMedium),
              const SizedBox(height: 6),
              Text('Levlofit only asks for what it uses. You can change any of these later in your phone settings.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              const SizedBox(height: 24),
              row(
                Icons.notifications_none,
                'Notifications',
                kIsWeb ? 'Reminders show inside the app while it is open on the web.' : 'Training, water and weigh-in reminders, with the Levlofit sound. You choose which ones in Reminders.',
                kIsWeb
                    ? Text('In the app', style: t.labelLarge?.copyWith(color: c.onSurfaceVariant))
                    : _notifications == true
                        ? Text('On', style: t.labelLarge?.copyWith(color: c.tertiary))
                        : _asked
                            ? Text('Off. You can turn them on later in Reminders or in your phone settings.', style: t.labelLarge?.copyWith(color: c.tertiary))
                            : FilledButton(
                                onPressed: () async {
                                  await Reminders.requestPermission();
                                  _asked = true;
                                  await _refresh();
                                },
                                child: const Text('Allow notifications'),
                              ),
              ),
              if (_timing case final timing?)
                row(
                  Icons.alarm,
                  'Reminders on time',
                  'So reminders arrive at the minute you set. This is a system setting, not a pop-up: the button opens Android\'s '
                      'Alarms & reminders page, where you switch Levlofit on and come back. Without it, reminders still come, just '
                      'possibly a few minutes late, and some phones may hold them briefly to save battery either way.',
                  timing == ReminderTiming.exact
                      ? Text('On', style: t.labelLarge?.copyWith(color: c.tertiary))
                      : OutlinedButton(onPressed: Reminders.requestExactTiming, child: const Text('Open Alarms & reminders')),
                ),
              row(Icons.photo_library_outlined, 'Photos and camera', 'Only for progress photos. Your phone asks the first time you add one, and photos stay private to your account.',
                  Text('Asked when needed', style: t.labelLarge?.copyWith(color: c.onSurfaceVariant))),
              row(Icons.lock_outline, 'Your data', 'Your plan, logs and photos are stored in your own account, protected so only you can read them. Delete your account any time from Profile.',
                  Text('Always on', style: t.labelLarge?.copyWith(color: c.onSurfaceVariant))),
              const SizedBox(height: 10),
              FilledButton(onPressed: _finish, child: const Text('Continue')),
            ])),
          ),
        ),
      ),
    );
  }
}

/// Launch: the mark's bubble settles, the wordmark rises, then the plate lifts away to reveal the app.
class Splash extends StatefulWidget {
  const Splash({super.key, required this.child});
  final Widget child;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _gone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _gone) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _gone = true;
    } else {
      _c.forward().whenComplete(() => mounted ? setState(() => _gone = true) : null);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    final word = CurvedAnimation(parent: _c, curve: const Interval(0.25, 0.6, curve: spring));
    final exit = CurvedAnimation(parent: _c, curve: const Interval(0.72, 1, curve: Curves.easeInCubic));
    return Stack(children: [
      // The app scales up from slightly behind as the plate leaves: depth, not a cut.
      AnimatedBuilder(animation: exit, builder: (_, child) => Transform.scale(scale: 0.96 + 0.04 * exit.value, child: child), child: widget.child),
      AnimatedBuilder(
        animation: _c,
        builder: (context, _) => IgnorePointer(
          child: Opacity(
            opacity: 1 - exit.value,
            child: Theme(
              data: darkTheme,
              child: Material(
                color: graphite, // also gives the wordmark a text style; nothing above the Navigator does
                child: Center(
                  child: Transform.scale(
                    scale: 1 + 0.08 * exit.value,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const LevloMark(size: 84, animate: true),
                      const SizedBox(height: 22),
                      Opacity(
                        opacity: word.value,
                        child: Transform.translate(offset: Offset(0, 12 * (1 - word.value)), child: const LevloWordmark(fontSize: 30)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Signed out -> auth. Signed in without a plan -> onboarding. Otherwise -> dashboard.
/// The server owns onboarding_complete (only generate-plan can set it).
/// What the start screen says when the account could not be loaded. Only a network failure is "could not reach"; a
/// server refusal (for example an account that no longer exists) says so and points to signing out.
@visibleForTesting
String gateLoadError(Object error) => error is PostgrestException || error is AuthException
    ? 'Could not load your account. Try again, or sign out and sign in again.'
    : 'Could not reach Levlofit. Check your connection.';

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  late final StreamSubscription<AuthState> _auth;
  String? _userId = supabase.auth.currentUser?.id;
  Future<bool>? _onboarded;
  bool _recovering = false; // opened a password reset link

  @override
  void initState() {
    super.initState();
    if (_userId != null) _onboarded = _loadOnboarded();
    // Errors from a failed Google/email-link redirect are shown by AuthScreen (it reads the URL);
    // swallow them here so they are not reported as uncaught.
    _auth = supabase.auth.onAuthStateChange.handleError((Object _) {}).listen((s) {
      if (s.event == AuthChangeEvent.passwordRecovery) setState(() => _recovering = true);
      final id = s.session?.user.id;
      if (id == _userId) return; // token refreshes keep the same user
      // Signed out for any reason (also an expired session): this account's reminders stop on this phone.
      if (id == null) Reminders.clearAll().catchError((Object _) {});
      // Steps and the choice to share them belong to the person who made them: forget both on any account change.
      forgetSteps().catchError((Object _) {});
      setState(() {
        _userId = id;
        _onboarded = id == null ? null : _loadOnboarded();
      });
    });
  }

  @override
  void dispose() {
    _auth.cancel();
    super.dispose();
  }

  Future<bool> _loadOnboarded() async {
    // Self-heal a missing profile row (RLS: own id only, id column only; no-op when it exists).
    await supabase.from('profiles').upsert({'id': _userId}, ignoreDuplicates: true);
    return (await supabase.from('profiles').select('onboarding_complete').eq('id', _userId!).single())['onboarding_complete'] as bool;
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering) return SetPasswordScreen(onDone: () => setState(() => _recovering = false));
    if (_userId == null) return const AuthScreen();
    return FutureBuilder<bool>(
      key: ValueKey(_userId),
      future: _onboarded,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ErrorLine(gateLoadError(snap.error!)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => setState(() { _onboarded = _loadOnboarded(); }), child: const Text('Try again')),
                  // A session whose account is gone (deleted on another phone) fails here on every try until the token
                  // expires; signing out is the way back to the sign-in screen (found on a phone, 2026-10-17).
                  TextButton(onPressed: signOutEverywhereOrLocally, child: const Text('Sign out')),
                ]),
              ),
            ),
          );
        }
        if (!snap.hasData) return const Scaffold(body: Center(child: LevloMark(size: 72, animate: true)));
        if (!snap.data!) return Onboarding(onDone: () => setState(() { _onboarded = Future.value(true); }));
        if (prefs.getBool('permissions_seen') != true) return PermissionsScreen(onDone: () => setState(() {}));
        return const Dashboard();
      },
    );
  }
}

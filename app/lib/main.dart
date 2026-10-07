import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'dashboard.dart';
import 'mark.dart';
import 'onboarding.dart';
import 'reminders.dart';
import 'theme.dart';

// Cloud project "levlo" (ap-south-1). The publishable key is public by design; RLS protects data.
// Override for a local stack: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ndeozgxowggkljluaccz.supabase.co');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_RDQ5eDXSYQn8vuBLZ5agFA_4wUGVi2r');

SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  prefs = await SharedPreferences.getInstance();
  themeMode.value = ThemeMode.values.asNameMap()[prefs.getString('theme')] ?? ThemeMode.system;
  runApp(const LevloApp());
}

/// Device settings: theme choice and which one-time screens were seen.
late final SharedPreferences prefs;

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

/// First run after sign-in: what Levlofit asks for and why, like any well-made app. Only the
/// notification permission is requested up front; photos and camera are asked the first time you add one.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool? _notifications; // null until asked

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
                kIsWeb ? 'Reminders show inside the app while it is open on the web.' : 'Training, water and weigh-in reminders, with the Levlofit sound. You choose which ones in Settings.',
                _notifications == null
                    ? FilledButton(
                        onPressed: () async {
                          final ok = await Reminders.requestPermission();
                          if (mounted) setState(() => _notifications = ok || kIsWeb);
                        },
                        child: const Text('Allow notifications'),
                      )
                    : Text(_notifications! ? 'Allowed' : 'Not allowed. You can turn them on later.', style: t.labelLarge?.copyWith(color: c.tertiary)),
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
                  const ErrorLine('Could not reach Levlofit. Check your connection.'),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => setState(() => _onboarded = _loadOnboarded()), child: const Text('Try again')),
                ]),
              ),
            ),
          );
        }
        if (!snap.hasData) return const Scaffold(body: Center(child: LevloMark(size: 72, animate: true)));
        if (!snap.data!) return Onboarding(onDone: () => setState(() => _onboarded = Future.value(true)));
        if (prefs.getBool('permissions_seen') != true) return PermissionsScreen(onDone: () => setState(() {}));
        return const Dashboard();
      },
    );
  }
}

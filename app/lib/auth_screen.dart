// Email sign in / sign up / password reset. The Gate in main.dart reacts to the new session.
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard.dart' show showPrivacyPolicy;
import 'icons.dart';
import 'main.dart';
import 'mark.dart';
import 'theme.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const _offline = 'Could not reach Levlofit. Check your connection and try again.';

// Google's standard "G" mark, required on sign-in buttons by Google's branding guidelines.
const _googleG =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';

/// Where email links (confirm, reset) return. Must be in Supabase Auth > URL Configuration > Redirect URLs.
/// Mobile scheme is registered in AndroidManifest.xml and ios/Runner/Info.plist.
String get authRedirect => kIsWeb ? Uri.base.origin : 'com.levlofit.app://login-callback';

String _authError(Object e) => switch (e) {
  AuthRetryableFetchException() => _offline, // never show the raw client error or endpoint
  AuthException(:final message) => message,
  _ => _offline,
};

Widget _passwordField({
  required TextEditingController controller,
  required bool hidden,
  required VoidCallback onToggle,
  required bool isNew,
  String? helper,
  ValueChanged<String>? onSubmitted,
}) => TextFormField(
  controller: controller,
  obscureText: hidden,
  textInputAction: TextInputAction.done,
  autofillHints: [isNew ? AutofillHints.newPassword : AutofillHints.password],
  onFieldSubmitted: onSubmitted,
  decoration: InputDecoration(
    helperText: helper,
    suffixIcon: IconButton(
      tooltip: hidden ? 'Show password' : 'Hide password',
      icon: Icon(hidden ? LvIcons.eye : LvIcons.eyeSlash, size: 22),
      onPressed: onToggle,
    ),
  ),
  validator: (v) {
    if (v == null || v.isEmpty) return 'Enter your password';
    if (isNew && v.length < 8) return 'Use at least 8 characters';
    return null;
  },
);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _signUp = false;
  bool _hidden = true;
  bool _busy = false;
  String? _error;
  String? _notice;
  OtpType? _awaiting; // signup or recovery: showing the "enter the code" view
  // Production builds show Google at once (the provider is on there); the settings check below hides it only when
  // the server says it is off, so a slow or failed check never hides it.
  bool _googleEnabled = backendChoice == 'production';

  @override
  void initState() {
    super.initState();
    _checkGoogle();
    // A failed OAuth or email-link redirect lands back here with ?error_description=... (web).
    final failure = Uri.base.queryParameters['error_description'] ?? Uri.base.queryParameters['error'];
    if (kIsWeb && failure != null) _error = 'Sign-in did not finish: $failure. Try again or use email.';
  }

  // Public auth settings endpoint: {"external": {"google": true, ...}}. Hides the button when the provider is off
  // instead of sending people to a raw "provider is not enabled" error page.
  Future<void> _checkGoogle() async {
    try {
      final res = await http.get(Uri.parse('$supabaseUrl/auth/v1/settings'), headers: {'apikey': supabaseKey});
      final on = (jsonDecode(res.body) as Map<String, dynamic>)['external']?['google'] == true;
      if (mounted && on != _googleEnabled) setState(() => _googleEnabled = on);
    } catch (_) {
      // Offline or blocked: keep the build's default.
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Runs [action] with the busy flag and friendly errors.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      _error = _authError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    await _run(() async {
      if (_signUp) {
        final res = await supabase.auth.signUp(email: email, password: _password.text, emailRedirectTo: authRedirect);
        // No session means the project requires email confirmation first.
        if (res.session == null) _awaitCode(OtpType.signup);
        return;
      }
      try {
        await supabase.auth.signInWithPassword(email: email, password: _password.text);
      } on AuthException catch (e) {
        if (e.code != ErrorCode.emailNotConfirmed.code) rethrow;
        // Signed up earlier but never confirmed: send a fresh code.
        await supabase.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: authRedirect);
        _awaitCode(OtpType.signup);
      }
    });
  }

  // Opens Google's consent page; the session arrives via authRedirect and the Gate reacts.
  // Supabase links it to an existing email account when the verified addresses match.
  Future<void> _google() => _run(() => supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: authRedirect));

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter your email above, then tap Forgot password.');
      return;
    }
    await _run(() async {
      await supabase.auth.resetPasswordForEmail(email, redirectTo: authRedirect);
      _awaitCode(OtpType.recovery);
    });
  }

  void _awaitCode(OtpType type) {
    _awaiting = type;
    _code.clear();
  }

  // Success emits signedIn (Gate opens onboarding) or passwordRecovery (Gate opens SetPasswordScreen).
  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the code from the email.');
      return;
    }
    await _run(() => supabase.auth.verifyOTP(type: _awaiting!, email: _email.text.trim(), token: code));
  }

  Future<void> _resend() => _run(() async {
    final email = _email.text.trim();
    if (_awaiting == OtpType.recovery) {
      await supabase.auth.resetPasswordForEmail(email, redirectTo: authRedirect);
    } else {
      await supabase.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: authRedirect);
    }
    _notice = 'New code sent. Codes expire after an hour.';
  });

  @override
  Widget build(BuildContext context) => _AuthFrame(
    child: AnimatedSwitcher(duration: motion(context), child: _awaiting != null ? _codeView(context) : _formView(context)),
  );

  Widget _codeView(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final recovery = _awaiting == OtpType.recovery;
    return AutofillGroup(
      key: const ValueKey('code'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: staggered([
          const Align(alignment: Alignment.centerLeft, child: LevloWordmark()),
          const SizedBox(height: 48),
          Text(recovery ? 'Reset your password' : 'Confirm your email', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            recovery ? 'If ${_email.text.trim()} has a Levlofit account, we sent it a code.' : 'We sent a code to ${_email.text.trim()}.',
            style: t.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 32),
          const FieldLabel('Code'),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: monoNumber(context, size: 22).copyWith(letterSpacing: 6),
            onSubmitted: (_) => _busy ? null : _verify(),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
          if (_notice != null) ...[const SizedBox(height: 12), Text(_notice!, style: t.bodySmall?.copyWith(color: muted))],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(recovery ? 'Continue' : 'Confirm'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : _resend, child: const Text('Send a new code')),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _awaiting = null;
                    _signUp = false;
                    _error = null;
                    _notice = null;
                  }),
            child: const Text('Back to sign in'),
          ),
        ]),
      ),
    );
  }

  Widget _formView(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AutofillGroup(
      key: const ValueKey('form'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: staggered([
            const Align(alignment: Alignment.centerLeft, child: LevloWordmark()),
            const SizedBox(height: 48),
            Text(_signUp ? 'Create your account' : 'Welcome back', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text(
              _signUp ? 'Your coach asks a few questions, then builds your plan.' : 'Sign in to pick up where you left off.',
              style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            if (_googleEnabled) ...[
              OutlinedButton(
                onPressed: _busy ? null : _google,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.string(_googleG, width: 18, height: 18),
                    const SizedBox(width: 12),
                    const Text('Continue with Google'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR USE EMAIL', style: monoLabel(context)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
            ],
            const FieldLabel('Email'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'you@example.com'),
              validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address',
            ),
            const SizedBox(height: 20),
            const FieldLabel('Password'),
            _passwordField(
              controller: _password,
              hidden: _hidden,
              onToggle: () => setState(() => _hidden = !_hidden),
              isNew: _signUp,
              helper: _signUp ? 'At least 8 characters' : null,
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            if (!_signUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
              ),
            if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signUp ? 'Create account' : 'Sign in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _signUp = !_signUp;
                      _error = null;
                    }),
              child: Text(_signUp ? 'I already have an account' : 'New to Levlofit? Create an account'),
            ),
            // DPDP Act notice before consent: the policy is readable before an account exists.
            TextButton(
              onPressed: () => showPrivacyPolicy(context),
              child: Text(_signUp ? 'By creating an account you agree to the privacy policy' : 'Privacy policy', textAlign: TextAlign.center),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Shown when the user opens a password reset link (AuthChangeEvent.passwordRecovery).
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: _password.text));
      widget.onDone();
    } catch (e) {
      _error = _authError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _AuthFrame(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: LevloWordmark()),
            const SizedBox(height: 48),
            Text('Set a new password', style: t.headlineMedium),
            const SizedBox(height: 32),
            const FieldLabel('New password'),
            AutofillGroup(
              child: _passwordField(
                controller: _password,
                hidden: _hidden,
                onToggle: () => setState(() => _hidden = !_hidden),
                isNew: true,
                helper: 'At least 8 characters',
                onSubmitted: (_) => _busy ? null : _save(),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: child),
        ),
      ),
    ),
  );
}

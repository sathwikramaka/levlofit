// Crash log (2026-10-27): unexpected errors from signed-in users go to public.app_errors so they can be fixed in
// updates. Release builds only; never blocks or throws; at most 10 reports per app run, each message once; email
// addresses are masked. The table caps reports per user per day and keeps them 90 days.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_version.dart';

const _maxPerRun = 10;
final _sent = <String>{};

/// The row sent for an error, or null when nothing should be sent.
Map<String, String>? errorRow(Object error, StackTrace? stack, {required TargetPlatform platform, required bool web}) {
  String clean(String s, int max) {
    final masked = s.replaceAll(RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+'), '<email>');
    return masked.length <= max ? masked : masked.substring(0, max);
  }

  final message = clean(error.toString().trim(), 1000);
  if (message.isEmpty) return null;
  return {
    'app_version': appVersion,
    'platform': web ? 'web' : switch (platform) { TargetPlatform.android => 'android', TargetPlatform.iOS => 'ios', _ => 'other' },
    'message': message,
    if (stack != null) 'stack': clean(stack.toString(), 4000),
  };
}

void reportError(Object error, StackTrace? stack) {
  if (!kReleaseMode || _sent.length >= _maxPerRun) return;
  try {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;
    final row = errorRow(error, stack, platform: defaultTargetPlatform, web: kIsWeb);
    if (row == null || !_sent.add(row['message']!)) return;
    unawaited(client.from('app_errors').insert(row).then((_) {}, onError: (_) {}));
  } catch (_) {
    // Reporting must never cause a second error.
  }
}

/// Hooks Flutter and platform errors into [reportError], keeping the default handling.
void installErrorReporting() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    reportError(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack);
    return false; // let the platform handle it as before
  };
}

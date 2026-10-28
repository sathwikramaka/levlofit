// Account actions shared by Profile and onboarding: sign out, and delete the account with everything in it.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'offline_cache.dart';
import 'reminders.dart';

/// Signs out after cancelling this account's reminders on the phone (best effort; sign-out always happens).
Future<void> signOutAndClearReminders() async {
  await Reminders.clearAll().catchError((_) {});
  await clearOfflineRows();
  await supabase.auth.signOut();
}

/// Sign out for the start screen's error state. If the server refuses (the account may no longer exist), the session
/// is still cleared on this phone, so the person always gets back to the sign-in screen.
Future<void> signOutEverywhereOrLocally() async {
  try {
    await signOutAndClearReminders();
  } catch (_) {
    await clearOfflineRows();
    await supabase.auth.signOut(scope: SignOutScope.local).catchError((_) {});
  }
}

/// Asks first, then deletes the account on the server (photos first, then the account and everything linked to it),
/// cancels its reminders on this phone and clears the local session. If the server call fails, nothing local
/// changes and the person can try again.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final danger = Theme.of(context).colorScheme.error;
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text('This permanently deletes your profile, answers, plans, logs and photos. It cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger, foregroundColor: Theme.of(d).colorScheme.onError),
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  // Deleting photos and the account takes a few seconds: block the screen so it cannot be started twice.
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
  );
  var deleted = false;
  try {
    await supabase.functions.invoke('delete-account');
    deleted = true;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not delete your account. Try again.')));
  } finally {
    navigator.pop();
  }
  if (!deleted) return;
  // The account is gone: its reminders must not keep firing on this phone (best effort, never blocks sign-out).
  await Reminders.clearAll().catchError((_) {});
  await clearOfflineRows();
  // The user no longer exists server-side, so only clear the local session.
  await supabase.auth.signOut(scope: SignOutScope.local);
}

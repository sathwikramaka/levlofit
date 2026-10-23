# Step counter: real-phone verification checklist

Prepared 2026-10-17; run 2026-10-17 to 2026-10-22 (results at the end: 15 pass, 1 partly, 1 not possible on this phone, 1 blocked on the device). Needs the owner's approval to install a build with Health Connect enabled and to
grant the health permission on a phone (STEP_COUNTER_PLAN.md, approvals 1, 2 and 5). Use a test account and the
local stack only (`adb reverse tcp:54321 tcp:54321`), never production.

## Build under test

```
LEVLOFIT_HEALTH_CONNECT=true flutter run -d <device> --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=<local key>
```

Before starting, record: phone model, Android version, Health Connect version (Settings > Apps), whether the phone
has its own step source (Google Fit, Samsung Health or the phone's own pedometer) writing steps into Health Connect.

## Checks

Tick each with what was seen. "Card" = the STEPS card at the top of Progress.

| # | Setup | Action | Expected |
|---|---|---|---|
| 1 | Default build (no flag) | Open Progress | Card says step counting is not available; no permission dialog; Health Connect lists no Levlofit entry |
| 2 | Flagged build, Health Connect present | Open Progress | Card shows Connect; nothing requested yet |
| 3 | As 2 | Connect > Not now | Nothing requested; card unchanged |
| 4 | As 2 | Connect > Continue > Allow | Today's steps, average of complete days, 7 days with "–" for days without data; sharing switch off |
| 5 | Compare | Open Health Connect > Data > Steps for the same days | Each day matches (Health Connect's total per local day) |
| 6 | As 4 | Health Connect > App permissions > Levlofit > remove Steps, return to the app | Card says no access; nothing read; Disconnect offered |
| 7 | As 6 | Try again > Allow | Steps shown again |
| 8 | Fresh install | Connect > Continue > Don't allow | Card says no access; Try again and Open Health Connect offered; no data read |
| 9 | As 8 | Deny twice in a row | Android stops showing the dialog; card still offers Open Health Connect, which opens its settings |
| 10 | Android 14+ | Settings > Security and privacy > Privacy > Health Connect > Levlofit > privacy link | The app opens and shows the privacy policy |
| 11 | Android 13 or lower, Health Connect not installed | Open Progress | Card says Health Connect is not on the phone; Get Health Connect opens its Play page |
| 12 | Android 13 or lower, app running | From Health Connect's permission screen, open the privacy rationale | The running app shows the privacy policy |
| 13 | As 4 | Switch on sharing, ask the coach "Am I walking enough?" (local stack, scripted or test provider only) | The coach request carries the 7 totals; a question about food carries none |
| 14 | As 13 | Sign out, sign in as another test account | Card shows Connect; sharing off; the coach request carries no steps |
| 15 | As 4 | Leave the phone 31 minutes on Progress, then Refresh | "may be out of date" shown before refresh, gone after |
| 16 | As 4 | Reboot the phone, open Progress | Steps read again without a new permission dialog |
| 17 | As 4 | Disconnect | Card shows Connect; sharing off; Health Connect still lists the permission (removal is the person's choice there) |
| 18 | Release build with the flag (debug-signed, local only) | Repeat 2 and 4 | Same as debug; the bridge was not removed by shrinking |

## Results, 2026-10-17 (batch 2I)

Phone: OnePlus 13 (CPH2649), Android 16 (SDK 36), Health Connect built into the system (controller module version 17);
Google Fit and the phone itself write steps. Builds: debug, local only, against a throwaway local Supabase stack
(project `levlo_phone_2i`, deleted afterwards) reached through `adb reverse tcp:54321 tcp:54326`; the dev database was
not used. Test accounts were created on the throwaway stack only. The owner approved granting and reading steps in
chat; the deny path, reboot and a debug-signed release build were **not** approved and not run. The permission was
removed again at the end (`READ_STEPS: granted=false`). Step totals seen on screen are not recorded here, and the
screenshots that showed them were deleted.

| # | Result |
|---|---|
| 1 | PASS: default APK declares no health permission; card says step counting is not available in this version |
| 2 | PASS: flagged APK declares only `android.permission.health.READ_STEPS` (granted=false after install); card shows Connect |
| 3 | PASS: Connect > Not now asks nothing; still granted=false |
| 4 | **FAILED first, fixed, then PASS.** Continue crashed the app: on Android 14+ the contract's `REQUEST_PERMISSIONS` intent has no handler for a FlutterActivity (`ActivityNotFoundException`), and the cancelled result then answered the call a second time (`IllegalStateException: Reply already submitted`). Fix in HealthConnectPlugin.kt: Android 14+ uses `Activity.requestPermissions` (Health Connect permissions are runtime permissions there) with a permissions-result listener; a failed start settles the call once. After the fix: Health Connect's own screen listed only Steps; Allow showed today's steps, the average of complete days and 7 days; sharing switch off |
| 5 | PASS: today and the two previous days equal Health Connect's deduplicated daily totals (Fit and the phone both write) |
| 6 | PASS: Health Connect > Levlofit > Remove all (data not deleted): Android restarts the app; card says no access, nothing read, Try again / Open Health Connect / Disconnect |
| 7 | PASS: Try again > Allow shows steps again |
| 8 | PASS (batch 2J, owner-approved): after access was removed, Try again > Continue > Don't allow: card says no access, nothing read, Try again / Open Health Connect / Disconnect; no crash |
| 9 | PASS (2J): Android 16 marked the denial fixed after that one refusal (the earlier removals count), so Try again showed no dialog and the card stayed on no access without a crash; Open Health Connect opened Health Connect. Cleanup: access switched on and straight off in Health Connect so Android asks normally again (final state granted=false, not fixed) |
| 10 | PASS: Health Connect's "Read privacy policy" opens the app's privacy policy (via the permission-usage alias, which shell cannot start: it is protected as intended) |
| 11 | NOT RUNNABLE on this phone (Health Connect is part of Android 16); covered by widget tests only |
| 12 | PASS (Android 16 equivalent): the rationale intent opens the privacy policy both in the running app and on a cold start |
| 13 | PARTLY: sharing switch turns on; the coach request was not exercised (no AI provider on the local stack); payload covered by tests |
| 14 | PASS: sign out, sign in as another test account: card shows Connect, sharing off; the previous account's totals are gone |
| 15 | **BLOCKED on the device** (2026-10-18, owner-approved grant + read): four 31-minute runs were interrupted (lock screen, notification shade, the phone in use); each return to the app correctly triggers a fresh read, so the label could not reach 30 minutes. Found and fixed on the way: nothing re-rendered the card at 30 minutes, so the label could never appear by itself; a one-shot timer now does (steps.dart), with a widget test that fails without it. Access removed afterwards (granted=false) |
| 16 | PASS (2J, owner-approved; the owner unlocked the phone): after one reboot the session was kept and steps were read with no new dialog. Before `adb reverse` was restored the app correctly showed the connection message, not the account message |
| 17 | PASS: Disconnect returns the card to Connect while Android still lists the permission; Connect again reads without a new dialog |
| 18 | PASS (2J, owner-approved): release build with R8, signed with the local Android Debug key (certificate SHA-256 264c8717..., same as ~/.android/debug.keystore; no store key; not distributed); mapping keeps com.levlofit.app.HealthConnectPlugin; Connect > Continue opened Health Connect's dialog, Allow read the totals; no crash |

Also found in 2J: a session whose account no longer exists (here: the throwaway stack was recreated) left the app on 'Could not reach Levlofit' with only Try again; fixed (account message plus a Sign out button) and verified on the phone. A phone call arrived mid-test; input paused until the call ended.

Also seen: leaving the app and coming back keeps the card and reads again without a dialog.

## iOS (HealthKit): not started

The Dart side (app/lib/steps.dart) talks to a platform channel `levlofit/health_connect` with the methods
`availability`, `hasPermission`, `requestPermission`, `readDaily(firstDay, days)` (returns `{yyyy-mm-dd: steps}`),
`openSettings` and `consumeRationaleLaunch`; on iOS there is no bridge, so the card reports "not available". An iOS
bridge needs a Mac with Xcode, the HealthKit capability, `NSHealthShareUsageDescription` in Info.plist, a
HKStatisticsCollectionQuery per local day, and App Store review of the usage text. HealthKit does not report whether
read access was denied, so `hasPermission` can only be "requested before"; the card must treat an empty read as
"no data", which it already does.

# Android validation: status and manual steps

Date: 2026-10-15. Local only: local Supabase stack and the local test account (tools/local-test-user.txt, git-ignored).
Never run the app without the local defines below: app/lib/main.dart defaults to the production project.

## Why this did not run here

> Historical (2026-10-15 morning). Superseded: a OnePlus 13 was connected later that day; see the results below.

- No Android device connected (`adb devices` empty) and no emulator image: the SDK has emulator and platform tools
  but no `system-images` and no AVD. An emulator needs a system image download (about 1 GB via sdkmanager), which
  is a tool install and needs the owner's approval.
- Possible blocker to confirm on the first run: debug builds talk to the local stack over plain `http://`. The app
  has no network security config. If sign-in fails with a cleartext or "Insecure HTTP" error, add a debug-only
  network security config permitting `10.0.2.2` (emulator) or the PC's LAN address (phone). Not added yet.

## Device or emulator

| # | Check | Emulator (API 34+) | Physical phone |
|---|---|---|---|
| 1 | Back gesture/button: Profile > Settings > Glossary, back, back (to Profile, then Home) | Yes | Recommended (gesture navigation, OEM back handling) |
| 2a | Notification permission prompt, allow and deny (Android 13+) | Yes | Yes |
| 2b | Built-in and custom reminders delivered at their time with the Levlofit sound | Yes for basic delivery | **Required** for real delivery: OEM battery savers (Xiaomi, Oppo, Vivo, Samsung) delay or drop inexact alarms; Doze; reboot restore |
| 3 | Create, edit, disable, delete a custom reminder; check the row in the local DB | Yes | Yes |
| 4 | BMI and Reminders at phone width (input, unit switch, messages, no overflow) | Yes | Yes |
| 5 | Exercise library: " · " separator, "No equipment" tag (guide wording kept as written since batch BE; was "No Equipment"), versions on the fallback page, version chip opens the move | Yes | Yes |

## Steps (owner, or Claude once an emulator or phone is available)

1. Start the local stack (`supabase start`) and confirm `supabase status` shows `API_URL=http://127.0.0.1:54321`.
2. Emulator: install a system image and create an AVD (needs approval), or connect a phone with USB debugging
   on the same Wi-Fi as the PC.
3. Backend address: emulator `http://10.0.2.2:54321`; phone `http://<PC LAN IP>:54321` (allow port 54321 on the
   Windows firewall for the private network only).
4. Run, always with both defines (the publishable key is the LOCAL one from `supabase status`):
   ```bash
   flutter run -d <device> --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=<local publishable key>
   ```
   Before signing in, confirm the app is local: the Supabase auth logs (`docker logs supabase_auth_Fitness_App`)
   show the sign-in request. If nothing appears there, stop: the app is not talking to the local stack.
5. Sign in with the local test account. Run checks 1 to 5 in the table.
6. Notifications: in Reminders, turn on, set a training time 2 to 3 minutes ahead, add a custom reminder 2 minutes
   ahead for today; lock the phone and wait. Record received or not, the time it arrived and the sound. Repeat after
   denying permission (expect no notification and no crash) and after a reboot (phone only).
7. Record results in docs/PROGRESS.md. A reminder counts as verified only if the notification was actually received.

## Verified so far without Android (2026-10-15)

- Web build against the local stack (0 production references in the bundle): " · " separator and versions on the
  fallback page seen on screen. The version chip tap and the "No Equipment" tag could not be confirmed on screen:
  the browser pane was hidden, which freezes the Flutter canvas.
- Widget tests at 375 x 812 (test/phone_width_test.dart, 3 tests): BMI units, imperial range message and result
  without overflow; Reminders tab layout; exercise fallback page with "No Equipment", three versions, and the
  version chip opening a new page.
- Not verified: anything on Android, notification permission prompts, notification delivery, the back gesture.

## Results on OnePlus 13 (CPH2649, Android 16), profile build, local stack via USB tunnel (2026-10-15)

| Test | Result |
|---|---|
| 1 Back gesture and arrows: Profile > Settings > Glossary and back | Pass (gesture navigation and on-screen arrows) |
| 2a Instant test notification | Delivered, Levlofit chime |
| 2a Custom reminder, first attempt (13:45, edited to 13:48 at 13:47:24) | 13:45 never delivered: the edit rescheduled it (cancelAll) before Android fired the inexact alarm. 13:48 delivered about 40 s late (phone alarm record) |
| 2a Custom reminder "Test 10min" 14:08, untouched, phone locked | Delivered late, not on time: owner observed about 30 s; phone alarm record shows delivery about 14:09:41 (about 1 min 41 s). Android gave it a 7 min 12 s window (inexact). Next occurrence queued for tomorrow 14:08 with a 1 h window |
| Queued built-in reminders | Inexact, windows 51 min to 1 h: a reminder can legally arrive up to about an hour late |

Open defects at that time (all fixed in batch AL, 2026-10-15: exact timing with inexact fallback, diff-based scheduling without cancelAll, UTC timestamps): inexact scheduling (lateness up to the window), any reminder edit or dashboard load cancels and reschedules all reminders, updated_at sent as local time without offset (stored 5 h 30 min off).

## After the reminder reliability fix (checklist not run as a whole)

> Partly covered: exact timing was granted and delivery was measured (diagnosis below); after the 2026-10-15 update the
> 12 alarms were re-registered as exact (Part A, A13). Not run: steps 2, 5-9 (step 7 and 8 need phone-setting changes).

1. Install over the current build (keeps app data). Reminders screen shows "Exact timing: off" (Android 16 default).
2. With it off: set a custom reminder 10 min ahead, lock, record arrival (expect inexact behaviour as before).
3. Tap "Allow exact timing", enable Levlofit in Alarms & reminders, return: row shows "on"; alarm queue (dumpsys alarm) shows no window for Levlofit alarms.
4. Reminder 10 min ahead, locked: record arrival and the phone's alarm delivery time.
5. Edit one reminder: other Levlofit alarms keep their entries in the alarm queue.
6. With a Levlofit notification on screen, open the dashboard: the notification stays in the shade.
7. Revoke Alarms & reminders while a reminder is pending, reopen the app: row shows "off", reminders re-registered inexact, the reminder still arrives.
8. Reboot with reminders set: they still fire (boot receiver).
9. Repeat Test 2b (notifications off, then on).

### Reminder delay diagnosis (OnePlus 13, exact timing allowed, 2026-10-15)

- The app requests exact alarms: all 12 scheduled reminders are stored by the plugin as `exactAllowWhileIdle` (payload `exact`, Asia/Kolkata), and Android records `exactAllowReason=permission`.
- Android still queues them with a window of up to 1 hour and flags `0x4` (no STANDALONE bit). On this phone every alarm whose exactness comes from the user-granted SCHEDULE_EXACT_ALARM permission is treated this way (16 of 16, Levlofit and other apps), while `policy_permission`, `listener` and allow-listed exact alarms mostly have a zero window. Interpretation: OnePlus policy, not app code.
- Measured: reminder 15:42:00, AlarmManager delivery 15:42:35.4 (about 35 s); owner saw about 45 s, so roughly 10 s more in app start or display, not measurable afterwards (logcat buffers had rolled over).
- OnePlus background control also lists Levlofit (uid 10790) in OAppNetControlService "Hans" and shrinks its memory while in the background.
- Not yet tested: alarm-clock scheduling (setAlarmClock) or a battery exemption; either may change the OnePlus treatment.

## Results, 2026-10-15 21:28-21:40 IST (profile build 8440def1..., OnePlus 13, local stack via USB tunnel)

Part A (no writes) 13/13 PASS and Part B (owner-approved test rows, removed afterwards) 7/7 PASS; details in docs/PROGRESS.md batches BJ-BM. Not run: reminder delivery with this build, permission revoke, reboot.

## Results, 2026-10-16 12:30-12:34 IST (profile build 00ca7cc2..., OnePlus 13, local stack via USB tunnel)

Batch BO, verifying the batch BN fixes: recipe editor keyboard stays closed and Name unfocused after the ingredient
sheet closes (PASS, no data written); Progress stat labels whole on two lines with equal tiles (PASS, no data written);
diary macro line keeps 'Fibre 11.4 g' together (PASS, with 3 owner-approved test rows created and deleted by id,
fingerprints restored). Still not run on any device: reminder delivery with the current build, permission revoke,
reboot, BMI, dashboard customise, daily goal, coach chat.

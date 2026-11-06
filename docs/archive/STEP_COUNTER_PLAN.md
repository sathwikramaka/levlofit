# Area 16: phone step counter, integration plan (2026-10-16, Levlofit-4)

**Status (batch 2F, 2026-10-16): code complete behind a build flag, not enabled, not verified on a phone.**
Device-only storage (no schema change); coach sharing off by default. Default builds declare no health permission
(verified with aapt). `flutter build ... ` with `LEVLOFIT_HEALTH_CONNECT=true` (or `-Plevlofit.healthConnect=true`)
adds READ_STEPS, the rationale screens, the Health Connect client 1.1.0 and minSdk 26. Approvals 1, 2, 4 and 5 below
are still needed before such a build ships; approval 3 is settled by device-only storage unless the owner wants
server-side steps.

## Facts that shape the design (sources checked 2026-10-16)

- Health Connect (developer.android.com, "Get started with Health Connect"): reading steps needs
  `android.permission.health.READ_STEPS`; a rationale activity for `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE`
  (Android 13 and lower) plus an activity-alias for `android.intent.action.VIEW_PERMISSION_USAGE` with category
  `android.intent.category.HEALTH_PERMISSIONS` and permission `android.permission.START_VIEW_PERMISSION_USAGE`
  (Android 14+); that screen must show the same privacy policy as the Play listing. Android 14+ has Health Connect
  built in; Android 13 and lower need the Health Connect app (`com.google.android.apps.healthdata`, Android 9+).
  The SDK needs API 26+. Play Console: declare every Health Connect data type the app reads, matching the manifest.
- **Levlofit today:** minSdk 24, targetSdk 36 (release manifest, batch CB). Adding Health Connect means raising minSdk
  to at least 26 (users on Android 7.x lose updates) and steps only work on Android 9+.
- iOS: app/ios exists but no iOS build has been verified. HealthKit would need the HealthKit capability,
  `NSHealthShareUsageDescription` in Info.plist and App Store review of the usage text.
- Candidate plugin (batch AS): pub.dev `health` 13.3.2, MIT, Health Connect + HealthKit. Not added.

## Proposed design (to build only after approval)

1. **Read path:** daily step totals only (no raw samples, no location), for the last 14 days, read on app start and
   when the user opens Progress; never in the background.
2. **Storage:** new table `daily_steps(user_id, day, steps, source, updated_at)`, primary key (user_id, day), RLS
   "own rows" for select/insert/update/delete, no anon grants, cascade on account deletion; one reviewed migration
   (adds an 8th pending production item). Alternative with no schema change: keep steps on the device only and send
   7-day totals to the coach per request (needs a privacy-text decision).
3. **Coach:** coach-context adds "steps per day, last 7 days" only for activity questions, like the food totals now;
   the privacy paragraph and the data-safety draft (Health and fitness / Fitness info) must say so.
4. **UI:** a Progress card "Steps (from Health Connect)" with an explicit connect button, a rationale screen before the
   system dialog, a clear "not connected" state, and a disconnect action that stops reading and deletes stored rows.
5. **Tests:** unit tests for aggregation and day boundaries (local midnight, DST-free IST but generic code), RLS pgTAP
   for daily_steps, coach-context tests that steps appear only when relevant, widget tests for all states; device
   tests: grant, deny, revoke in Health Connect settings, no Health Connect installed (Android 13), reboot.

## Approvals needed (in order)

| # | Decision | Consequence |
|---|---|---|
| 1 | Add the `health` dependency (network download, MIT) and raise minSdk to 26 | Android 7.x users can no longer update |
| 2 | Request READ_STEPS and ship the rationale screen | Sensitive permission; Play declaration and privacy policy update |
| 3 | Store steps server-side (daily_steps migration) or device-only | Schema change and production item, or a coach-only path |
| 4 | Send step totals to the AI provider | Privacy text and data-safety update; legal review |
| 5 | Device test session on the phone | Needs the phone connected |

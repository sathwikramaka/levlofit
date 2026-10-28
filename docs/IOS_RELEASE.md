# iPhone app: what is ready and what the paid step unlocks

Owner decision 2026-10-28: stay free for now. iPhone users use the web app at https://levlofit.pages.dev/app/
(Safari, Share, Add to Home Screen). A native iPhone app waits until the owner joins the Apple Developer Program.

## Why not now

- iPhones install apps only from the App Store or TestFlight (in India; sideloading is EU-only).
- Both need the Apple Developer Program: USD 99 a year. A free Apple ID only installs on the owner's own iPhone, from a
  Mac, for 7 days.

## Already ready in app/ios

- Bundle ID `com.levlofit.app`, display name Levlofit, app icon set.
- Camera and photo library usage text (progress photos).
- Sign-in return scheme `com.levlofit.app://login-callback` (Info.plist CFBundleURLSchemes).
- Account deletion in the app and a public privacy policy (App Store guideline 5.1.1(v)).

## Steps once the account is paid

1. Apple Developer Program: enrol (individual), USD 99/yr.
2. App Store Connect: create the app with bundle ID `com.levlofit.app`.
3. Build without a Mac: Codemagic free tier (500 macOS minutes a month). Connect the private GitHub repo, Flutter
   workflow, `app/` as the project folder, automatic code signing with an App Store Connect API key,
   `flutter build ipa --release --dart-define=LEVLOFIT_BACKEND=production`, publish to TestFlight.
4. Sign in with Apple (guideline 4.8, the app offers Google sign-in): enable the Apple provider in Supabase Auth,
   add the button next to Google in `app/lib/auth_screen.dart`.
5. Step counts: Health Connect is Android only. Apple Health (HealthKit) is extra work; leave it off for the first
   iPhone release and say so in the listing.
6. Reminders: flutter_local_notifications supports iOS; check the patched copy in app/third_party builds for iOS.
7. Listing: App Privacy answers (reuse docs/PLAY_DATA_SAFETY_DRAFT.md), screenshots, privacy URL
   https://levlofit.pages.dev/privacy, support email levlofit.app@gmail.com.
8. Testing without an iPhone: TestFlight testers and Apple's own review.
9. Website: swap the iPhone steps in website/src/components/download.tsx for the App Store link.

# Device checklist: Levlofit 1.0.8 on a real Android phone

About 15 minutes. Use your own account; everything you log is yours and can be deleted. Write Pass / Fail and a note
(what you saw) in the last column. Screenshots of failures help.

| # | Do | Expect | Result |
|---|---|---|---|
| D1 | Open the old version (1.0.7) if still installed, else skip | An "Update ready" card that cannot be dismissed | |
| D2 | Install 1.0.8 from levlofit.pages.dev (or the update card) | Installs over the old app; your data is still there | |
| D3 | Sign out, then sign in again (Google or email code) | Signed in, dashboard opens | |
| D4 | Sign-up screen (signed out) | "Terms of service" and "Privacy policy" links both open | |
| D5 | Protocol -> change nothing -> Save | "Plan updated"; dashboard opens normally (new plan on generate-plan v29) | |
| D6 | (Only with a second, new test account) at sign-up, year of birth = this year minus 18 | Refused ("For adults 18 to 80 ..."); skip if you have no spare account | |
| D7 | Levlofit AI: ask "Why is my calorie target what it is?" | An answer in a few seconds, no error | |
| D8 | Log today's workout from the dashboard, then Calendar -> today -> "Edit effort and pain" | Saved; editing shows your answers | |
| D9 | Airplane mode on, close and reopen the app | Dashboard opens with a "saved copy" banner; logging says it could not save | |
| D10 | Airplane mode off. Food diary: add a food, change its grams | Totals update | |
| D11 | Daily check-in card: answer two questions, Save; tap again | Summary on the card; the sheet shows your answers | |
| D12 | Progress tab | Weekly report card "LAST WEEK"; weight trend; no error | |
| D13 | Reminders: water on, set 8 am to 8 pm | Saved; no water reminder outside those hours | |
| D14 | Settings -> Send feedback "device test" | "Reached the Levlofit team"; email arrives | |

## Web app (for the CSP decision)

| # | Do | Expect | Result |
|---|---|---|---|
| W1 | On a computer: open levlofit.pages.dev/app/ in Chrome, press F12 -> Console, sign in, open Workout and a move with a GIF | No red "Content Security Policy" messages | |

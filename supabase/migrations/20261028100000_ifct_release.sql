-- Owner decision 2026-10-27 (release step A20): show the IFCT 2017 food values in the app. NIN has not confirmed reuse
-- permission for an app (docs/LICENSING_REQUIREMENTS.md); the owner accepts that for the launch and will recheck it
-- before any paid features. Without this, 20261025100000_food_sources hides every IFCT value from the app and coach.
update public.food_sources set release_allowed = true where source = 'ifct2017';

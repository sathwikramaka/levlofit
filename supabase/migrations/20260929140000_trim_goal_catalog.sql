-- User decision 2026-09-29: keep a focused catalog.
-- Removed: racket sports, team sports, combat sports, athletics, skill and outdoor, dance fitness,
-- obstacle course racing, Olympic weightlifting, and every endurance goal except running.
-- No user_goals referenced these rows when removed (checked before applying).
delete from public.goal_catalog
where category in ('Racket sports', 'Team sports', 'Combat sports', 'Athletics', 'Skill and outdoor')
   or id in ('dance_fitness', 'ocr', 'weightlifting', 'trail_running', 'walking', 'cycling', 'swimming', 'triathlon', 'rowing');

-- Hybrid heading without racing entries.
update public.goal_catalog set category = 'Hybrid fitness' where category = 'Hybrid and racing';

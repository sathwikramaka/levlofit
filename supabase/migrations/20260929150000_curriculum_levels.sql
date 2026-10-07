-- Level 0-5 content per goal, taken from the seed curriculum
-- (Refrence/Self_Coaching_Athlete_Master_Curriculum.pdf). Public read; written only by migrations.
-- The app shows the row matching each plan goal's current level. Goals without rows here get
-- their levels when their cited Handbook chapter is authored (Phase 4).

create table public.curriculum_levels (
  goal text not null references public.goal_catalog (id) on delete cascade,
  level smallint not null check (level between 0 and 5),
  title text not null,
  practice text[] not null,          -- what to train at this level
  advance_when text not null,        -- the curriculum's own pass rule
  coach_recommended boolean not null default false,
  source text not null,              -- chapter reference in the curriculum
  primary key (goal, level)
);

alter table public.curriculum_levels enable row level security;
create policy "curriculum is public" on public.curriculum_levels for select to anon, authenticated using (true);
revoke insert, update, delete on public.curriculum_levels from anon, authenticated;

-- Mobility has no level curriculum in the source (it only appears inside warm-ups).
update public.goal_catalog set curriculum = false where id = 'mobility';

insert into public.curriculum_levels (goal, level, title, practice, advance_when, coach_recommended, source) values
-- Strength: ch. 8
('strength', 0, 'Learn to move', array['Box or bodyweight squat, 3×10 controlled','Hip hinge drill, 3×10 stable','Wall or incline push-up, 3×10 controlled','Scapular pull or inverted row, 3×8 controlled','Dead bug or plank, 30–45 s quality'], 'Pass every pattern standard above with control.', false, 'Curriculum ch. 8'),
('strength', 1, 'Foundation', array['2–3 full-body sessions a week','2–3 sets per exercise','Stop about 2–4 reps short of failure (RIR 2–4)','Master squat, hinge, push, pull, carry and brace'], 'Prescribed work done with repeatable technique, no pain, stable recovery and measurable progress.', false, 'Curriculum ch. 8'),
('strength', 2, 'Intermediate', array['Harder variations or external load','3–4 sets on major movements','Mostly moderate repetitions','Track progression every session'], 'Prescribed work done with repeatable technique, no pain, stable recovery and measurable progress.', false, 'Curriculum ch. 8'),
('strength', 3, 'Strength emphasis', array['Heavier compound work','Lower repetitions on priority lifts','Accessory work for weak links','Longer rest for quality'], 'Prescribed work done with repeatable technique, no pain, stable recovery and measurable progress.', false, 'Curriculum ch. 8'),
('strength', 4, 'Advanced', array['Higher specificity','Planned training blocks','Strength testing','Individual volume and fatigue management'], 'Passes a high-specificity strength test (ch. 31).', false, 'Curriculum ch. 8, 31'),
('strength', 5, 'Performance', array['Peak or maintain strength around another sport','Highly specific loads, speeds and testing'], 'Individual; this stage benefits from a coach.', true, 'Curriculum ch. 8'),
-- Muscle building and aesthetic physique: ch. 9 (same progression)
('bodybuilding', 0, 'Full-body basics', array['2–3 sessions a week','Full-body training','Basic push, pull, legs and core','Learn controlled range of motion'], 'Controlled range on the basic patterns, session after session.', false, 'Curriculum ch. 9'),
('bodybuilding', 1, 'Full-body basics', array['2–3 sessions a week','Full-body training','Basic push, pull, legs and core','Learn controlled range of motion'], 'Controlled range on the basic patterns, session after session.', false, 'Curriculum ch. 9'),
('bodybuilding', 2, 'Build volume', array['Add direct shoulder and arm work','Use roughly 6–15 rep ranges','Build weekly volume gradually','Keep strength movements in the program'], 'Weekly volume rising without recovery problems.', false, 'Curriculum ch. 9'),
('bodybuilding', 3, 'Muscle-specific volume', array['Increase weekly volume per muscle as tolerated (≥10 sets per muscle group a week supports growth, ACSM 2026)','Multiple angles for priority muscles','Track body mass, waist and performance'], 'Progress continues on the tracked measures.', false, 'Curriculum ch. 9'),
('bodybuilding', 4, 'Specialise', array['Specialise lagging muscle groups','Advanced exercise selection','Manage fatigue and exercise overlap'], 'Lagging groups respond without stalling everything else.', false, 'Curriculum ch. 9'),
('bodybuilding', 5, 'Advanced physique', array['Specialisation blocks','Exercise rotation','Detailed nutrition'], 'Highly individual; not simply more sets.', true, 'Curriculum ch. 9'),
('aesthetic', 0, 'Full-body basics', array['2–3 sessions a week','Full-body training','Basic push, pull, legs and core','Learn controlled range of motion'], 'Controlled range on the basic patterns, session after session.', false, 'Curriculum ch. 9'),
('aesthetic', 1, 'Full-body basics', array['2–3 sessions a week','Full-body training','Basic push, pull, legs and core','Learn controlled range of motion'], 'Controlled range on the basic patterns, session after session.', false, 'Curriculum ch. 9'),
('aesthetic', 2, 'Build volume', array['Add direct shoulder and arm work','Use roughly 6–15 rep ranges','Build weekly volume gradually','Keep strength movements in the program'], 'Weekly volume rising without recovery problems.', false, 'Curriculum ch. 9'),
('aesthetic', 3, 'Muscle-specific volume', array['Increase weekly volume per muscle as tolerated (≥10 sets per muscle group a week supports growth, ACSM 2026)','Multiple angles for priority muscles','Track body mass, waist and performance'], 'Progress continues on the tracked measures.', false, 'Curriculum ch. 9'),
('aesthetic', 4, 'Specialise', array['Specialise lagging muscle groups','Advanced exercise selection','Manage fatigue and exercise overlap'], 'Lagging groups respond without stalling everything else.', false, 'Curriculum ch. 9'),
('aesthetic', 5, 'Advanced physique', array['Specialisation blocks','Exercise rotation','Detailed nutrition'], 'Highly individual; not simply more sets.', true, 'Curriculum ch. 9'),
-- Calisthenics: ch. 11-13
('calisthenics', 0, 'Body control', array['Dead bug','Plank and side plank','Scapular push-up','Scapular pull','Dead hang','Controlled squat and lunge'], 'Each drill controlled and repeatable.', false, 'Curriculum ch. 11'),
('calisthenics', 1, 'Basic calisthenics', array['Incline or standard push-up','Inverted row','Assisted chin-up','Support hold','Pike preparation','Hollow hold'], 'Pushing: 3×10 incline push-ups. Pulling: 8–12 controlled scapular pulls and rows.', false, 'Curriculum ch. 11, 12'),
('calisthenics', 2, 'Strict strength', array['Strict push-ups','Chin-ups','Pull-ups','Parallel-bar dip','Pike push-up','Hanging knee raise'], 'Pulling: 5–10 strict pull-ups. Pushing: 3×10–15 floor push-ups.', false, 'Curriculum ch. 11, 12'),
('calisthenics', 3, 'Weighted basics', array['Weighted pull-up','Weighted dip','Decline or deficit push-up','Feet-elevated pike','Hanging leg raise','Single-leg work'], 'Controlled, repeatable and strong enough for the next step; never advance a leverage step you only survive.', false, 'Curriculum ch. 11'),
('calisthenics', 4, 'Advanced skills', array['Handstand','Muscle-up progression','Front-lever progression','Planche progression','Ring strength'], 'Skill milestones held with pain-free shoulders and wrists.', true, 'Curriculum ch. 11, 13'),
('calisthenics', 5, 'Advanced mastery', array['Advanced single-arm and static skills','Structured skill practice','Strength maintenance'], 'Can take years; use specialised coaching where joint or skill risk is high.', true, 'Curriculum ch. 11'),
-- Running: ch. 14-16
('running', 0, 'Re-entry', array['1 min run / 2 min walk × 6–8, comfortable','Walking and mobility for recovery','Short strides only if comfortable'], 'Run/walk sessions feel comfortable.', false, 'Curriculum ch. 14'),
('running', 1, 'Continuous base', array['Extend the run intervals','Keep most running easy','Build toward 15–30 min continuous'], '30 min easy continuous running (ch. 31 foundation indicator).', false, 'Curriculum ch. 14, 31'),
('running', 2, 'Aerobic development', array['2–4 runs a week','Mostly easy','One modestly faster session when ready'], 'Easy runs stay easy while volume grows. Change one variable at a time.', false, 'Curriculum ch. 14, 15'),
('running', 3, 'Threshold and intervals', array['Easy volume stays dominant','Controlled threshold work, e.g. 2–4 × 8 min','Intervals with full recovery, e.g. 4 × 3 min hard'], 'Threshold sessions repeatable without accumulated fatigue.', false, 'Curriculum ch. 14, 15'),
('running', 4, 'Performance', array['Longer aerobic work','Threshold development','VO2 and speed sessions','Race-specific pacing'], 'Race or threshold performance improving on retests.', false, 'Curriculum ch. 14, 31'),
('running', 5, 'Advanced', array['Individual volume and intensity distribution','Race-specific blocks and peaking'], 'Coaching and performance testing become increasingly useful.', true, 'Curriculum ch. 14'),
-- HYROX: ch. 20-22
('hyrox', 0, 'Foundations', array['Walk/run base','Squat, lunge and push-up','Carry technique','Basic burpee movement','General aerobic work'], 'Comfortable with the basic patterns and easy aerobic work.', false, 'Curriculum ch. 21'),
('hyrox', 1, 'Base', array['Continuous easy running','Loaded carries','Step-ups and lunges','Intro ergometer technique'], 'Continuous easy running and loaded carries with good posture.', false, 'Curriculum ch. 21'),
('hyrox', 2, 'Stations', array['1 km run repeats','Moderate station combinations','Sled technique if available','Wall-ball technique'], 'Each station tolerated with repeated running, without technique collapse.', false, 'Curriculum ch. 21'),
('hyrox', 3, 'Race skills', array['Compromised running (running after a station)','Race-pace station intervals','Transition practice','Pacing strategy'], 'Tolerates stations and repeated running before full simulations.', false, 'Curriculum ch. 21, 22'),
('hyrox', 4, 'Simulations', array['Longer simulations','Division-specific loads','Fuel and hydration practice','Weak-station specialisation'], 'Half-race, then full-race simulation completed at sustainable pace.', false, 'Curriculum ch. 21, 22'),
('hyrox', 5, 'Race preparation', array['Exact event standards (check the current official rulebook)','Pacing models','Transition optimisation','Race simulations and taper'], 'Individual load management around the race.', false, 'Curriculum ch. 20, 21');

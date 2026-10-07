-- Goals become data: every recognised sport or fitness activity is a row, read by the app,
-- the plan engine (kind + coach rule) and, later, the Handbook (one chapter per goal).
-- kind drives scheduling only: strength | endurance | hybrid | skill | mobility.
-- curriculum = covered by the seed curriculum; others get cited Handbook chapters as they are authored.
-- coach_led_from_level: contact sparring and advanced gymnastics need a qualified coach from that level.

create table public.goal_catalog (
  id text primary key check (id ~ '^[a-z_]{2,40}$'),
  name text not null check (char_length(name) <= 60),
  category text not null,
  kind text not null check (kind in ('strength', 'endurance', 'hybrid', 'skill', 'mobility')),
  coach_led_from_level smallint check (coach_led_from_level between 1 and 5),
  curriculum boolean not null default false,
  handbook_chapter smallint references public.handbook_chapters (id),
  sort smallint not null
);

alter table public.goal_catalog enable row level security;
create policy "goal catalog is public" on public.goal_catalog for select to anon, authenticated using (true);
revoke insert, update, delete on public.goal_catalog from anon, authenticated;

insert into public.goal_catalog (id, name, category, kind, coach_led_from_level, curriculum, sort) values
  -- Strength and physique
  ('strength', 'Strength', 'Strength and physique', 'strength', null, true, 10),
  ('bodybuilding', 'Muscle building', 'Strength and physique', 'strength', null, true, 11),
  ('aesthetic', 'Aesthetic physique', 'Strength and physique', 'strength', null, true, 12),
  ('calisthenics', 'Calisthenics', 'Strength and physique', 'strength', null, true, 13),
  ('powerlifting', 'Powerlifting', 'Strength and physique', 'strength', null, false, 14),
  ('weightlifting', 'Olympic weightlifting', 'Strength and physique', 'strength', null, false, 15),
  ('strongman', 'Strongman', 'Strength and physique', 'strength', null, false, 16),
  ('kettlebell', 'Kettlebell training', 'Strength and physique', 'strength', null, false, 17),
  ('general', 'General fitness', 'Strength and physique', 'strength', null, true, 18),
  -- Endurance
  ('running', 'Running', 'Endurance', 'endurance', null, true, 20),
  ('trail_running', 'Trail running', 'Endurance', 'endurance', null, false, 21),
  ('walking', 'Walking and hiking', 'Endurance', 'endurance', null, false, 22),
  ('cycling', 'Cycling', 'Endurance', 'endurance', null, false, 23),
  ('swimming', 'Swimming', 'Endurance', 'endurance', null, false, 24),
  ('triathlon', 'Triathlon', 'Endurance', 'endurance', null, false, 25),
  ('rowing', 'Rowing', 'Endurance', 'endurance', null, false, 26),
  -- Hybrid and racing
  ('hyrox', 'HYROX', 'Hybrid and racing', 'hybrid', null, true, 30),
  ('functional_fitness', 'Functional fitness', 'Hybrid and racing', 'hybrid', null, false, 31),
  ('ocr', 'Obstacle course racing', 'Hybrid and racing', 'hybrid', null, false, 32),
  -- Athletics
  ('sprinting', 'Sprinting', 'Athletics', 'skill', null, true, 40),
  ('jumps', 'Jumping events', 'Athletics', 'skill', null, false, 41),
  ('throws', 'Throwing events', 'Athletics', 'skill', null, false, 42),
  -- Combat sports
  ('boxing', 'Boxing', 'Combat sports', 'skill', 4, true, 50),
  ('kickboxing', 'Kickboxing', 'Combat sports', 'skill', 4, false, 51),
  ('muay_thai', 'Muay Thai', 'Combat sports', 'skill', 4, false, 52),
  ('mma', 'Mixed martial arts', 'Combat sports', 'skill', 4, false, 53),
  ('wrestling', 'Wrestling and kushti', 'Combat sports', 'skill', 4, false, 54),
  ('judo', 'Judo', 'Combat sports', 'skill', 4, false, 55),
  ('bjj', 'Brazilian jiu-jitsu', 'Combat sports', 'skill', 4, false, 56),
  ('karate', 'Karate', 'Combat sports', 'skill', 4, false, 57),
  ('taekwondo', 'Taekwondo', 'Combat sports', 'skill', 4, false, 58),
  ('fencing', 'Fencing', 'Combat sports', 'skill', 4, false, 59),
  -- Racket sports
  ('badminton', 'Badminton', 'Racket sports', 'skill', null, false, 60),
  ('tennis', 'Tennis', 'Racket sports', 'skill', null, false, 61),
  ('table_tennis', 'Table tennis', 'Racket sports', 'skill', null, false, 62),
  ('squash', 'Squash', 'Racket sports', 'skill', null, false, 63),
  ('pickleball', 'Pickleball', 'Racket sports', 'skill', null, false, 64),
  -- Team sports
  ('cricket', 'Cricket', 'Team sports', 'skill', null, false, 70),
  ('football', 'Football', 'Team sports', 'skill', null, false, 71),
  ('hockey', 'Field hockey', 'Team sports', 'skill', null, false, 72),
  ('kabaddi', 'Kabaddi', 'Team sports', 'skill', null, false, 73),
  ('kho_kho', 'Kho-kho', 'Team sports', 'skill', null, false, 74),
  ('basketball', 'Basketball', 'Team sports', 'skill', null, false, 75),
  ('volleyball', 'Volleyball', 'Team sports', 'skill', null, false, 76),
  ('handball', 'Handball', 'Team sports', 'skill', null, false, 77),
  ('rugby', 'Rugby', 'Team sports', 'skill', null, false, 78),
  -- Mind and body
  ('mobility', 'Mobility', 'Mind and body', 'mobility', null, true, 80),
  ('yoga', 'Yoga', 'Mind and body', 'mobility', null, false, 81),
  ('pilates', 'Pilates', 'Mind and body', 'mobility', null, false, 82),
  ('dance_fitness', 'Dance fitness', 'Mind and body', 'hybrid', null, false, 83),
  -- Skill and outdoor
  ('climbing', 'Climbing and bouldering', 'Skill and outdoor', 'skill', null, false, 90),
  ('gymnastics', 'Gymnastics', 'Skill and outdoor', 'skill', 4, false, 91),
  ('archery', 'Archery', 'Skill and outdoor', 'skill', null, false, 92),
  ('shooting', 'Shooting', 'Skill and outdoor', 'skill', null, false, 93),
  ('golf', 'Golf', 'Skill and outdoor', 'skill', null, false, 94),
  ('skating', 'Skating', 'Skill and outdoor', 'skill', null, false, 95);

-- user_goals now points at the catalog instead of a hard-coded list.
alter table public.user_goals drop constraint user_goals_goal_check;
alter table public.user_goals add constraint user_goals_goal_fkey foreign key (goal) references public.goal_catalog (id);

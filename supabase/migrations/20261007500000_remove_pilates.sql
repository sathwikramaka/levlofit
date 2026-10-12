-- Pilates removed from the goal list by request (no user had chosen it).
delete from public.user_goals where goal = 'pilates';
delete from public.goal_levels where goal = 'pilates';
delete from public.goal_catalog where id = 'pilates';

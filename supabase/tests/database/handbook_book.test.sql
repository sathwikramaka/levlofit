-- Handbook book: the migration loads every chapter in reading order, readable by the app, with no goal left pointing at it.
begin;
select plan(9);

select is((select count(*)::int from public.handbook_chapters), 69, '69 chapters');
select is((select max(id)::int - min(id)::int + 1 from public.handbook_chapters), 69, 'ids run without gaps');
select is((select slug from public.handbook_chapters where id = 1), 'welcome', 'the book opens with Welcome');
select is((select slug from public.handbook_chapters where id = 69), 'building-a-week', 'the book closes with Building a week');
select is((select count(distinct part)::int from public.handbook_chapters), 6, 'six volumes');
select is((select count(*)::int from public.goal_catalog where handbook_chapter is not null), 0, 'no goal points at a chapter id');
select is(
  (select count(*)::int from public.handbook_chapters where body_md ~ '\*\*|\[\[|\{[a-z0-9-]+\}'),
  0, 'the search text holds no markup');
select ok(
  (select id from public.handbook_chapters where search @@ plainto_tsquery('english', 'rhabdomyolysis') limit 1) is not null,
  'search finds a word inside a chapter');

set local role anon;
select is(
  (select jsonb_array_length(blocks -> 'blocks') > 0 from public.handbook_chapters where slug = 'safety-first'),
  true, 'an anonymous reader gets the chapter blocks');
reset role;

select * from finish();
rollback;

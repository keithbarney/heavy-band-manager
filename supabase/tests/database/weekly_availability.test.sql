begin;
select plan(12);

select has_table('public', 'weekly_availability_rules', 'weekly availability table exists');

insert into auth.users (id, email) values
  ('10000000-0000-0000-0000-000000000001', 'weekly-owner@example.com'),
  ('10000000-0000-0000-0000-000000000002', 'weekly-bandmate@example.com'),
  ('10000000-0000-0000-0000-000000000003', 'weekly-outsider@example.com');
insert into public.bands (id, name, creator_id, leader_id, invite_code) values
  ('10000000-0000-0000-0000-000000000010', 'Weekly Band', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'HBM-AAAA-BBBB-CCCC-DDDD'),
  ('10000000-0000-0000-0000-000000000020', 'Other Band', '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'HBM-EEEE-FFFF-0000-1111');
insert into public.band_members (id, band_id, user_id, name, color) values
  ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000001', 'Owner', '#0A84FF'),
  ('10000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000002', 'Bandmate', '#30D158');

select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select lives_ok($$
  insert into public.weekly_availability_rules (member_id, band_id, day_of_week, start_minutes, end_minutes)
  values ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000010', 1, 1140, 1320)
$$, 'member can save their own weekly hours');
select is((select availability_mode from public.band_members where id = '10000000-0000-0000-0000-000000000011'), 'calendar', 'existing memberships retain calendar mode by default');
select lives_ok($$
  update public.band_members set availability_mode = 'weekly', availability_setup_complete = true
  where id = '10000000-0000-0000-0000-000000000011'
$$, 'member can select manual availability');
select is((select availability_mode from public.band_members where id = '10000000-0000-0000-0000-000000000011'), 'weekly', 'manual selection persists');
select throws_ok($$
  insert into public.weekly_availability_rules (member_id, band_id, day_of_week, start_minutes, end_minutes)
  values ('10000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000010', 2, 1140, 1320)
$$, '42501', null, 'member cannot write a bandmate’s hours');
select throws_ok($$
  insert into public.weekly_availability_rules (member_id, band_id, day_of_week, start_minutes, end_minutes)
  values ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000020', 2, 1140, 1320)
$$, '42501', null, 'member cannot publish their hours into a different band');
select throws_ok($$
  insert into public.weekly_availability_rules (member_id, band_id, day_of_week, start_minutes, end_minutes)
  values ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000010', 3, 1320, 1140)
$$, '23514', null, 'end time must follow start time');

reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.weekly_availability_rules), 1::bigint, 'bandmate can read shared weekly hours');
delete from public.weekly_availability_rules;
select is((select count(*) from public.weekly_availability_rules), 1::bigint, 'bandmate cannot delete someone else’s hours');

reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.weekly_availability_rules), 0::bigint, 'outsider cannot read weekly hours');

reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
delete from public.weekly_availability_rules;
select is((select count(*) from public.weekly_availability_rules), 0::bigint, 'owner can replace or remove their weekly hours');

reset role;
select * from finish();
rollback;

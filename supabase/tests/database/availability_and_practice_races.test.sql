begin;
select plan(30);

select has_column('public', 'band_members', 'availability_revision', 'membership has an availability revision');

insert into auth.users (id, email) values
  ('20000000-0000-0000-0000-000000000001', 'race-owner@example.com'),
  ('20000000-0000-0000-0000-000000000002', 'race-bandmate@example.com');
insert into public.bands (id, name, creator_id, leader_id, invite_code) values
  ('20000000-0000-0000-0000-000000000010', 'Race Band', '20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'HBM-FACE-0000-0000-0000');
insert into public.band_members (id, band_id, user_id, name, color) values
  ('20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', '20000000-0000-0000-0000-000000000001', 'Owner', '#0A84FF'),
  ('20000000-0000-0000-0000-000000000012', '20000000-0000-0000-0000-000000000010', '20000000-0000-0000-0000-000000000002', 'Bandmate', '#30D158');

select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is((select availability_revision from public.band_members where id = '20000000-0000-0000-0000-000000000011'), 0::bigint, 'new memberships begin at revision zero');
select is(public.replace_calendar_availability(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 0,
  '2026-09-15', '2026-09-16', '[{"date":"2026-09-15","start_minutes":1140,"end_minutes":1260}]'
), 1::bigint, 'calendar replacement advances the revision');
select is((select start_minutes from public.availability_slots where member_id = '20000000-0000-0000-0000-000000000011'), 1140::smallint, 'calendar replacement publishes its slot');

select is(public.replace_calendar_availability(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 0,
  '2026-09-15', '2026-09-16', '[{"date":"2026-09-15","start_minutes":1200,"end_minutes":1320}]'
), null::bigint, 'a second auto writer with the stale revision cannot commit');
select is((select start_minutes from public.availability_slots where member_id = '20000000-0000-0000-0000-000000000011'), 1140::smallint, 'stale auto writer leaves the first result intact');

select is(public.set_member_availability_mode(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 1, 'weekly'
), 2::bigint, 'mode switch advances the revision');
select is(public.replace_calendar_availability(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 1,
  '2026-09-15', '2026-09-16', '[]'
), null::bigint, 'an old calendar refresh cannot overwrite a newer manual choice');
select is((select availability_mode from public.band_members where id = '20000000-0000-0000-0000-000000000011'), 'weekly', 'manual mode remains selected');
select is((select count(*) from public.availability_slots where member_id = '20000000-0000-0000-0000-000000000011'), 1::bigint, 'stale mode writer does not delete published slots');

select is(public.update_member_practice_window(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 2, 1080, 1320
), 3::bigint, 'practice window change advances the revision');
select is((select practice_window_start from public.band_members where id = '20000000-0000-0000-0000-000000000011'), 1080::smallint, 'practice window update persists');
select is(public.set_member_availability_mode(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 3, 'calendar'
), 4::bigint, 'member can return to calendar mode');

select throws_ok($$
  select public.replace_calendar_availability(
    '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 4,
    '2026-09-15', '2026-09-16', '[{"date":"2026-09-15","start_minutes":1300,"end_minutes":1200}]'
  )
$$, '22023', 'Calendar availability contains an invalid slot', 'invalid replacement fails before deleting the last good rows');
select is((select availability_revision from public.band_members where id = '20000000-0000-0000-0000-000000000011'), 4::bigint, 'failed replacement does not advance the revision');

select is(public.save_weekly_availability(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 4,
  '2026-09-15', '2026-09-16',
  '[{"day_of_week":2,"start_minutes":1080,"end_minutes":1260}]',
  '[{"date":"2026-09-15","start_minutes":1080,"end_minutes":1260}]'
), 5::bigint, 'weekly rules and projected slots commit together');
select is((select count(*) from public.weekly_availability_rules where member_id = '20000000-0000-0000-0000-000000000011'), 1::bigint, 'weekly rule was replaced');
select is((select availability_mode from public.band_members where id = '20000000-0000-0000-0000-000000000011'), 'weekly', 'weekly transaction updates the mode');

reset role;
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$
  select public.replace_calendar_availability(
    '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 5,
    '2026-09-15', '2026-09-16', '[]'
  )
$$, '42501', 'Availability can only be changed by its member', 'bandmate cannot replace another member availability');

reset role;
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$
  insert into public.scheduled_practices (band_id, date, start_minutes, end_minutes, scheduled_by)
  values ('20000000-0000-0000-0000-000000000010', '2026-09-20', 1140, 1260, '20000000-0000-0000-0000-000000000001')
$$, 'organizer can schedule a unique practice');
select throws_ok($$
  insert into public.scheduled_practices (band_id, date, start_minutes, end_minutes, scheduled_by)
  values ('20000000-0000-0000-0000-000000000010', '2026-09-20', 1140, 1260, '20000000-0000-0000-0000-000000000001')
$$, '23505', null, 'database rejects a duplicate practice window');

select is((select count(*) from public.scheduled_practices where band_id = '20000000-0000-0000-0000-000000000010'), 1::bigint, 'duplicate race leaves one practice');

reset role;
create function public.test_fail_availability_insert() returns trigger
language plpgsql as $$
begin
  raise exception 'Injected insert failure';
end;
$$;
create trigger test_slot_insert_failure
before insert on public.availability_slots
for each row execute function public.test_fail_availability_insert();

set local role authenticated;
select is(public.set_member_availability_mode(
  '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 5, 'calendar'
), 6::bigint, 'prepare automatic transaction failure');
select throws_ok($$
  select public.replace_calendar_availability(
    '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 6,
    '2026-09-15', '2026-09-16', '[{"date":"2026-09-15","start_minutes":1150,"end_minutes":1250}]'
  )
$$, 'P0001', 'Injected insert failure', 'insert failure after deletion is returned');
select is((select start_minutes from public.availability_slots where member_id = '20000000-0000-0000-0000-000000000011'), 1080::smallint, 'insert failure restores the prior slot');
select is((select availability_revision from public.band_members where id = '20000000-0000-0000-0000-000000000011'), 6::bigint, 'insert failure preserves the revision');

reset role;
drop trigger test_slot_insert_failure on public.availability_slots;
create trigger test_rule_insert_failure
before insert on public.weekly_availability_rules
for each row execute function public.test_fail_availability_insert();

set local role authenticated;
select throws_ok($$
  select public.save_weekly_availability(
    '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 6,
    '2026-09-15', '2026-09-16',
    '[{"day_of_week":4,"start_minutes":1140,"end_minutes":1260}]', '[]'
  )
$$, 'P0001', 'Injected insert failure', 'weekly insert failure after deletion is returned');
select is((select day_of_week from public.weekly_availability_rules where member_id = '20000000-0000-0000-0000-000000000011'), 2::smallint, 'weekly failure restores the prior rule');
select is((select availability_mode from public.band_members where id = '20000000-0000-0000-0000-000000000011'), 'calendar', 'weekly failure preserves the selected mode');

reset role;
set local role anon;
select throws_ok($$
  select public.replace_calendar_availability(
    '20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010', 6,
    '2026-09-15', '2026-09-16', '[]'
  )
$$, '42501', null, 'anonymous role cannot execute replacement');

reset role;
select * from finish();
rollback;

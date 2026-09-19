-- Coordinate availability writers through a revisioned, transactional contract.
-- The functions remain SECURITY INVOKER so existing RLS policies authorize every row.
alter table public.band_members
  add column if not exists availability_revision bigint not null default 0
    check (availability_revision >= 0);

grant update (availability_revision) on public.band_members to authenticated;

create or replace function public.replace_calendar_availability(
  p_member_id uuid,
  p_band_id uuid,
  p_expected_revision bigint,
  p_start_date date,
  p_end_date date,
  p_slots jsonb
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_mode text;
  v_revision bigint;
begin
  if p_start_date is null or p_end_date is null or p_start_date > p_end_date
     or p_slots is null or jsonb_typeof(p_slots) <> 'array' then
    raise exception using errcode = '22023', message = 'Invalid calendar availability payload';
  end if;

  select availability_mode, availability_revision
    into v_mode, v_revision
    from public.band_members
   where id = p_member_id
     and band_id = p_band_id
     and user_id = (select auth.uid())
   for update;

  if not found then
    raise exception using errcode = '42501', message = 'Availability can only be changed by its member';
  end if;

  if v_mode <> 'calendar' or v_revision <> p_expected_revision then
    return null;
  end if;

  if exists (
    select 1
      from jsonb_to_recordset(p_slots) as slot(date date, start_minutes integer, end_minutes integer)
     where slot.date is null
        or slot.date < p_start_date
        or slot.date > p_end_date
        or slot.start_minutes is null
        or slot.end_minutes is null
        or slot.start_minutes < 0
        or slot.end_minutes > 1440
        or slot.start_minutes >= slot.end_minutes
  ) then
    raise exception using errcode = '22023', message = 'Calendar availability contains an invalid slot';
  end if;

  delete from public.availability_slots
   where member_id = p_member_id
     and band_id = p_band_id
     and date between p_start_date and p_end_date;

  insert into public.availability_slots
    (member_id, band_id, date, start_minutes, end_minutes, confirmed)
  select p_member_id, p_band_id, slot.date, slot.start_minutes, slot.end_minutes, true
    from jsonb_to_recordset(p_slots) as slot(date date, start_minutes integer, end_minutes integer);

  update public.band_members
     set availability_revision = availability_revision + 1
   where id = p_member_id and band_id = p_band_id
   returning availability_revision into v_revision;

  return v_revision;
end;
$$;

create or replace function public.save_weekly_availability(
  p_member_id uuid,
  p_band_id uuid,
  p_expected_revision bigint,
  p_start_date date,
  p_end_date date,
  p_rules jsonb,
  p_slots jsonb
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_revision bigint;
begin
  if p_start_date is null or p_end_date is null or p_start_date > p_end_date
     or p_rules is null or jsonb_typeof(p_rules) <> 'array'
     or jsonb_array_length(p_rules) = 0
     or p_slots is null or jsonb_typeof(p_slots) <> 'array' then
    raise exception using errcode = '22023', message = 'Invalid weekly availability payload';
  end if;

  select availability_revision
    into v_revision
    from public.band_members
   where id = p_member_id
     and band_id = p_band_id
     and user_id = (select auth.uid())
   for update;

  if not found then
    raise exception using errcode = '42501', message = 'Availability can only be changed by its member';
  end if;

  if v_revision <> p_expected_revision then
    raise exception using errcode = '40001', message = 'Availability changed on another device; reload and try again';
  end if;

  if exists (
    select 1
      from jsonb_to_recordset(p_rules) as rule(day_of_week integer, start_minutes integer, end_minutes integer)
     where rule.day_of_week is null
        or rule.day_of_week not between 0 and 6
        or rule.start_minutes is null
        or rule.end_minutes is null
        or rule.start_minutes < 0
        or rule.end_minutes > 1440
        or rule.start_minutes >= rule.end_minutes
  ) or (
    select count(*) <> count(distinct rule.day_of_week)
      from jsonb_to_recordset(p_rules) as rule(day_of_week integer)
  ) or exists (
    select 1
      from jsonb_to_recordset(p_slots) as slot(date date, start_minutes integer, end_minutes integer)
     where slot.date is null
        or slot.date < p_start_date
        or slot.date > p_end_date
        or slot.start_minutes is null
        or slot.end_minutes is null
        or slot.start_minutes < 0
        or slot.end_minutes > 1440
        or slot.start_minutes >= slot.end_minutes
  ) then
    raise exception using errcode = '22023', message = 'Weekly availability contains an invalid range';
  end if;

  delete from public.weekly_availability_rules
   where member_id = p_member_id and band_id = p_band_id;

  insert into public.weekly_availability_rules
    (member_id, band_id, day_of_week, start_minutes, end_minutes)
  select p_member_id, p_band_id, rule.day_of_week, rule.start_minutes, rule.end_minutes
    from jsonb_to_recordset(p_rules) as rule(day_of_week integer, start_minutes integer, end_minutes integer);

  delete from public.availability_slots
   where member_id = p_member_id
     and band_id = p_band_id
     and date between p_start_date and p_end_date;

  insert into public.availability_slots
    (member_id, band_id, date, start_minutes, end_minutes, confirmed)
  select p_member_id, p_band_id, slot.date, slot.start_minutes, slot.end_minutes, true
    from jsonb_to_recordset(p_slots) as slot(date date, start_minutes integer, end_minutes integer);

  update public.band_members
     set availability_mode = 'weekly',
         availability_setup_complete = true,
         availability_revision = availability_revision + 1
   where id = p_member_id and band_id = p_band_id
   returning availability_revision into v_revision;

  return v_revision;
end;
$$;

create or replace function public.set_member_availability_mode(
  p_member_id uuid,
  p_band_id uuid,
  p_expected_revision bigint,
  p_mode text
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_revision bigint;
begin
  if p_mode not in ('calendar', 'weekly') then
    raise exception using errcode = '22023', message = 'Invalid availability mode';
  end if;

  update public.band_members
     set availability_mode = p_mode,
         availability_setup_complete = true,
         availability_revision = availability_revision + 1
   where id = p_member_id
     and band_id = p_band_id
     and user_id = (select auth.uid())
     and availability_revision = p_expected_revision
   returning availability_revision into v_revision;

  if v_revision is null then
    if not exists (
      select 1 from public.band_members
       where id = p_member_id and band_id = p_band_id and user_id = (select auth.uid())
    ) then
      raise exception using errcode = '42501', message = 'Availability can only be changed by its member';
    end if;
    raise exception using errcode = '40001', message = 'Availability changed on another device; reload and try again';
  end if;

  return v_revision;
end;
$$;

create or replace function public.update_member_practice_window(
  p_member_id uuid,
  p_band_id uuid,
  p_expected_revision bigint,
  p_start_minutes integer,
  p_end_minutes integer
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_revision bigint;
begin
  if p_start_minutes < 0 or p_end_minutes > 1440 or p_start_minutes >= p_end_minutes then
    raise exception using errcode = '22023', message = 'Invalid practice window';
  end if;

  update public.band_members
     set practice_window_start = p_start_minutes,
         practice_window_end = p_end_minutes,
         availability_revision = availability_revision + 1
   where id = p_member_id
     and band_id = p_band_id
     and user_id = (select auth.uid())
     and availability_revision = p_expected_revision
   returning availability_revision into v_revision;

  if v_revision is null then
    if not exists (
      select 1 from public.band_members
       where id = p_member_id and band_id = p_band_id and user_id = (select auth.uid())
    ) then
      raise exception using errcode = '42501', message = 'Availability can only be changed by its member';
    end if;
    raise exception using errcode = '40001', message = 'Availability changed on another device; reload and try again';
  end if;

  return v_revision;
end;
$$;

revoke all on function public.replace_calendar_availability(uuid, uuid, bigint, date, date, jsonb) from public, anon;
revoke all on function public.save_weekly_availability(uuid, uuid, bigint, date, date, jsonb, jsonb) from public, anon;
revoke all on function public.set_member_availability_mode(uuid, uuid, bigint, text) from public, anon;
revoke all on function public.update_member_practice_window(uuid, uuid, bigint, integer, integer) from public, anon;
grant execute on function public.replace_calendar_availability(uuid, uuid, bigint, date, date, jsonb) to authenticated;
grant execute on function public.save_weekly_availability(uuid, uuid, bigint, date, date, jsonb, jsonb) to authenticated;
grant execute on function public.set_member_availability_mode(uuid, uuid, bigint, text) to authenticated;
grant execute on function public.update_member_practice_window(uuid, uuid, bigint, integer, integer) to authenticated;

-- Preserve any existing duplicate practices. The migration stops and reports their
-- count so an organizer can review them before enforcing the race-safe constraint.
do $$
declare
  duplicate_windows bigint;
begin
  select count(*) into duplicate_windows
    from (
      select band_id, date, start_minutes, end_minutes
        from public.scheduled_practices
       group by band_id, date, start_minutes, end_minutes
      having count(*) > 1
    ) duplicates;
  if duplicate_windows > 0 then
    raise exception using
      errcode = 'P0001',
      message = format('Cannot add practice uniqueness constraint: %s duplicate window(s) need organizer review', duplicate_windows),
      hint = 'Run the duplicate-practice preflight query in docs/bug-fixes-20260915.md and resolve each group explicitly.';
  end if;
end;
$$;

alter table public.scheduled_practices
  add constraint scheduled_practices_unique_window
  unique (band_id, date, start_minutes, end_minutes);

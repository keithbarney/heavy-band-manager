-- Reconcile schema changes that existed in the hosted project before its
-- migration history was checked into this repository. The statements are
-- idempotent so the migration is safe on both the hosted project and a fresh
-- local database built from the recovered migration history.

alter table public.bands
  add column if not exists logo_url text;

alter table public.band_members
  add column if not exists avatar_url text;

alter table public.availability_slots
  add column if not exists date date;

do $$
begin
  if exists (select 1 from public.availability_slots where date is null) then
    raise exception using
      errcode = 'P0001',
      message = 'Legacy availability rows need an explicit calendar-date backfill before migration';
  end if;
end;
$$;

alter table public.availability_slots
  alter column date set not null,
  drop column if exists day_of_week;

alter table public.scheduled_practices
  add column if not exists date date;

do $$
begin
  if exists (select 1 from public.scheduled_practices where date is null) then
    raise exception using
      errcode = 'P0001',
      message = 'Legacy practice rows need an explicit calendar-date backfill before migration';
  end if;
end;
$$;

alter table public.scheduled_practices
  alter column date set not null,
  drop column if exists day_of_week;

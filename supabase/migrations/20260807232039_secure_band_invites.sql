-- HVY-216: make invite codes the only way for an authenticated non-member to
-- join a band, and prevent unrelated accounts from enumerating band records.

create table if not exists public.band_join_attempts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  attempt_count integer not null default 0 check (attempt_count >= 0)
);

alter table public.band_join_attempts enable row level security;
revoke all on table public.band_join_attempts from public, anon, authenticated;

-- Keep the hosted rollout backwards-compatible: the new client can be
-- released before enforcement is enabled for older installed clients. The
-- flag is switched on through the reviewed rollout SQL after the App Store
-- update is available.
create table if not exists public.security_flags (
  singleton boolean primary key default true check (singleton),
  invite_enforcement_enabled boolean not null default false
);

insert into public.security_flags (singleton, invite_enforcement_enabled)
values (true, false)
on conflict (singleton) do nothing;

alter table public.security_flags enable row level security;
revoke all on table public.security_flags from public, anon, authenticated;

create or replace function public.invite_enforcement_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select invite_enforcement_enabled
  from public.security_flags
  where singleton;
$$;

revoke execute on function public.invite_enforcement_enabled() from public, anon, authenticated;
grant execute on function public.invite_enforcement_enabled() to authenticated;

-- Rotate legacy 16-bit HBM-XXXX codes before enforcing the stronger format.
-- Grouped hexadecimal stays typeable while providing 64 bits of entropy.
do $$
declare
  v_band_id uuid;
  v_uuid_text text;
  v_token text;
  v_invite_code text;
begin
  for v_band_id in
    select id
    from public.bands
    where invite_code !~ '^HBM-[0-9A-F]{4}(-[0-9A-F]{4}){3}$'
  loop
    loop
      v_uuid_text := replace(gen_random_uuid()::text, '-', '');
      -- UUIDv4 positions 13 and 17 contain fixed version/variant bits.
      v_token := upper(substr(v_uuid_text, 1, 12) || substr(v_uuid_text, 18, 4));
      v_invite_code := 'HBM-'
        || substr(v_token, 1, 4) || '-'
        || substr(v_token, 5, 4) || '-'
        || substr(v_token, 9, 4) || '-'
        || substr(v_token, 13, 4);
      exit when not exists (
        select 1 from public.bands where invite_code = v_invite_code
      );
    end loop;

    update public.bands
    set invite_code = v_invite_code
    where id = v_band_id;
  end loop;
end;
$$;

alter table public.bands
  add constraint bands_invite_code_format
  check (invite_code ~ '^HBM-[0-9A-F]{4}(-[0-9A-F]{4}){3}$');

create or replace function public.is_band_member(p_band_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.band_members
    where band_id = p_band_id
      and user_id = (select auth.uid())
  );
$$;

create or replace function public.is_band_leader(p_band_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.bands
    where id = p_band_id
      and leader_id = (select auth.uid())
  );
$$;

create or replace function public.create_band_with_member(
  p_band_name text,
  p_member_name text,
  p_instrument text default null,
  p_color text default '#0A84FF'
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_band_id uuid;
  v_uuid_text text;
  v_token text;
  v_invite_code text;
  v_band json;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Not authenticated';
  end if;

  if nullif(btrim(p_band_name), '') is null then
    raise exception using errcode = '22023', message = 'Band name is required';
  end if;

  loop
    v_uuid_text := replace(gen_random_uuid()::text, '-', '');
    -- UUIDv4 positions 13 and 17 contain fixed version/variant bits.
    v_token := upper(substr(v_uuid_text, 1, 12) || substr(v_uuid_text, 18, 4));
    v_invite_code := 'HBM-'
      || substr(v_token, 1, 4) || '-'
      || substr(v_token, 5, 4) || '-'
      || substr(v_token, 9, 4) || '-'
      || substr(v_token, 13, 4);
    exit when not exists (
      select 1 from public.bands where invite_code = v_invite_code
    );
  end loop;

  insert into public.bands (name, creator_id, leader_id, invite_code)
  values (btrim(p_band_name), v_user_id, v_user_id, v_invite_code)
  returning id into v_band_id;

  insert into public.band_members (band_id, user_id, name, instrument, color)
  values (
    v_band_id,
    v_user_id,
    coalesce(nullif(btrim(p_member_name), ''), 'Member'),
    nullif(btrim(p_instrument), ''),
    coalesce(nullif(btrim(p_color), ''), '#0A84FF')
  );

  select json_build_object(
    'id', b.id,
    'name', b.name,
    'creator_id', b.creator_id,
    'leader_id', b.leader_id,
    'invite_code', b.invite_code,
    'created_at', b.created_at
  )
  into v_band
  from public.bands b
  where b.id = v_band_id;

  return v_band;
end;
$$;

create or replace function public.join_band_with_invite_code(
  p_invite_code text,
  p_member_name text,
  p_instrument text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_band_id uuid;
  v_attempt_count integer;
  v_member_count integer;
  v_colors constant text[] := array[
    '#0A84FF',
    '#01B8CA',
    '#FC823A',
    '#F83446',
    '#A855F7',
    '#FF2D92'
  ];
  v_color text;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Not authenticated';
  end if;

  insert into public.band_join_attempts (
    user_id,
    window_started_at,
    attempt_count
  )
  values (v_user_id, clock_timestamp(), 1)
  on conflict (user_id) do update
  set
    window_started_at = case
      when excluded.window_started_at - band_join_attempts.window_started_at >= interval '1 minute'
        then excluded.window_started_at
      else band_join_attempts.window_started_at
    end,
    attempt_count = case
      when excluded.window_started_at - band_join_attempts.window_started_at >= interval '1 minute'
        then 1
      else band_join_attempts.attempt_count + 1
    end
  returning attempt_count into v_attempt_count;

  if v_attempt_count > 10 then
    return null;
  end if;

  select b.id
  into v_band_id
  from public.bands b
  where b.invite_code = upper(btrim(coalesce(p_invite_code, '')))
  limit 1;

  if v_band_id is null then
    return null;
  end if;

  -- Serialize joins for this band so simultaneous requests choose distinct
  -- colors based on the committed member count.
  perform 1
  from public.bands
  where id = v_band_id
  for update;

  select count(*)::integer
  into v_member_count
  from public.band_members
  where band_id = v_band_id;

  v_color := v_colors[(v_member_count % array_length(v_colors, 1)) + 1];

  insert into public.band_members (band_id, user_id, name, instrument, color)
  values (
    v_band_id,
    v_user_id,
    coalesce(nullif(btrim(p_member_name), ''), 'Member'),
    nullif(btrim(p_instrument), ''),
    v_color
  )
  on conflict (band_id, user_id) do nothing;

  return v_band_id;
end;
$$;

create or replace function public.get_my_bands()
returns setof public.bands
language sql
stable
security definer
set search_path = ''
as $$
  select b.*
  from public.bands b
  join public.band_members bm on bm.band_id = b.id
  where bm.user_id = (select auth.uid())
  order by b.created_at desc;
$$;

create or replace function public.delete_band(p_band_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.bands
    where id = p_band_id
      and leader_id = v_user_id
  ) then
    raise exception using errcode = '42501', message = 'Only the band leader can delete a band';
  end if;

  delete from public.bands where id = p_band_id;
end;
$$;

create or replace function public.update_member_instrument(
  p_member_id uuid,
  p_instrument text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_member_user_id uuid;
  v_band_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Not authenticated';
  end if;

  select bm.user_id, bm.band_id
  into v_member_user_id, v_band_id
  from public.band_members bm
  where bm.id = p_member_id;

  if v_member_user_id is null
     or (
       v_member_user_id <> v_user_id
       and not exists (
         select 1
         from public.bands b
         where b.id = v_band_id
           and b.leader_id = v_user_id
       )
     ) then
    raise exception using errcode = '42501', message = 'Not authorized to edit this member';
  end if;

  update public.band_members
  set instrument = coalesce(nullif(btrim(p_instrument), ''), '')
  where id = p_member_id;
end;
$$;

revoke execute on function public.is_band_member(uuid) from public, anon;
revoke execute on function public.is_band_leader(uuid) from public, anon;
revoke execute on function public.create_band_with_member(text, text, text, text) from public, anon;
revoke execute on function public.join_band_with_invite_code(text, text, text) from public, anon;
revoke execute on function public.get_my_bands() from public, anon;
revoke execute on function public.delete_band(uuid) from public, anon;
revoke execute on function public.update_member_instrument(uuid, text) from public, anon;

grant execute on function public.is_band_member(uuid) to authenticated;
grant execute on function public.is_band_leader(uuid) to authenticated;
grant execute on function public.create_band_with_member(text, text, text, text) to authenticated;
grant execute on function public.join_band_with_invite_code(text, text, text) to authenticated;
grant execute on function public.get_my_bands() to authenticated;
grant execute on function public.delete_band(uuid) to authenticated;
grant execute on function public.update_member_instrument(uuid, text) to authenticated;

-- Membership identity is established only by the trusted create/join RPCs.
-- Members may edit their profile fields, but cannot move a membership to a
-- different user or band to bypass invite-code validation.
revoke update on table public.band_members from authenticated;
grant update (
  name,
  instrument,
  avatar_url,
  practice_window_start,
  practice_window_end
) on table public.band_members to authenticated;

drop policy if exists "Authenticated can create bands" on public.bands;
drop policy if exists "Authenticated can view bands" on public.bands;
drop policy if exists "Leader can update band" on public.bands;

create policy "Authenticated can create bands"
  on public.bands
  for insert
  to authenticated
  with check (
    not (select public.invite_enforcement_enabled())
    and creator_id = (select auth.uid())
  );

create policy "Members can view their bands"
  on public.bands
  for select
  to authenticated
  using (
    not (select public.invite_enforcement_enabled())
    or (select public.is_band_member(id))
  );

create policy "Leader can update band"
  on public.bands
  for update
  to authenticated
  using (leader_id = (select auth.uid()))
  with check (leader_id = (select auth.uid()));

drop policy if exists "Users can join via band membership" on public.band_members;
drop policy if exists "Members can view band members" on public.band_members;
drop policy if exists "Users can read own memberships" on public.band_members;
drop policy if exists "Members can update own membership" on public.band_members;
drop policy if exists "Leader can remove members" on public.band_members;
drop policy if exists "Users can leave their band" on public.band_members;

create policy "Users can join via band membership"
  on public.band_members
  for insert
  to authenticated
  with check (
    not (select public.invite_enforcement_enabled())
    and user_id = (select auth.uid())
  );

create policy "Members can view band members"
  on public.band_members
  for select
  to authenticated
  using (
    not (select public.invite_enforcement_enabled())
    or (select public.is_band_member(band_id))
  );

create policy "Users can read own memberships"
  on public.band_members
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Members can update own membership"
  on public.band_members
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Leader can remove members"
  on public.band_members
  for delete
  to authenticated
  using ((select public.is_band_leader(band_id)));

create policy "Users can leave their band"
  on public.band_members
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

notify pgrst, 'reload schema';

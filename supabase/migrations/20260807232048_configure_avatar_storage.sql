-- Reproduce the public avatar/logo bucket required by the iOS client and
-- restrict writes to a member's own avatar or a band leader's logo.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update
set public = excluded.public;

create or replace function public.can_manage_avatar_object(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and (
      exists (
        select 1
        from public.band_members bm
        where bm.user_id = (select auth.uid())
          and lower(p_name) = lower(bm.id::text || '.jpg')
      )
      or exists (
        select 1
        from public.bands b
        where b.leader_id = (select auth.uid())
          and lower(p_name) = lower('bands/' || b.id::text || '/logo.jpg')
      )
    );
$$;

revoke execute on function public.can_manage_avatar_object(text) from public, anon;
grant execute on function public.can_manage_avatar_object(text) to authenticated;

drop policy if exists "Public can read avatar objects" on storage.objects;
drop policy if exists "Members can read managed avatar objects" on storage.objects;
drop policy if exists "Members can upload avatar objects" on storage.objects;
drop policy if exists "Members can update avatar objects" on storage.objects;
drop policy if exists "Members can delete avatar objects" on storage.objects;

create policy "Members can read managed avatar objects"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (select public.can_manage_avatar_object(name))
  );

create policy "Members can upload avatar objects"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (select public.can_manage_avatar_object(name))
  );

create policy "Members can update avatar objects"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (select public.can_manage_avatar_object(name))
  )
  with check (
    bucket_id = 'avatars'
    and (select public.can_manage_avatar_object(name))
  );

create policy "Members can delete avatar objects"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (select public.can_manage_avatar_object(name))
  );

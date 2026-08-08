begin;

select plan(38);

insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-000000000001', 'leader@example.com'),
  ('00000000-0000-0000-0000-000000000002', 'invitee@example.com'),
  ('00000000-0000-0000-0000-000000000003', 'attacker@example.com');

insert into public.bands (id, name, creator_id, leader_id, invite_code)
values
  (
    '00000000-0000-0000-0000-000000000010',
    'First Band',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'HBM-1111-1111-1111-1111'
  ),
  (
    '00000000-0000-0000-0000-000000000011',
    'Private Band',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'HBM-2222-2222-2222-2222'
  );

insert into public.band_members (band_id, user_id, name, color)
values
  (
    '00000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000001',
    'Leader',
    '#0A84FF'
  ),
  (
    '00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001',
    'Leader',
    '#0A84FF'
  );

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '00000000-0000-0000-0000-000000000002',
    'role', 'authenticated'
  )::text,
  true
);
set local role authenticated;

select is(
  public.invite_enforcement_enabled(),
  false,
  'fresh migrations keep enforcement disabled for older clients'
);

select is(
  (select count(*) from public.bands),
  2::bigint,
  'older clients can still read bands during the staged rollout'
);

select lives_ok(
  $$
    insert into public.band_members (band_id, user_id, name, color)
    values (
      '00000000-0000-0000-0000-000000000011',
      '00000000-0000-0000-0000-000000000002',
      'Compatibility member',
      '#01B8CA'
    )
  $$,
  'older clients can still use the direct join write during rollout'
);

delete from public.band_members
where band_id = '00000000-0000-0000-0000-000000000011'
  and user_id = '00000000-0000-0000-0000-000000000002';

reset role;

-- CI exercises the enforced post-rollout state. Production flips this flag
-- only after the new App Store client reaches the documented adoption cutoff.
update public.security_flags
set invite_enforcement_enabled = true
where singleton;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '00000000-0000-0000-0000-000000000002',
    'role', 'authenticated'
  )::text,
  true
);
set local role authenticated;

select is(
  (select count(*) from public.bands),
  0::bigint,
  'unrelated authenticated users cannot enumerate bands'
);

select throws_ok(
  $$
    insert into public.band_members (band_id, user_id, name, color)
    values (
      '00000000-0000-0000-0000-000000000010',
      '00000000-0000-0000-0000-000000000002',
      'Invitee',
      '#01B8CA'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "band_members"',
  'direct membership inserts are rejected'
);

select is(
  public.join_band_with_invite_code(
    'HBM-FFFF-FFFF-FFFF-FFFF',
    'Invitee',
    null
  ),
  null::uuid,
  'invalid invite codes return the same empty result as throttled attempts'
);

select lives_ok(
  $$ select public.join_band_with_invite_code('hbm-1111-1111-1111-1111', 'Invitee', 'Guitar') $$,
  'a valid normalized invite code joins the band'
);

select is(
  (select count(*) from public.bands),
  1::bigint,
  'the new member can see only the joined band'
);

select is(
  (
    select count(*)
    from public.band_members
    where user_id = '00000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'joining creates exactly one membership'
);

select is(
  (
    select instrument
    from public.band_members
    where user_id = '00000000-0000-0000-0000-000000000002'
  ),
  'Guitar',
  'joining preserves the supplied instrument'
);

select is(
  (
    select color
    from public.band_members
    where user_id = '00000000-0000-0000-0000-000000000002'
  ),
  '#01B8CA',
  'joining assigns the next member color server-side'
);

select ok(
  public.can_manage_avatar_object(
    (
      select id::text || '.jpg'
      from public.band_members
      where user_id = '00000000-0000-0000-0000-000000000002'
        and band_id = '00000000-0000-0000-0000-000000000010'
    )
  ),
  'a member can manage their own avatar object'
);

select ok(
  not public.can_manage_avatar_object(
    'bands/00000000-0000-0000-0000-000000000011/logo.jpg'
  ),
  'a non-leader cannot manage another band logo'
);

select throws_ok(
  $$
    select public.update_member_instrument(
      (
        select id
        from public.band_members
        where band_id = '00000000-0000-0000-0000-000000000010'
          and user_id = '00000000-0000-0000-0000-000000000001'
      ),
      'Unauthorized'
    )
  $$,
  '42501',
  'Not authorized to edit this member',
  'a non-leader cannot edit another member instrument'
);

select lives_ok(
  $$ select public.join_band_with_invite_code('HBM-1111-1111-1111-1111', 'Invitee', 'Guitar') $$,
  'joining the same band again is idempotent'
);

select is(
  (
    select count(*)
    from public.band_members
    where user_id = '00000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'a duplicate join does not create another membership'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.band_members',
    'band_id',
    'UPDATE'
  ),
  'authenticated users cannot move a membership to another band'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.band_members',
    'name',
    'UPDATE'
  ),
  'authenticated users can still edit permitted member profile fields'
);

select is(
  (
    select count(*)
    from public.bands
    where id = '00000000-0000-0000-0000-000000000011'
  ),
  0::bigint,
  'other bands remain hidden after joining one band'
);

select throws_ok(
  $$
    insert into public.bands (name, creator_id, leader_id, invite_code)
    values (
      'Bypass Band',
      '00000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      'HBM-3333-3333-3333-3333'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "bands"',
  'direct band creation is rejected'
);

select lives_ok(
  $$
    select public.create_band_with_member(
      'Invitee Band',
      'Invitee',
      'Guitar',
      '#0A84FF'
    )
  $$,
  'the authenticated create-band RPC still works'
);

select is(
  (select count(*) from public.bands),
  2::bigint,
  'the user can see the joined band and newly created band only'
);

select ok(
  (
    select invite_code ~ '^HBM-[0-9A-F]{4}(-[0-9A-F]{4}){3}$'
    from public.bands
    where name = 'Invitee Band'
  ),
  'new bands receive a 64-bit grouped invite code'
);

select is(
  (
    select count(*)
    from public.band_members
    where user_id = '00000000-0000-0000-0000-000000000002'
  ),
  2::bigint,
  'the create-band RPC creates the leader membership atomically'
);

reset role;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '00000000-0000-0000-0000-000000000001',
    'role', 'authenticated'
  )::text,
  true
);
set local role authenticated;

select ok(
  public.can_manage_avatar_object(
    'bands/00000000-0000-0000-0000-000000000010/logo.jpg'
  ),
  'a leader can manage their band logo object'
);

select lives_ok(
  $$
    select public.update_member_instrument(
      (
        select id
        from public.band_members
        where band_id = '00000000-0000-0000-0000-000000000010'
          and user_id = '00000000-0000-0000-0000-000000000002'
      ),
      'Bass'
    )
  $$,
  'a leader can edit a member instrument through the narrow RPC'
);

select is(
  (
    select instrument
    from public.band_members
    where band_id = '00000000-0000-0000-0000-000000000010'
      and user_id = '00000000-0000-0000-0000-000000000002'
  ),
  'Bass',
  'the leader instrument edit is persisted'
);

reset role;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '00000000-0000-0000-0000-000000000003',
    'role', 'authenticated'
  )::text,
  true
);
set local role authenticated;

select lives_ok(
  $$
    do $block$
    begin
      for attempt in 1..10 loop
        perform public.join_band_with_invite_code(
          'HBM-FFFF-FFFF-FFFF-FFFF',
          'Attacker',
          null
        );
      end loop;
    end;
    $block$
  $$,
  'the rate-limit window records ten invite attempts'
);

select is(
  public.join_band_with_invite_code(
    'HBM-1111-1111-1111-1111',
    'Attacker',
    null
  ),
  null::uuid,
  'the rate limit rejects even a valid code after too many attempts'
);

select is(
  (
    select count(*)
    from public.band_members
    where user_id = '00000000-0000-0000-0000-000000000003'
  ),
  0::bigint,
  'a rate-limited account is not added to the band'
);

reset role;

select ok(
  not has_function_privilege(
    'anon',
    'public.join_band_with_invite_code(text,text,text)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the join function'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.join_band_with_invite_code(text,text,text)',
    'EXECUTE'
  ),
  'authenticated users can execute the join function'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.can_manage_avatar_object(text)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the storage authorization helper'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.can_manage_avatar_object(text)',
    'EXECUTE'
  ),
  'authenticated users can execute the storage authorization helper'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.band_join_attempts',
    'SELECT'
  ),
  'authenticated users cannot inspect invite-attempt records'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.bands'::regclass
      and conname = 'bands_invite_code_format'
  ),
  'the database rejects legacy weak invite-code formats'
);

select ok(
  exists (
    select 1
    from storage.buckets
    where id = 'avatars'
      and public
  ),
  'the public avatars bucket is reproducible from migrations'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'Members can read managed avatar objects',
        'Members can upload avatar objects',
        'Members can update avatar objects',
        'Members can delete avatar objects'
      )
  ),
  4::bigint,
  'avatar storage read and write policies are installed'
);

select * from finish();

rollback;

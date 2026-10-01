-- Adapted from TV & Movie's guarded registration/APNs pattern. Durable jobs
-- capture committed changes; APNs failures never roll back a practice save.
create table public.practice_push_devices (
    installation_id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    token text not null check (token ~ '^[0-9a-f]{64,}$' and char_length(token) <= 512),
    bundle_id text not null check (bundle_id in ('com.keithbarney.heavybandmanager', 'com.keithbarney.heavybandmanager.local')),
    environment text not null check (environment in ('sandbox', 'production')),
    updated_at timestamptz not null default now(),
    unique (token, bundle_id, environment)
);
create index practice_push_devices_user_idx on public.practice_push_devices(user_id);
alter table public.practice_push_devices enable row level security;
revoke all on public.practice_push_devices from anon, authenticated;
grant all on public.practice_push_devices to service_role;

create table public.practice_push_jobs (
    id uuid primary key default gen_random_uuid(),
    installation_id uuid not null references public.practice_push_devices(installation_id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    band_id uuid not null,
    payload jsonb not null,
    created_at timestamptz not null default now(),
    next_attempt_at timestamptz not null default now(),
    attempts integer not null default 0,
    lease_id uuid,
    completed_at timestamptz,
    last_error text
);
create index practice_push_jobs_pending_idx on public.practice_push_jobs(next_attempt_at) where completed_at is null;
alter table public.practice_push_jobs enable row level security;
revoke all on public.practice_push_jobs from anon, authenticated;
grant all on public.practice_push_jobs to service_role;

create or replace function public.register_practice_push_device(
    p_installation_id uuid, p_token text, p_bundle_id text, p_environment text
) returns void language plpgsql security definer set search_path = '' as $$
begin
    if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
    if p_installation_id is null or p_token is null or p_token !~ '^[0-9a-fA-F]{64,}$' or char_length(p_token) > 512
       or p_bundle_id is null or p_bundle_id not in ('com.keithbarney.heavybandmanager', 'com.keithbarney.heavybandmanager.local')
       or p_environment is null or p_environment not in ('sandbox', 'production')
       or (p_bundle_id = 'com.keithbarney.heavybandmanager' and p_environment <> 'production')
       or (p_bundle_id = 'com.keithbarney.heavybandmanager.local' and p_environment <> 'sandbox') then
        raise exception 'invalid_request' using errcode = '22023';
    end if;
    -- Token rotation/account changes must invalidate queued private destinations.
    delete from public.practice_push_devices where
        (installation_id = p_installation_id and (user_id <> auth.uid() or token <> lower(p_token)))
        or (token = lower(p_token) and bundle_id = p_bundle_id and environment = p_environment
            and installation_id <> p_installation_id);
    insert into public.practice_push_devices(installation_id, user_id, token, bundle_id, environment)
    values (p_installation_id, auth.uid(), lower(p_token), p_bundle_id, p_environment)
    on conflict (installation_id) do update set user_id = excluded.user_id,
        token = excluded.token, bundle_id = excluded.bundle_id,
        environment = excluded.environment, updated_at = now();
end;
$$;

create or replace function public.unregister_practice_push_device(p_installation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
    if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
    delete from public.practice_push_devices where installation_id = p_installation_id and user_id = auth.uid();
end;
$$;
revoke all on function public.register_practice_push_device(uuid,text,text,text),
    public.unregister_practice_push_device(uuid) from public, anon, service_role;
grant execute on function public.register_practice_push_device(uuid,text,text,text),
    public.unregister_practice_push_device(uuid) to authenticated;

create or replace function public.enqueue_practice_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
    practice public.scheduled_practices;
    band_name text;
    kind text;
    title text;
    body text;
begin
    if tg_op = 'DELETE' then practice := old; else practice := new; end if;
    if tg_op = 'UPDATE' then
        if (new.date, new.start_minutes, new.end_minutes, coalesce(new.location,''))
            is not distinct from (old.date, old.start_minutes, old.end_minutes, coalesce(old.location,'')) then
            return new; -- Ignore event-ID bookkeeping and unchanged saves.
        end if;
        if coalesce(new.location,'') is distinct from coalesce(old.location,'') then
            kind := 'practice_location_changed'; title := 'Practice Location Changed';
            body := 'The practice location was changed.';
            if (new.date,new.start_minutes,new.end_minutes) is distinct from (old.date,old.start_minutes,old.end_minutes) then
                body := 'The practice location and time were changed.';
            end if;
        else
            kind := 'practice_updated'; title := 'Practice Updated'; body := 'The practice time was changed.';
        end if;
    elsif tg_op = 'INSERT' then
        kind := 'practice_scheduled'; title := 'Practice Scheduled'; body := 'A practice was scheduled.';
    else
        kind := 'practice_cancelled'; title := 'Practice Cancelled'; body := 'The practice was cancelled.';
    end if;
    select name into band_name from public.bands where id = practice.band_id;
    -- Band deletion removes membership and suppresses notifications to former members.
    if band_name is null then return practice; end if;
    insert into public.practice_push_jobs(installation_id,user_id,band_id,payload)
    select device.installation_id, device.user_id, practice.band_id,
        jsonb_build_object('title', title, 'body', band_name || ': ' || body || ' (' || practice.date::text || ')',
            'notification_type',kind,'band_id',practice.band_id,'practice_id',practice.id)
    from public.practice_push_devices device
    where exists (select 1 from public.band_members member
        where member.band_id = practice.band_id and member.user_id = device.user_id);
    return practice;
end;
$$;
revoke all on function public.enqueue_practice_push() from public, anon, authenticated;
create trigger practice_push_changed after insert or update or delete on public.scheduled_practices
    for each row execute function public.enqueue_practice_push();

-- A lease prevents concurrent webhook/cron workers from claiming the same job.
create or replace function public.claim_practice_push_jobs()
returns table(id uuid, lease_id uuid, installation_id uuid, user_id uuid, band_id uuid,
    payload jsonb, token text, bundle_id text, environment text)
language sql security definer set search_path = '' as $$
    with candidates as (
        select job.id from public.practice_push_jobs job
        where job.completed_at is null and job.next_attempt_at <= now()
          and job.attempts < 8 and job.created_at > now() - interval '6 hours'
        order by job.created_at, job.id limit 10 for update skip locked
    ), claimed as (
        update public.practice_push_jobs job set attempts = job.attempts + 1,
            next_attempt_at = now() + interval '2 minutes', lease_id = gen_random_uuid()
        from candidates where job.id = candidates.id returning job.*
    )
    select job.id,job.lease_id,job.installation_id,job.user_id,job.band_id,job.payload,
        device.token,device.bundle_id,device.environment
    from claimed job join public.practice_push_devices device
        on device.installation_id = job.installation_id and device.user_id = job.user_id;
$$;

create or replace function public.finish_practice_push_job(p_id uuid,p_lease_id uuid,p_error text,p_terminal boolean)
returns void language sql security definer set search_path = '' as $$
    update public.practice_push_jobs set completed_at = case when p_terminal then now() else null end,
        last_error = left(p_error,120),
        next_attempt_at = now() + make_interval(secs => least(3600, (power(2,attempts)::integer * 15))),
        lease_id = null
    where id = p_id and lease_id = p_lease_id;
$$;
revoke all on function public.claim_practice_push_jobs(), public.finish_practice_push_job(uuid,uuid,text,boolean)
    from public, anon, authenticated;
grant execute on function public.claim_practice_push_jobs(), public.finish_practice_push_job(uuid,uuid,text,boolean)
    to service_role;

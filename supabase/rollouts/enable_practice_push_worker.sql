-- Apply only after deploying practice-push and setting Edge Function secrets.
-- Store these two values in Supabase Vault using the Dashboard (never in Git):
-- practice_push_project_url = the project's https://<ref>.supabase.co URL
-- practice_push_worker_secret = the same random PRACTICE_PUSH_WORKER_SECRET
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
    if not exists (select 1 from vault.decrypted_secrets where name = 'practice_push_project_url')
       or not exists (select 1 from vault.decrypted_secrets where name = 'practice_push_worker_secret') then
        raise exception 'Configure practice push Vault secrets before enabling delivery';
    end if;
end;
$$;

create or replace function public.wake_practice_push_worker()
returns void language plpgsql security definer set search_path = '' as $$
declare project_url text; worker_secret text;
begin
    select decrypted_secret into project_url from vault.decrypted_secrets where name = 'practice_push_project_url';
    select decrypted_secret into worker_secret from vault.decrypted_secrets where name = 'practice_push_worker_secret';
    if project_url is null or worker_secret is null then return; end if;
    perform net.http_post(
        url := project_url || '/functions/v1/practice-push',
        headers := jsonb_build_object('content-type','application/json','x-practice-push-secret',worker_secret),
        body := '{}'::jsonb, timeout_milliseconds := 60000
    );
end;
$$;
revoke all on function public.wake_practice_push_worker() from public,anon,authenticated;
grant execute on function public.wake_practice_push_worker() to service_role;

create or replace function public.wake_practice_push_after_enqueue()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    perform public.wake_practice_push_worker();
    return null;
exception when others then
    -- Scheduling failure must not roll back the practice; Cron retries the outbox.
    return null;
end;
$$;
revoke all on function public.wake_practice_push_after_enqueue() from public,anon,authenticated;
drop trigger if exists practice_push_wake on public.practice_push_jobs;
create trigger practice_push_wake after insert on public.practice_push_jobs
    for each statement execute function public.wake_practice_push_after_enqueue();

-- Immediate wakeup plus a one-minute safety net for transient delivery failures.
select cron.schedule('practice-push-retry', '* * * * *', 'select public.wake_practice_push_worker()');
select cron.schedule('practice-push-retention', '17 3 * * *',
    $cron$delete from public.practice_push_jobs where created_at < now() - interval '7 days'$cron$);

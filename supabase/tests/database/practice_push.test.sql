begin;
select no_plan();

insert into auth.users(id,email) values
 ('30000000-0000-4000-8000-000000000001','push-leader@example.com'),
 ('30000000-0000-4000-8000-000000000002','push-member@example.com');
insert into public.bands(id,name,creator_id,leader_id,invite_code) values
 ('30000000-0000-4000-8000-000000000010','Push Test Band','30000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001','HBM-FACE-1111-2222-3333');
insert into public.band_members(id,band_id,user_id,name,color) values
 ('30000000-0000-4000-8000-000000000011','30000000-0000-4000-8000-000000000010','30000000-0000-4000-8000-000000000001','Leader','#0A84FF'),
 ('30000000-0000-4000-8000-000000000012','30000000-0000-4000-8000-000000000010','30000000-0000-4000-8000-000000000002','Member','#30D158');

select ok(not has_table_privilege('authenticated','public.practice_push_devices','SELECT'),'clients cannot read device tokens');
select ok(not has_table_privilege('authenticated','public.practice_push_jobs','INSERT'),'clients cannot forge notification jobs');
select ok(not has_function_privilege('authenticated','public.claim_practice_push_jobs()','EXECUTE'),'clients cannot claim jobs');

select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select public.register_practice_push_device('30000000-0000-4000-8000-000000000021',repeat('a',64),
 'com.keithbarney.heavybandmanager.local','sandbox');
select throws_ok($$select public.register_practice_push_device('30000000-0000-4000-8000-000000000024',repeat('d',64),
 'com.someone.else','sandbox')$$,'22023','invalid_request','rejects another app topic');
select throws_ok($$select public.register_practice_push_device('30000000-0000-4000-8000-000000000024',repeat('d',64),
 'com.keithbarney.heavybandmanager','sandbox')$$,'22023','invalid_request','rejects wrong APNs environment');
reset role;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
select public.register_practice_push_device('30000000-0000-4000-8000-000000000022',repeat('b',64),
 'com.keithbarney.heavybandmanager','production');
select public.unregister_practice_push_device('30000000-0000-4000-8000-000000000021');
reset role;
select is((select count(*) from public.practice_push_devices),2::bigint,'another account cannot unregister a device');

insert into public.scheduled_practices(id,band_id,date,start_minutes,end_minutes,location,scheduled_by) values
 ('30000000-0000-4000-8000-000000000030','30000000-0000-4000-8000-000000000010','2026-10-02',1140,1260,'Old test location','30000000-0000-4000-8000-000000000001');
select is((select count(*) from public.practice_push_jobs),2::bigint,'schedule notifies all registered members including leader');
select is((select count(*) from public.practice_push_jobs where payload->>'notification_type'='practice_scheduled'),2::bigint,'schedule message kind');
update public.scheduled_practices set location=location,calendar_event_id='local-bookkeeping' where id='30000000-0000-4000-8000-000000000030';
select is((select count(*) from public.practice_push_jobs),2::bigint,'no-op and calendar bookkeeping do not notify');
update public.scheduled_practices set start_minutes=1080 where id='30000000-0000-4000-8000-000000000030';
select is((select count(*) from public.practice_push_jobs where payload->>'notification_type'='practice_updated'),2::bigint,'time change notifies all members');
update public.scheduled_practices set location='New test location' where id='30000000-0000-4000-8000-000000000030';
select is((select count(*) from public.practice_push_jobs where payload->>'title'='Practice Location Changed'),2::bigint,'location change uses specific title');
update public.scheduled_practices set location='' where id='30000000-0000-4000-8000-000000000030';
select is((select count(*) from public.practice_push_jobs where payload->>'notification_type'='practice_location_changed'),4::bigint,'clearing a location notifies too');
update public.bands set default_practice_location='Future practices only' where id='30000000-0000-4000-8000-000000000010';
select is((select count(*) from public.practice_push_jobs),8::bigint,'default-only edits do not claim an existing practice changed');
delete from public.scheduled_practices where id='30000000-0000-4000-8000-000000000030';
select is((select count(*) from public.practice_push_jobs where payload->>'notification_type'='practice_cancelled'),2::bigint,'cancellation keeps route IDs after deletion');

create temporary table claimed as select * from public.claim_practice_push_jobs();
select is((select count(*) from claimed),10::bigint,'worker claims pending jobs');
select is((select count(*) from public.claim_practice_push_jobs()),0::bigint,'leased jobs cannot be claimed twice');
select public.finish_practice_push_job((select id from claimed limit 1),gen_random_uuid(),null,true);
select is((select count(*) from public.practice_push_jobs where completed_at is not null),0::bigint,'stale worker cannot complete a job');
select public.finish_practice_push_job(id,lease_id,null,true) from claimed limit 1;
select is((select count(*) from public.practice_push_jobs where completed_at is not null),1::bigint,'current lease can complete a job');

select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
set local role authenticated;
select public.register_practice_push_device('30000000-0000-4000-8000-000000000021',repeat('a',64),
 'com.keithbarney.heavybandmanager.local','sandbox');
reset role;
select is((select user_id from public.practice_push_devices where installation_id='30000000-0000-4000-8000-000000000021'),
 '30000000-0000-4000-8000-000000000002'::uuid,'account switch reassigns device');
select is((select count(*) from public.practice_push_jobs where user_id='30000000-0000-4000-8000-000000000001'),
 0::bigint,'account switch removes former account jobs');

select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.unregister_practice_push_device('30000000-0000-4000-8000-000000000021')$$,
 '28000','not_authenticated','unauthenticated registration cleanup is rejected');
reset role;
select * from finish();
rollback;

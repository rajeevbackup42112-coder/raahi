-- Raahi Learning V1.3 — derived notification transition wiring
-- Notifications remain non-authoritative. They are best-effort derived records and may never
-- roll back a successful domain transition. No sponsored/ad-viewer/promotional push is added.

create or replace function app_private.enqueue_notification_safely(
  p_recipient_account_id uuid,
  p_context_learner_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
begin
  perform app_private.enqueue_notification(
    p_recipient_account_id,p_context_learner_id,p_notification_type,p_source_type,p_source_id,
    p_title,p_body,coalesce(p_payload,'{}'::jsonb)
  );
  return true;
exception when others then
  -- Notifications are a derived convenience surface. A failure here must never own/rollback
  -- Enquiry, Class, Activity or Test state.
  return false;
end;
$$;

create or replace function app_private.notify_learner_accounts(
  p_learner_id uuid,
  p_exclude_account_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare v_rec record; v_count integer:=0;
begin
  for v_rec in
    select distinct ala.account_id
    from public.account_learner_access ala
    join public.accounts a on a.id=ala.account_id
    where ala.learner_id=p_learner_id
      and ala.status='active'
      and a.lifecycle_status<>'closed'
      and ala.account_id is distinct from p_exclude_account_id
  loop
    if app_private.enqueue_notification_safely(
      v_rec.account_id,p_learner_id,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
    ) then v_count:=v_count+1; end if;
  end loop;
  return v_count;
end;
$$;

create or replace function app_private.notify_learner_decision_account(
  p_learner_id uuid,
  p_exclude_account_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare v_account uuid;
begin
  v_account:=app_private.learner_decision_account_id(p_learner_id);
  if v_account is null or v_account is not distinct from p_exclude_account_id then return 0; end if;
  if app_private.enqueue_notification_safely(
    v_account,p_learner_id,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
  ) then return 1; end if;
  return 0;
end;
$$;

create or replace function app_private.notify_enquiry_provider_accounts(
  p_enquiry_id uuid,
  p_exclude_account_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare v_provider_account uuid; v_provider_org uuid; v_rec record; v_count integer:=0;
begin
  select provider_account_id,provider_organization_id into v_provider_account,v_provider_org
  from public.enquiries where id=p_enquiry_id;
  if not found then return 0; end if;

  if v_provider_account is not null then
    if v_provider_account is distinct from p_exclude_account_id
       and exists(select 1 from public.accounts a where a.id=v_provider_account and a.lifecycle_status<>'closed')
       and app_private.enqueue_notification_safely(
         v_provider_account,null,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
       )
    then return 1; end if;
    return 0;
  end if;

  for v_rec in
    select distinct om.account_id
    from public.organization_members om
    join public.organization_member_capabilities c on c.organization_member_id=om.id
    join public.accounts a on a.id=om.account_id
    join public.organizations o on o.id=om.organization_id
    where om.organization_id=v_provider_org
      and om.status='active'
      and c.capability_code='manage_teaching_options'
      and a.lifecycle_status<>'closed'
      and o.status<>'closed'
      and om.account_id is distinct from p_exclude_account_id
  loop
    if app_private.enqueue_notification_safely(
      v_rec.account_id,null,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
    ) then v_count:=v_count+1; end if;
  end loop;
  return v_count;
end;
$$;

create or replace function app_private.notify_class_provider_accounts(
  p_class_id uuid,
  p_exclude_account_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare v_teacher uuid; v_org uuid; v_rec record; v_count integer:=0;
begin
  select responsible_teacher_account_id,organization_id into v_teacher,v_org
  from public.classes where id=p_class_id;
  if not found then return 0; end if;

  if v_org is null then
    if v_teacher is distinct from p_exclude_account_id
       and exists(select 1 from public.accounts a where a.id=v_teacher and a.lifecycle_status<>'closed')
       and app_private.enqueue_notification_safely(
         v_teacher,null,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
       )
    then return 1; end if;
    return 0;
  end if;

  for v_rec in
    select distinct om.account_id
    from public.organization_members om
    join public.organization_member_capabilities c on c.organization_member_id=om.id
    join public.accounts a on a.id=om.account_id
    join public.organizations o on o.id=om.organization_id
    where om.organization_id=v_org
      and om.status='active'
      and c.capability_code='manage_classes'
      and a.lifecycle_status<>'closed'
      and o.status<>'closed'
      and om.account_id is distinct from p_exclude_account_id
  loop
    if app_private.enqueue_notification_safely(
      v_rec.account_id,null,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
    ) then v_count:=v_count+1; end if;
  end loop;
  return v_count;
end;
$$;

create or replace function app_private.notify_active_class_learner_accounts(
  p_class_id uuid,
  p_exclude_account_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare v_rec record; v_count integer:=0;
begin
  for v_rec in
    select distinct m.learner_id,ala.account_id
    from public.class_memberships m
    join public.account_learner_access ala on ala.learner_id=m.learner_id and ala.status='active'
    join public.accounts a on a.id=ala.account_id
    where m.class_id=p_class_id
      and m.state='active'
      and a.lifecycle_status<>'closed'
      and ala.account_id is distinct from p_exclude_account_id
  loop
    if app_private.enqueue_notification_safely(
      v_rec.account_id,v_rec.learner_id,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
    ) then v_count:=v_count+1; end if;
  end loop;
  return v_count;
end;
$$;

create or replace function app_private.notify_evaluated_test_accounts(
  p_test_id uuid,
  p_exclude_account_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare v_rec record; v_count integer:=0;
begin
  for v_rec in
    select distinct ta.learner_id,ala.account_id
    from public.test_attempts ta
    join public.tests t on t.id=ta.test_id
    join public.class_memberships m on m.class_id=t.class_id and m.learner_id=ta.learner_id
      and m.state in ('active','completed','transferred')
    join public.account_learner_access ala on ala.learner_id=ta.learner_id and ala.status='active'
    join public.accounts a on a.id=ala.account_id
    where ta.test_id=p_test_id
      and ta.state='evaluated'
      and a.lifecycle_status<>'closed'
      and ala.account_id is distinct from p_exclude_account_id
  loop
    if app_private.enqueue_notification_safely(
      v_rec.account_id,v_rec.learner_id,p_notification_type,p_source_type,p_source_id,p_title,p_body,p_payload
    ) then v_count:=v_count+1; end if;
  end loop;
  return v_count;
end;
$$;

create or replace function app_private.trg_notify_enquiry_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.source_type in ('direct','sponsored') then
    perform app_private.notify_enquiry_provider_accounts(
      new.id,new.created_by_account_id,'enquiry_received','enquiry',new.id,
      'New Enquiry','A learner has sent a new Enquiry.',jsonb_build_object('enquiry_id',new.id)
    );
  elsif new.source_type='learning_request' then
    perform app_private.notify_learner_decision_account(
      new.learner_id,new.created_by_account_id,'learning_request_interest','enquiry',new.id,
      'New interest in your Learning Request','A teacher or learning provider is interested in your Learning Request.',
      jsonb_build_object('enquiry_id',new.id,'learning_request_id',new.learning_request_id)
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_enquiry_state_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if old.state='pending' and new.state='active' then
    if new.source_type in ('direct','sponsored') then
      perform app_private.notify_learner_decision_account(
        new.learner_id,v_actor,'enquiry_engaged','enquiry',new.id,
        'Your Enquiry was accepted','The teacher or learning provider accepted your Enquiry.',jsonb_build_object('enquiry_id',new.id)
      );
    elsif new.source_type='learning_request' then
      perform app_private.notify_enquiry_provider_accounts(
        new.id,v_actor,'learning_request_interest_accepted','enquiry',new.id,
        'Your interest was accepted','The learner side accepted your interest in the Learning Request.',jsonb_build_object('enquiry_id',new.id)
      );
    end if;
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_enquiry_message_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_learner uuid; v_sender_on_learner_side boolean;
begin
  select learner_id into v_learner from public.enquiries where id=new.enquiry_id;
  if v_learner is null or new.sender_account_id is null then return new; end if;
  select exists(
    select 1 from public.account_learner_access ala
    where ala.learner_id=v_learner and ala.account_id=new.sender_account_id and ala.status='active'
  ) into v_sender_on_learner_side;

  if v_sender_on_learner_side then
    perform app_private.notify_enquiry_provider_accounts(
      new.enquiry_id,new.sender_account_id,'enquiry_message','enquiry',new.enquiry_id,
      'New Enquiry message','You have a new message in an Enquiry.',jsonb_build_object('enquiry_id',new.enquiry_id,'message_id',new.id)
    );
  else
    perform app_private.notify_learner_accounts(
      v_learner,new.sender_account_id,'enquiry_message','enquiry',new.enquiry_id,
      'New Enquiry message','You have a new message in an Enquiry.',jsonb_build_object('enquiry_id',new.enquiry_id,'message_id',new.id)
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_class_invitation_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.state='pending' then
    perform app_private.notify_learner_decision_account(
      new.learner_id,new.invited_by_account_id,'class_invitation','class_invitation',new.id,
      'Class invitation','You have a new Class invitation to review.',jsonb_build_object('class_id',new.class_id,'invitation_id',new.id)
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_class_invitation_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if old.state='pending' and new.state in ('accepted','declined') then
    perform app_private.notify_class_provider_accounts(
      new.class_id,v_actor,
      case when new.state='accepted' then 'class_invitation_accepted' else 'class_invitation_declined' end,
      'class_invitation',new.id,
      case when new.state='accepted' then 'Class invitation accepted' else 'Class invitation declined' end,
      case when new.state='accepted' then 'A learner accepted the Class invitation.' else 'A learner declined the Class invitation.' end,
      jsonb_build_object('class_id',new.class_id,'invitation_id',new.id,'state',new.state)
    );
  elsif old.state='pending' and new.state='cancelled' then
    perform app_private.notify_learner_decision_account(
      new.learner_id,v_actor,'class_invitation_cancelled','class_invitation',new.id,
      'Class invitation cancelled','A Class invitation was cancelled by the learning provider.',
      jsonb_build_object('class_id',new.class_id,'invitation_id',new.id)
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_class_message_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_class uuid; v_learner uuid; v_sender_on_learner_side boolean;
begin
  select class_id,learner_id into v_class,v_learner from public.class_learner_threads where id=new.thread_id;
  if v_class is null or v_learner is null then return new; end if;
  select exists(
    select 1 from public.account_learner_access ala
    where ala.learner_id=v_learner and ala.account_id=new.sender_account_id and ala.status='active'
  ) into v_sender_on_learner_side;

  if v_sender_on_learner_side then
    perform app_private.notify_class_provider_accounts(
      v_class,new.sender_account_id,'class_message','class',v_class,
      'New Class message','You have a new learner-side message in a Class.',
      jsonb_build_object('class_id',v_class,'learner_id',v_learner,'thread_id',new.thread_id,'message_id',new.id)
    );
  else
    perform app_private.notify_learner_accounts(
      v_learner,new.sender_account_id,'class_message','class',v_class,
      'New Class message','You have a new message in a Class.',
      jsonb_build_object('class_id',v_class,'learner_id',v_learner,'thread_id',new.thread_id,'message_id',new.id)
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_activity_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if old.state='draft' and new.state='open' then
    perform app_private.notify_active_class_learner_accounts(
      new.class_id,v_actor,'activity_published','activity',new.id,
      'New Activity',new.title,jsonb_build_object('activity_id',new.id,'class_id',new.class_id)
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_test_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if old.state='draft' and new.state='available' then
    perform app_private.notify_active_class_learner_accounts(
      new.class_id,v_actor,'test_published','test',new.id,
      'New Test',new.title,jsonb_build_object('test_id',new.id,'class_id',new.class_id)
    );
  end if;
  if coalesce(old.results_visible,false)=false and new.results_visible=true then
    perform app_private.notify_evaluated_test_accounts(
      new.id,v_actor,'test_results_available','test',new.id,
      'Test results available','Results are now available for a completed Test.',jsonb_build_object('test_id',new.id,'class_id',new.class_id)
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_test_attempt_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_visible boolean; v_class uuid; v_actor uuid:=app_private.current_account_id();
begin
  if old.state is distinct from 'evaluated' and new.state='evaluated' then
    select t.results_visible,t.class_id into v_visible,v_class from public.tests t where t.id=new.test_id;
    if coalesce(v_visible,false) then
      perform app_private.notify_learner_accounts(
        new.learner_id,v_actor,'test_results_available','test',new.test_id,
        'Test results available','Results are now available for a completed Test.',
        jsonb_build_object('test_id',new.test_id,'class_id',v_class,'attempt_id',new.id)
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists notify_enquiry_insert on public.enquiries;
create trigger notify_enquiry_insert after insert on public.enquiries
for each row execute function app_private.trg_notify_enquiry_insert();

drop trigger if exists notify_enquiry_state_update on public.enquiries;
create trigger notify_enquiry_state_update after update of state on public.enquiries
for each row execute function app_private.trg_notify_enquiry_state_update();

drop trigger if exists notify_enquiry_message_insert on public.enquiry_messages;
create trigger notify_enquiry_message_insert after insert on public.enquiry_messages
for each row execute function app_private.trg_notify_enquiry_message_insert();

drop trigger if exists notify_class_invitation_insert on public.class_invitations;
create trigger notify_class_invitation_insert after insert on public.class_invitations
for each row execute function app_private.trg_notify_class_invitation_insert();

drop trigger if exists notify_class_invitation_update on public.class_invitations;
create trigger notify_class_invitation_update after update of state on public.class_invitations
for each row execute function app_private.trg_notify_class_invitation_update();

drop trigger if exists notify_class_message_insert on public.class_learner_messages;
create trigger notify_class_message_insert after insert on public.class_learner_messages
for each row execute function app_private.trg_notify_class_message_insert();

drop trigger if exists notify_activity_update on public.activities;
create trigger notify_activity_update after update of state on public.activities
for each row execute function app_private.trg_notify_activity_update();

drop trigger if exists notify_test_update on public.tests;
create trigger notify_test_update after update of state,results_visible on public.tests
for each row execute function app_private.trg_notify_test_update();

drop trigger if exists notify_test_attempt_update on public.test_attempts;
create trigger notify_test_attempt_update after update of state on public.test_attempts
for each row execute function app_private.trg_notify_test_attempt_update();

revoke all on function app_private.enqueue_notification_safely(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.notify_learner_accounts(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.notify_learner_decision_account(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.notify_enquiry_provider_accounts(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.notify_class_provider_accounts(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.notify_active_class_learner_accounts(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.notify_evaluated_test_accounts(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_enquiry_insert() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_enquiry_state_update() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_enquiry_message_insert() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_class_invitation_insert() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_class_invitation_update() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_class_message_insert() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_activity_update() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_test_update() from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_test_attempt_update() from public,anon,authenticated,service_role;

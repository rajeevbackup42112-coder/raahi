-- Raahi Learning V1.3 — do not double-notify the opening structured Enquiry message.
-- send_enquiry / express_interest_in_request already produce a dedicated Enquiry-level alert.
-- Later free-form messages use message_type='text' and continue to create message alerts.

create or replace function app_private.trg_notify_enquiry_message_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_learner uuid; v_sender_on_learner_side boolean;
begin
  if new.message_type<>'text' then return new; end if;

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

revoke all on function app_private.trg_notify_enquiry_message_insert() from public,anon,authenticated,service_role;

-- Raahi Learning V1.2 — Persisted Location Interest

create table public.location_interests (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  account_id uuid not null references public.accounts(id),
  intent_type text not null,
  state text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint location_interests_intent_check check (intent_type in ('learn','teach')),
  constraint location_interests_state_check check (state in ('active','withdrawn'))
);

comment on table public.location_interests is 'Authenticated launch interest only. It never auto-creates a Learning Request or Teaching Option.';

create unique index location_interests_one_active_tuple_idx
  on public.location_interests (location_id, account_id, intent_type)
  where state = 'active';

create index location_interests_account_idx
  on public.location_interests (account_id, created_at desc);

create index location_interests_location_active_idx
  on public.location_interests (location_id, intent_type)
  where state = 'active';

create trigger location_interests_set_updated_at
before update on public.location_interests
for each row execute function app_private.set_updated_at();

create or replace function app_private.cmd_register_location_interest(
  p_location_id uuid,
  p_intent_type text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fingerprint text;
  v_location_state text;
  v_interest_id uuid;
  v_inserted boolean := false;
  v_result jsonb;
begin
  if p_intent_type not in ('learn','teach') then
    raise exception 'INVALID_LOCATION_INTEREST_INTENT';
  end if;

  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'location_id', p_location_id, 'intent_type', p_intent_type
  ));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'register_location_interest', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select state into v_location_state
  from public.locations
  where id = p_location_id
  for update;
  if not found then raise exception 'LOCATION_NOT_FOUND'; end if;
  if v_location_state not in ('interest_only','preparing') then
    raise exception 'LOCATION_NOT_ACCEPTING_INTEREST';
  end if;

  insert into public.location_interests (location_id, account_id, intent_type)
  values (p_location_id, v_actor, p_intent_type)
  on conflict (location_id, account_id, intent_type) where state = 'active'
  do nothing
  returning id into v_interest_id;

  if v_interest_id is not null then
    v_inserted := true;
    perform app_private.write_location_audit(
      v_actor, 'location.interest_register', p_location_id,
      'location_interest', v_interest_id, null,
      jsonb_build_object('intent_type', p_intent_type)
    );
  else
    select id into v_interest_id
    from public.location_interests
    where location_id = p_location_id
      and account_id = v_actor
      and intent_type = p_intent_type
      and state = 'active'
    limit 1;
  end if;

  v_result := jsonb_build_object(
    'interest_id', v_interest_id,
    'location_id', p_location_id,
    'intent_type', p_intent_type,
    'state', 'active',
    'already_active', not v_inserted
  );
  perform app_private.complete_human_idempotent_command(
    v_actor, 'register_location_interest', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_withdraw_location_interest(
  p_location_id uuid,
  p_intent_type text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fingerprint text;
  v_interest_id uuid;
  v_result jsonb;
begin
  if p_intent_type not in ('learn','teach') then
    raise exception 'INVALID_LOCATION_INTEREST_INTENT';
  end if;

  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'location_id', p_location_id, 'intent_type', p_intent_type
  ));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'withdraw_location_interest', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select id into v_interest_id
  from public.location_interests
  where location_id = p_location_id
    and account_id = v_actor
    and intent_type = p_intent_type
    and state = 'active'
  order by created_at desc
  limit 1
  for update;

  if v_interest_id is null then
    select id into v_interest_id
    from public.location_interests
    where location_id = p_location_id
      and account_id = v_actor
      and intent_type = p_intent_type
      and state = 'withdrawn'
    order by updated_at desc
    limit 1;

    if v_interest_id is null then
      raise exception 'ACTIVE_LOCATION_INTEREST_NOT_FOUND';
    end if;

    v_result := jsonb_build_object(
      'interest_id', v_interest_id,
      'location_id', p_location_id,
      'intent_type', p_intent_type,
      'state', 'withdrawn',
      'already_withdrawn', true
    );
    perform app_private.complete_human_idempotent_command(
      v_actor, 'withdraw_location_interest', p_idempotency_key, v_result
    );
    return v_result;
  end if;

  update public.location_interests
  set state = 'withdrawn'
  where id = v_interest_id;

  perform app_private.write_location_audit(
    v_actor, 'location.interest_withdraw', p_location_id,
    'location_interest', v_interest_id, null,
    jsonb_build_object('intent_type', p_intent_type)
  );

  v_result := jsonb_build_object(
    'interest_id', v_interest_id,
    'location_id', p_location_id,
    'intent_type', p_intent_type,
    'state', 'withdrawn',
    'already_withdrawn', false
  );
  perform app_private.complete_human_idempotent_command(
    v_actor, 'withdraw_location_interest', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.get_location_interest_counts(p_location_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_learn bigint;
  v_teach bigint;
begin
  if not app_private.has_account_capability('platform_admin')
     and not app_private.has_location_staff_scope(p_location_id, 'local_manager') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  if not exists (select 1 from public.locations where id = p_location_id) then
    raise exception 'LOCATION_NOT_FOUND';
  end if;

  select
    count(*) filter (where intent_type = 'learn'),
    count(*) filter (where intent_type = 'teach')
  into v_learn, v_teach
  from public.location_interests
  where location_id = p_location_id
    and state = 'active';

  return jsonb_build_object(
    'location_id', p_location_id,
    'learn', coalesce(v_learn, 0),
    'teach', coalesce(v_teach, 0),
    'total', coalesce(v_learn, 0) + coalesce(v_teach, 0)
  );
end;
$$;

alter table public.location_interests enable row level security;
alter table public.location_interests force row level security;

create policy location_interests_select_own_or_platform
on public.location_interests for select
to authenticated
using (
  account_id = (select app_private.current_account_id())
  or (select app_private.has_account_capability('platform_admin'))
);

revoke all on table public.location_interests from public, anon, authenticated, service_role;
grant select on table public.location_interests to authenticated;
grant select, insert, update, delete on table public.location_interests to service_role;

revoke all on function app_private.cmd_register_location_interest(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_withdraw_location_interest(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function app_private.get_location_interest_counts(uuid) from public, anon, authenticated, service_role;

grant execute on function app_private.cmd_register_location_interest(uuid,text,text) to authenticated;
grant execute on function app_private.cmd_withdraw_location_interest(uuid,text,text) to authenticated;
grant execute on function app_private.get_location_interest_counts(uuid) to authenticated;

create or replace function public.register_location_interest(
  p_location_id uuid,
  p_intent_type text,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_register_location_interest(p_location_id,p_intent_type,p_idempotency_key);
$$;

create or replace function public.withdraw_location_interest(
  p_location_id uuid,
  p_intent_type text,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_withdraw_location_interest(p_location_id,p_intent_type,p_idempotency_key);
$$;

create or replace function public.get_location_interest_counts(p_location_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app_private.get_location_interest_counts(p_location_id);
$$;

revoke all on function public.register_location_interest(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function public.withdraw_location_interest(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function public.get_location_interest_counts(uuid) from public, anon, authenticated, service_role;

grant execute on function public.register_location_interest(uuid,text,text) to authenticated;
grant execute on function public.withdraw_location_interest(uuid,text,text) to authenticated;
grant execute on function public.get_location_interest_counts(uuid) to authenticated;
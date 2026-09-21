-- Raahi Learning V1.4B — Raahi Desk provenance and platform-editorial Community publishing.
-- Seed usefulness, never fake popularity.
-- Existing Community content remains organic. Platform-editorial content is published only
-- through a canonical Platform Admin command and is publicly attributed to "Raahi Desk".

alter table public.community_posts
  add column provenance_kind text not null default 'organic';

alter table public.community_posts
  add constraint community_posts_provenance_kind_check
  check (provenance_kind in ('organic','platform_editorial','assisted'));

comment on column public.community_posts.provenance_kind is
  'Server-owned Community provenance. organic=user-published; platform_editorial=Raahi Desk; assisted=reserved for a separately governed genuine-user assistance flow.';

create or replace function app_private.command_requires_fresh_phone_trust(p_command_name text)
returns boolean
language sql
immutable
strict
set search_path=''
as $$
  select p_command_name = any(array[
    'post_learning_request',
    'reopen_learning_request',
    'send_enquiry',
    'send_sponsored_enquiry',
    'express_interest_in_request',
    'accept_class_invitation',
    'publish_teaching_option',
    'create_organization',
    'add_organization_member',
    'issue_organization_member_invitation',
    'accept_organization_member_invitation',
    'set_organization_member_capability',
    'grant_learner_self_access',
    'issue_learner_self_access_invitation',
    'accept_learner_self_access_invitation',
    'request_account_closure',
    'publish_community_post',
    'publish_raahi_desk_post',
    'submit_ad_campaign_revision',
    'confirm_ad_commercial_clearance',
    'confirm_ad_inventory',
    'apply_access_restriction',
    'lift_access_restriction',
    'moderate_community_content',
    'resolve_report'
  ]::text[]);
$$;

revoke all on function app_private.command_requires_fresh_phone_trust(text)
from public,anon,authenticated,service_role;

create or replace function app_private.cmd_publish_community_post(
  p_location_id uuid,
  p_post_type text,
  p_body text,
  p_attachment_asset_id uuid,
  p_external_url text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_post uuid;
  v_result jsonb;
begin
  if not app_private.has_account_capability('community_post') then
    raise exception 'COMMUNITY_POST_CAPABILITY_REQUIRED';
  end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then
    raise exception 'LOCATION_NOT_LIVE';
  end if;
  if not app_private.account_has_location_connection(p_location_id) then
    raise exception 'LOCATION_CONNECTION_REQUIRED';
  end if;
  if app_private.has_active_account_restriction(v_actor,'community',p_location_id) then
    raise exception 'COMMUNITY_RESTRICTED';
  end if;
  if p_post_type not in ('discussion','question','resource','event','update') then
    raise exception 'INVALID_POST_TYPE';
  end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 12000 then
    raise exception 'INVALID_POST_BODY';
  end if;
  if p_attachment_asset_id is not null
     and not exists(
       select 1 from public.file_assets
       where id=p_attachment_asset_id
         and uploaded_by_account_id=v_actor
         and status='active'
     ) then
    raise exception 'ATTACHMENT_NOT_OWNED';
  end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'location_id',p_location_id,
    'post_type',p_post_type,
    'body',p_body,
    'attachment_asset_id',p_attachment_asset_id,
    'external_url',p_external_url
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'publish_community_post',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  insert into public.community_posts(
    location_id,author_account_id,post_type,body,attachment_asset_id,external_url,provenance_kind
  )
  values(
    p_location_id,v_actor,p_post_type,btrim(p_body),p_attachment_asset_id,
    nullif(btrim(p_external_url),''),'organic'
  )
  returning id into v_post;

  v_result:=jsonb_build_object(
    'post_id',v_post,
    'visibility_status','published',
    'provenance_kind','organic'
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'publish_community_post',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_publish_raahi_desk_post(
  p_location_id uuid,
  p_post_type text,
  p_body text,
  p_external_url text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_post uuid;
  v_result jsonb;
begin
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then
    raise exception 'LOCATION_NOT_LIVE';
  end if;
  if p_post_type not in ('discussion','question','resource','event','update') then
    raise exception 'INVALID_POST_TYPE';
  end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 12000 then
    raise exception 'INVALID_POST_BODY';
  end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'location_id',p_location_id,
    'post_type',p_post_type,
    'body',p_body,
    'external_url',p_external_url,
    'provenance_kind','platform_editorial'
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'publish_raahi_desk_post',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  insert into public.community_posts(
    location_id,author_account_id,post_type,body,attachment_asset_id,external_url,provenance_kind
  )
  values(
    p_location_id,v_actor,p_post_type,btrim(p_body),null,
    nullif(btrim(p_external_url),''),'platform_editorial'
  )
  returning id into v_post;

  perform app_private.write_location_audit(
    v_actor,
    'community.raahi_desk_publish',
    p_location_id,
    'community_post',
    v_post,
    null,
    jsonb_build_object(
      'provenance_kind','platform_editorial',
      'post_type',p_post_type,
      'public_attribution','Raahi Desk'
    )
  );

  v_result:=jsonb_build_object(
    'post_id',v_post,
    'visibility_status','published',
    'provenance_kind','platform_editorial',
    'attribution_label','Raahi Desk'
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'publish_raahi_desk_post',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_comment_on_community_post(
  p_post_id uuid,
  p_body text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_location uuid;
  v_author uuid;
  v_provenance text;
  v_comment uuid;
  v_result jsonb;
begin
  select location_id,author_account_id,provenance_kind
    into v_location,v_author,v_provenance
  from public.community_posts
  where id=p_post_id and visibility_status='published';
  if not found then
    raise exception 'COMMUNITY_POST_NOT_AVAILABLE';
  end if;
  if not exists(select 1 from public.locations where id=v_location and state='live') then
    raise exception 'LOCATION_NOT_LIVE';
  end if;
  if not app_private.account_has_location_connection(v_location) then
    raise exception 'LOCATION_CONNECTION_REQUIRED';
  end if;
  if app_private.has_active_account_restriction(v_actor,'community',v_location) then
    raise exception 'COMMUNITY_RESTRICTED';
  end if;
  if v_provenance<>'platform_editorial'
     and app_private.community_blocked_between(v_author) then
    raise exception 'COMMUNITY_RELATION_BLOCKED';
  end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 8000 then
    raise exception 'INVALID_COMMENT_BODY';
  end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'post_id',p_post_id,'body',p_body
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'comment_on_community_post',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  insert into public.community_comments(post_id,author_account_id,body)
  values(p_post_id,v_actor,btrim(p_body))
  returning id into v_comment;

  v_result:=jsonb_build_object(
    'comment_id',v_comment,'post_id',p_post_id,'visibility_status','published'
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'comment_on_community_post',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_react_to_community_content(
  p_target_type text,
  p_target_id uuid,
  p_reaction_type text,
  p_enabled boolean,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_location uuid;
  v_author uuid;
  v_post_provenance text;
  v_result jsonb;
begin
  if p_reaction_type not in ('helpful','thanks','support','interesting') then
    raise exception 'INVALID_REACTION_TYPE';
  end if;

  if p_target_type='post' then
    select location_id,author_account_id,provenance_kind
      into v_location,v_author,v_post_provenance
    from public.community_posts
    where id=p_target_id and visibility_status='published';
  elsif p_target_type='comment' then
    select p.location_id,c.author_account_id,p.provenance_kind
      into v_location,v_author,v_post_provenance
    from public.community_comments c
    join public.community_posts p on p.id=c.post_id
    where c.id=p_target_id
      and c.visibility_status='published'
      and p.visibility_status='published';
  else
    raise exception 'INVALID_REACTION_TARGET';
  end if;

  if v_location is null then
    raise exception 'COMMUNITY_CONTENT_NOT_AVAILABLE';
  end if;
  if not app_private.account_has_location_connection(v_location) then
    raise exception 'LOCATION_CONNECTION_REQUIRED';
  end if;
  if app_private.has_active_account_restriction(v_actor,'community',v_location) then
    raise exception 'COMMUNITY_RESTRICTED';
  end if;
  if not (p_target_type='post' and v_post_provenance='platform_editorial')
     and app_private.community_blocked_between(v_author) then
    raise exception 'COMMUNITY_RELATION_BLOCKED';
  end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'target_type',p_target_type,
    'target_id',p_target_id,
    'reaction_type',p_reaction_type,
    'enabled',p_enabled
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'react_to_community_content',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  if p_target_type='post' then
    if p_enabled then
      insert into public.community_post_reactions(post_id,account_id,reaction_type)
      values(p_target_id,v_actor,p_reaction_type)
      on conflict(post_id,account_id)
      do update set reaction_type=excluded.reaction_type,created_at=now();
    else
      delete from public.community_post_reactions
      where post_id=p_target_id and account_id=v_actor;
    end if;
  else
    if p_enabled then
      insert into public.community_comment_reactions(comment_id,account_id,reaction_type)
      values(p_target_id,v_actor,p_reaction_type)
      on conflict(comment_id,account_id)
      do update set reaction_type=excluded.reaction_type,created_at=now();
    else
      delete from public.community_comment_reactions
      where comment_id=p_target_id and account_id=v_actor;
    end if;
  end if;

  v_result:=jsonb_build_object(
    'target_type',p_target_type,
    'target_id',p_target_id,
    'reaction_type',p_reaction_type,
    'enabled',p_enabled
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'react_to_community_content',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.discover_community_posts(
  p_location_id uuid,
  p_limit integer default 50
)
returns setof jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'post_id',p.id,
    'location_id',p.location_id,
    'post_type',p.post_type,
    'body',p.body,
    'external_url',p.external_url,
    'created_at',p.created_at,
    'provenance_kind',p.provenance_kind,
    'attribution_label',case when p.provenance_kind='platform_editorial' then 'Platform-authored' else null end,
    'is_platform_editorial',(p.provenance_kind='platform_editorial'),
    'can_block_author',(p.provenance_kind<>'platform_editorial'),
    'author_account_id',case when p.provenance_kind='platform_editorial' then null else p.author_account_id end,
    'author_name',case when p.provenance_kind='platform_editorial' then 'Raahi Desk' else a.display_name end,
    'comment_count',(
      select count(*)
      from public.community_comments c
      where c.post_id=p.id and c.visibility_status='published'
    ),
    'reaction_count',(
      select count(*)
      from public.community_post_reactions r
      where r.post_id=p.id
    )
  )
  from public.community_posts p
  join public.accounts a on a.id=p.author_account_id
  where p.location_id=p_location_id
    and p.visibility_status='published'
    and exists(
      select 1 from public.locations l
      where l.id=p.location_id and l.state='live'
    )
    and (
      p.provenance_kind='platform_editorial'
      or not app_private.community_blocked_between(p.author_account_id)
    )
  order by p.created_at desc,p.id
  limit greatest(1,least(coalesce(p_limit,50),100));
$$;

create or replace function app_private.get_community_post_projection(p_post_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'post_id',p.id,
    'location_id',p.location_id,
    'post_type',p.post_type,
    'body',p.body,
    'external_url',p.external_url,
    'created_at',p.created_at,
    'provenance_kind',p.provenance_kind,
    'attribution_label',case when p.provenance_kind='platform_editorial' then 'Platform-authored' else null end,
    'is_platform_editorial',(p.provenance_kind='platform_editorial'),
    'can_block_author',(p.provenance_kind<>'platform_editorial'),
    'author_account_id',case when p.provenance_kind='platform_editorial' then null else p.author_account_id end,
    'author_name',case when p.provenance_kind='platform_editorial' then 'Raahi Desk' else a.display_name end,
    'comments',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'comment_id',c.id,
          'author_account_id',c.author_account_id,
          'author_name',ca.display_name,
          'body',c.body,
          'created_at',c.created_at,
          'reaction_count',(
            select count(*)
            from public.community_comment_reactions r
            where r.comment_id=c.id
          )
        )
        order by c.created_at,c.id
      )
      from public.community_comments c
      join public.accounts ca on ca.id=c.author_account_id
      where c.post_id=p.id
        and c.visibility_status='published'
        and not app_private.community_blocked_between(c.author_account_id)
    ),'[]'::jsonb)
  )
  from public.community_posts p
  join public.accounts a on a.id=p.author_account_id
  where p.id=p_post_id
    and p.visibility_status='published'
    and (
      p.provenance_kind='platform_editorial'
      or not app_private.community_blocked_between(p.author_account_id)
    );
$$;

revoke all on function app_private.cmd_publish_raahi_desk_post(uuid,text,text,text,text)
from public,anon,authenticated,service_role;
grant execute on function app_private.cmd_publish_raahi_desk_post(uuid,text,text,text,text)
to authenticated;

revoke all on function app_private.cmd_publish_community_post(uuid,text,text,uuid,text,text),
  app_private.cmd_comment_on_community_post(uuid,text,text),
  app_private.cmd_react_to_community_content(text,uuid,text,boolean,text),
  app_private.discover_community_posts(uuid,integer),
  app_private.get_community_post_projection(uuid)
from public,anon,authenticated,service_role;

grant execute on function app_private.cmd_publish_community_post(uuid,text,text,uuid,text,text),
  app_private.cmd_comment_on_community_post(uuid,text,text),
  app_private.cmd_react_to_community_content(text,uuid,text,boolean,text),
  app_private.discover_community_posts(uuid,integer),
  app_private.get_community_post_projection(uuid)
to authenticated;

create or replace function public.publish_raahi_desk_post(
  p_location_id uuid,
  p_post_type text,
  p_body text,
  p_external_url text,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_publish_raahi_desk_post(
    p_location_id,p_post_type,p_body,p_external_url,p_idempotency_key
  );
$$;

revoke all on function public.publish_raahi_desk_post(uuid,text,text,text,text)
from public,anon,authenticated,service_role;
grant execute on function public.publish_raahi_desk_post(uuid,text,text,text,text)
to authenticated;

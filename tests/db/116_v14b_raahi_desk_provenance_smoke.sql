-- Raahi Learning V1.4B — Raahi Desk provenance runtime smoke.
-- Disposable test only: all synthetic Auth/application rows and content roll back.

begin;

insert into auth.users(id,aud,role,email) values
('86666666-6666-6666-6666-666666666661','authenticated','authenticated','desk-admin@test.invalid'),
('86666666-6666-6666-6666-666666666662','authenticated','authenticated','organic-poster@test.invalid'),
('86666666-6666-6666-6666-666666666663','authenticated','authenticated','desk-reader@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','86666666-6666-6666-6666-666666666661',true);
select set_config('test.desk_admin',(public.bootstrap_account('Desk Operator')->>'account_id'),true);
select set_config('request.jwt.claim.sub','86666666-6666-6666-6666-666666666662',true);
select set_config('test.organic_poster',(public.bootstrap_account('Organic Poster')->>'account_id'),true);
select set_config('request.jwt.claim.sub','86666666-6666-6666-6666-666666666663',true);
select set_config('test.reader',(public.bootstrap_account('Desk Reader')->>'account_id'),true);
reset role;

insert into public.locations(id,name,slug,state,country_code) values
('86666666-6666-6666-6666-666666666670','Desk Test Location','desk-test-location-v14b','live','IN');

insert into public.account_capabilities(account_id,capability_code) values
(current_setting('test.desk_admin')::uuid,'platform_admin'),
(current_setting('test.organic_poster')::uuid,'community_post');

insert into public.account_location_preferences(account_id,selected_location_id) values
(current_setting('test.organic_poster')::uuid,'86666666-6666-6666-6666-666666666670'),
(current_setting('test.reader')::uuid,'86666666-6666-6666-6666-666666666670');

set local role authenticated;
select set_config('request.jwt.claim.sub','86666666-6666-6666-6666-666666666662',true);
select set_config(
  'test.organic_post',
  (
    public.publish_community_post(
      '86666666-6666-6666-6666-666666666670',
      'question',
      'What helps students stay consistent with revision?',
      null,
      null,
      'organic-post-v14b'
    )->>'post_id'
  ),
  true
);

do $$
declare p jsonb;
begin
  select public.get_community_post(current_setting('test.organic_post')::uuid) into p;
  if p->>'provenance_kind' <> 'organic' then raise exception 'ORGANIC_PROVENANCE_MISSING'; end if;
  if p->>'author_account_id' is null then raise exception 'ORGANIC_AUTHOR_HIDDEN'; end if;
  if p->>'author_name' <> 'Organic Poster' then raise exception 'ORGANIC_AUTHOR_CHANGED'; end if;
  if (p->>'can_block_author')::boolean is not true then raise exception 'ORGANIC_BLOCKABILITY_CHANGED'; end if;
end $$;

select set_config('request.jwt.claim.sub','86666666-6666-6666-6666-666666666663',true);
do $$
begin
  perform public.publish_raahi_desk_post(
    '86666666-6666-6666-6666-666666666670',
    'update',
    'Forged Desk post',
    null,
    'desk-forgery-v14b'
  );
  raise exception 'NON_ADMIN_RAAHI_DESK_ALLOWED';
exception
  when others then
    if position('PLATFORM_ADMIN_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;

select set_config('request.jwt.claim.sub','86666666-6666-6666-6666-666666666661',true);
select set_config(
  'test.desk_post',
  (
    public.publish_raahi_desk_post(
      '86666666-6666-6666-6666-666666666670',
      'resource',
      'A simple checklist for choosing a local Class 10 Maths tutor.',
      'https://example.com/learning-guide',
      'desk-post-v14b'
    )->>'post_id'
  ),
  true
);

do $$
declare r jsonb;
begin
  r:=public.publish_raahi_desk_post(
    '86666666-6666-6666-6666-666666666670',
    'resource',
    'A simple checklist for choosing a local Class 10 Maths tutor.',
    'https://example.com/learning-guide',
    'desk-post-v14b'
  );
  if r->>'post_id' <> current_setting('test.desk_post') then
    raise exception 'DESK_IDEMPOTENT_RETRY_CHANGED_POST';
  end if;
end $$;

do $$
begin
  perform public.publish_raahi_desk_post(
    '86666666-6666-6666-6666-666666666670',
    'resource',
    'Changed body must not reuse the same key.',
    'https://example.com/learning-guide',
    'desk-post-v14b'
  );
  raise exception 'DESK_IDEMPOTENCY_REUSE_ALLOWED';
exception
  when others then
    if position('IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST' in sqlerrm)=0 then raise; end if;
end $$;

reset role;

do $$
begin
  if (
    select provenance_kind
    from public.community_posts
    where id=current_setting('test.desk_post')::uuid
  ) <> 'platform_editorial' then
    raise exception 'DESK_ROW_PROVENANCE_WRONG';
  end if;

  if (
    select author_account_id
    from public.community_posts
    where id=current_setting('test.desk_post')::uuid
  ) <> current_setting('test.desk_admin')::uuid then
    raise exception 'DESK_OPERATOR_NOT_RETAINED';
  end if;

  if exists(
    select 1 from public.community_comments
    where post_id=current_setting('test.desk_post')::uuid
  ) then
    raise exception 'DESK_FAKE_COMMENT_CREATED';
  end if;

  if exists(
    select 1 from public.community_post_reactions
    where post_id=current_setting('test.desk_post')::uuid
  ) then
    raise exception 'DESK_FAKE_REACTION_CREATED';
  end if;

  if not exists(
    select 1
    from public.audit_log
    where action_type='community.raahi_desk_publish'
      and actor_account_id=current_setting('test.desk_admin')::uuid
      and target_type='community_post'
      and target_id=current_setting('test.desk_post')::uuid
      and location_id='86666666-6666-6666-6666-666666666670'
  ) then
    raise exception 'DESK_AUDIT_MISSING';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','86666666-6666-6666-6666-666666666663',true);

do $$
declare p jsonb;
begin
  select public.get_community_post(current_setting('test.desk_post')::uuid) into p;
  if p->>'provenance_kind' <> 'platform_editorial' then raise exception 'DESK_PUBLIC_PROVENANCE_MISSING'; end if;
  if p->>'author_name' <> 'Raahi Desk' then raise exception 'DESK_PUBLIC_AUTHOR_WRONG'; end if;
  if p->>'author_account_id' is not null then raise exception 'DESK_OPERATOR_ID_LEAKED'; end if;
  if p->>'attribution_label' <> 'Platform-authored' then raise exception 'DESK_ATTRIBUTION_MISSING'; end if;
  if (p->>'is_platform_editorial')::boolean is not true then raise exception 'DESK_EDITORIAL_FLAG_MISSING'; end if;
  if (p->>'can_block_author')::boolean is not false then raise exception 'DESK_BLOCK_FLAG_WRONG'; end if;
end $$;

select public.set_block(current_setting('test.desk_admin')::uuid,true,'block-desk-operator-v14b');

do $$
declare n integer;
begin
  select count(*) into n
  from public.discover_community_posts(
    '86666666-6666-6666-6666-666666666670',50
  ) p
  where p->>'post_id'=current_setting('test.desk_post');
  if n<>1 then raise exception 'DESK_HIDDEN_BY_OPERATOR_BLOCK'; end if;
end $$;

select public.comment_on_community_post(
  current_setting('test.desk_post')::uuid,
  'This checklist is useful.',
  'desk-comment-v14b'
);
select public.react_to_community_content(
  'post',
  current_setting('test.desk_post')::uuid,
  'helpful',
  true,
  'desk-react-v14b'
);

select public.set_block(current_setting('test.organic_poster')::uuid,true,'block-organic-v14b');

do $$
declare organic_n integer; desk_n integer;
begin
  select count(*) into organic_n
  from public.discover_community_posts(
    '86666666-6666-6666-6666-666666666670',50
  ) p
  where p->>'post_id'=current_setting('test.organic_post');

  select count(*) into desk_n
  from public.discover_community_posts(
    '86666666-6666-6666-6666-666666666670',50
  ) p
  where p->>'post_id'=current_setting('test.desk_post');

  if organic_n<>0 then raise exception 'ORGANIC_BLOCK_FILTER_REGRESSED'; end if;
  if desk_n<>1 then raise exception 'DESK_VISIBILITY_REGRESSED'; end if;
end $$;

do $$
begin
  insert into public.community_posts(
    location_id,author_account_id,post_type,body,provenance_kind
  ) values (
    '86666666-6666-6666-6666-666666666670',
    current_setting('test.reader')::uuid,
    'update',
    'Forged direct platform post',
    'platform_editorial'
  );
  raise exception 'DIRECT_DESK_WRITE_ALLOWED';
exception
  when insufficient_privilege then null;
end $$;

reset role;

do $$
begin
  insert into public.community_posts(
    location_id,author_account_id,post_type,body,provenance_kind
  ) values (
    '86666666-6666-6666-6666-666666666670',
    current_setting('test.desk_admin')::uuid,
    'update',
    'Bad provenance',
    'fabricated'
  );
  raise exception 'UNKNOWN_PROVENANCE_ALLOWED';
exception
  when check_violation then null;
end $$;

rollback;

select 'RAAHI_DESK_PROVENANCE_RUNTIME_TESTS_PASS' as result;

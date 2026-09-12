-- Raahi Learning V1.2 — frontend Organization workspace projection runtime smoke.
-- Disposable dev suite; all fixtures roll back.

begin;
insert into auth.users(id,aud,role,email) values
('b9111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend109-owner@test.invalid'),
('b9222222-2222-2222-2222-222222222222','authenticated','authenticated','frontend109-outsider@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','b9111111-1111-1111-1111-111111111111',true);
select set_config('test.owner',(public.bootstrap_account('Frontend Org Owner 109')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b9222222-2222-2222-2222-222222222222',true);
select set_config('test.outsider',(public.bootstrap_account('Frontend Org Outsider 109')->>'account_id'),true);
reset role;
insert into public.locations(id,name,slug,state,country_code) values('b9000000-0000-0000-0000-000000000001','Frontend Org Location 109','frontend-org-location-109','live','IN');
set local role authenticated;
select set_config('request.jwt.claim.sub','b9111111-1111-1111-1111-111111111111',true);
select set_config('test.org',(public.create_organization('academy','Frontend Workspace Academy','Private editable description','Contact desk','Main Road','https://example.invalid','none',null,'109-org')->>'organization_id'),true);
select public.publish_teaching_option(current_setting('test.org')::uuid,'Archived-capable option','Academics','Workspace projection includes non-public option','online',null,'₹500',array['b9000000-0000-0000-0000-000000000001']::uuid[],'109-option');
do $$ declare w jsonb; begin
  w:=public.get_organization_workspace(current_setting('test.org')::uuid);
  if w #>> '{organization,description}' <> 'Private editable description' then raise exception 'ORG_WORKSPACE_PROFILE_BAD:%',w; end if;
  if jsonb_array_length(w->'teaching_options')<>1 then raise exception 'ORG_WORKSPACE_OPTIONS_BAD:%',w; end if;
end $$;
select set_config('request.jwt.claim.sub','b9222222-2222-2222-2222-222222222222',true);
do $$ begin
  perform public.get_organization_workspace(current_setting('test.org')::uuid);
  raise exception 'OUTSIDER_ORG_WORKSPACE_ALLOWED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;
rollback;
select 'FRONTEND_ORGANIZATION_WORKSPACE_PASS' as result;

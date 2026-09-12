-- Raahi Learning V1.2 — Class, Membership, Session and Material read boundaries

create or replace function app_private.can_read_class_shared(p_class_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select
    (
      app_private.can_manage_class(p_class_id)
      or exists(
        select 1 from public.class_memberships m
        where m.class_id=p_class_id
          and m.state in ('active','completed','transferred')
          and app_private.can_access_learner(m.learner_id)
      )
    )
    and not app_private.current_actor_class_access_blocked(p_class_id)
    and not app_private.class_provider_access_blocked(p_class_id);
$$;

create or replace function app_private.can_read_class_membership(p_membership_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_class uuid; v_learner uuid;
begin
  select class_id,learner_id into v_class,v_learner from public.class_memberships where id=p_membership_id;
  if not found then return false; end if;
  if app_private.can_manage_class(v_class) then return true; end if;
  if not app_private.can_access_learner(v_learner) then return false; end if;
  return not app_private.current_actor_class_access_blocked(v_class) and not app_private.class_provider_access_blocked(v_class);
end; $$;

create or replace function app_private.can_read_class_invitation(p_invitation_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_class uuid; v_learner uuid;
begin
  select class_id,learner_id into v_class,v_learner from public.class_invitations where id=p_invitation_id;
  if not found then return false; end if;
  return app_private.can_manage_class(v_class) or app_private.can_read_learner_relationship(v_learner);
end; $$;

create or replace function app_private.can_read_material(p_material_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.can_manage_material(p_material_id)
    or exists(
      select 1 from public.material_class_links l
      where l.material_id=p_material_id and app_private.can_read_class_shared(l.class_id)
    );
$$;

create or replace function app_private.can_read_file_asset(p_file_asset_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
      select 1 from public.file_assets f
      where f.id=p_file_asset_id
        and f.status='active'
        and f.uploaded_by_account_id=app_private.current_account_id()
    )
    or exists(
      select 1 from public.materials m
      where m.file_asset_id=p_file_asset_id and app_private.can_read_material(m.id)
    );
$$;

alter table public.classes enable row level security; alter table public.classes force row level security;
alter table public.class_invitations enable row level security; alter table public.class_invitations force row level security;
alter table public.class_memberships enable row level security; alter table public.class_memberships force row level security;
alter table public.class_sessions enable row level security; alter table public.class_sessions force row level security;
alter table public.file_assets enable row level security; alter table public.file_assets force row level security;
alter table public.materials enable row level security; alter table public.materials force row level security;
alter table public.material_class_links enable row level security; alter table public.material_class_links force row level security;

create policy classes_select_authorized on public.classes for select to authenticated using(app_private.can_read_class_shared(id));
create policy class_invitations_select_authorized on public.class_invitations for select to authenticated using(app_private.can_read_class_invitation(id));
create policy class_memberships_select_authorized on public.class_memberships for select to authenticated using(app_private.can_read_class_membership(id));
create policy class_sessions_select_authorized on public.class_sessions for select to authenticated using(app_private.can_read_class_shared(class_id));
create policy file_assets_select_authorized on public.file_assets for select to authenticated using(app_private.can_read_file_asset(id));
create policy materials_select_authorized on public.materials for select to authenticated using(app_private.can_read_material(id));
create policy material_class_links_select_authorized on public.material_class_links for select to authenticated using(app_private.can_read_class_shared(class_id));

revoke all on table public.classes,public.class_invitations,public.class_memberships,public.class_sessions,public.file_assets,public.materials,public.material_class_links
from public,anon,authenticated,service_role;
grant select on table public.classes,public.class_invitations,public.class_memberships,public.class_sessions,public.file_assets,public.materials,public.material_class_links to authenticated;
grant select,insert,update,delete on table public.classes,public.class_invitations,public.class_memberships,public.class_sessions,public.file_assets,public.materials,public.material_class_links to service_role;

revoke all on function app_private.can_read_class_shared(uuid),app_private.can_read_class_membership(uuid),app_private.can_read_class_invitation(uuid),
 app_private.can_read_material(uuid),app_private.can_read_file_asset(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_class_shared(uuid),app_private.can_read_class_membership(uuid),app_private.can_read_class_invitation(uuid),
 app_private.can_read_material(uuid),app_private.can_read_file_asset(uuid) to authenticated;

-- Raahi Learning V1.2 — Locations RLS performance forward fix
-- Consolidates authenticated SELECT into one permissive policy so PostgreSQL
-- does not evaluate two overlapping permissive policies for every Location row.

drop policy if exists locations_select_public on public.locations;
drop policy if exists locations_select_privileged on public.locations;

create policy locations_select_anon
on public.locations for select
to anon
using (state <> 'retired');

create policy locations_select_authenticated
on public.locations for select
to authenticated
using (
  state <> 'retired'
  or (select app_private.has_account_capability('platform_admin'))
  or (select app_private.has_location_staff_scope(id, 'local_manager'))
);
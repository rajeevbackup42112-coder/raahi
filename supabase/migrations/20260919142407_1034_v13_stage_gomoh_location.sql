-- Raahi Learning V1.3 — prepare Gomoh as the second Stage Location.
-- Configuration-only migration for the approved single-project Stage -> Controlled Pilot strategy.
-- Dhanbad remains live. Gomoh is intentionally PREPARING and must not be switched
-- to LIVE until the controlled-pilot cutover gate is explicitly satisfied.

insert into public.locations (
  name,
  slug,
  region,
  state_or_province,
  country_code,
  coverage_metadata,
  state
)
values (
  'Gomoh',
  'gomoh',
  'Dhanbad',
  'Jharkhand',
  'IN',
  jsonb_build_object(
    'purpose','Raahi Learning Stage / controlled-pilot preparation',
    'pilot_scope','Gomoh + Dhanbad',
    'configured_by','migration_1034'
  ),
  'preparing'
)
on conflict (slug) do nothing;

update public.locations
set
  name = 'Gomoh',
  region = 'Dhanbad',
  state_or_province = 'Jharkhand',
  country_code = 'IN',
  coverage_metadata = coalesce(coverage_metadata,'{}'::jsonb) || jsonb_build_object(
    'purpose','Raahi Learning Stage / controlled-pilot preparation',
    'pilot_scope','Gomoh + Dhanbad',
    'configured_by','migration_1034'
  ),
  state = case when state = 'interest_only' then 'preparing' else state end,
  updated_at = now()
where slug = 'gomoh';

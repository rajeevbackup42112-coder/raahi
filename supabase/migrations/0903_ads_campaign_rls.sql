-- Raahi Learning V1.2 — advertiser/reviewer/commercial read boundaries.

create or replace function app_private.can_review_campaign_locally(p_campaign_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.ad_campaign_targets t
    where t.campaign_id=p_campaign_id
      and app_private.has_location_staff_scope(t.location_id,'local_manager')
  );
$$;

create or replace function app_private.can_read_ad_campaign(p_campaign_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.campaign_advertiser_authority(p_campaign_id)
    or app_private.has_account_capability('platform_admin')
    or app_private.has_account_capability('ads_commercial')
    or app_private.can_review_campaign_locally(p_campaign_id);
$$;

create or replace function app_private.can_read_ad_evidence(p_revision_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.ad_campaign_revisions r
    where r.id=p_revision_id
      and (
        app_private.campaign_advertiser_authority(r.campaign_id)
        or app_private.has_account_capability('platform_admin')
        or app_private.can_review_campaign_locally(r.campaign_id)
      )
  );
$$;

create or replace function app_private.can_read_ad_commercial(p_campaign_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.campaign_advertiser_authority(p_campaign_id)
    or app_private.has_account_capability('platform_admin')
    or app_private.has_account_capability('ads_commercial');
$$;

create or replace function app_private.can_read_advertising_eligibility(p_account_id uuid,p_organization_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_advertiser_authority(p_account_id,p_organization_id)
    or app_private.has_account_capability('platform_admin')
    or app_private.has_account_capability('ads_commercial');
$$;

alter table public.advertising_eligibility enable row level security; alter table public.advertising_eligibility force row level security;
alter table public.ad_campaigns enable row level security; alter table public.ad_campaigns force row level security;
alter table public.ad_campaign_targets enable row level security; alter table public.ad_campaign_targets force row level security;
alter table public.ad_campaign_revisions enable row level security; alter table public.ad_campaign_revisions force row level security;
alter table public.ad_reviews enable row level security; alter table public.ad_reviews force row level security;
alter table public.ad_claim_evidence enable row level security; alter table public.ad_claim_evidence force row level security;
alter table public.ad_commercial_clearances enable row level security; alter table public.ad_commercial_clearances force row level security;

create policy advertising_eligibility_select_authorized on public.advertising_eligibility for select to authenticated using(app_private.can_read_advertising_eligibility(account_id,organization_id));
create policy ad_campaigns_select_authorized on public.ad_campaigns for select to authenticated using(app_private.can_read_ad_campaign(id));
create policy ad_campaign_targets_select_authorized on public.ad_campaign_targets for select to authenticated using(app_private.can_read_ad_campaign(campaign_id));
create policy ad_campaign_revisions_select_authorized on public.ad_campaign_revisions for select to authenticated using(app_private.can_read_ad_campaign(campaign_id));
create policy ad_reviews_select_authorized on public.ad_reviews for select to authenticated using(exists(select 1 from public.ad_campaign_revisions r where r.id=campaign_revision_id and app_private.can_read_ad_campaign(r.campaign_id)));
create policy ad_claim_evidence_select_authorized on public.ad_claim_evidence for select to authenticated using(app_private.can_read_ad_evidence(campaign_revision_id));
create policy ad_commercial_clearances_select_authorized on public.ad_commercial_clearances for select to authenticated using(app_private.can_read_ad_commercial(campaign_id));

revoke all on table public.advertising_eligibility,public.ad_campaigns,public.ad_campaign_targets,public.ad_campaign_revisions,public.ad_reviews,public.ad_claim_evidence,public.ad_commercial_clearances from public,anon,authenticated,service_role;
grant select on table public.advertising_eligibility,public.ad_campaigns,public.ad_campaign_targets,public.ad_campaign_revisions,public.ad_reviews,public.ad_claim_evidence,public.ad_commercial_clearances to authenticated;
grant select,insert,update,delete on table public.advertising_eligibility,public.ad_campaigns,public.ad_campaign_targets,public.ad_campaign_revisions,public.ad_reviews,public.ad_claim_evidence,public.ad_commercial_clearances to service_role;

revoke all on function app_private.can_review_campaign_locally(uuid),app_private.can_read_ad_campaign(uuid),app_private.can_read_ad_evidence(uuid),app_private.can_read_ad_commercial(uuid),app_private.can_read_advertising_eligibility(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.can_review_campaign_locally(uuid),app_private.can_read_ad_campaign(uuid),app_private.can_read_ad_evidence(uuid),app_private.can_read_ad_commercial(uuid),app_private.can_read_advertising_eligibility(uuid,uuid) to authenticated;

-- Raahi Learning V1.2 — Sponsored discovery attribution reuses the normal Enquiry relationship.

alter table public.enquiries
  add column source_campaign_id uuid null references public.ad_campaigns(id);

alter table public.enquiries
  add constraint enquiries_sponsored_campaign_consistency check (
    (source_type='sponsored' and source_campaign_id is not null)
    or (source_type<>'sponsored' and source_campaign_id is null)
  );

create index enquiries_source_campaign_idx
  on public.enquiries(source_campaign_id,created_at desc)
  where source_campaign_id is not null;

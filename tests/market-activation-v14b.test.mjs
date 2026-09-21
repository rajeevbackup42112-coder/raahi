import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const ui=fs.readFileSync('apps/raahi-learning/market-activation-v14b.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260921055900_v14_raahi_desk_provenance.sql','utf8');
const builder=fs.readFileSync('apps/raahi-learning/build-source-v13.mjs','utf8');
const packager=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');

test('Raahi Desk provenance is server-owned and cannot masquerade as organic activity',()=>{
  assert.match(migration,/add column provenance_kind text not null default 'organic'/);
  assert.match(migration,/provenance_kind in \('organic','platform_editorial','assisted'\)/);
  assert.match(migration,/cmd_publish_raahi_desk_post/);
  assert.match(migration,/has_account_capability\('platform_admin'\)/);
  assert.match(migration,/raise exception 'PLATFORM_ADMIN_REQUIRED'/);
  assert.match(migration,/provenance_kind[\s\S]*'platform_editorial'/);
  assert.match(migration,/community\.raahi_desk_publish/);
  assert.match(migration,/public_attribution','Raahi Desk'/);
  assert.doesNotMatch(migration,/p_(?:author|attribution|provenance)_/i);
});

test('ordinary Community publishing remains explicitly organic',()=>{
  assert.match(migration,/cmd_publish_community_post[\s\S]*'organic'/);
  assert.match(migration,/publish_community_post'/);
  assert.match(migration,/COMMUNITY_POST_CAPABILITY_REQUIRED/);
  assert.match(migration,/LOCATION_CONNECTION_REQUIRED/);
});

test('public projections reveal provenance while hiding Raahi Desk operator identity',()=>{
  assert.match(migration,/'author_account_id',case when p\.provenance_kind='platform_editorial' then null else p\.author_account_id end/);
  assert.match(migration,/'author_name',case when p\.provenance_kind='platform_editorial' then 'Raahi Desk' else a\.display_name end/);
  assert.match(migration,/'attribution_label',case when p\.provenance_kind='platform_editorial' then 'Platform-authored' else null end/);
  assert.match(migration,/'can_block_author',\(p\.provenance_kind<>'platform_editorial'\)/);
  assert.match(migration,/p\.provenance_kind='platform_editorial'[\s\S]*community_blocked_between/);
});

test('Raahi Desk public RPC is a guarded invoker wrapper and table grants stay closed',()=>{
  assert.match(migration,/create or replace function public\.publish_raahi_desk_post/);
  assert.match(migration,/language sql[\s\S]*security invoker/);
  assert.match(migration,/revoke all on function public\.publish_raahi_desk_post[\s\S]*from public,anon,authenticated,service_role/);
  assert.match(migration,/grant execute on function public\.publish_raahi_desk_post[\s\S]*to authenticated/);
  assert.doesNotMatch(migration,/grant\s+(?:insert|update|delete).*community_posts.*authenticated/i);
});

test('Raahi Desk UI uses only the canonical RPC and is available only in Platform workspace',()=>{
  assert.match(ui,/api\.state\.role !== 'platform'/);
  assert.match(ui,/publish_raahi_desk_post/);
  assert.match(ui,/discover_community_posts/);
  assert.match(ui,/Raahi Desk/);
  assert.match(ui,/Platform-authored/);
  assert.match(ui,/New Raahi Desk post/);
  assert.match(ui,/does not create fake students, teachers, requests, comments, reactions or popularity/);
  assert.doesNotMatch(ui,/\.from\s*\(/);
  assert.doesNotMatch(ui,/\.insert\s*\(/);
  assert.doesNotMatch(ui,/\.update\s*\(/);
  assert.doesNotMatch(ui,/\.delete\s*\(/);
  assert.doesNotMatch(ui,/service_role|sb_secret_/i);
});

test('platform editorial cards never offer Block author but remain reportable',()=>{
  assert.match(ui,/editorialPostById/);
  assert.match(ui,/data-live-report-community/);
  assert.match(ui,/Raahi Desk post/);
  assert.match(ui,/Raahi Desk · Platform-authored/);
  const editorialMenu=ui.slice(ui.indexOf("document.addEventListener('click'"),ui.indexOf("document.addEventListener('submit'"));
  assert.doesNotMatch(editorialMenu,/data-live-block-account/);
});

test('canonical reconstruction and release packaging ship the market activation layer',()=>{
  assert.match(builder,/market-activation-v14b\.js/);
  assert.match(packager,/market-activation-v14b\.js/);
});

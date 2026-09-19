import test from 'node:test';
import assert from 'node:assert/strict';
import {parseLoadConfig,summarizeSamples} from './production-like-load.mjs';

const BASE={
  RAAHI_LOAD_CONFIRM_TARGET:'PRODUCTION_LIKE_ISOLATED',
  RAAHI_LOAD_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',
  RAAHI_LOAD_EXPECTED_PROJECT_REF:'abcdefghijklmnopqrst',
  RAAHI_LOAD_PUBLISHABLE_KEY:'sb_publishable_example',
  RAAHI_LOAD_ORIGIN:'https://learning.example.test',
  RAAHI_LOAD_IDENTITIES_JSON:JSON.stringify([
    {email:'a@example.test',password:'StrongPass1!'},
    {email:'b@example.test',password:'StrongPass2!'},
  ]),
};

function env(overrides={}){return {...BASE,...overrides};}
function rejects(overrides,pattern){
  assert.throws(()=>parseLoadConfig(env(overrides)),pattern);
}

test('accepts an explicitly confirmed isolated managed target',()=>{
  const c=parseLoadConfig(env());
  assert.equal(c.projectRef,'abcdefghijklmnopqrst');
  assert.equal(c.concurrency,2);
  assert.equal(c.durationSeconds,300);
  assert.equal(c.maxErrorRate,null);
  assert.equal(c.maxP95Ms,null);
});

test('requires exact destructive-load confirmation phrase',()=>{
  rejects({RAAHI_LOAD_CONFIRM_TARGET:''},/MISSING_RAAHI_LOAD_CONFIRM_TARGET/);
  rejects({RAAHI_LOAD_CONFIRM_TARGET:'yes'},/LOAD_TARGET_NOT_EXPLICITLY_CONFIRMED/);
});

test('binds the typed expected ref to the actual Supabase URL',()=>{
  rejects({RAAHI_LOAD_EXPECTED_PROJECT_REF:'differentprojectref'},/LOAD_PROJECT_REF_MISMATCH/);
});

test('forbids Raahi Learning DEV project and DEV origin',()=>{
  rejects({RAAHI_LOAD_SUPABASE_URL:'https://iiwwmqokaeflaenhlyip.supabase.co',RAAHI_LOAD_EXPECTED_PROJECT_REF:'iiwwmqokaeflaenhlyip'},/FORBIDDEN_LOAD_PROJECT_iiwwmqokaeflaenhlyip/);
  rejects({RAAHI_LOAD_ORIGIN:'https://dev.learning.myraahi.co.in'},/FORBIDDEN_LOAD_ORIGIN/);
});

test('forbids separate Where Is My Raahi project',()=>{
  rejects({RAAHI_LOAD_SUPABASE_URL:'https://hoshprxoyhjyyigxkang.supabase.co',RAAHI_LOAD_EXPECTED_PROJECT_REF:'hoshprxoyhjyyigxkang'},/FORBIDDEN_LOAD_PROJECT_hoshprxoyhjyyigxkang/);
});

test('requires managed Supabase URL, HTTPS origin and publishable key',()=>{
  rejects({RAAHI_LOAD_SUPABASE_URL:'https://example.com'},/SUPABASE_URL_NOT_MANAGED_PROJECT/);
  rejects({RAAHI_LOAD_ORIGIN:'http://learning.example.test'},/LOAD_ORIGIN_MUST_BE_HTTPS/);
  rejects({RAAHI_LOAD_PUBLISHABLE_KEY:'service_role_secret'},/LOAD_KEY_MUST_BE_PUBLISHABLE/);
});

test('requires non-empty unique identities and bounded concurrency',()=>{
  rejects({RAAHI_LOAD_IDENTITIES_JSON:'[]'},/LOAD_IDENTITIES_EMPTY/);
  rejects({RAAHI_LOAD_IDENTITIES_JSON:'not json'},/INVALID_RAAHI_LOAD_IDENTITIES_JSON/);
  rejects({RAAHI_LOAD_IDENTITIES_JSON:JSON.stringify([
    {email:'same@example.test',password:'one'},
    {email:'SAME@example.test',password:'two'},
  ])},/LOAD_IDENTITIES_NOT_UNIQUE/);
  rejects({RAAHI_LOAD_CONCURRENCY:'3'},/LOAD_CONCURRENCY_EXCEEDS_IDENTITIES/);
  rejects({RAAHI_LOAD_CONCURRENCY:'201'},/INVALID_RAAHI_LOAD_CONCURRENCY/);
});

test('bounds duration and parses optional thresholds',()=>{
  rejects({RAAHI_LOAD_DURATION_SECONDS:'9'},/INVALID_RAAHI_LOAD_DURATION_SECONDS/);
  rejects({RAAHI_LOAD_DURATION_SECONDS:'3601'},/INVALID_RAAHI_LOAD_DURATION_SECONDS/);
  rejects({RAAHI_LOAD_MAX_P95_MS:'-1'},/INVALID_RAAHI_LOAD_MAX_P95_MS/);
  const c=parseLoadConfig(env({RAAHI_LOAD_DURATION_SECONDS:'60',RAAHI_LOAD_MAX_ERROR_RATE:'0.01',RAAHI_LOAD_MAX_P95_MS:'1500'}));
  assert.equal(c.durationSeconds,60);
  assert.equal(c.maxErrorRate,0.01);
  assert.equal(c.maxP95Ms,1500);
});

test('summarizes latency percentiles deterministically',()=>{
  assert.deepEqual(summarizeSamples([50,10,40,20,30]),{
    count:5,p50_ms:30,p95_ms:50,p99_ms:50,max_ms:50,
  });
});

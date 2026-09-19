import test from 'node:test';
import assert from 'node:assert/strict';
import { parseLoadConfig, summarizeSamples } from './raahi-learning-e2e/production-like-load.mjs';

function base(){
  return {
    RAAHI_LOAD_CONFIRM_TARGET:'PRODUCTION_LIKE_ISOLATED',
    RAAHI_LOAD_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',
    RAAHI_LOAD_PUBLISHABLE_KEY:'sb_publishable_test_only_key',
    RAAHI_LOAD_ORIGIN:'https://learning.example.test',
    RAAHI_LOAD_IDENTITIES_JSON:JSON.stringify([
      {email:'a@example.test',password:'not-a-real-secret-Aa1!'},
      {email:'b@example.test',password:'not-a-real-secret-Bb1!'},
    ]),
    RAAHI_LOAD_CONCURRENCY:'2',
    RAAHI_LOAD_DURATION_SECONDS:'30',
  };
}

test('requires explicit isolated-target confirmation',()=>{
  const env=base();
  delete env.RAAHI_LOAD_CONFIRM_TARGET;
  assert.throws(()=>parseLoadConfig(env),/MISSING_RAAHI_LOAD_CONFIRM_TARGET/);
  env.RAAHI_LOAD_CONFIRM_TARGET='NO';
  assert.throws(()=>parseLoadConfig(env),/LOAD_TARGET_NOT_EXPLICITLY_CONFIRMED/);
});

test('refuses the Raahi Learning DEV project',()=>{
  const env=base();
  env.RAAHI_LOAD_SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
  assert.throws(()=>parseLoadConfig(env),/FORBIDDEN_LOAD_PROJECT_iiwwmqokaeflaenhlyip/);
});

test('refuses the separate Where Is My Raahi project',()=>{
  const env=base();
  env.RAAHI_LOAD_SUPABASE_URL='https://hoshprxoyhjyyigxkang.supabase.co';
  assert.throws(()=>parseLoadConfig(env),/FORBIDDEN_LOAD_PROJECT_hoshprxoyhjyyigxkang/);
});

test('refuses the Learning DEV origin even with a different project ref',()=>{
  const env=base();
  env.RAAHI_LOAD_ORIGIN='https://dev.learning.myraahi.co.in';
  assert.throws(()=>parseLoadConfig(env),/FORBIDDEN_LOAD_ORIGIN/);
});

test('requires HTTPS production-like origin',()=>{
  const env=base();
  env.RAAHI_LOAD_ORIGIN='http://learning.example.test';
  assert.throws(()=>parseLoadConfig(env),/LOAD_ORIGIN_MUST_BE_HTTPS/);
});

test('requires a publishable client key',()=>{
  const env=base();
  env.RAAHI_LOAD_PUBLISHABLE_KEY='not-a-publishable-key';
  assert.throws(()=>parseLoadConfig(env),/LOAD_KEY_MUST_BE_PUBLISHABLE/);
});

test('requires unique identities and enough identities for concurrency',()=>{
  const env=base();
  env.RAAHI_LOAD_IDENTITIES_JSON=JSON.stringify([
    {email:'same@example.test',password:'one-Aa1!'},
    {email:'same@example.test',password:'two-Aa1!'},
  ]);
  assert.throws(()=>parseLoadConfig(env),/LOAD_IDENTITIES_NOT_UNIQUE/);

  const env2=base();
  env2.RAAHI_LOAD_CONCURRENCY='3';
  assert.throws(()=>parseLoadConfig(env2),/LOAD_CONCURRENCY_EXCEEDS_IDENTITIES/);
});

test('accepts a guarded isolated production-like configuration',()=>{
  const config=parseLoadConfig(base());
  assert.equal(config.projectRef,'abcdefghijklmnopqrst');
  assert.equal(config.identities.length,2);
  assert.equal(config.concurrency,2);
  assert.equal(config.durationSeconds,30);
});

test('summarizes latency samples deterministically',()=>{
  assert.deepEqual(summarizeSamples([100,200,300,400,500]),{
    count:5,p50_ms:300,p95_ms:500,p99_ms:500,max_ms:500,
  });
  assert.deepEqual(summarizeSamples([]),{
    count:0,p50_ms:null,p95_ms:null,p99_ms:null,max_ms:null,
  });
});

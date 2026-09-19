import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCanaryConfig } from './raahi-learning-e2e/production-canary.mjs';

function base(){
  return {
    RAAHI_CANARY_CONFIRM_TARGET:'NON_DEV_LEARNING_TARGET',
    RAAHI_CANARY_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',
    RAAHI_CANARY_EXPECTED_PROJECT_REF:'abcdefghijklmnopqrst',
    RAAHI_CANARY_PUBLISHABLE_KEY:'sb_publishable_test_only_key',
    RAAHI_CANARY_ORIGIN:'https://learning.example.test',
    RAAHI_CANARY_PRIMARY_EMAIL:'primary@example.test',
    RAAHI_CANARY_PRIMARY_PASSWORD:'not-a-real-secret-Aa1!',
    RAAHI_CANARY_UNRELATED_EMAIL:'other@example.test',
    RAAHI_CANARY_UNRELATED_PASSWORD:'not-a-real-secret-Bb1!',
  };
}

test('canary requires explicit non-DEV target confirmation',()=>{
  const env=base();
  env.RAAHI_CANARY_CONFIRM_TARGET='NO';
  assert.throws(()=>parseCanaryConfig(env),/CANARY_TARGET_NOT_EXPLICITLY_CONFIRMED/);
});

test('canary binds typed expected project ref to actual Supabase URL',()=>{
  const env=base();
  env.RAAHI_CANARY_EXPECTED_PROJECT_REF='differentprojectref';
  assert.throws(()=>parseCanaryConfig(env),/CANARY_PROJECT_REF_MISMATCH/);
});

test('canary refuses both existing non-production projects',()=>{
  const learning=base();
  learning.RAAHI_CANARY_SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
  learning.RAAHI_CANARY_EXPECTED_PROJECT_REF='iiwwmqokaeflaenhlyip';
  assert.throws(()=>parseCanaryConfig(learning),/FORBIDDEN_CANARY_PROJECT_iiwwmqokaeflaenhlyip/);

  const ride=base();
  ride.RAAHI_CANARY_SUPABASE_URL='https://hoshprxoyhjyyigxkang.supabase.co';
  ride.RAAHI_CANARY_EXPECTED_PROJECT_REF='hoshprxoyhjyyigxkang';
  assert.throws(()=>parseCanaryConfig(ride),/FORBIDDEN_CANARY_PROJECT_hoshprxoyhjyyigxkang/);
});

test('canary refuses DEV origin and non-publishable key',()=>{
  const dev=base();
  dev.RAAHI_CANARY_ORIGIN='https://dev.learning.myraahi.co.in';
  assert.throws(()=>parseCanaryConfig(dev),/FORBIDDEN_CANARY_ORIGIN/);

  const key=base();
  key.RAAHI_CANARY_PUBLISHABLE_KEY='service-role-not-allowed';
  assert.throws(()=>parseCanaryConfig(key),/CANARY_KEY_MUST_BE_PUBLISHABLE/);
});

test('canary requires distinct test identities',()=>{
  const env=base();
  env.RAAHI_CANARY_UNRELATED_EMAIL=env.RAAHI_CANARY_PRIMARY_EMAIL.toUpperCase();
  assert.throws(()=>parseCanaryConfig(env),/CANARY_IDENTITIES_MUST_DIFFER/);
});

test('canary accepts an isolated non-DEV Learning target',()=>{
  const config=parseCanaryConfig(base());
  assert.equal(config.projectRef,'abcdefghijklmnopqrst');
  assert.equal(config.origin,'https://learning.example.test');
});

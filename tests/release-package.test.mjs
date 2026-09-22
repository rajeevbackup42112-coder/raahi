import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

function makeFixture(root){
  const source=path.join(root,'source');fs.mkdirSync(source);
  for(const name of ['styles.css','app.live-core-v13.js','live-product-fix-v13.js','live-thread-deeplink-v13.js','launch-polish-v13.js','delight-v14.css','delight-v14.js','market-activation-v14b.js','founding-supply-v14c.js','admin-management-v14e.js'])fs.writeFileSync(path.join(source,name),'/* package fixture */');
  fs.writeFileSync(path.join(source,'privacy.html'),'<html>Privacy</html>');
  fs.writeFileSync(path.join(source,'terms.html'),'<html>Terms</html>');
  fs.writeFileSync(path.join(source,'live.js'),"const SUPABASE_URL = 'https://iiwwmqokaeflaenhlyip.supabase.co';\nconst SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';");
  fs.writeFileSync(path.join(source,'dev-test-login-v13.html'),'NEVER SHIP');
  fs.writeFileSync(path.join(source,'build-meta.json'),JSON.stringify({commit_sha:'a'.repeat(40)}));
  return source;
}

test('Dedicated production packaging refuses DEV, secrets and overwrite; ships public launch surfaces only',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'raahi-release-test-'));
  try{
    const source=makeFixture(root);
    const output=path.join(root,'candidate');
    const env={...process.env,RAAHI_RELEASE_MODE:'NON_DEV',RAAHI_RELEASE_CONFIRM_TARGET:'NON_DEV_LEARNING_TARGET',RAAHI_RELEASE_PROJECT_REF:'abcdefghijklmnopqrst',RAAHI_RELEASE_PUBLISHABLE_KEY:'sb_publishable_test_only',RAAHI_RELEASE_ORIGIN:'https://learning.example.com',RAAHI_RELEASE_COMMIT:'a'.repeat(40),RAAHI_RELEASE_SOURCE:source,RAAHI_RELEASE_OUTPUT:output};
    const run=overrides=>spawnSync(process.execPath,['scripts/prepare-learning-release.mjs'],{env:{...env,...overrides},encoding:'utf8'});
    for(const overrides of [{RAAHI_RELEASE_PROJECT_REF:'iiwwmqokaeflaenhlyip'},{RAAHI_RELEASE_PUBLISHABLE_KEY:'sb_secret_never'},{RAAHI_RELEASE_ORIGIN:'https://dev.learning.myraahi.co.in'},{RAAHI_RELEASE_COMMIT:'main'},{RAAHI_RELEASE_CONFIRM_TARGET:'wrong'}]){
      assert.notEqual(run(overrides).status,0);assert.equal(fs.existsSync(output),false);
    }
    assert.equal(run({}).status,0);
    assert.equal(fs.existsSync(path.join(output,'dev-test-login-v13.html')),false);
    assert.equal(fs.existsSync(path.join(output,'privacy.html')),true);
    assert.equal(fs.existsSync(path.join(output,'terms.html')),true);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/launch-polish-v13\.js/);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/delight-v14\.css/);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/delight-v14\.js/);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/market-activation-v14b\.js/);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/founding-supply-v14c\.js/);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/admin-management-v14e\.js/);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/\"phoneTrustMode\":\"phone_trust_required\"/);
    assert.match(fs.readFileSync(path.join(output,'index.html'),'utf8'),/\"phoneTrustProvider\":\"disabled\"/);
    assert.equal(fs.readFileSync(path.join(output,'live.js'),'utf8').includes('iiwwmqokaeflaenhlyip'),false);
    const meta=JSON.parse(fs.readFileSync(path.join(output,'build-meta.json'),'utf8'));
    assert.equal(meta.release_mode,'NON_DEV');
    assert.equal(Object.keys(meta.files).length,14);
    assert.notEqual(run({}).status,0);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});

test('Controlled pilot packaging explicitly permits Learning DEV backend but never DEV web origin or ride project',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'raahi-pilot-release-test-'));
  try{
    const source=makeFixture(root);
    const env={...process.env,RAAHI_RELEASE_MODE:'CONTROLLED_PILOT',RAAHI_RELEASE_CONFIRM_TARGET:'CONTROLLED_PILOT_SAME_PROJECT',RAAHI_RELEASE_PROJECT_REF:'iiwwmqokaeflaenhlyip',RAAHI_RELEASE_PUBLISHABLE_KEY:'sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi',RAAHI_RELEASE_ORIGIN:'https://learning.myraahi.co.in',RAAHI_RELEASE_COMMIT:'a'.repeat(40),RAAHI_RELEASE_SOURCE:source};
    const run=(name,overrides={})=>spawnSync(process.execPath,['scripts/prepare-learning-release.mjs'],{env:{...env,RAAHI_RELEASE_OUTPUT:path.join(root,name),...overrides},encoding:'utf8'});
    assert.equal(run('ok').status,0);
    const meta=JSON.parse(fs.readFileSync(path.join(root,'ok','build-meta.json'),'utf8'));
    assert.equal(meta.release_mode,'CONTROLLED_PILOT');
    assert.equal(meta.project_ref,'iiwwmqokaeflaenhlyip');
    assert.equal(meta.origin,'https://learning.myraahi.co.in');
    assert.equal(fs.existsSync(path.join(root,'ok','privacy.html')),true);
    assert.equal(fs.existsSync(path.join(root,'ok','terms.html')),true);
    assert.match(fs.readFileSync(path.join(root,'ok','index.html'),'utf8'),/delight-v14\.css/);
    assert.match(fs.readFileSync(path.join(root,'ok','index.html'),'utf8'),/delight-v14\.js/);
    assert.match(fs.readFileSync(path.join(root,'ok','index.html'),'utf8'),/market-activation-v14b\.js/);
    assert.match(fs.readFileSync(path.join(root,'ok','index.html'),'utf8'),/founding-supply-v14c\.js/);
    assert.match(fs.readFileSync(path.join(root,'ok','index.html'),'utf8'),/admin-management-v14e\.js/);
    assert.match(fs.readFileSync(path.join(root,'ok','index.html'),'utf8'),/\"phoneTrustMode\":\"controlled_pilot_google_only\"/);
    assert.match(fs.readFileSync(path.join(root,'ok','index.html'),'utf8'),/\"phoneTrustProvider\":\"disabled\"/);
    assert.notEqual(run('bad-origin',{RAAHI_RELEASE_ORIGIN:'https://dev.learning.myraahi.co.in'}).status,0);
    assert.notEqual(run('bad-ref',{RAAHI_RELEASE_PROJECT_REF:'hoshprxoyhjyyigxkang'}).status,0);
    assert.notEqual(run('bad-confirm',{RAAHI_RELEASE_CONFIRM_TARGET:'NON_DEV_LEARNING_TARGET'}).status,0);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});

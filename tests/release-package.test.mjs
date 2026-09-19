import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

test('Production packaging refuses DEV, secrets and overwrite; excludes diagnostics and fixture entry point',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'raahi-release-test-'));
  try{
    const source=path.join(root,'source');fs.mkdirSync(source);
    for(const name of ['styles.css','app.live-core-v13.js','live-product-fix-v13.js','live-thread-deeplink-v13.js'])fs.writeFileSync(path.join(source,name),'/* package fixture */');
    fs.writeFileSync(path.join(source,'live.js'),"const SUPABASE_URL = 'https://iiwwmqokaeflaenhlyip.supabase.co';\nconst SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';");
    fs.writeFileSync(path.join(source,'dev-test-login-v13.html'),'NEVER SHIP');
    fs.writeFileSync(path.join(source,'build-meta.json'),JSON.stringify({commit_sha:'a'.repeat(40)}));
    const output=path.join(root,'candidate');
    const env={...process.env,RAAHI_RELEASE_PROJECT_REF:'abcdefghijklmnopqrst',RAAHI_RELEASE_PUBLISHABLE_KEY:'sb_publishable_test_only',RAAHI_RELEASE_ORIGIN:'https://learning.example.com',RAAHI_RELEASE_COMMIT:'a'.repeat(40),RAAHI_RELEASE_SOURCE:source,RAAHI_RELEASE_OUTPUT:output};
    const run=overrides=>spawnSync(process.execPath,['scripts/prepare-learning-release.mjs'],{env:{...env,...overrides},encoding:'utf8'});
    for(const overrides of [{RAAHI_RELEASE_PROJECT_REF:'iiwwmqokaeflaenhlyip'},{RAAHI_RELEASE_PUBLISHABLE_KEY:'sb_secret_never'},{RAAHI_RELEASE_ORIGIN:'https://dev.learning.myraahi.co.in'},{RAAHI_RELEASE_COMMIT:'main'}]){
      assert.notEqual(run(overrides).status,0);assert.equal(fs.existsSync(output),false);
    }
    assert.equal(run({}).status,0);
    assert.equal(fs.existsSync(path.join(output,'dev-test-login-v13.html')),false);
    assert.equal(fs.readFileSync(path.join(output,'index.html'),'utf8').includes('fixture'),false);
    assert.equal(fs.readFileSync(path.join(output,'live.js'),'utf8').includes('iiwwmqokaeflaenhlyip'),false);
    assert.equal(Object.keys(JSON.parse(fs.readFileSync(path.join(output,'build-meta.json'),'utf8')).files).length,6);
    assert.notEqual(run({}).status,0);
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});

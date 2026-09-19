// Offline packaging only. Does not provision infrastructure or deploy anything.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const required=['RAAHI_RELEASE_PROJECT_REF','RAAHI_RELEASE_PUBLISHABLE_KEY','RAAHI_RELEASE_ORIGIN','RAAHI_RELEASE_COMMIT'];
const missing=required.filter(k=>!process.env[k]);
if(missing.length)throw new Error('RELEASE_CONFIGURATION_REQUIRED: '+missing.join(', '));
const ref=process.env.RAAHI_RELEASE_PROJECT_REF;
const key=process.env.RAAHI_RELEASE_PUBLISHABLE_KEY;
const origin=new URL(process.env.RAAHI_RELEASE_ORIGIN);
const commit=process.env.RAAHI_RELEASE_COMMIT;
if(!/^[a-z]{20}$/.test(ref)||['iiwwmqokaeflaenhlyip','hoshprxoyhjyyigxkang'].includes(ref))throw new Error('DEDICATED_PRODUCTION_PROJECT_REQUIRED');
if(!/^sb_publishable_[A-Za-z0-9_-]+$/.test(key)||key==='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi')throw new Error('PRODUCTION_PUBLISHABLE_KEY_REQUIRED');
if(origin.protocol!=='https:'||origin.username||origin.password||origin.port||origin.pathname!=='/'||origin.search||origin.hash||/(^|[.-])(dev|localhost|test|preview)([.-]|$)/i.test(origin.hostname))throw new Error('PRODUCTION_HTTPS_ORIGIN_REQUIRED');
if(!/^[a-f0-9]{40}$/.test(commit))throw new Error('EXACT_RELEASE_COMMIT_REQUIRED');
const source=path.resolve(process.env.RAAHI_RELEASE_SOURCE||'apps/raahi-learning/reconstructed-v13');
const output=path.resolve(process.env.RAAHI_RELEASE_OUTPUT||'release/raahi-learning');
if(output===source||output.startsWith(source+path.sep)||source.startsWith(output+path.sep))throw new Error('SOURCE_OUTPUT_OVERLAP');
if(fs.existsSync(output))throw new Error('OUTPUT_ALREADY_EXISTS');
const sourceMeta=JSON.parse(fs.readFileSync(path.join(source,'build-meta.json'),'utf8'));
if(sourceMeta.commit_sha!==commit)throw new Error('SOURCE_COMMIT_MISMATCH');
const names=['styles.css','live.js','app.live-core-v13.js','live-product-fix-v13.js','live-thread-deeplink-v13.js'];
const files=new Map(names.map(n=>[n,fs.readFileSync(path.join(source,n),'utf8')]));
let live=files.get('live.js');
const devUrl="const SUPABASE_URL = 'https://iiwwmqokaeflaenhlyip.supabase.co';";
const devKey="const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';";
if(live.split(devUrl).length!==2||live.split(devKey).length!==2)throw new Error('SOURCE_CONFIG_CONTRACT_CHANGED');
live=live.replace(devUrl,`const SUPABASE_URL = 'https://${ref}.supabase.co';`).replace(devKey,`const SUPABASE_PUBLISHABLE_KEY = '${key}';`);
files.set('live.js',live);
files.set('index.html',`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="Raahi Learning"><title>Raahi Learning</title><link rel="stylesheet" href="./styles.css"></head>
<body><div id="app"></div>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.116.0/dist/umd/supabase.min.js"></script>
<script src="./live.js"></script><script src="./app.live-core-v13.js"></script>
<script src="./live-product-fix-v13.js"></script><script src="./live-thread-deeplink-v13.js"></script>
</body></html>\n`);
for(const [name,content] of files){
  if(/iiwwmqokaeflaenhlyip|dev\.learning\.myraahi|sb_secret_|dev-test-identities|dev-test-login/.test(content))throw new Error('DEV_OR_SECRET_REFERENCE: '+name);
}
const hashes=Object.fromEntries([...files].map(([name,content])=>[name,crypto.createHash('sha256').update(content).digest('hex')]));
files.set('build-meta.json',JSON.stringify({artifact:'raahi-learning-v1.3-production-candidate',commit_sha:commit,origin:origin.origin,project_ref:ref,files:hashes,qualification:'Unverified candidate: production integration and release gates must pass before deployment.'},null,2)+'\n');
fs.mkdirSync(output,{recursive:true});
for(const [name,content] of files)fs.writeFileSync(path.join(output,name),content);
console.log(JSON.stringify({result:'packaged_not_deployed',output,files:[...files.keys()],commit_sha:commit}));

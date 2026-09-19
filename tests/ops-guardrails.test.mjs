import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const db=fs.readFileSync(new URL('../scripts/raahi-learning-backup-database.sh',import.meta.url),'utf8');
const storage=fs.readFileSync(new URL('../scripts/raahi-learning-backup-storage.sh',import.meta.url),'utf8');

test('database backup script preserves project/environment guards',()=>{
  assert.match(db,/hoshprxoyhjyyigxkang/);
  assert.match(db,/iiwwmqokaeflaenhlyip/);
  assert.match(db,/DEV_TEST\|PRODUCTION_LIKE\|PRODUCTION/);
  assert.match(db,/RAAHI_LEARNING_DB_URL/);
  assert.match(db,/supabase db dump/);
  assert.match(db,/--role-only/);
  assert.match(db,/--use-copy --data-only/);
  assert.match(db,/credential_material_in_manifest=false/);
  assert.match(db,/restore_verified=false/);
});

test('database backup script never embeds a database credential',()=>{
  assert.doesNotMatch(db,/postgres(?:ql)?:\/\/[^\s"'$]*:[^\s"'$]+@/i);
});

test('storage backup script is fixed to Raahi Learning buckets and non-destructive copy',()=>{
  for(const bucket of [
    'ads-public','ads-review-private','class-private',
    'community-public','learner-private-media','public-profile-media',
  ]) assert.match(storage,new RegExp(bucket));

  assert.match(storage,/rclone copy/);
  assert.doesNotMatch(storage,/rclone sync/);
  assert.match(storage,/--checksum/);
  assert.match(storage,/storage_copy_verified=true/);
  assert.match(storage,/restore_verified=false/);
});

test('storage backup script preserves project separation and avoids embedded S3 credentials',()=>{
  assert.match(storage,/hoshprxoyhjyyigxkang/);
  assert.match(storage,/iiwwmqokaeflaenhlyip/);
  assert.doesNotMatch(storage,/aws_access_key_id\s*=/i);
  assert.doesNotMatch(storage,/aws_secret_access_key\s*=/i);
  assert.doesNotMatch(storage,/secret_access_key\s*=/i);
});

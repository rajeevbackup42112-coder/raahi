import fs from 'node:fs';
import { createClient } from '@supabase/supabase-js';

const EXPECTED_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const EXPECTED_CONFIRM='DELETE_RAAHI_LEARNING_HARNESS_AUTH_USERS_FOR_CONTROLLED_PILOT';

function required(name){
  const value=process.env[name]?.trim();
  if(!value) throw new Error(name+'_REQUIRED');
  return value;
}

async function listAll(admin){
  const users=[];
  for(let page=1;page<=20;page++){
    const {data,error}=await admin.auth.admin.listUsers({page,perPage:1000});
    if(error) throw error;
    users.push(...data.users);
    if(data.users.length<1000) return users;
  }
  throw new Error('AUTH_USER_SCAN_LIMIT_EXCEEDED');
}

const url=required('RAAHI_PILOT_SUPABASE_URL');
const serviceRole=required('RAAHI_PILOT_SERVICE_ROLE_KEY');
const confirmation=required('RAAHI_PILOT_AUTH_CLEANUP_CONFIRMATION');

if(url!==EXPECTED_URL) throw new Error('PILOT_AUTH_CLEANUP_WRONG_PROJECT');
if(confirmation!==EXPECTED_CONFIRM) throw new Error('PILOT_AUTH_CLEANUP_CONFIRMATION_MISMATCH');
if(!serviceRole.startsWith('sb_secret_') && !serviceRole.startsWith('eyJ')) throw new Error('PILOT_AUTH_CLEANUP_SERVICE_ROLE_FORMAT_UNEXPECTED');

const admin=createClient(url,serviceRole,{auth:{persistSession:false,autoRefreshToken:false}});
const before=await listAll(admin);
const harness=before.filter(u=>u.user_metadata?.raahi_test_harness===true);
const protectedUsers=before.filter(u=>u.user_metadata?.raahi_test_harness!==true);

if(protectedUsers.length!==8) throw new Error('PILOT_AUTH_CLEANUP_PROTECTED_USER_REVIEW_REQUIRED_'+protectedUsers.length);
if(harness.length<1) throw new Error('PILOT_AUTH_CLEANUP_NO_HARNESS_USERS_FOUND');

for(const user of harness){
  const {error}=await admin.auth.admin.deleteUser(user.id);
  if(error) throw new Error('PILOT_AUTH_DELETE_FAILED_'+user.id+': '+error.message);
}

const after=await listAll(admin);
const remainingHarness=after.filter(u=>u.user_metadata?.raahi_test_harness===true);
const remainingProtected=after.filter(u=>u.user_metadata?.raahi_test_harness!==true);

if(remainingHarness.length!==0) throw new Error('PILOT_AUTH_CLEANUP_HARNESS_USERS_REMAIN_'+remainingHarness.length);
if(remainingProtected.length!==8) throw new Error('PILOT_AUTH_CLEANUP_PROTECTED_USER_COUNT_CHANGED_'+remainingProtected.length);

const report={
  result:'pass',
  project_ref:'iiwwmqokaeflaenhlyip',
  deleted_harness_users:harness.length,
  preserved_non_harness_users:remainingProtected.length,
  completed_at:new Date().toISOString(),
};
const output=process.env.RAAHI_PILOT_AUTH_CLEANUP_REPORT?.trim();
if(output) fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));

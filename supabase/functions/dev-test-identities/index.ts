// Raahi Learning V1.3 — DEV-only deterministic test identity factory.
// Trust boundary: GitHub Actions OIDC from the canonical repository + implementation branch.
// The Supabase service-role key stays inside the Edge Function environment and is never returned.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import { createRemoteJWKSet, jwtVerify } from 'npm:jose@6.1.0';

const EXPECTED_SUPABASE_URL = 'https://iiwwmqokaeflaenhlyip.supabase.co';
const EXPECTED_REPOSITORY = 'rajeevbackup42112-coder/raahi';
const EXPECTED_REF = 'refs/heads/raahi-learning-implementation-v1';
const EXPECTED_AUDIENCE = 'raahi-learning-dev-test-harness';
const GITHUB_ISSUER = 'https://token.actions.githubusercontent.com';
const GITHUB_JWKS = createRemoteJWKSet(
  new URL('https://token.actions.githubusercontent.com/.well-known/jwks')
);

type PersonaSpec = {
  email: string;
  phone: string;
  display_name: string;
  scenario: string;
};

type PersonaSet = Record<string, PersonaSpec>;

const PERSONA_SETS: Record<string, PersonaSet> = {
  core: {
    learner: { email: 'e2e.learner@dev.learning.myraahi.co.in', phone: '+919100000101', display_name: 'E2E Learner Account', scenario: 'foundational learner' },
    teacher: { email: 'e2e.teacher@dev.learning.myraahi.co.in', phone: '+919100000102', display_name: 'E2E Teacher Account', scenario: 'foundational teacher' },
    unrelated: { email: 'e2e.unrelated@dev.learning.myraahi.co.in', phone: '+919100000103', display_name: 'E2E Unrelated Account', scenario: 'foundational unrelated actor' },
    admin: { email: 'e2e.admin@dev.learning.myraahi.co.in', phone: '+919100000104', display_name: 'E2E Platform Admin', scenario: 'foundational platform admin' },
  },
  r4: {
    learner: { email: 'e2e.r4.learner@dev.learning.myraahi.co.in', phone: '+919100000201', display_name: 'R4 E2E Learner Account', scenario: 'R4 learner side' },
    teacher: { email: 'e2e.r4.teacher@dev.learning.myraahi.co.in', phone: '+919100000202', display_name: 'R4 E2E Teacher Account', scenario: 'R4 provider side' },
    unrelated: { email: 'e2e.r4.unrelated@dev.learning.myraahi.co.in', phone: '+919100000203', display_name: 'R4 E2E Unrelated Account', scenario: 'R4 privacy actor' },
    admin: { email: 'e2e.r4.admin@dev.learning.myraahi.co.in', phone: '+919100000204', display_name: 'R4 E2E Platform Admin', scenario: 'R4 fixture admin' },
  },
  ui: {
    learner: { email: 'e2e.ui.learner@dev.learning.myraahi.co.in', phone: '+919100000301', display_name: 'UI E2E Learner', scenario: 'UI convergence learner' },
    teacher: { email: 'e2e.ui.teacher@dev.learning.myraahi.co.in', phone: '+919100000302', display_name: 'UI E2E Teacher', scenario: 'UI convergence teacher' },
    parent: { email: 'e2e.ui.parent@dev.learning.myraahi.co.in', phone: '+919100000303', display_name: 'UI E2E Parent', scenario: 'UI convergence parent' },
    unrelated: { email: 'e2e.ui.unrelated@dev.learning.myraahi.co.in', phone: '+919100000304', display_name: 'UI E2E Unrelated', scenario: 'UI convergence privacy actor' },
  },
  ui2: {
    parent: { email: 'e2e.ui2.parent@dev.learning.myraahi.co.in', phone: '+919100000401', display_name: 'UI2 E2E Parent', scenario: 'managed-parent UI convergence' },
    org_owner: { email: 'e2e.ui2.org_owner@dev.learning.myraahi.co.in', phone: '+919100000402', display_name: 'UI2 E2E Organization Owner', scenario: 'organization owner UI convergence' },
    unrelated: { email: 'e2e.ui2.unrelated@dev.learning.myraahi.co.in', phone: '+919100000403', display_name: 'UI2 E2E Unrelated', scenario: 'UI2 privacy actor' },
    staff: { email: 'e2e.ui2.staff@dev.learning.myraahi.co.in', phone: '+919100000404', display_name: 'UI2 E2E Staff', scenario: 'organization staff UI convergence' },
  },
  ui3: {
    manager: { email: 'e2e.ui3.manager@dev.learning.myraahi.co.in', phone: '+919100000501', display_name: 'UI3 E2E Local Manager', scenario: 'Local Manager UI convergence' },
    admin: { email: 'e2e.ui3.admin@dev.learning.myraahi.co.in', phone: '+919100000502', display_name: 'UI3 E2E Platform Admin', scenario: 'Platform Admin UI convergence' },
    ads_operator: { email: 'e2e.ui3.ads@dev.learning.myraahi.co.in', phone: '+919100000503', display_name: 'UI3 E2E Ads Operator', scenario: 'Ads operator UI convergence' },
    safety: { email: 'e2e.ui3.safety@dev.learning.myraahi.co.in', phone: '+919100000504', display_name: 'UI3 E2E Safety Reviewer', scenario: 'Safety reviewer UI convergence' },
  },
  ui4_ads: {
    org_owner: { email: 'e2e.ui4ads.org_owner@dev.learning.myraahi.co.in', phone: '+919100000611', display_name: 'UI4 Ads E2E Owner', scenario: 'Raahi Ads organization owner convergence' },
  },
  ui4_staff: {
    org_owner: { email: 'e2e.ui4staff.org_owner@dev.learning.myraahi.co.in', phone: '+919100000621', display_name: 'UI4 Staff E2E Owner', scenario: 'Organization staff capability owner' },
    staff_profile: { email: 'e2e.ui4staff.profile@dev.learning.myraahi.co.in', phone: '+919100000622', display_name: 'UI4 Staff E2E Profile', scenario: 'Organization profile-limited staff convergence' },
    staff_ads: { email: 'e2e.ui4staff.ads@dev.learning.myraahi.co.in', phone: '+919100000623', display_name: 'UI4 Staff E2E Ads', scenario: 'Organization ads-limited staff convergence' },
    unrelated: { email: 'e2e.ui4staff.unrelated@dev.learning.myraahi.co.in', phone: '+919100000624', display_name: 'UI4 Staff E2E Unrelated', scenario: 'Organization staff privacy actor' },
  },
  ui4: {
    org_owner: { email: 'e2e.ui4.org_owner@dev.learning.myraahi.co.in', phone: '+919100000601', display_name: 'UI4 E2E Advertiser Owner', scenario: 'Raahi Ads organization owner convergence' },
    staff_profile: { email: 'e2e.ui4.staff_profile@dev.learning.myraahi.co.in', phone: '+919100000602', display_name: 'UI4 E2E Profile Staff', scenario: 'Organization profile-limited staff convergence' },
    staff_ads: { email: 'e2e.ui4.staff_ads@dev.learning.myraahi.co.in', phone: '+919100000603', display_name: 'UI4 E2E Ads Staff', scenario: 'Organization ads-limited staff convergence' },
    unrelated: { email: 'e2e.ui4.unrelated@dev.learning.myraahi.co.in', phone: '+919100000604', display_name: 'UI4 E2E Unrelated', scenario: 'Organization staff privacy actor' },
  },
  sidefx_enquiry: {
    learner: { email: 'e2e.sidefx.learner@dev.learning.myraahi.co.in', phone: '+919100000701', display_name: 'SideFX E2E Learner', scenario: 'Enquiry and Trial side-effect learner' },
    teacher: { email: 'e2e.sidefx.teacher@dev.learning.myraahi.co.in', phone: '+919100000702', display_name: 'SideFX E2E Teacher', scenario: 'Enquiry and Trial side-effect provider' },
    unrelated: { email: 'e2e.sidefx.unrelated@dev.learning.myraahi.co.in', phone: '+919100000703', display_name: 'SideFX E2E Unrelated', scenario: 'Enquiry and Trial side-effect privacy actor' },
  },
  cohort: {
    adult_learner: { email: 'e2e.cohort.adult_learner@dev.learning.myraahi.co.in', phone: '+919100001001', display_name: 'Cohort Adult Learner', scenario: 'adult learner' },
    parent_single: { email: 'e2e.cohort.parent_single@dev.learning.myraahi.co.in', phone: '+919100001002', display_name: 'Cohort Parent Single', scenario: 'parent managing one learner' },
    parent_multi: { email: 'e2e.cohort.parent_multi@dev.learning.myraahi.co.in', phone: '+919100001003', display_name: 'Cohort Parent Multi', scenario: 'parent managing multiple learners' },
    teacher: { email: 'e2e.cohort.teacher@dev.learning.myraahi.co.in', phone: '+919100001004', display_name: 'Cohort Teacher', scenario: 'teacher' },
    teacher_parent: { email: 'e2e.cohort.teacher_parent@dev.learning.myraahi.co.in', phone: '+919100001005', display_name: 'Cohort Teacher Parent', scenario: 'teacher plus parent' },
    second_teacher: { email: 'e2e.cohort.second_teacher@dev.learning.myraahi.co.in', phone: '+919100001006', display_name: 'Cohort Second Teacher', scenario: 'second teacher / cross-provider actor' },
    unrelated: { email: 'e2e.cohort.unrelated@dev.learning.myraahi.co.in', phone: '+919100001007', display_name: 'Cohort Unrelated', scenario: 'unrelated privacy actor' },
    org_owner: { email: 'e2e.cohort.org_owner@dev.learning.myraahi.co.in', phone: '+919100001008', display_name: 'Cohort Organization Owner', scenario: 'organization owner' },
    org_staff_profile: { email: 'e2e.cohort.org_staff_profile@dev.learning.myraahi.co.in', phone: '+919100001009', display_name: 'Cohort Org Staff Profile', scenario: 'organization profile-limited staff' },
    org_staff_teaching: { email: 'e2e.cohort.org_staff_teaching@dev.learning.myraahi.co.in', phone: '+919100001010', display_name: 'Cohort Org Staff Teaching', scenario: 'organization teaching-options staff' },
    org_staff_classes: { email: 'e2e.cohort.org_staff_classes@dev.learning.myraahi.co.in', phone: '+919100001011', display_name: 'Cohort Org Staff Classes', scenario: 'organization class-management staff' },
    org_staff_members: { email: 'e2e.cohort.org_staff_members@dev.learning.myraahi.co.in', phone: '+919100001012', display_name: 'Cohort Org Staff Members', scenario: 'organization member-management staff' },
    org_staff_ads: { email: 'e2e.cohort.org_staff_ads@dev.learning.myraahi.co.in', phone: '+919100001013', display_name: 'Cohort Org Staff Ads', scenario: 'organization ads staff' },
    local_manager: { email: 'e2e.cohort.local_manager@dev.learning.myraahi.co.in', phone: '+919100001014', display_name: 'Cohort Local Manager', scenario: 'location-scoped manager' },
    admin: { email: 'e2e.cohort.admin@dev.learning.myraahi.co.in', phone: '+919100001015', display_name: 'Cohort Platform Admin', scenario: 'platform admin' },
    safety_reviewer: { email: 'e2e.cohort.safety_reviewer@dev.learning.myraahi.co.in', phone: '+919100001016', display_name: 'Cohort Safety Reviewer', scenario: 'safety reviewer' },
    verifier: { email: 'e2e.cohort.verifier@dev.learning.myraahi.co.in', phone: '+919100001017', display_name: 'Cohort Verifier', scenario: 'verification actor' },
    ads_commercial: { email: 'e2e.cohort.ads_commercial@dev.learning.myraahi.co.in', phone: '+919100001018', display_name: 'Cohort Ads Commercial', scenario: 'ads commercial operator' },
    invite_recipient: { email: 'e2e.cohort.invite_recipient@dev.learning.myraahi.co.in', phone: '+919100001019', display_name: 'Cohort Invite Recipient', scenario: 'private invitation recipient' },
    recovery_actor: { email: 'e2e.cohort.recovery_actor@dev.learning.myraahi.co.in', phone: '+919100001020', display_name: 'Cohort Recovery Actor', scenario: 'recovery / stale-state actor' },
  },
};

type SuiteKey = keyof typeof PERSONA_SETS;

function requireSuite(value: unknown): SuiteKey {
  const suite = String(value || 'core');
  if (!Object.prototype.hasOwnProperty.call(PERSONA_SETS, suite)) throw new Error('TEST_SUITE_NOT_ALLOWED');
  return suite;
}

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

async function requireGithubActionsCaller(req: Request) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
  if (supabaseUrl !== EXPECTED_SUPABASE_URL) throw new Error('DEV_PROJECT_GUARD_FAILED');

  const header = req.headers.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error('GITHUB_OIDC_REQUIRED');

  const { payload } = await jwtVerify(match[1], GITHUB_JWKS, {
    issuer: GITHUB_ISSUER,
    audience: EXPECTED_AUDIENCE,
  });

  if (payload.repository !== EXPECTED_REPOSITORY) throw new Error('GITHUB_REPOSITORY_NOT_ALLOWED');
  if (payload.ref !== EXPECTED_REF) throw new Error('GITHUB_REF_NOT_ALLOWED');
  return payload;
}

function requirePassword(value: unknown) {
  const password = String(value || '');
  if (password.length < 24) throw new Error('TEST_PASSWORD_TOO_SHORT');
  if (!/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/\d/.test(password) || !/[^A-Za-z0-9]/.test(password)) {
    throw new Error('TEST_PASSWORD_COMPLEXITY_REQUIRED');
  }
  return password;
}

async function listAuthUsers(admin: ReturnType<typeof createClient>) {
  const all = [];
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    all.push(...data.users);
    if (data.users.length < 1000) return all;
  }
  throw new Error('AUTH_USER_SCAN_LIMIT_EXCEEDED');
}

async function findAuthUserByEmail(admin: ReturnType<typeof createClient>, email: string) {
  const users = await listAuthUsers(admin);
  return users.find((user) => user.email?.toLowerCase() === email.toLowerCase()) || null;
}

async function ensurePersona(
  admin: ReturnType<typeof createClient>,
  suite: SuiteKey,
  key: string,
  spec: PersonaSpec,
  password: string,
  runId: string,
  existing: ReturnType<typeof Array.prototype.find>,
) {
  const metadata = {
    ...(existing?.user_metadata || {}),
    raahi_test_harness: true,
    raahi_test_suite: suite,
    raahi_test_persona: key,
    raahi_test_scenario: spec.scenario,
    raahi_test_run_id: runId,
    display_name: spec.display_name,
  };

  if (existing) {
    const { data, error } = await admin.auth.admin.updateUserById(existing.id, {
      password,
      email_confirm: true,
      phone: spec.phone,
      phone_confirm: true,
      user_metadata: metadata,
    });
    if (error) throw error;
    return { key, scenario: spec.scenario, auth_user_id: data.user.id, email: spec.email, phone: spec.phone, created: false };
  }

  const { data, error } = await admin.auth.admin.createUser({
    email: spec.email,
    password,
    email_confirm: true,
    phone: spec.phone,
    phone_confirm: true,
    user_metadata: metadata,
  });
  if (error) throw error;
  return { key, scenario: spec.scenario, auth_user_id: data.user.id, email: spec.email, phone: spec.phone, created: true };
}

async function ensureAdminCapability(admin: ReturnType<typeof createClient>, suite: SuiteKey) {
  const adminSpec = PERSONA_SETS[suite]?.admin;
  if (!adminSpec) throw new Error('ADMIN_PERSONA_NOT_DEFINED_FOR_SUITE');
  const authUser = await findAuthUserByEmail(admin, adminSpec.email);
  if (!authUser) throw new Error('ADMIN_TEST_AUTH_USER_NOT_FOUND');

  const { data: account, error: accountError } = await admin
    .from('accounts')
    .select('id,lifecycle_status')
    .eq('auth_user_id', authUser.id)
    .maybeSingle();
  if (accountError) throw accountError;
  if (!account) throw new Error('ADMIN_TEST_ACCOUNT_NOT_BOOTSTRAPPED');
  if (account.lifecycle_status !== 'active') throw new Error('ADMIN_TEST_ACCOUNT_NOT_ACTIVE');

  const { data: existing, error: existingError } = await admin
    .from('account_capabilities')
    .select('id,status')
    .eq('account_id', account.id)
    .eq('capability_code', 'platform_admin')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existingError) throw existingError;

  if (existing?.status === 'active') return { account_id: account.id, capability_id: existing.id, already_active: true };

  if (existing?.id) {
    const { error } = await admin
      .from('account_capabilities')
      .update({ status: 'active', revoked_at: null, granted_by_account_id: null })
      .eq('id', existing.id);
    if (error) throw error;
    return { account_id: account.id, capability_id: existing.id, already_active: false };
  }

  const { data: inserted, error } = await admin
    .from('account_capabilities')
    .insert({ account_id: account.id, capability_code: 'platform_admin', status: 'active', granted_by_account_id: null })
    .select('id')
    .single();
  if (error) throw error;
  return { account_id: account.id, capability_id: inserted.id, already_active: false };
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return response(405, { ok: false, error: 'POST_REQUIRED' });

  try {
    const claims = await requireGithubActionsCaller(req);
    const body = await req.json();
    const action = String(body?.action || '');
    const runId = String(body?.run_id || '').trim();
    const suite = requireSuite(body?.suite);

    if (!/^[A-Za-z0-9._-]{6,120}$/.test(runId)) return response(400, { ok: false, error: 'INVALID_RUN_ID' });

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (action === 'ensure_personas') {
      const supplied = body?.passwords || {};
      const specs = PERSONA_SETS[suite];
      const users = await listAuthUsers(admin);
      const byEmail = new Map(users.map((user) => [String(user.email || '').toLowerCase(), user]));
      const results = [];

      for (const [key, spec] of Object.entries(specs)) {
        results.push(await ensurePersona(
          admin,
          suite,
          key,
          spec,
          requirePassword(supplied[key]),
          runId,
          byEmail.get(spec.email.toLowerCase()) || null,
        ));
      }

      console.log('[dev-test-identities] ensured personas', {
        run_id: runId,
        suite,
        repository: claims.repository,
        ref: claims.ref,
        count: results.length,
        personas: results.map((x) => x.key),
      });
      return response(200, { ok: true, run_id: runId, suite, personas: results });
    }

    if (action === 'ensure_admin_capability') {
      const result = await ensureAdminCapability(admin, suite);
      console.log('[dev-test-identities] ensured admin capability', {
        run_id: runId,
        suite,
        repository: claims.repository,
        ref: claims.ref,
      });
      return response(200, { ok: true, run_id: runId, suite, admin: result });
    }

    if (action === 'inspect_enquiry_trial_audit') {
      if (suite !== 'sidefx_enquiry') throw new Error('AUDIT_INSPECTION_SUITE_NOT_ALLOWED');
      const trialEventId = String(body?.trial_event_id || '');
      if (!/^[0-9a-f-]{36}$/i.test(trialEventId)) throw new Error('INVALID_TRIAL_EVENT_ID');

      const { data: audits, error: auditError } = await admin
        .from('audit_log')
        .select('id,actor_account_id,action_type,target_type,target_id,metadata,created_at')
        .eq('target_type','enquiry_trial_event')
        .eq('target_id',trialEventId)
        .in('action_type',['trial.reschedule','trial.cancel'])
        .order('created_at',{ascending:true});
      if (auditError) throw auditError;

      return response(200,{
        ok:true,
        run_id:runId,
        suite,
        audit_rows:(audits || []).map((row:any)=>({
          id:row.id,
          actor_account_id:row.actor_account_id,
          action_type:row.action_type,
          target_type:row.target_type,
          target_id:row.target_id,
          metadata:row.metadata,
          created_at:row.created_at,
        }))
      });
    }

    return response(400, { ok: false, error: 'UNKNOWN_ACTION' });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('[dev-test-identities] rejected', message);
    const authFailure =
      message.includes('GITHUB_') ||
      message.includes('DEV_PROJECT_GUARD') ||
      message.includes('JWT') ||
      message.includes('signature') ||
      message.includes('audience') ||
      message.includes('issuer');
    return response(authFailure ? 403 : 500, { ok: false, error: message });
  }
});

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

const PERSONAS = {
  learner: {
    email: 'e2e.learner@dev.learning.myraahi.co.in',
    display_name: 'E2E Learner Account',
  },
  teacher: {
    email: 'e2e.teacher@dev.learning.myraahi.co.in',
    display_name: 'E2E Teacher Account',
  },
  unrelated: {
    email: 'e2e.unrelated@dev.learning.myraahi.co.in',
    display_name: 'E2E Unrelated Account',
  },
  admin: {
    email: 'e2e.admin@dev.learning.myraahi.co.in',
    display_name: 'E2E Platform Admin',
  },
} as const;

type PersonaKey = keyof typeof PERSONAS;

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
  if (supabaseUrl !== EXPECTED_SUPABASE_URL) {
    throw new Error('DEV_PROJECT_GUARD_FAILED');
  }

  const header = req.headers.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error('GITHUB_OIDC_REQUIRED');

  const { payload } = await jwtVerify(match[1], GITHUB_JWKS, {
    issuer: GITHUB_ISSUER,
    audience: EXPECTED_AUDIENCE,
  });

  if (payload.repository !== EXPECTED_REPOSITORY) {
    throw new Error('GITHUB_REPOSITORY_NOT_ALLOWED');
  }
  if (payload.ref !== EXPECTED_REF) {
    throw new Error('GITHUB_REF_NOT_ALLOWED');
  }
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

async function findAuthUserByEmail(admin: ReturnType<typeof createClient>, email: string) {
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    const found = data.users.find((user) => user.email?.toLowerCase() === email.toLowerCase());
    if (found) return found;
    if (data.users.length < 1000) return null;
  }
  throw new Error('AUTH_USER_SCAN_LIMIT_EXCEEDED');
}

async function ensurePersona(
  admin: ReturnType<typeof createClient>,
  key: PersonaKey,
  password: string,
  runId: string,
) {
  const spec = PERSONAS[key];
  const existing = await findAuthUserByEmail(admin, spec.email);
  const metadata = {
    ...(existing?.user_metadata || {}),
    raahi_test_harness: true,
    raahi_test_persona: key,
    raahi_test_run_id: runId,
    display_name: spec.display_name,
  };

  if (existing) {
    const { data, error } = await admin.auth.admin.updateUserById(existing.id, {
      password,
      email_confirm: true,
      user_metadata: metadata,
    });
    if (error) throw error;
    return { key, auth_user_id: data.user.id, email: spec.email, created: false };
  }

  const { data, error } = await admin.auth.admin.createUser({
    email: spec.email,
    password,
    email_confirm: true,
    user_metadata: metadata,
  });
  if (error) throw error;
  return { key, auth_user_id: data.user.id, email: spec.email, created: true };
}

async function ensureAdminCapability(admin: ReturnType<typeof createClient>) {
  const authUser = await findAuthUserByEmail(admin, PERSONAS.admin.email);
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

  if (existing?.status === 'active') {
    return { account_id: account.id, capability_id: existing.id, already_active: true };
  }
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
    .insert({
      account_id: account.id,
      capability_code: 'platform_admin',
      status: 'active',
      granted_by_account_id: null,
    })
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

    if (!/^[A-Za-z0-9._-]{6,120}$/.test(runId)) {
      return response(400, { ok: false, error: 'INVALID_RUN_ID' });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (action === 'ensure_personas') {
      const supplied = body?.passwords || {};
      const results = [];
      for (const key of Object.keys(PERSONAS) as PersonaKey[]) {
        results.push(await ensurePersona(admin, key, requirePassword(supplied[key]), runId));
      }
      console.log('[dev-test-identities] ensured personas', {
        run_id: runId,
        repository: claims.repository,
        ref: claims.ref,
        personas: results.map((x) => x.key),
      });
      return response(200, { ok: true, run_id: runId, personas: results });
    }

    if (action === 'ensure_admin_capability') {
      const result = await ensureAdminCapability(admin);
      console.log('[dev-test-identities] ensured admin capability', {
        run_id: runId,
        repository: claims.repository,
        ref: claims.ref,
      });
      return response(200, { ok: true, run_id: runId, admin: result });
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

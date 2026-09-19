// Raahi Learning V1.3 — MessageCentral VerifyNow phone-trust bridge.
// MessageCentral owns OTP generation + validation. Supabase Auth remains the
// source of truth for confirmed phone and the existing 90-day trust window.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const MC_BASE_URL = 'https://cpaas.messagecentral.com';
const PROVIDER = 'messagecentral';
const MAX_VERIFY_ATTEMPTS = 5;
const USER_SENDS_PER_10_MIN = 3;
const USER_SENDS_PER_DAY = 10;
const PHONE_SENDS_PER_10_MIN = 5;
const ALLOWED_ORIGINS = new Set([
  'https://dev.learning.myraahi.co.in',
  'https://learning.myraahi.co.in',
]);

type Json = Record<string, unknown>;

function corsHeaders(req: Request) {
  const origin = req.headers.get('origin') || '';
  return {
    ...(ALLOWED_ORIGINS.has(origin) ? { 'access-control-allow-origin': origin } : {}),
    'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
    'access-control-allow-methods': 'POST, OPTIONS',
    'vary': 'Origin',
  };
}

function json(req: Request, status: number, body: Json) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      ...corsHeaders(req),
    },
  });
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name)?.trim() || '';
  if (!value) throw new Error('MESSAGECENTRAL_NOT_CONFIGURED');
  return value;
}

function normalizeIndiaPhone(value: unknown) {
  const phone = String(value || '').trim().replace(/[\s()-]/g, '');
  if (!/^\+91[6-9][0-9]{9}$/.test(phone)) throw new Error('INDIA_PHONE_REQUIRED');
  return phone;
}

function mobileWithoutCountry(phone: string) {
  return phone.slice(3);
}

function masked(phone: string) {
  return '••••' + phone.slice(-4);
}

function isFresh(confirmedAt: string | null | undefined) {
  if (!confirmedAt) return false;
  const confirmed = Date.parse(confirmedAt);
  return Number.isFinite(confirmed) && confirmed + 90 * 24 * 60 * 60 * 1000 > Date.now();
}

async function providerAuthToken() {
  const customerId = requiredEnv('MESSAGECENTRAL_CUSTOMER_ID');
  const password = requiredEnv('MESSAGECENTRAL_PASSWORD');
  const email = Deno.env.get('MESSAGECENTRAL_EMAIL')?.trim() || '';
  const key = btoa(String.fromCharCode(...new TextEncoder().encode(password)));

  const params = new URLSearchParams({
    customerId,
    key,
    scope: 'NEW',
    country: '91',
  });
  if (email) params.set('email', email);

  const response = await fetch(`${MC_BASE_URL}/auth/v1/authentication/token?${params.toString()}`, {
    method: 'GET',
    headers: { accept: '*/*' },
  });
  const body = await response.json().catch(() => ({}));

  if (!response.ok || typeof body?.token !== 'string' || !body.token) {
    console.error('[phone-trust-messagecentral] provider token failure', {
      http_status: response.status,
      provider_status: body?.status ?? null,
    });
    throw new Error('MESSAGECENTRAL_AUTH_FAILED');
  }
  return { token: body.token as string, customerId };
}

async function providerSend(phone: string) {
  const { token, customerId } = await providerAuthToken();
  const params = new URLSearchParams({
    countryCode: '91',
    flowType: 'SMS',
    mobileNumber: mobileWithoutCountry(phone),
    otpLength: '6',
    customerId,
  });

  const response = await fetch(`${MC_BASE_URL}/verification/v3/send?${params.toString()}`, {
    method: 'POST',
    headers: { authToken: token, accept: 'application/json' },
  });
  const body = await response.json().catch(() => ({}));
  const responseCode = Number(body?.responseCode ?? body?.data?.responseCode ?? response.status);
  const verificationId = body?.data?.verificationId;

  if (!response.ok || responseCode !== 200 || verificationId == null) {
    console.error('[phone-trust-messagecentral] provider send failure', {
      http_status: response.status,
      response_code: responseCode,
      error: body?.data?.errorMessage ?? body?.message ?? null,
    });
    if (responseCode === 800) throw new Error('PHONE_OTP_PROVIDER_LIMIT');
    if (responseCode === 506) throw new Error('PHONE_OTP_REQUEST_ALREADY_EXISTS');
    throw new Error('PHONE_OTP_SEND_FAILED');
  }

  const timeout = Math.max(60, Math.min(600, Number(body?.data?.timeout || 60) || 60));
  return { verificationId: String(verificationId), timeout };
}

async function providerValidate(verificationId: string, code: string) {
  const { token } = await providerAuthToken();
  const params = new URLSearchParams({ verificationId, code });

  const response = await fetch(`${MC_BASE_URL}/verification/v3/validateOtp?${params.toString()}`, {
    method: 'GET',
    headers: { authToken: token, accept: 'application/json' },
  });
  const body = await response.json().catch(() => ({}));
  const responseCode = Number(body?.responseCode ?? body?.data?.responseCode ?? response.status);
  const verificationStatus = String(body?.data?.verificationStatus || '');

  return {
    ok: response.ok && responseCode === 200 && verificationStatus === 'VERIFICATION_COMPLETED',
    responseCode,
    verificationStatus,
    errorMessage: body?.data?.errorMessage ?? body?.message ?? null,
  };
}

function publicError(error: unknown) {
  const code = String((error as Error)?.message || error || 'PHONE_TRUST_FAILED');
  const statusByCode: Record<string, number> = {
    AUTH_REQUIRED: 401,
    INDIA_PHONE_REQUIRED: 400,
    PHONE_ALREADY_FRESH: 409,
    PHONE_OTP_RATE_LIMIT: 429,
    PHONE_OTP_PROVIDER_LIMIT: 429,
    PHONE_OTP_REQUEST_ALREADY_EXISTS: 409,
    PHONE_OTP_SEND_FAILED: 502,
    MESSAGECENTRAL_AUTH_FAILED: 502,
    MESSAGECENTRAL_NOT_CONFIGURED: 503,
    CHALLENGE_NOT_FOUND: 404,
    CHALLENGE_EXPIRED: 410,
    CHALLENGE_NOT_ACTIVE: 409,
    VERIFY_ATTEMPTS_EXCEEDED: 429,
    INVALID_OTP: 400,
    PHONE_ALREADY_IN_USE: 409,
    PHONE_CONFIRM_FAILED: 502,
  };
  return { code, status: statusByCode[code] || 500 };
}

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_EDGE_ENV_MISSING');
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});

async function requireUser(req: Request) {
  const header = req.headers.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error('AUTH_REQUIRED');
  const { data, error } = await admin.auth.getUser(match[1]);
  if (error || !data.user) throw new Error('AUTH_REQUIRED');
  return { user: data.user, jwt: match[1] };
}

async function countChallenges(filters: {
  authUserId?: string;
  phone?: string;
  since: string;
}) {
  let query = admin
    .from('phone_trust_challenges')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', filters.since);
  if (filters.authUserId) query = query.eq('auth_user_id', filters.authUserId);
  if (filters.phone) query = query.eq('phone_e164', filters.phone);
  const { count, error } = await query;
  if (error) throw error;
  return count || 0;
}

async function sendChallenge(req: Request, user: any, body: any) {
  if (isFresh(user.phone_confirmed_at) && !body?.phone) throw new Error('PHONE_ALREADY_FRESH');

  const existingPhone = user.phone ? normalizeIndiaPhone(user.phone) : null;
  const phone = user.phone_confirmed_at
    ? existingPhone!
    : normalizeIndiaPhone(body?.phone || existingPhone);

  const now = Date.now();
  const tenMinAgo = new Date(now - 10 * 60 * 1000).toISOString();
  const dayAgo = new Date(now - 24 * 60 * 60 * 1000).toISOString();

  const [user10m, userDay, phone10m] = await Promise.all([
    countChallenges({ authUserId: user.id, since: tenMinAgo }),
    countChallenges({ authUserId: user.id, since: dayAgo }),
    countChallenges({ phone, since: tenMinAgo }),
  ]);
  if (
    user10m >= USER_SENDS_PER_10_MIN ||
    userDay >= USER_SENDS_PER_DAY ||
    phone10m >= PHONE_SENDS_PER_10_MIN
  ) throw new Error('PHONE_OTP_RATE_LIMIT');

  const { data: recent, error: recentError } = await admin
    .from('phone_trust_challenges')
    .select('id,phone_e164,expires_at,created_at')
    .eq('auth_user_id', user.id)
    .eq('phone_e164', phone)
    .eq('state', 'sent')
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (recentError) throw recentError;

  if (recent && Date.parse(recent.created_at) > now - 15_000) {
    return json(req, 200, {
      ok: true,
      challenge_id: recent.id,
      masked_phone: masked(recent.phone_e164),
      expires_in: Math.max(1, Math.ceil((Date.parse(recent.expires_at) - now) / 1000)),
      provider: PROVIDER,
      reused: true,
    });
  }

  await admin
    .from('phone_trust_challenges')
    .update({ state: 'expired', updated_at: new Date().toISOString() })
    .eq('auth_user_id', user.id)
    .eq('state', 'sent');

  const sent = await providerSend(phone);
  const createdAt = new Date();
  const expiresAt = new Date(createdAt.getTime() + sent.timeout * 1000);

  const { data: challenge, error } = await admin
    .from('phone_trust_challenges')
    .insert({
      auth_user_id: user.id,
      phone_e164: phone,
      provider: PROVIDER,
      provider_verification_id: sent.verificationId,
      state: 'sent',
      verify_attempts: 0,
      expires_at: expiresAt.toISOString(),
      created_at: createdAt.toISOString(),
      updated_at: createdAt.toISOString(),
    })
    .select('id')
    .single();
  if (error) throw error;

  return json(req, 200, {
    ok: true,
    challenge_id: challenge.id,
    masked_phone: masked(phone),
    expires_in: sent.timeout,
    provider: PROVIDER,
    reused: false,
  });
}

async function verifyChallenge(req: Request, user: any, body: any) {
  const challengeId = String(body?.challenge_id || '');
  const code = String(body?.code || '').trim();
  if (!/^[0-9a-f-]{36}$/i.test(challengeId)) throw new Error('CHALLENGE_NOT_FOUND');
  if (!/^\d{4,8}$/.test(code)) throw new Error('INVALID_OTP');

  const { data: challenge, error } = await admin
    .from('phone_trust_challenges')
    .select('id,auth_user_id,phone_e164,provider_verification_id,state,verify_attempts,expires_at')
    .eq('id', challengeId)
    .eq('auth_user_id', user.id)
    .eq('provider', PROVIDER)
    .maybeSingle();
  if (error) throw error;
  if (!challenge) throw new Error('CHALLENGE_NOT_FOUND');

  if (challenge.state === 'verified') {
    const { data: latest } = await admin.auth.admin.getUserById(user.id);
    if (
      latest.user?.phone === challenge.phone_e164 &&
      latest.user?.phone_confirmed_at
    ) {
      return json(req, 200, {
        ok: true,
        verified: true,
        masked_phone: masked(challenge.phone_e164),
        provider: PROVIDER,
        replay: true,
      });
    }
    throw new Error('CHALLENGE_NOT_ACTIVE');
  }

  if (challenge.state !== 'sent') throw new Error('CHALLENGE_NOT_ACTIVE');
  if (Date.parse(challenge.expires_at) <= Date.now()) {
    await admin.from('phone_trust_challenges')
      .update({ state: 'expired', updated_at: new Date().toISOString() })
      .eq('id', challenge.id);
    throw new Error('CHALLENGE_EXPIRED');
  }
  if (Number(challenge.verify_attempts) >= MAX_VERIFY_ATTEMPTS) {
    await admin.from('phone_trust_challenges')
      .update({ state: 'failed', updated_at: new Date().toISOString() })
      .eq('id', challenge.id);
    throw new Error('VERIFY_ATTEMPTS_EXCEEDED');
  }

  const nextAttempts = Number(challenge.verify_attempts) + 1;
  const { data: locked, error: lockError } = await admin
    .from('phone_trust_challenges')
    .update({ verify_attempts: nextAttempts, updated_at: new Date().toISOString() })
    .eq('id', challenge.id)
    .eq('state', 'sent')
    .eq('verify_attempts', challenge.verify_attempts)
    .select('id')
    .maybeSingle();
  if (lockError) throw lockError;
  if (!locked) throw new Error('CHALLENGE_NOT_ACTIVE');

  const result = await providerValidate(challenge.provider_verification_id, code);

  if (!result.ok) {
    if (result.responseCode === 705) {
      await admin.from('phone_trust_challenges')
        .update({ state: 'expired', updated_at: new Date().toISOString() })
        .eq('id', challenge.id);
      throw new Error('CHALLENGE_EXPIRED');
    }
    if (nextAttempts >= MAX_VERIFY_ATTEMPTS) {
      await admin.from('phone_trust_challenges')
        .update({ state: 'failed', updated_at: new Date().toISOString() })
        .eq('id', challenge.id);
      throw new Error('VERIFY_ATTEMPTS_EXCEEDED');
    }
    if (result.responseCode === 702 || result.responseCode === 700) throw new Error('INVALID_OTP');
    if (result.responseCode === 800) throw new Error('PHONE_OTP_PROVIDER_LIMIT');

    console.error('[phone-trust-messagecentral] provider validation failure', {
      response_code: result.responseCode,
      status: result.verificationStatus,
      error: result.errorMessage,
    });
    throw new Error('INVALID_OTP');
  }

  const { data: updated, error: updateError } = await admin.auth.admin.updateUserById(user.id, {
    phone: challenge.phone_e164,
    phone_confirm: true,
  });
  if (updateError) {
    console.error('[phone-trust-messagecentral] auth confirmation failure', {
      code: updateError.code ?? null,
      status: updateError.status ?? null,
    });
    if (/already|exists|registered/i.test(updateError.message || '')) throw new Error('PHONE_ALREADY_IN_USE');
    throw new Error('PHONE_CONFIRM_FAILED');
  }

  const verifiedAt = updated.user?.phone_confirmed_at || new Date().toISOString();
  const { error: challengeUpdateError } = await admin
    .from('phone_trust_challenges')
    .update({
      state: 'verified',
      verified_at: verifiedAt,
      updated_at: new Date().toISOString(),
    })
    .eq('id', challenge.id);
  if (challengeUpdateError) {
    console.error('[phone-trust-messagecentral] challenge audit update failed', {
      challenge_id: challenge.id,
    });
  }

  return json(req, 200, {
    ok: true,
    verified: true,
    masked_phone: masked(challenge.phone_e164),
    provider: PROVIDER,
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    const origin = req.headers.get('origin') || '';
    if (origin && !ALLOWED_ORIGINS.has(origin)) return json(req, 403, { ok: false, error: 'ORIGIN_NOT_ALLOWED' });
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== 'POST') return json(req, 405, { ok: false, error: 'POST_REQUIRED' });

  try {
    const { user } = await requireUser(req);
    const body = await req.json().catch(() => ({}));
    const action = String(body?.action || '');

    if (action === 'send') return await sendChallenge(req, user, body);
    if (action === 'verify') return await verifyChallenge(req, user, body);
    return json(req, 400, { ok: false, error: 'ACTION_NOT_SUPPORTED' });
  } catch (error) {
    const safe = publicError(error);
    if (safe.status >= 500) console.error('[phone-trust-messagecentral] request failed', { code: safe.code });
    return json(req, safe.status, { ok: false, error: safe.code });
  }
});

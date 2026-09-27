import { createRemoteJWKSet, jwtVerify } from "jose";

export interface Gate13SpikeEnv {
  DB: D1Database;
  ENABLE_GATE13_SSO_SPIKE?: string;
}

const LEARNING_ISSUER = "https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1";
const LEARNING_JWKS = createRemoteJWKSet(
  new URL("https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1/.well-known/jwks.json")
);
const COOKIE_NAME = "raahi_gate13_sso";
const SESSION_SECONDS = 60 * 60;

function spikeJson(data: unknown, status = 200, headers: HeadersInit = {}) {
  const merged = new Headers(headers);
  if (!merged.has("content-type")) merged.set("content-type", "application/json; charset=utf-8");
  if (!merged.has("cache-control")) merged.set("cache-control", "no-store");
  if (!merged.has("x-content-type-options")) merged.set("x-content-type-options", "nosniff");
  return new Response(JSON.stringify(data), { status, headers: merged });
}

function cookieValue(request: Request, name: string) {
  const header = request.headers.get("cookie") ?? "";
  for (const part of header.split(";")) {
    const [key, ...rest] = part.trim().split("=");
    if (key === name) return rest.join("=");
  }
  return null;
}

async function learningIdentity(accessToken: string) {
  const { payload, protectedHeader } = await jwtVerify(accessToken, LEARNING_JWKS, {
    issuer: LEARNING_ISSUER,
    audience: "authenticated",
    algorithms: ["ES256"],
  });

  if (protectedHeader.alg !== "ES256") {
    throw new Error("UNEXPECTED_ALGORITHM");
  }

  if (payload.role !== "authenticated") {
    throw new Error("UNEXPECTED_ROLE");
  }

  if (!payload.sub || typeof payload.sub !== "string") {
    throw new Error("MISSING_SUBJECT");
  }

  return {
    issuer: LEARNING_ISSUER,
    subject: payload.sub,
  };
}

async function handoff(request: Request, env: Gate13SpikeEnv) {
  if (request.method !== "POST") {
    return spikeJson(
      { error: { code: "METHOD_NOT_ALLOWED", message: "POST required." } },
      405,
      { allow: "POST" }
    );
  }

  let accessToken = "";
  try {
    const form = await request.formData();
    const submitted = form.get("access_token");
    accessToken = typeof submitted === "string" ? submitted.trim() : "";
  } catch {
    return spikeJson(
      { error: { code: "INVALID_HANDOFF", message: "Invalid handoff request." } },
      400
    );
  }

  if (!accessToken || accessToken.length > 12000) {
    return spikeJson(
      { error: { code: "INVALID_HANDOFF", message: "Invalid handoff request." } },
      400
    );
  }

  try {
    const identity = await learningIdentity(accessToken);
    // Never persist or log the submitted access token.
    accessToken = "";

    const candidateAccountId = `acct_${crypto.randomUUID()}`;
    await env.DB.prepare(
      `INSERT INTO sso_spike_accounts (id, issuer, subject, created_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(issuer, subject) DO NOTHING`
    )
      .bind(candidateAccountId, identity.issuer, identity.subject, new Date().toISOString())
      .run();

    const account = await env.DB.prepare(
      `SELECT id
       FROM sso_spike_accounts
       WHERE issuer = ? AND subject = ?
       LIMIT 1`
    )
      .bind(identity.issuer, identity.subject)
      .first<{ id: string }>();

    if (!account?.id) {
      throw new Error("ACCOUNT_RESOLUTION_FAILED");
    }

    const sessionId = crypto.randomUUID();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + SESSION_SECONDS * 1000);

    await env.DB.prepare(
      `INSERT INTO sso_spike_sessions
       (id, account_id, created_at, expires_at)
       VALUES (?, ?, ?, ?)`
    )
      .bind(sessionId, account.id, now.toISOString(), expiresAt.toISOString())
      .run();

    const headers = new Headers({
      location: "/?sso_spike=ok",
      "cache-control": "no-store",
      "referrer-policy": "no-referrer",
    });
    headers.append(
      "set-cookie",
      `${COOKIE_NAME}=${sessionId}; Path=/; Max-Age=${SESSION_SECONDS}; HttpOnly; Secure; SameSite=Lax`
    );

    return new Response(null, { status: 303, headers });
  } catch {
    accessToken = "";
    return spikeJson(
      {
        error: {
          code: "HANDOFF_REJECTED",
          message: "This Raahi Learn session could not be verified.",
        },
      },
      401
    );
  }
}

async function me(request: Request, env: Gate13SpikeEnv) {
  if (request.method !== "GET") {
    return spikeJson(
      { error: { code: "METHOD_NOT_ALLOWED", message: "GET required." } },
      405,
      { allow: "GET" }
    );
  }

  const sessionId = cookieValue(request, COOKIE_NAME);
  if (!sessionId) {
    return spikeJson({ authenticated: false }, 401);
  }

  const row = await env.DB.prepare(
    `SELECT s.account_id, a.issuer
     FROM sso_spike_sessions s
     INNER JOIN sso_spike_accounts a ON a.id = s.account_id
     WHERE s.id = ?
       AND s.expires_at > ?
     LIMIT 1`
  )
    .bind(sessionId, new Date().toISOString())
    .first<{ account_id: string; issuer: string }>();

  if (!row) {
    return spikeJson({ authenticated: false }, 401);
  }

  return spikeJson({
    authenticated: true,
    account_id: row.account_id,
    identity_source: "raahi_learn",
    issuer: row.issuer,
    capabilities: [],
    product_roles: [],
  });
}

async function logout(request: Request, env: Gate13SpikeEnv) {
  if (request.method !== "POST") {
    return spikeJson(
      { error: { code: "METHOD_NOT_ALLOWED", message: "POST required." } },
      405,
      { allow: "POST" }
    );
  }

  const sessionId = cookieValue(request, COOKIE_NAME);
  if (sessionId) {
    await env.DB.prepare("DELETE FROM sso_spike_sessions WHERE id = ?")
      .bind(sessionId)
      .run();
  }

  const headers = new Headers({
    "cache-control": "no-store",
  });
  headers.append(
    "set-cookie",
    `${COOKIE_NAME}=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax`
  );
  return spikeJson({ signed_out: true }, 200, headers);
}

export async function handleGate13SsoSpike(
  request: Request,
  env: Gate13SpikeEnv
): Promise<Response | null> {
  const url = new URL(request.url);
  if (!url.pathname.startsWith("/api/v1/_spike/auth/")) return null;

  if (env.ENABLE_GATE13_SSO_SPIKE !== "true") {
    return spikeJson(
      { error: { code: "API_NOT_FOUND", message: "That Raahi API route does not exist." } },
      404
    );
  }

  if (url.pathname === "/api/v1/_spike/auth/learning-handoff") {
    return handoff(request, env);
  }

  if (url.pathname === "/api/v1/_spike/auth/me") {
    return me(request, env);
  }

  if (url.pathname === "/api/v1/_spike/auth/logout") {
    return logout(request, env);
  }

  return spikeJson(
    { error: { code: "API_NOT_FOUND", message: "That Raahi API route does not exist." } },
    404
  );
}

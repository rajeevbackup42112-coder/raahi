// Raahi Learning V1.3
// MessageCentral is intentionally disabled during the Google-only controlled pilot.
// The full implementation remains in git history. Do not re-enable without an
// explicit post-pilot phone-trust decision and fresh provider proof.

Deno.serve((_req: Request) => new Response(
  JSON.stringify({
    ok: false,
    error: 'PHONE_PROVIDER_DISABLED_DURING_GOOGLE_ONLY_PILOT'
  }),
  {
    status: 410,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store'
    }
  }
));

// Raahi Learning V1.3 — CONTROLLED PILOT seal for the DEV test identity factory.
// PREPARED ONLY. Do not deploy during DEV/STAGE.
// At controlled-pilot cutover deploy this source over the existing
// "dev-test-identities" function with verify_jwt=true.
//
// Purpose: make old/manual DEV writer workflows incapable of creating,
// updating, or granting capabilities to synthetic identities after real pilot
// data enters the single Learning Supabase project.

const BODY = JSON.stringify({
  ok: false,
  error: 'DEV_TEST_IDENTITIES_DISABLED_FOR_CONTROLLED_PILOT',
});

Deno.serve((_req: Request) => new Response(BODY, {
  status: 410,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  },
}));

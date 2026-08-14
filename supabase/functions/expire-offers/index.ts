// Raahi — Stage 5.1 — Server-side Offer Expiry Edge Function
// Deploy as a Supabase Edge Function with a cron trigger.
//
// Supabase Cron Setup (Dashboard → Edge Functions → Schedules):
//   Function: expire-offers
//   Schedule: */1 * * * *   (every 1 minute)
//   Or use pg_cron if available (see migration Step 13).
//
// This function calls expire_all_stale_offers() which:
//   1. Finds all OFFERED driver_queue entries past offer_expires_at
//   2. For each: locks entry, releases provisional trip, returns
//      passengers to WAITING (preserving queue_sequence/FIFO),
//      applies timeout queue behavior to driver, writes audit log,
//      triggers match_route_queue(route_id)
//   3. No frontend/browser required.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

declare const Deno: {
  env: { get(key: string): string | undefined };
  serve(handler: (req: Request) => Promise<Response>): void;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (_req) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    const { data, error } = await supabase.rpc('expire_all_stale_offers');

    if (error) {
      console.error('[expire-offers] RPC error:', error.message);
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const result = data as { success: boolean; expired_count: number; ran_at: string };
    if (result.expired_count > 0) {
      console.log(`[expire-offers] Expired ${result.expired_count} stale offer(s) at ${result.ran_at}`);
    }

    return new Response(
      JSON.stringify(result),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    console.error('[expire-offers] Unexpected error:', err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

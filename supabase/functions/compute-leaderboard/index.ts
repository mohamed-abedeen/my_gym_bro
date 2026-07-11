// compute-leaderboard — scheduled recompute of `leaderboard_scores`.
//
// All scoring logic (plausibility caps, percentile normalisation, ranking)
// lives in the `compute_leaderboard_scores()` SQL function (008_leaderboard.sql)
// so it runs in one transaction next to the data; this function is just the
// scheduler entry point.
//
// Invoke from a cron schedule (e.g. Supabase Dashboard → Edge Functions →
// Schedules, hourly) with the `x-cron-secret` header set to the CRON_SECRET
// project secret. Requests without the secret are rejected — this endpoint
// must never be callable by clients.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret || req.headers.get("x-cron-secret") !== cronSecret) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const startedAt = Date.now();
    const { error } = await supabaseAdmin.rpc("compute_leaderboard_scores");
    if (error) {
      console.error("compute_leaderboard_scores failed:", error.message);
      return jsonResponse({ error: error.message }, 500);
    }

    return jsonResponse({
      ok: true,
      elapsed_ms: Date.now() - startedAt,
    });
  } catch (e) {
    console.error("compute-leaderboard error:", e);
    return jsonResponse({ error: String(e) }, 500);
  }
});

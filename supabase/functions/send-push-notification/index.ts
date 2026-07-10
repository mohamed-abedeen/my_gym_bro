// send-push-notification — internal utility to push to a set of users.
//
// Server-to-server only: callers must present the CRON_SECRET header. It was
// previously unauthenticated, which let anyone push arbitrary notifications to
// any user.
//
// Uses the shared FCM v1 sender (../_shared/fcm.ts). The legacy topic branch
// was removed — no caller used it; add v1 topic support to _shared/fcm.ts if a
// future feature needs it.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  // Auth: shared secret, same gate as compute-leaderboard. Never client-callable.
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret || req.headers.get("x-cron-secret") !== cronSecret) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  try {
    const {
      userIds,
      title,
      body,
      data,
    }: {
      userIds?: string[];
      title: string;
      body: string;
      data?: Record<string, string>;
    } = await req.json();

    if (!title || !body) {
      return jsonResponse({ error: "title and body are required" }, 400);
    }
    if (!userIds || userIds.length === 0) {
      return jsonResponse({ error: "userIds is required" }, 400);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: profiles, error: fetchError } = await supabaseAdmin
      .from("user_profiles")
      .select("fcm_token")
      .in("user_id", userIds)
      .not("fcm_token", "is", null);

    if (fetchError) {
      console.error("Error fetching tokens:", fetchError);
      return jsonResponse({ error: "Failed to fetch tokens" }, 500);
    }

    const tokens: string[] = (profiles ?? [])
      .map((p: { fcm_token: string | null }) => p.fcm_token)
      .filter((t): t is string => !!t && t.trim().length > 0);

    if (tokens.length === 0) {
      return jsonResponse({ sent: 0, failed: 0 });
    }

    const result = await sendPush(tokens, { title, body }, data);

    // Prune dead tokens so we stop pushing to uninstalled apps.
    if (result.staleTokens.length > 0) {
      await supabaseAdmin
        .from("user_profiles")
        .update({ fcm_token: null })
        .in("fcm_token", result.staleTokens);
    }

    return jsonResponse({ sent: result.sent, failed: result.failed });
  } catch (err) {
    console.error("send-push-notification error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

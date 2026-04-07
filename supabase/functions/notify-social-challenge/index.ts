import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const CHALLENGE_MESSAGES = [
  "{name} just hit a new PR. What are you going to do about it?",
  "{name} trained today. Did you?",
  "{name} is getting stronger. Are you keeping up?",
  "{name} just crushed a workout. Your move.",
];

const FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send";
const MAX_TOKENS_PER_BATCH = 500;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization header" }, 401);
    }

    // Verify the calling user's JWT
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authHeader } },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return jsonResponse({ error: "Invalid or expired token" }, 401);
    }

    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
    if (!fcmServerKey) {
      return jsonResponse({ error: "FCM_SERVER_KEY not configured" }, 500);
    }

    const {
      recordHolderId,
      recordHolderName,
      exerciseName,
    }: {
      recordHolderId: string;
      recordHolderName: string;
      exerciseName: string;
    } = await req.json();

    if (!recordHolderId || !recordHolderName || !exerciseName) {
      return jsonResponse(
        {
          error:
            "recordHolderId, recordHolderName, and exerciseName are required",
        },
        400
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!
    );

    // Find all users with active subscriptions EXCEPT the record holder
    const { data: eligibleUsers, error: subError } = await supabaseAdmin
      .from("subscriptions")
      .select("user_id")
      .eq("status", "active")
      .neq("user_id", recordHolderId);

    if (subError) {
      console.error("Subscription query error:", subError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    if (!eligibleUsers || eligibleUsers.length === 0) {
      return jsonResponse({ notified: 0 });
    }

    const eligibleUserIds = eligibleUsers.map(
      (u: { user_id: string }) => u.user_id
    );

    // Fetch FCM tokens
    const { data: profiles, error: tokenError } = await supabaseAdmin
      .from("user_profiles")
      .select("fcm_token")
      .in("user_id", eligibleUserIds)
      .not("fcm_token", "is", null);

    if (tokenError) {
      console.error("Token fetch error:", tokenError);
      return jsonResponse({ error: "Failed to fetch tokens" }, 500);
    }

    const tokens = (profiles ?? [])
      .map((p: { fcm_token: string | null }) => p.fcm_token)
      .filter((t): t is string => !!t && t.trim().length > 0);

    if (tokens.length === 0) {
      return jsonResponse({ notified: 0 });
    }

    // Pick a random challenge message
    const template =
      CHALLENGE_MESSAGES[
        Math.floor(Math.random() * CHALLENGE_MESSAGES.length)
      ];
    const message = template.replace(/\{name\}/g, recordHolderName);

    // Send FCM notifications in batches
    let totalNotified = 0;

    for (let i = 0; i < tokens.length; i += MAX_TOKENS_PER_BATCH) {
      const batch = tokens.slice(i, i + MAX_TOKENS_PER_BATCH);
      const payload = {
        registration_ids: batch,
        notification: {
          title: `New PR on ${exerciseName}!`,
          body: message,
        },
        data: {
          type: "social_challenge",
          record_holder_id: recordHolderId,
          exercise_name: exerciseName,
        },
      };

      try {
        const res = await fetch(FCM_ENDPOINT, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `key=${fcmServerKey}`,
          },
          body: JSON.stringify(payload),
        });

        if (res.ok) {
          const data = await res.json();
          totalNotified += data.success ?? 0;
        } else {
          console.error("FCM batch failed:", res.status);
        }
      } catch (err) {
        console.error("FCM batch error:", err);
      }
    }

    return jsonResponse({ notified: totalNotified });
  } catch (err) {
    console.error("notify-social-challenge error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

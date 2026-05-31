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

const FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send";
const MAX_TOKENS_PER_BATCH = 500;

interface FcmResponse {
  success: number;
  failure: number;
}

async function sendFcmRequest(
  serverKey: string,
  payload: Record<string, unknown>
): Promise<FcmResponse> {
  const res = await fetch(FCM_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${serverKey}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("FCM request failed:", res.status, text);
    return { success: 0, failure: 1 };
  }

  const data = await res.json();
  return {
    success: data.success ?? (data.message_id ? 1 : 0),
    failure: data.failure ?? 0,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
    if (!fcmServerKey) {
      return jsonResponse({ error: "FCM_SERVER_KEY not configured" }, 500);
    }

    const {
      userIds,
      title,
      body,
      data,
      topic,
    }: {
      userIds?: string[];
      title: string;
      body: string;
      data?: Record<string, string>;
      topic?: string;
    } = await req.json();

    if (!title || !body) {
      return jsonResponse(
        { error: "title and body are required" },
        400
      );
    }

    const notification = { title, body };

    // Topic-based notification
    if (topic) {
      const payload: Record<string, unknown> = {
        to: `/topics/${topic}`,
        notification,
      };
      if (data) payload.data = data;

      const result = await sendFcmRequest(fcmServerKey, payload);
      return jsonResponse({
        sent: result.success,
        failed: result.failure,
      });
    }

    // Token-based notification
    if (!userIds || userIds.length === 0) {
      return jsonResponse(
        { error: "userIds or topic is required" },
        400
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!
    );

    // Fetch FCM tokens for the given user IDs
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

    // Batch tokens in groups of MAX_TOKENS_PER_BATCH
    let totalSent = 0;
    let totalFailed = 0;

    for (let i = 0; i < tokens.length; i += MAX_TOKENS_PER_BATCH) {
      const batch = tokens.slice(i, i + MAX_TOKENS_PER_BATCH);
      const payload: Record<string, unknown> = {
        registration_ids: batch,
        notification,
      };
      if (data) payload.data = data;

      const result = await sendFcmRequest(fcmServerKey, payload);
      totalSent += result.success;
      totalFailed += result.failure;
    }

    return jsonResponse({ sent: totalSent, failed: totalFailed });
  } catch (err) {
    console.error("send-push-notification error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

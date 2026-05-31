import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const TRIAL_DURATION_DAYS = 7;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization header" }, 401);
    }

    // Create client with user's JWT to verify identity
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

    const userId = user.id;

    // Use service_role to read subscription data (bypasses RLS)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!
    );

    // Check subscriptions table
    const { data: subscription, error: subError } = await supabaseAdmin
      .from("subscriptions")
      .select("status, product_id, expiration_date")
      .eq("user_id", userId)
      .maybeSingle();

    if (subError) {
      console.error("Subscription query error:", subError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    if (subscription) {
      return jsonResponse({
        status: subscription.status,
        product_id: subscription.product_id,
        expires_at: subscription.expiration_date,
        is_trial: false,
      });
    }

    // No subscription found - check trial eligibility
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("user_profiles")
      .select("trial_started_at")
      .eq("user_id", userId)
      .maybeSingle();

    if (profileError) {
      console.error("Profile query error:", profileError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    if (profile?.trial_started_at) {
      const trialStart = new Date(profile.trial_started_at);
      const trialEnd = new Date(trialStart);
      trialEnd.setDate(trialEnd.getDate() + TRIAL_DURATION_DAYS);

      if (new Date() < trialEnd) {
        return jsonResponse({
          status: "trial",
          product_id: null,
          expires_at: trialEnd.toISOString(),
          is_trial: true,
        });
      }
    }

    // No subscription, no active trial
    return jsonResponse({
      status: "expired",
      product_id: null,
      expires_at: null,
      is_trial: false,
    });
  } catch (err) {
    console.error("verify-subscription error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

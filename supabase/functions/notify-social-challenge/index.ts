// notify-social-challenge — when a user sets a PR, nudge the people who follow
// them ("your gym bro just hit a PR").
//
// Hardening (was an open spam vector): the previous version let ANY authenticated
// user broadcast an attacker-chosen, unsanitized name to the ENTIRE user base.
// Now:
//   • the record holder is the CALLER (from their JWT) — you can't fire a PR
//     notification about someone else;
//   • the display name is read server-side from the profile, never trusted from
//     the client;
//   • the exercise label is sanitized + length-capped;
//   • the audience is the caller's FOLLOWERS, not everyone.
// ponytail: add a per-user cooldown (last_pr_notified_at) if users spam PRs.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

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

/** Strip control chars, collapse whitespace, cap length. */
function clean(s: string, max = 60): string {
  return (s ?? "")
    // deno-lint-ignore no-control-regex
    .replace(/[\x00-\x1F\x7F]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, max);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization header" }, 401);
    }

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
      error: authError,
    } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return jsonResponse({ error: "Invalid or expired token" }, 401);
    }

    const { exerciseName }: { exerciseName?: string } = await req.json();
    const exercise = clean(exerciseName ?? "");
    if (!exercise) {
      return jsonResponse({ error: "exerciseName is required" }, 400);
    }

    const recordHolderId = user.id; // the caller — cannot be spoofed

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Display name from the server, never from the client.
    const { data: profile } = await supabaseAdmin
      .from("user_profiles")
      .select("display_name")
      .eq("user_id", recordHolderId)
      .maybeSingle();
    const name = clean(profile?.display_name ?? "Someone", 40);

    // Audience: people who follow the record holder.
    const { data: followers, error: followErr } = await supabaseAdmin
      .from("follows")
      .select("follower_id")
      .eq("followee_id", recordHolderId);
    if (followErr) {
      console.error("Follower query error:", followErr);
      return jsonResponse({ error: "Database error" }, 500);
    }
    const followerIds = (followers ?? []).map(
      (f: { follower_id: string }) => f.follower_id,
    );
    if (followerIds.length === 0) {
      return jsonResponse({ notified: 0 });
    }

    const { data: profiles } = await supabaseAdmin
      .from("user_profiles")
      .select("fcm_token")
      .in("user_id", followerIds)
      .not("fcm_token", "is", null);
    const tokens = (profiles ?? [])
      .map((p: { fcm_token: string | null }) => p.fcm_token)
      .filter((t): t is string => !!t && t.trim().length > 0);
    if (tokens.length === 0) {
      return jsonResponse({ notified: 0 });
    }

    const template =
      CHALLENGE_MESSAGES[Math.floor(Math.random() * CHALLENGE_MESSAGES.length)];
    const result = await sendPush(
      tokens,
      { title: `New PR on ${exercise}!`, body: template.replace(/\{name\}/g, name) },
      { type: "social_challenge", record_holder_id: recordHolderId, exercise_name: exercise },
    );

    if (result.staleTokens.length > 0) {
      await supabaseAdmin
        .from("user_profiles")
        .update({ fcm_token: null })
        .in("fcm_token", result.staleTokens);
    }

    return jsonResponse({ notified: result.sent });
  } catch (err) {
    console.error("notify-social-challenge error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

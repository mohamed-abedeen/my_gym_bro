// notify-social-challenge — social pushes to a user's FRIENDS (the mutual
// `friends` view from 012; the old follows audience was dropped with the feed).
//
// Two kinds:
//   • kind "challenge_completed" — fired by the DB trigger
//     trg_notify_challenge_completion (014) via pg_net with x-cron-secret.
//     The subject comes from the payload but is VERIFIED against
//     challenge_participants server-side: no completed+awarded row, no push.
//   • kind "pr" (default, legacy shape { exerciseName }) — called by the app
//     with the user's JWT when they set a PR. The record holder is always the
//     caller (can't fire a notification about someone else).
//
// Auth: EITHER a valid x-cron-secret (server path, any kind) OR a user JWT
// (client path, "pr" only — challenge completion pushes are server-initiated
// so a client can't broadcast an unearned completion). verify_jwt is disabled
// in config.toml because the trigger path has no JWT; both paths are enforced
// here instead.
//
// Tone (04-BACKEND §3.7): each recipient's user_profiles.notification_tone
// picks the message variant (supportive/balanced/bold/savage → fallback
// balanced), resolved at delivery time.
//
// Hardening kept from the previous version: display name and challenge title
// are read server-side and sanitized; the exercise label is sanitized +
// length-capped; stale FCM tokens are pruned.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

type Tone = "supportive" | "balanced" | "bold" | "savage";
const TONES: Tone[] = ["supportive", "balanced", "bold", "savage"];

// {name} = subject's display name, {what} = exercise or challenge title.
const PR_MESSAGES: Record<Tone, string[]> = {
  supportive: [
    "{name} just set a new PR on {what} — send some love!",
    "{name} hit a personal best on {what}. Cheer them on!",
  ],
  balanced: [
    "{name} just hit a new PR on {what}.",
    "{name} set a personal best on {what} today.",
  ],
  bold: [
    "{name} just hit a PR on {what}. What are you going to do about it?",
    "{name} is getting stronger. Are you keeping up?",
  ],
  savage: [
    "{name} PR'd on {what} while you were scrolling.",
    "{name} just moved the bar. You're still warming up.",
  ],
};

const CHALLENGE_MESSAGES: Record<Tone, string[]> = {
  supportive: [
    "{name} completed the \"{what}\" challenge — congratulate them!",
    "{name} just finished \"{what}\". Amazing work deserves a shout!",
  ],
  balanced: [
    "{name} completed the \"{what}\" challenge.",
    "{name} just finished the \"{what}\" challenge.",
  ],
  bold: [
    "{name} crushed the \"{what}\" challenge. Your move.",
    "{name} finished \"{what}\". Did you even start?",
  ],
  savage: [
    "{name} completed \"{what}\". You weren't even on the list.",
    "\"{what}\": done — by {name}, not you.",
  ],
};

/** Strip control chars, collapse whitespace, cap length. */
function clean(s: string, max = 60): string {
  return (s ?? "")
    // deno-lint-ignore no-control-regex
    .replace(/[\x00-\x1F\x7F]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, max);
}

function pick(arr: string[]): string {
  return arr[Math.floor(Math.random() * arr.length)];
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ── Auth: cron secret (server path) or user JWT (client path) ──────────
    const cronSecret = Deno.env.get("CRON_SECRET");
    const isServerCall = !!cronSecret &&
      req.headers.get("x-cron-secret") === cronSecret;

    let callerId: string | null = null;
    if (!isServerCall) {
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
      callerId = user.id;
    }

    const body: {
      kind?: string;
      exerciseName?: string;
      user_id?: string;
      challenge_id?: string;
    } = await req.json();
    const kind = body.kind === "challenge_completed" ? "challenge_completed" : "pr";

    // ── Resolve subject + message inputs per kind ───────────────────────────
    let subjectId: string;
    let what: string;
    let templates: Record<Tone, string[]>;
    let title: string;
    let data: Record<string, string>;

    if (kind === "challenge_completed") {
      // Server-initiated only: a client must not broadcast completions.
      if (!isServerCall) {
        return jsonResponse({ error: "Forbidden" }, 403);
      }
      if (!body.user_id || !body.challenge_id) {
        return jsonResponse({ error: "user_id and challenge_id are required" }, 400);
      }
      // Verify the completion actually stands (award trigger is the source of
      // truth) — and read the challenge title server-side.
      const { data: row } = await supabaseAdmin
        .from("challenge_participants")
        .select("completed_at, points_awarded, challenges ( title, status )")
        .eq("challenge_id", body.challenge_id)
        .eq("user_id", body.user_id)
        .maybeSingle();
      const challenge = row?.challenges as
        | { title: string | null; status: string | null }
        | null;
      if (
        !row?.completed_at || (row.points_awarded ?? 0) <= 0 ||
        !challenge || challenge.status === "hidden"
      ) {
        return jsonResponse({ notified: 0, reason: "no verified completion" });
      }
      subjectId = body.user_id;
      what = clean(challenge.title ?? "a challenge", 50);
      templates = CHALLENGE_MESSAGES;
      title = "Challenge completed!";
      data = { type: "social_challenge", subject_id: subjectId, challenge_id: body.challenge_id };
    } else {
      // PR path: the record holder is the caller — cannot be spoofed.
      if (!callerId) {
        // Server calls must name a subject explicitly; PRs are client events.
        return jsonResponse({ error: "pr kind requires a user JWT" }, 403);
      }
      const exercise = clean(body.exerciseName ?? "");
      if (!exercise) {
        return jsonResponse({ error: "exerciseName is required" }, 400);
      }
      subjectId = callerId;
      what = exercise;
      templates = PR_MESSAGES;
      title = `New PR on ${exercise}!`;
      data = { type: "social_challenge", subject_id: subjectId, exercise_name: exercise };
    }

    // Display name from the server, never from the client.
    const { data: profile } = await supabaseAdmin
      .from("user_profiles")
      .select("display_name")
      .eq("user_id", subjectId)
      .maybeSingle();
    const name = clean(profile?.display_name ?? "Someone", 40);

    // ── Audience: the subject's mutual friends (012 `friends` view) ─────────
    const { data: friendRows, error: friendErr } = await supabaseAdmin
      .from("friends")
      .select("friend_id")
      .eq("user_id", subjectId);
    if (friendErr) {
      console.error("Friends query error:", friendErr);
      return jsonResponse({ error: "Database error" }, 500);
    }
    const friendIds = (friendRows ?? []).map(
      (f: { friend_id: string }) => f.friend_id,
    );
    if (friendIds.length === 0) {
      return jsonResponse({ notified: 0 });
    }

    // ── Tone-resolved delivery: group recipients by notification_tone ───────
    const { data: recipients } = await supabaseAdmin
      .from("user_profiles")
      .select("fcm_token, notification_tone")
      .in("user_id", friendIds)
      .not("fcm_token", "is", null);

    const byTone = new Map<Tone, string[]>();
    for (const r of recipients ?? []) {
      const token = (r.fcm_token ?? "").trim();
      if (!token) continue;
      const tone: Tone = TONES.includes(r.notification_tone as Tone)
        ? (r.notification_tone as Tone)
        : "balanced";
      byTone.set(tone, [...(byTone.get(tone) ?? []), token]);
    }
    if (byTone.size === 0) {
      return jsonResponse({ notified: 0 });
    }

    let sent = 0;
    const staleTokens: string[] = [];
    for (const [tone, tokens] of byTone) {
      const message = pick(templates[tone])
        .replace(/\{name\}/g, name)
        .replace(/\{what\}/g, what);
      const result = await sendPush(tokens, { title, body: message }, {
        ...data,
        tone,
      });
      sent += result.sent;
      staleTokens.push(...result.staleTokens);
    }

    if (staleTokens.length > 0) {
      await supabaseAdmin
        .from("user_profiles")
        .update({ fcm_token: null })
        .in("fcm_token", staleTokens);
    }

    return jsonResponse({ notified: sent });
  } catch (err) {
    console.error("notify-social-challenge error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

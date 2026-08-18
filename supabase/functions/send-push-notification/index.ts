// send-push-notification — internal utility to push to a set of users.
//
// Server-to-server only: callers must present the CRON_SECRET header. It was
// previously unauthenticated, which let anyone push arbitrary notifications to
// any user.
//
// Two payload shapes:
//   • { userIds, title, body, data? } — verbatim send (legacy callers).
//   • { user_ids | userIds, kind: "season_ended", board, placement } — from
//     finalize_season (migration 015). The copy is composed HERE, per
//     recipient, resolved against user_profiles.notification_tone — SQL
//     can't tone-resolve, and every notification must carry a tone.
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

type Tone = "supportive" | "balanced" | "bold" | "savage";
const TONES: Tone[] = ["supportive", "balanced", "bold", "savage"];

// {place} = "1st"/"2nd"/"3rd", {period} = "weekly"/"monthly". Index 0 is the
// winner variant, index 1 the placed variant.
const SEASON_MESSAGES: Record<Tone, [string, string]> = {
  supportive: [
    "You WON the {period} leaderboard! Incredible work 🎉",
    "You finished {place} on the {period} leaderboard — be proud!",
  ],
  balanced: [
    "You won the {period} leaderboard. New season starts now.",
    "Season over: you placed {place} on the {period} board.",
  ],
  bold: [
    "Winner. The {period} board is yours. Defend it.",
    "{place} on the {period} board. Next season: take the top.",
  ],
  savage: [
    "You own the {period} board. Everyone else was warming up.",
    "{place}. Decent. Now do it again.",
  ],
};

// {skin} = display name from the skins catalog (migration 016). Sent by
// evaluate_earned_skins() on a new grant.
const SKIN_MESSAGES: Record<Tone, string> = {
  supportive: "You unlocked the {skin} skin! Go try it on 🎉",
  balanced: "New skin unlocked: {skin}.",
  bold: "The {skin} skin is yours. Wear it.",
  savage: "{skin} unlocked. You've earned the flex.",
};

// {period} = "weekly"/"monthly". Sent by generate_progress_reports
// (migration 017) when a new report lands.
const REPORT_MESSAGES: Record<Tone, string> = {
  supportive: "Your {period} report is ready — go see how far you've come!",
  balanced: "Your {period} report is ready.",
  bold: "{period} report's in. Read it, then beat it.",
  savage: "{period} report dropped. The numbers don't lie.",
};

function ordinal(n: number): string {
  if (n % 100 >= 11 && n % 100 <= 13) return `${n}th`;
  return `${n}${["th", "st", "nd", "rd"][n % 10] ?? "th"}`;
}

serve(async (req: Request) => {
  // Auth: shared secret, same gate as compute-leaderboard. Never client-callable.
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret || req.headers.get("x-cron-secret") !== cronSecret) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  try {
    const raw: {
      userIds?: string[];
      user_ids?: string[];
      title?: string;
      body?: string;
      data?: Record<string, string>;
      kind?: string;
      board?: string;
      placement?: number;
      skin_id?: string;
      skin_name?: string;
      period?: string;
    } = await req.json();

    const userIds = raw.userIds ?? raw.user_ids;
    if (!userIds || userIds.length === 0) {
      return jsonResponse({ error: "userIds is required" }, 400);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let sent = 0;
    let failed = 0;
    const staleTokens: string[] = [];

    if (raw.kind === "season_ended") {
      const board = raw.board === "monthly" ? "monthly" : "weekly";
      const placement = Math.max(1, Math.trunc(raw.placement ?? 1));

      const { data: profiles, error: fetchError } = await supabaseAdmin
        .from("user_profiles")
        .select("fcm_token, notification_tone")
        .in("user_id", userIds)
        .not("fcm_token", "is", null);
      if (fetchError) {
        console.error("Error fetching tokens:", fetchError);
        return jsonResponse({ error: "Failed to fetch tokens" }, 500);
      }

      // Tone-resolved per recipient (04-BACKEND §3.7).
      const byTone = new Map<Tone, string[]>();
      for (const p of profiles ?? []) {
        const token = (p.fcm_token ?? "").trim();
        if (!token) continue;
        const tone: Tone = TONES.includes(p.notification_tone as Tone)
          ? (p.notification_tone as Tone)
          : "balanced";
        byTone.set(tone, [...(byTone.get(tone) ?? []), token]);
      }

      for (const [tone, tokens] of byTone) {
        const message = SEASON_MESSAGES[tone][placement === 1 ? 0 : 1]
          .replace(/\{place\}/g, ordinal(placement))
          .replace(/\{period\}/g, board);
        const result = await sendPush(
          tokens,
          { title: "Season ended!", body: message },
          { type: "season_ended", board, placement: `${placement}`, tone },
        );
        sent += result.sent;
        failed += result.failed;
        staleTokens.push(...result.staleTokens);
      }
    } else if (raw.kind === "skin_unlocked") {
      const skinName = (raw.skin_name ?? "").trim() || "Secret";

      const { data: profiles, error: fetchError } = await supabaseAdmin
        .from("user_profiles")
        .select("fcm_token, notification_tone")
        .in("user_id", userIds)
        .not("fcm_token", "is", null);
      if (fetchError) {
        console.error("Error fetching tokens:", fetchError);
        return jsonResponse({ error: "Failed to fetch tokens" }, 500);
      }

      // Tone-resolved per recipient (04-BACKEND §3.7), same shape as
      // season_ended above.
      const byTone = new Map<Tone, string[]>();
      for (const p of profiles ?? []) {
        const token = (p.fcm_token ?? "").trim();
        if (!token) continue;
        const tone: Tone = TONES.includes(p.notification_tone as Tone)
          ? (p.notification_tone as Tone)
          : "balanced";
        byTone.set(tone, [...(byTone.get(tone) ?? []), token]);
      }

      for (const [tone, tokens] of byTone) {
        const message = SKIN_MESSAGES[tone].replace(/\{skin\}/g, skinName);
        const result = await sendPush(
          tokens,
          { title: "Skin unlocked!", body: message },
          { type: "skin_unlocked", skin_id: raw.skin_id ?? "", tone },
        );
        sent += result.sent;
        failed += result.failed;
        staleTokens.push(...result.staleTokens);
      }
    } else if (raw.kind === "report_ready") {
      const period = raw.period === "monthly" ? "monthly" : "weekly";

      const { data: profiles, error: fetchError } = await supabaseAdmin
        .from("user_profiles")
        .select("fcm_token, notification_tone")
        .in("user_id", userIds)
        .not("fcm_token", "is", null);
      if (fetchError) {
        console.error("Error fetching tokens:", fetchError);
        return jsonResponse({ error: "Failed to fetch tokens" }, 500);
      }

      const byTone = new Map<Tone, string[]>();
      for (const p of profiles ?? []) {
        const token = (p.fcm_token ?? "").trim();
        if (!token) continue;
        const tone: Tone = TONES.includes(p.notification_tone as Tone)
          ? (p.notification_tone as Tone)
          : "balanced";
        byTone.set(tone, [...(byTone.get(tone) ?? []), token]);
      }

      for (const [tone, tokens] of byTone) {
        const message = REPORT_MESSAGES[tone].replace(/\{period\}/g, period)
          // Bold/savage templates open with the placeholder.
          .replace(/^(weekly|monthly)/, (m) => m[0].toUpperCase() + m.slice(1));
        const result = await sendPush(
          tokens,
          { title: "Report ready", body: message },
          { type: "report_ready", period, tone },
        );
        sent += result.sent;
        failed += result.failed;
        staleTokens.push(...result.staleTokens);
      }
    } else {
      const { title, body, data } = raw;
      if (!title || !body) {
        return jsonResponse({ error: "title and body are required" }, 400);
      }

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
      sent = result.sent;
      failed = result.failed;
      staleTokens.push(...result.staleTokens);
    }

    // Prune dead tokens so we stop pushing to uninstalled apps.
    if (staleTokens.length > 0) {
      await supabaseAdmin
        .from("user_profiles")
        .update({ fcm_token: null })
        .in("fcm_token", staleTokens);
    }

    return jsonResponse({ sent, failed });
  } catch (err) {
    console.error("send-push-notification error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

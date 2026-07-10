// schedule-notifications — hourly cron that sends morning / evening / streak
// reminders. Cron-only: requires the CRON_SECRET header.
//
// Targeting note (fixes the day_of_week bug): MyGymBro schedules are ROTATIONS
// (schedule_days.day_index, is_rest_day), not fixed weekdays — the previous
// code filtered on a schedule_days.day_of_week column that does not exist, so
// morning/evening reminders errored out and never sent. The server can't know
// where a user is in their rotation on a given date (that state isn't synced),
// so reminders now target "active schedule + hasn't trained today/recently".
// ponytail: rotation-aware "is today your training day" targeting needs the app
// to sync the user's current rotation position; do that if reminders feel noisy.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

type Supa = ReturnType<typeof createClient>;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getRandomTemplate(
  supabase: Supa,
  category: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("notification_templates")
    .select("message")
    .eq("category", category)
    .eq("is_active", true);
  if (error || !data || data.length === 0) {
    console.error(`No templates found for category: ${category}`, error);
    return null;
  }
  return data[Math.floor(Math.random() * data.length)].message;
}

/** Distinct user ids that own an active, non-deleted schedule. */
async function activeScheduleUserIds(supabase: Supa): Promise<string[]> {
  const { data, error } = await supabase
    .from("schedules")
    .select("user_id")
    .eq("is_active", true)
    .is("deleted_at", null);
  if (error) {
    console.error("Active schedule query error:", error);
    return [];
  }
  return [...new Set((data ?? []).map((u: { user_id: string }) => u.user_id))];
}

/** Non-null FCM tokens for the given users. */
async function tokensFor(supabase: Supa, userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];
  const { data } = await supabase
    .from("user_profiles")
    .select("fcm_token")
    .in("user_id", userIds)
    .not("fcm_token", "is", null);
  return (data ?? [])
    .map((p: { fcm_token: string | null }) => p.fcm_token)
    .filter((t): t is string => !!t && t.trim().length > 0);
}

/** User ids (from the given set) with a non-deleted session since `sinceIso`. */
async function trainedSince(
  supabase: Supa,
  userIds: string[],
  sinceIso: string,
): Promise<Set<string>> {
  if (userIds.length === 0) return new Set();
  const { data } = await supabase
    .from("sessions")
    .select("user_id")
    .in("user_id", userIds)
    .gte("created_at", sinceIso)
    .is("deleted_at", null);
  return new Set((data ?? []).map((s: { user_id: string }) => s.user_id));
}

serve(async (req: Request) => {
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret || req.headers.get("x-cron-secret") !== cronSecret) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const currentHour = new Date().getUTCHours();
    const todayStart = `${new Date().toISOString().split("T")[0]}T00:00:00Z`;

    let morningSent = 0;
    let eveningSent = 0;
    let streakSent = 0;

    // --- MORNING (08:00 UTC): motivational nudge to everyone training-active ---
    if (currentHour === 8) {
      const template = await getRandomTemplate(supabase, "morning");
      if (template) {
        const tokens = await tokensFor(supabase, await activeScheduleUserIds(supabase));
        const r = await sendPush(tokens, { title: "Time to train!", body: template });
        morningSent = r.sent;
      }
    }

    // --- EVENING (19:00 UTC): only users who haven't trained today ---
    if (currentHour === 19) {
      const template = await getRandomTemplate(supabase, "evening");
      if (template) {
        const active = await activeScheduleUserIds(supabase);
        const trained = await trainedSince(supabase, active, todayStart);
        const pending = active.filter((id) => !trained.has(id));
        const tokens = await tokensFor(supabase, pending);
        const r = await sendPush(tokens, { title: "Don't skip today!", body: template });
        eveningSent = r.sent;
      }
    }

    // --- STREAK AT RISK (09:00 UTC): active users idle for 2+ days ---
    if (currentHour === 9) {
      const template = await getRandomTemplate(supabase, "streak_at_risk");
      if (template) {
        const twoDaysAgo = new Date();
        twoDaysAgo.setUTCDate(twoDaysAgo.getUTCDate() - 2);
        const active = await activeScheduleUserIds(supabase);
        const recent = await trainedSince(supabase, active, twoDaysAgo.toISOString());
        const atRisk = active.filter((id) => !recent.has(id));
        const tokens = await tokensFor(supabase, atRisk);
        const r = await sendPush(tokens, {
          title: "Your streak is at risk!",
          body: template,
        });
        streakSent = r.sent;
      }
    }

    return jsonResponse({
      morning_sent: morningSent,
      evening_sent: eveningSent,
      streak_sent: streakSent,
    });
  } catch (err) {
    console.error("schedule-notifications error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

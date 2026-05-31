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

async function sendFcmBatch(
  serverKey: string,
  tokens: string[],
  notification: { title: string; body: string }
): Promise<{ sent: number; failed: number }> {
  if (tokens.length === 0) return { sent: 0, failed: 0 };

  let totalSent = 0;
  let totalFailed = 0;

  for (let i = 0; i < tokens.length; i += MAX_TOKENS_PER_BATCH) {
    const batch = tokens.slice(i, i + MAX_TOKENS_PER_BATCH);
    const payload = {
      registration_ids: batch,
      notification,
    };

    try {
      const res = await fetch(FCM_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${serverKey}`,
        },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        const data = await res.json();
        totalSent += data.success ?? 0;
        totalFailed += data.failure ?? 0;
      } else {
        console.error("FCM batch failed:", res.status);
        totalFailed += batch.length;
      }
    } catch (err) {
      console.error("FCM batch error:", err);
      totalFailed += batch.length;
    }
  }

  return { sent: totalSent, failed: totalFailed };
}

function getDayOfWeekName(): string {
  const days = [
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
  ];
  return days[new Date().getUTCDay()];
}

async function getRandomTemplate(
  supabase: ReturnType<typeof createClient>,
  category: string
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

  const randomIndex = Math.floor(Math.random() * data.length);
  return data[randomIndex].message;
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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!
    );

    const currentHour = new Date().getUTCHours();
    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
    const dayOfWeek = getDayOfWeekName();

    let morningSent = 0;
    let eveningSent = 0;
    let streakSent = 0;

    // --- MORNING NOTIFICATIONS (08:00 UTC) ---
    if (currentHour === 8) {
      const template = await getRandomTemplate(supabase, "morning");
      if (template) {
        // Find users with active schedules who have a session scheduled today
        // Active schedule + schedule_day matching today's day of week
        const { data: usersWithSchedule, error: schedErr } = await supabase
          .from("schedules")
          .select(
            `
            user_id,
            schedule_days!inner (day_of_week)
          `
          )
          .eq("is_active", true)
          .is("deleted_at", null)
          .eq("schedule_days.day_of_week", dayOfWeek)
          .is("schedule_days.deleted_at", null);

        if (schedErr) {
          console.error("Morning query error:", schedErr);
        } else if (usersWithSchedule && usersWithSchedule.length > 0) {
          const userIds = [
            ...new Set(
              usersWithSchedule.map(
                (u: { user_id: string }) => u.user_id
              )
            ),
          ];

          // Get FCM tokens
          const { data: profiles } = await supabase
            .from("user_profiles")
            .select("fcm_token")
            .in("user_id", userIds)
            .not("fcm_token", "is", null);

          const tokens = (profiles ?? [])
            .map((p: { fcm_token: string | null }) => p.fcm_token)
            .filter((t): t is string => !!t && t.trim().length > 0);

          const result = await sendFcmBatch(fcmServerKey, tokens, {
            title: "Time to train!",
            body: template,
          });
          morningSent = result.sent;
        }
      }
    }

    // --- EVENING NOTIFICATIONS (19:00 UTC) ---
    if (currentHour === 19) {
      const template = await getRandomTemplate(supabase, "evening");
      if (template) {
        // Find users with active schedules who have today scheduled but haven't completed a session
        const { data: usersWithSchedule, error: schedErr } = await supabase
          .from("schedules")
          .select(
            `
            user_id,
            schedule_days!inner (day_of_week)
          `
          )
          .eq("is_active", true)
          .is("deleted_at", null)
          .eq("schedule_days.day_of_week", dayOfWeek)
          .is("schedule_days.deleted_at", null);

        if (schedErr) {
          console.error("Evening schedule query error:", schedErr);
        } else if (usersWithSchedule && usersWithSchedule.length > 0) {
          const scheduledUserIds = [
            ...new Set(
              usersWithSchedule.map(
                (u: { user_id: string }) => u.user_id
              )
            ),
          ];

          // Find users who completed a session today
          const { data: completedSessions } = await supabase
            .from("sessions")
            .select("user_id")
            .in("user_id", scheduledUserIds)
            .gte("created_at", `${today}T00:00:00Z`)
            .lte("created_at", `${today}T23:59:59Z`)
            .is("deleted_at", null);

          const completedUserIds = new Set(
            (completedSessions ?? []).map(
              (s: { user_id: string }) => s.user_id
            )
          );

          // Filter to users who haven't completed
          const pendingUserIds = scheduledUserIds.filter(
            (id) => !completedUserIds.has(id)
          );

          if (pendingUserIds.length > 0) {
            const { data: profiles } = await supabase
              .from("user_profiles")
              .select("fcm_token")
              .in("user_id", pendingUserIds)
              .not("fcm_token", "is", null);

            const tokens = (profiles ?? [])
              .map((p: { fcm_token: string | null }) => p.fcm_token)
              .filter((t): t is string => !!t && t.trim().length > 0);

            const result = await sendFcmBatch(fcmServerKey, tokens, {
              title: "Don't skip today!",
              body: template,
            });
            eveningSent = result.sent;
          }
        }
      }
    }

    // --- STREAK AT RISK NOTIFICATIONS (09:00 UTC) ---
    if (currentHour === 9) {
      const template = await getRandomTemplate(supabase, "streak_at_risk");
      if (template) {
        const twoDaysAgo = new Date();
        twoDaysAgo.setUTCDate(twoDaysAgo.getUTCDate() - 2);
        const twoDaysAgoStr = twoDaysAgo.toISOString();

        // Find users with active schedules
        const { data: activeUsers, error: activeErr } = await supabase
          .from("schedules")
          .select("user_id")
          .eq("is_active", true)
          .is("deleted_at", null);

        if (activeErr) {
          console.error("Streak query error:", activeErr);
        } else if (activeUsers && activeUsers.length > 0) {
          const allActiveUserIds = [
            ...new Set(
              activeUsers.map((u: { user_id: string }) => u.user_id)
            ),
          ];

          // Find users who HAVE had a session in the last 2 days
          const { data: recentSessions } = await supabase
            .from("sessions")
            .select("user_id")
            .in("user_id", allActiveUserIds)
            .gte("created_at", twoDaysAgoStr)
            .is("deleted_at", null);

          const recentUserIds = new Set(
            (recentSessions ?? []).map(
              (s: { user_id: string }) => s.user_id
            )
          );

          // Users at risk = active users with no recent session
          const atRiskUserIds = allActiveUserIds.filter(
            (id) => !recentUserIds.has(id)
          );

          if (atRiskUserIds.length > 0) {
            const { data: profiles } = await supabase
              .from("user_profiles")
              .select("fcm_token")
              .in("user_id", atRiskUserIds)
              .not("fcm_token", "is", null);

            const tokens = (profiles ?? [])
              .map((p: { fcm_token: string | null }) => p.fcm_token)
              .filter((t): t is string => !!t && t.trim().length > 0);

            const result = await sendFcmBatch(fcmServerKey, tokens, {
              title: "Your streak is at risk!",
              body: template,
            });
            streakSent = result.sent;
          }
        }
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

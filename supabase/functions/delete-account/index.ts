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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization header" }, 401);
    }

    // Verify user identity with their JWT
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
    const now = new Date().toISOString();

    // Use service_role to bypass RLS for soft-delete and auth deletion
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!
    );

    // --- Cascading soft-delete ---

    // 1. Get user's schedule IDs
    const { data: schedules } = await supabaseAdmin
      .from("schedules")
      .select("id")
      .eq("user_id", userId)
      .is("deleted_at", null);

    const scheduleIds = schedules?.map((s: { id: string }) => s.id) ?? [];

    // 2. Get schedule_day IDs for those schedules
    let scheduleDayIds: string[] = [];
    if (scheduleIds.length > 0) {
      const { data: scheduleDays } = await supabaseAdmin
        .from("schedule_days")
        .select("id")
        .in("schedule_id", scheduleIds)
        .is("deleted_at", null);

      scheduleDayIds =
        scheduleDays?.map((d: { id: string }) => d.id) ?? [];
    }

    // 3. Soft-delete scheduled_exercises (belong to schedule_days)
    if (scheduleDayIds.length > 0) {
      await supabaseAdmin
        .from("scheduled_exercises")
        .update({ deleted_at: now })
        .in("schedule_day_id", scheduleDayIds)
        .is("deleted_at", null);
    }

    // 4. Soft-delete schedule_days
    if (scheduleIds.length > 0) {
      await supabaseAdmin
        .from("schedule_days")
        .update({ deleted_at: now })
        .in("schedule_id", scheduleIds)
        .is("deleted_at", null);
    }

    // 5. Soft-delete schedules
    if (scheduleIds.length > 0) {
      await supabaseAdmin
        .from("schedules")
        .update({ deleted_at: now })
        .in("id", scheduleIds);
    }

    // 6. Get user's session IDs
    const { data: sessions } = await supabaseAdmin
      .from("sessions")
      .select("id")
      .eq("user_id", userId)
      .is("deleted_at", null);

    const sessionIds = sessions?.map((s: { id: string }) => s.id) ?? [];

    // 7. Get session_exercise IDs
    let sessionExerciseIds: string[] = [];
    if (sessionIds.length > 0) {
      const { data: sessionExercises } = await supabaseAdmin
        .from("session_exercises")
        .select("id")
        .in("session_id", sessionIds)
        .is("deleted_at", null);

      sessionExerciseIds =
        sessionExercises?.map((e: { id: string }) => e.id) ?? [];
    }

    // 8. Soft-delete sets (belong to session_exercises)
    if (sessionExerciseIds.length > 0) {
      await supabaseAdmin
        .from("sets")
        .update({ deleted_at: now })
        .in("session_exercise_id", sessionExerciseIds)
        .is("deleted_at", null);
    }

    // 9. Soft-delete session_exercises
    if (sessionIds.length > 0) {
      await supabaseAdmin
        .from("session_exercises")
        .update({ deleted_at: now })
        .in("session_id", sessionIds)
        .is("deleted_at", null);
    }

    // 10. Soft-delete sessions
    if (sessionIds.length > 0) {
      await supabaseAdmin
        .from("sessions")
        .update({ deleted_at: now })
        .in("id", sessionIds);
    }

    // 11. Soft-delete social data (direct user_id references)
    const directTables = [
      "posts",
      "post_likes",
      "post_comments",
      "subscriptions",
      "user_profiles",
    ];

    for (const table of directTables) {
      await supabaseAdmin
        .from(table)
        .update({ deleted_at: now })
        .eq("user_id", userId)
        .is("deleted_at", null);
    }

    // 12. Hard-delete auth user
    const { error: deleteAuthError } =
      await supabaseAdmin.auth.admin.deleteUser(userId);

    if (deleteAuthError) {
      console.error("Failed to delete auth user:", deleteAuthError);
      // Data is already soft-deleted, so log but don't fail the request
    }

    return jsonResponse({ message: "Account deleted successfully" });
  } catch (err) {
    console.error("delete-account error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

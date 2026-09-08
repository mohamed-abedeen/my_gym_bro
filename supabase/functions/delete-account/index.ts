import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { revokeAppleTokens } from "../_shared/apple.ts";

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

/**
 * Optional JSON body `{ apple_authorization_code }`: the code from the
 * client's Sign in with Apple re-auth sheet. Absent on Android or when the
 * sheet failed -- the body may also be empty or missing entirely.
 */
async function readAppleCode(req: Request): Promise<string | null> {
  try {
    const body = await req.json();
    const code = body?.apple_authorization_code;
    return typeof code === "string" && code.length > 0 ? code : null;
  } catch {
    return null;
  }
}

function hasAppleIdentity(user: {
  identities?: { provider: string }[] | null;
  app_metadata?: Record<string, unknown>;
}): boolean {
  if (user.identities?.some((i) => i.provider === "apple")) return true;
  const providers = user.app_metadata?.providers;
  return Array.isArray(providers) && providers.includes("apple");
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
      },
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return jsonResponse({ error: "Invalid or expired token" }, 401);
    }

    const userId = user.id;
    const appleCode = await readAppleCode(req);

    // Sign in with Apple accounts: revoke Apple's tokens FIRST (App Store
    // guideline 5.1.1(v)). The code is single-use and expires in 5 minutes,
    // and if the purge below fails the user can retry with a fresh sheet --
    // whereas a revocation that fails after the account is gone can never be
    // retried. A failed revocation is logged but never blocks deletion: the
    // account must stay deletable even when Apple is down or the APPLE_*
    // secrets aren't set yet.
    let appleRevoked: boolean | null = null;
    if (hasAppleIdentity(user)) {
      if (appleCode) {
        const result = await revokeAppleTokens(appleCode);
        appleRevoked = result.ok;
        if (!result.ok) {
          console.error(
            `Apple token revocation failed (${result.reason}):`,
            result.detail ?? "",
          );
        }
      } else {
        appleRevoked = false;
        console.warn(
          "Apple-linked account deleted without an authorization code; Apple tokens not revoked",
        );
      }
    }

    // Use service_role to bypass RLS for the delete.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Hard-delete all of the user's data in one transaction (009 migration),
    // in FK-safe order. This MUST run before deleteUser -- otherwise the FKs to
    // auth.users (no ON DELETE CASCADE) block the auth deletion.
    const { error: purgeError } = await supabaseAdmin.rpc(
      "delete_account_data",
      { target: userId },
    );
    if (purgeError) {
      console.error("Failed to purge account data:", purgeError);
      return jsonResponse({ error: "Failed to delete account data" }, 500);
    }

    // Remove the auth user. This is the record that actually makes the account
    // "gone" (email, identities, PII) -- if it fails, surface an error so the
    // client can retry rather than reporting a delete that didn't happen.
    const { error: deleteAuthError } = await supabaseAdmin.auth.admin
      .deleteUser(userId);
    if (deleteAuthError) {
      console.error("Failed to delete auth user:", deleteAuthError);
      return jsonResponse({ error: "Failed to delete account" }, 500);
    }

    return jsonResponse({
      message: "Account deleted successfully",
      apple_revoked: appleRevoked,
    });
  } catch (err) {
    console.error("delete-account error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

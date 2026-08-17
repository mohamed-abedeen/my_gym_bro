// purchase-skin — verify RevenueCat one-time skin purchases server-side and
// grant ownership (04-BACKEND §3.3, 03-DATABASE §3.3).
//
// User-JWT authenticated (verify_jwt stays ON for this function). The client
// calls it right after Purchases.purchasePackage/StoreProduct succeeds, after
// restorePurchases, and on gallery refresh. Rather than trusting a
// client-asserted product id, it fetches the caller's RevenueCat subscriber
// (server API key) and grants EVERY purchasable skin whose product appears in
// the receipt's non-subscription purchases — so the same endpoint serves
// purchase, restore, and reinstall, and a spoofed call can never grant a skin
// the store never sold to this user.
//
// RevenueCat app_user_id == the Supabase auth user id (auth_notifier logs
// RevenueCat in with the Supabase uid), so the lookup key is the JWT subject —
// nothing client-supplied.
//
// Env: REVENUECAT_SECRET_KEY — a RevenueCat *secret* API key (sk_…). NOT the
// public SDK key. Set via `supabase secrets set` (see SETUP-STATUS). A 404
// from RevenueCat (unknown subscriber) verifies to "owns nothing" — not an
// error.

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

    const rcKey = Deno.env.get("REVENUECAT_SECRET_KEY");
    if (!rcKey) {
      // Deployable before RevenueCat setup finishes: fail soft so the client
      // can tell "not configured yet" apart from "you own nothing".
      return jsonResponse({ error: "Purchases not configured" }, 503);
    }

    // The caller's receipt, straight from RevenueCat.
    const rcRes = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user.id)}`,
      { headers: { Authorization: `Bearer ${rcKey}` } },
    );

    // Known limitation (accepted at this scale): RC's v1 subscriber payload
    // keeps non_subscriptions entries after a store refund — refund signals
    // are webhook/v2-only — so a refunded skin re-verifies as owned. Revisit
    // via the REFUND event in revenuecat-webhook if it ever matters.
    let ownedProducts = new Set<string>();
    if (rcRes.ok) {
      const rcBody: {
        subscriber?: {
          non_subscriptions?: Record<string, unknown[]>;
        };
      } = await rcRes.json();
      ownedProducts = new Set(
        Object.entries(rcBody.subscriber?.non_subscriptions ?? {})
          .filter(([, purchases]) => (purchases ?? []).length > 0)
          .map(([productId]) => productId),
      );
    } else if (rcRes.status !== 404) {
      console.error("RevenueCat lookup failed:", rcRes.status);
      return jsonResponse({ error: "Receipt verification failed" }, 502);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: purchasable, error: skinsError } = await supabaseAdmin
      .from("skins")
      .select("id, product_id")
      .eq("acquisition", "purchasable")
      .not("product_id", "is", null);
    if (skinsError) {
      console.error("Skins query error:", skinsError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    const verified = (purchasable ?? []).filter((s) =>
      ownedProducts.has(s.product_id as string)
    );

    if (verified.length > 0) {
      // Idempotent: the (user_id, skin_id) unique key makes re-verification
      // (restore, reinstall, retries) a no-op.
      const { error: insertError } = await supabaseAdmin
        .from("skin_ownership")
        .upsert(
          verified.map((s) => ({
            user_id: user.id,
            skin_id: s.id,
            source: "purchased",
          })),
          { onConflict: "user_id,skin_id", ignoreDuplicates: true },
        );
      if (insertError) {
        console.error("Ownership insert error:", insertError);
        return jsonResponse({ error: "Database error" }, 500);
      }
    }

    // Full ownership snapshot so the client can refresh its cache in one hop.
    const { data: owned, error: ownedError } = await supabaseAdmin
      .from("skin_ownership")
      .select("skin_id, source, acquired_at")
      .eq("user_id", user.id);
    if (ownedError) {
      console.error("Ownership query error:", ownedError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    return jsonResponse({
      verified: verified.map((s) => s.id),
      owned: owned ?? [],
    });
  } catch (err) {
    console.error("purchase-skin error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

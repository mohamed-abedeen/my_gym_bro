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

// RevenueCat does NOT HMAC-sign webhook bodies. It sends the exact string you
// put in the dashboard's "Authorization header value" field on every request.
// So authentication is a constant-time equality check of that header against
// the configured secret — the previous HMAC verification rejected every real
// event, so subscriptions never updated from the webhook.
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
}

type RevenueCatEventType =
  | "INITIAL_PURCHASE"
  | "RENEWAL"
  | "CANCELLATION"
  | "EXPIRATION"
  | "BILLING_ISSUE"
  | "PRODUCT_CHANGE"
  | string;

function mapEventToStatus(
  eventType: RevenueCatEventType
): "active" | "expired" | "grace_period" | null {
  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    // CANCELLATION = auto-renew turned off; the entitlement stays paid until
    // the period ends, when EXPIRATION arrives. Marking it expired here would
    // lock a paying subscriber out for the remainder of their paid period.
    case "CANCELLATION":
      return "active";
    case "EXPIRATION":
      return "expired";
    case "BILLING_ISSUE":
      return "grace_period";
    default:
      return null;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
    if (!webhookSecret) {
      console.error("REVENUECAT_WEBHOOK_SECRET not configured");
      return jsonResponse({ error: "Server misconfiguration" }, 500);
    }

    // Authenticate: the Authorization header must equal the configured secret
    // (set REVENUECAT_WEBHOOK_SECRET to the exact value entered in RevenueCat's
    // webhook "Authorization header value" field).
    const authHeader = req.headers.get("authorization") ?? "";
    if (!safeEqual(authHeader, webhookSecret)) {
      return jsonResponse({ error: "Invalid authorization" }, 401);
    }

    const payload = JSON.parse(await req.text());
    const event = payload.event;

    if (!event) {
      return jsonResponse({ error: "No event in payload" }, 400);
    }

    const eventType: RevenueCatEventType = event.type;
    const status = mapEventToStatus(eventType);

    if (!status) {
      // Unhandled event type - acknowledge but skip processing
      return jsonResponse({ message: `Ignored event type: ${eventType}` });
    }

    const userId = event.app_user_id;
    if (!userId) {
      return jsonResponse({ error: "Missing app_user_id" }, 400);
    }

    // Use service_role key to bypass RLS
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const upsertData: Record<string, unknown> = {
      user_id: userId,
      status,
      product_id: event.product_id ?? null,
      platform: event.store ?? null,
      original_purchase_date: event.original_purchase_date ?? null,
      expiration_date: event.expiration_at_ms
        ? new Date(event.expiration_at_ms).toISOString()
        : null,
      is_sandbox: event.environment === "SANDBOX",
      store_transaction_id: event.transaction_id ?? null,
      updated_at: new Date().toISOString(),
    };

    const { error: upsertError } = await supabase
      .from("subscriptions")
      .upsert(upsertData, { onConflict: "user_id" });

    if (upsertError) {
      console.error("Upsert error:", upsertError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    return jsonResponse({ message: "Webhook processed", status });
  } catch (err) {
    console.error("Webhook handler error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

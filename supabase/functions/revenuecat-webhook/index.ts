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

async function verifySignature(
  payload: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  const computed = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return computed === signature;
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
      return "active";
    case "CANCELLATION":
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

    const rawBody = await req.text();

    // Verify HMAC-SHA256 signature
    const authHeader = req.headers.get("authorization") ?? "";
    const signature = authHeader.replace(/^Bearer\s+/i, "").trim();

    if (!signature) {
      return jsonResponse({ error: "Missing signature" }, 401);
    }

    const valid = await verifySignature(rawBody, signature, webhookSecret);
    if (!valid) {
      return jsonResponse({ error: "Invalid signature" }, 401);
    }

    const payload = JSON.parse(rawBody);
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
      Deno.env.get("SERVICE_ROLE_KEY")!
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

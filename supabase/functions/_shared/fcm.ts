// Shared FCM HTTP v1 sender.
//
// The legacy `fcm.googleapis.com/fcm/send` + `Authorization: key=<server key>`
// API was shut down by Google in 2024. This module talks to the current v1
// API (`/v1/projects/<id>/messages:send`) using an OAuth2 access token minted
// from a Firebase service-account key.
//
// Configure ONE project secret:
//   FCM_SERVICE_ACCOUNT = the full service-account JSON (the file you download
//   from Firebase console → Project settings → Service accounts → Generate key)
//
// v1 sends one message per request (no `registration_ids` multicast), so
// `sendPush` fans out over tokens with bounded concurrency and reports how many
// succeeded, plus any tokens FCM says are dead so callers can prune them.

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

export interface PushResult {
  sent: number;
  failed: number;
  /** Tokens FCM rejected as unregistered/invalid — safe to delete. */
  staleTokens: string[];
}

let cached: { account: ServiceAccount; token: string; expiresAt: number } | null =
  null;

function loadAccount(): ServiceAccount {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT not configured");
  const sa = JSON.parse(raw) as ServiceAccount;
  if (!sa.client_email || !sa.private_key || !sa.project_id) {
    throw new Error("FCM_SERVICE_ACCOUNT missing required fields");
  }
  return sa;
}

function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

async function mintAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claim}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`OAuth token request failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  return json.access_token as string;
}

/** Returns a valid access token + project id, minting/caching as needed. */
async function getAuth(): Promise<{ token: string; projectId: string }> {
  const nowMs = Date.now();
  if (cached && cached.expiresAt > nowMs + 60_000) {
    return { token: cached.token, projectId: cached.account.project_id };
  }
  const account = cached?.account ?? loadAccount();
  const token = await mintAccessToken(account);
  // Google tokens live 1h; refresh a bit early via the 60s guard above.
  cached = { account, token, expiresAt: nowMs + 3_600_000 };
  return { token, projectId: account.project_id };
}

const CONCURRENCY = 20;

/**
 * Send a notification to many device tokens via FCM v1.
 * Never throws for individual token failures — only for a total auth failure.
 */
export async function sendPush(
  tokens: string[],
  notification: { title: string; body: string },
  data?: Record<string, string>,
): Promise<PushResult> {
  const result: PushResult = { sent: 0, failed: 0, staleTokens: [] };
  if (tokens.length === 0) return result;

  const { token: accessToken, projectId } = await getAuth();
  const url =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  for (let i = 0; i < tokens.length; i += CONCURRENCY) {
    const batch = tokens.slice(i, i + CONCURRENCY);
    await Promise.all(
      batch.map(async (deviceToken) => {
        try {
          const res = await fetch(url, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: { token: deviceToken, notification, data },
            }),
          });
          if (res.ok) {
            result.sent++;
          } else {
            result.failed++;
            // 404 UNREGISTERED / 400 INVALID_ARGUMENT → token is dead.
            if (res.status === 404 || res.status === 400) {
              result.staleTokens.push(deviceToken);
            }
            console.error("FCM v1 send failed:", res.status, await res.text());
          }
        } catch (e) {
          result.failed++;
          console.error("FCM v1 send error:", e);
        }
      }),
    );
  }
  return result;
}

// Sign in with Apple token revocation -- App Store Review Guideline 5.1.1(v):
// apps that offer Sign in with Apple must call Apple's REST API to revoke the
// user's tokens when they delete their account. auth.admin.deleteUser() only
// removes the identity on our side; until /auth/revoke is called the app keeps
// showing under the user's Apple ID -> "Sign in with Apple".
//
// Flow (all server-side -- nothing sensitive reaches the client):
//   1. The client re-runs the native Sign in with Apple sheet and sends us the
//      fresh, single-use `authorizationCode` (Apple expires it after 5 min).
//   2. We mint the client_secret JWT (ES256, signed with the Sign in with Apple
//      private key), exchange the code for a refresh token at /auth/token, then
//      revoke that token at /auth/revoke.
//
// Configuration -- three function secrets (`supabase secrets set ...`), from
// Apple Developer -> Certificates, IDs & Profiles -> Keys -> the "Sign in with
// Apple" key (the same .p8 the Supabase Apple provider's client secret is
// generated from):
//   APPLE_TEAM_ID      10-character Team ID
//   APPLE_KEY_ID       Key ID of that .p8
//   APPLE_PRIVATE_KEY  full .p8 contents (PEM, header/footer lines included)
// Optional: APPLE_CLIENT_ID -- defaults to the iOS bundle id, which is the
// client_id Apple expects for credentials issued by the native (non-web) sheet.

const APPLE_ISSUER = "https://appleid.apple.com";
const DEFAULT_CLIENT_ID = "com.mygymbro.myGymBro";

export interface AppleConfig {
  teamId: string;
  keyId: string;
  privateKey: string;
  clientId: string;
}

export type AppleRevokeResult =
  | { ok: true }
  | {
    ok: false;
    reason:
      | "not_configured"
      | "token_exchange_failed"
      | "revoke_failed"
      | "error";
    detail?: string;
  };

/** Reads the APPLE_* secrets; null when the revocation path isn't configured. */
export function loadAppleConfig(): AppleConfig | null {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  if (!teamId || !keyId || !privateKey) return null;
  return {
    teamId,
    keyId,
    privateKey,
    clientId: Deno.env.get("APPLE_CLIENT_ID") || DEFAULT_CLIENT_ID,
  };
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
    .replace(/\\n/g, "\n") // secret pasted with literal "\n" escapes
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

/**
 * The client_secret Apple's token endpoints require: an ES256 JWT signed with
 * the Sign in with Apple key (Apple docs: "Creating a client secret").
 */
export async function mintAppleClientSecret(
  cfg: AppleConfig,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  const header = b64url(JSON.stringify({ alg: "ES256", kid: cfg.keyId }));
  const claims = b64url(
    JSON.stringify({
      iss: cfg.teamId,
      iat: nowSeconds,
      exp: nowSeconds + 600, // Apple allows up to 6 months; we need minutes.
      aud: APPLE_ISSUER,
      sub: cfg.clientId,
    }),
  );
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(cfg.privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  // WebCrypto's ECDSA output is the raw r||s pair (64 bytes) -- exactly the
  // JWS ES256 encoding, no DER conversion needed.
  return `${signingInput}.${b64url(new Uint8Array(sig))}`;
}

function appleForm(
  path: string,
  params: Record<string, string>,
  fetchImpl: typeof fetch,
): Promise<Response> {
  return fetchImpl(`${APPLE_ISSUER}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params),
  });
}

/**
 * Exchanges a fresh authorization code for Apple tokens and revokes them.
 * Never throws -- callers decide whether a failed revocation blocks deletion
 * (it must not: the account has to stay deletable even if Apple is down).
 */
export async function revokeAppleTokens(
  authorizationCode: string,
  fetchImpl: typeof fetch = fetch,
): Promise<AppleRevokeResult> {
  const cfg = loadAppleConfig();
  if (!cfg) return { ok: false, reason: "not_configured" };
  try {
    const clientSecret = await mintAppleClientSecret(cfg);
    const tokenRes = await appleForm("/auth/token", {
      client_id: cfg.clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }, fetchImpl);
    if (!tokenRes.ok) {
      return {
        ok: false,
        reason: "token_exchange_failed",
        detail: `${tokenRes.status} ${await tokenRes.text()}`,
      };
    }
    const tokens = (await tokenRes.json()) as {
      refresh_token?: string;
      access_token?: string;
    };
    // Revoking the refresh token invalidates every token Apple issued for
    // this user + app; the access token is only a fallback.
    const token = tokens.refresh_token ?? tokens.access_token;
    if (!token) {
      return {
        ok: false,
        reason: "token_exchange_failed",
        detail: "no token in response",
      };
    }
    const revokeRes = await appleForm("/auth/revoke", {
      client_id: cfg.clientId,
      client_secret: clientSecret,
      token,
      token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
    }, fetchImpl);
    if (!revokeRes.ok) {
      return {
        ok: false,
        reason: "revoke_failed",
        detail: `${revokeRes.status} ${await revokeRes.text()}`,
      };
    }
    return { ok: true };
  } catch (err) {
    return { ok: false, reason: "error", detail: String(err) };
  }
}

// RevenueCat customer deletion, the purchases half of account deletion
// (App Store guideline 5.1.1(v): deleting an account deletes its data).
//
// The app logs RevenueCat in with the Supabase auth uid (auth_notifier), so a
// customer's app_user_id IS the auth uid, and a purchase made anonymously
// before sign-up is aliased onto it at that login. Deleting the uid therefore
// removes the whole customer: purchase history, attributes and aliases.
// The store subscription itself belongs to Apple / Google; deleting the
// customer doesn't cancel it (the app tells people to cancel in the store).
//
// Env: REVENUECAT_SECRET_KEY — a RevenueCat *secret* API key (sk_…), the same
// one purchase-skin uses.

export type RevenueCatDeleteResult =
  | { ok: true }
  | {
    ok: false;
    reason: "not_configured" | "delete_failed" | "error";
    detail?: string;
  };

/**
 * Deletes RevenueCat customer [appUserId]. A customer RevenueCat doesn't know
 * (never purchased, or already deleted by an earlier attempt) counts as done.
 * Never throws -- callers decide whether a failure blocks deletion (it must
 * not: the account has to stay deletable even when RevenueCat is down).
 */
export async function deleteRevenueCatCustomer(
  appUserId: string,
  fetchImpl: typeof fetch = fetch,
): Promise<RevenueCatDeleteResult> {
  const key = Deno.env.get("REVENUECAT_SECRET_KEY");
  if (!key) return { ok: false, reason: "not_configured" };
  try {
    const res = await fetchImpl(
      `https://api.revenuecat.com/v1/subscribers/${
        encodeURIComponent(appUserId)
      }`,
      { method: "DELETE", headers: { Authorization: `Bearer ${key}` } },
    );
    if (res.ok || res.status === 404) {
      await res.body?.cancel();
      return { ok: true };
    }
    return {
      ok: false,
      reason: "delete_failed",
      detail: `${res.status} ${await res.text()}`,
    };
  } catch (err) {
    return { ok: false, reason: "error", detail: String(err) };
  }
}

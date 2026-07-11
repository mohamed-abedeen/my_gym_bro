#!/usr/bin/env python3
"""End-to-end verification of migration 009's delete_account_data() against LOCAL Supabase.

Exercises the transactional hard-delete the delete-account edge function relies on
(009_security_hardening.sql): create a throwaway auth user, seed one row for that user
in every table the function purges, call delete_account_data(uid) via RPC, then assert
every purged table has zero rows for the user and the auth user itself is gone.

Uses the SERVICE-ROLE key throughout: delete_account_data is REVOKEd from anon /
authenticated (server-only), creating/removing an auth user needs the admin API, and
service-role PostgREST writes bypass RLS so the seed inserts land directly. Requires
`supabase start` running.

Usage:
    SUPABASE_SERVICE_ROLE_KEY=sb_secret_... python3 tool/verify_delete_account.py
    # override the URL / key if your local stack differs:
    SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=sb_secret_... \
        python3 tool/verify_delete_account.py
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

BASE = os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
SERVICE = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

# Tables delete_account_data() purges, in insert-safe (parent-first) order. The
# script asserts each of these has zero rows for the user after the RPC.
PURGED_TABLES = (
    "posts", "post_likes", "post_comments",
    "sessions", "session_exercises", "sets",
    "schedules", "schedule_days", "scheduled_exercises",
    "follows", "subscriptions", "leaderboard_scores", "user_profiles",
)


def req(method, path, body=None, prefer=None):
    if not SERVICE:
        sys.exit("SUPABASE_SERVICE_ROLE_KEY is required (see the module docstring).")
    headers = {"apikey": SERVICE, "Authorization": f"Bearer {SERVICE}",
               "Content-Type": "application/json"}
    if prefer:
        headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def create_user():
    email = f"del_{uuid.uuid4().hex[:8]}@delacct.local"
    s, b = req("POST", "/auth/v1/admin/users",
               body={"email": email, "password": "Test12345!", "email_confirm": True})
    if s not in (200, 201):
        sys.exit(f"could not create throwaway auth user (HTTP {s}): {b}")
    return json.loads(b)["id"]


def count(table, uid):
    """Rows in `table` owned by uid. follows uses follower_id, not user_id."""
    col = "follower_id" if table == "follows" else "user_id"
    s, b = req("GET", f"/rest/v1/{table}?{col}=eq.{uid}&select=*")
    return len(json.loads(b)) if s == 200 else -1  # -1 => query failed, forces FAIL


def seed(uid):
    """Insert one row per purged table (parent rows first so FKs resolve)."""
    def ins(table, row):
        s, b = req("POST", f"/rest/v1/{table}", body=row, prefer="return=representation")
        if s not in (200, 201):
            sys.exit(f"seed insert into {table} failed (HTTP {s}): {b}")
        return json.loads(b)[0]["id"]

    post_id = ins("posts", {"user_id": uid, "content": "seed"})
    ins("post_likes", {"post_id": post_id, "user_id": uid})
    ins("post_comments", {"post_id": post_id, "user_id": uid, "content": "seed"})

    sess_id = ins("sessions", {"user_id": uid})
    se_id = ins("session_exercises",
                {"user_id": uid, "session_id": sess_id, "exercise_id": "ex1", "order_index": 0})
    ins("sets", {"user_id": uid, "session_exercise_id": se_id, "set_index": 0})

    sched_id = ins("schedules", {"user_id": uid, "name": "seed"})
    day_id = ins("schedule_days", {"user_id": uid, "schedule_id": sched_id, "day_index": 0})
    ins("scheduled_exercises",
        {"user_id": uid, "schedule_day_id": day_id, "exercise_id": "ex1", "order_index": 0})

    # follows needs a *second* user to point at (self-follow is blocked by a CHECK).
    other = create_user()
    ins("follows", {"follower_id": uid, "followee_id": other})

    ins("subscriptions", {"user_id": uid})
    # leaderboard_scores has a composite PK and no id column — insert without capturing one.
    s, b = req("POST", "/rest/v1/leaderboard_scores",
               body={"user_id": uid, "board": "weekly"}, prefer="return=minimal")
    if s not in (200, 201):
        sys.exit(f"seed insert into leaderboard_scores failed (HTTP {s}): {b}")
    # user_profiles row is auto-created by the 007 signup trigger — but the admin
    # create path may not fire it, so upsert one to be certain it exists to purge.
    req("POST", "/rest/v1/user_profiles",
        body={"user_id": uid, "display_name": "seed"},
        prefer="resolution=merge-duplicates,return=minimal")


def main():
    passed = failed = 0

    def check(name, cond):
        nonlocal passed, failed
        print(("  PASS" if cond else "  FAIL") + f" — {name}")
        passed += bool(cond)
        failed += (not cond)

    uid = create_user()
    print(f"throwaway user = {uid}")

    seed(uid)
    # Sanity: every table actually has the seeded row before we purge.
    seeded_ok = all(count(t, uid) >= 1 for t in PURGED_TABLES)
    check("all purged tables seeded with >=1 row before delete", seeded_ok)

    s, b = req("POST", "/rest/v1/rpc/delete_account_data", body={"target": uid})
    check(f"delete_account_data RPC succeeds (HTTP {s})", s in (200, 204))

    for t in PURGED_TABLES:
        n = count(t, uid)
        check(f"{t} has 0 rows for the user after delete (got {n})", n == 0)

    # The edge function calls auth.admin.deleteUser() after the RPC — emulate + assert.
    req("DELETE", f"/auth/v1/admin/users/{uid}")
    s, _ = req("GET", f"/auth/v1/admin/users/{uid}")
    check(f"auth user is gone after deletion (HTTP {s})", s == 404)

    print(f"\nRESULT: {passed} passed, {failed} failed")
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()

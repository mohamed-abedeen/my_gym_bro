#!/usr/bin/env python3
"""End-to-end verification for the Phase 2 social graph against LOCAL Supabase.

Drives the exact client path the app uses: signup via GoTrue, then
follow/unfollow + counts through PostgREST with real user JWTs (so RLS is
enforced — not the postgres superuser). Requires `supabase start` running.

Usage:
    python3 tool/verify_social.py
    # override the local anon key if your stack prints a different one:
    SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=sb_publishable_... \
        python3 tool/verify_social.py

Cleanup of the throwaway @phase2test.local users is left to:
    psql ... -c "delete from auth.users where email like '%@phase2test.local';"
(delete dependent public.user_profiles / public.follows rows first).
"""
import base64
import json
import os
import urllib.error
import urllib.request
import uuid

BASE = os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
ANON = os.environ.get(
    "SUPABASE_ANON_KEY", "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
)


def req(method, path, token=None, body=None, prefer=None):
    headers = {"apikey": ANON, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def jwt_sub(tok):
    p = tok.split(".")[1]
    p += "=" * (-len(p) % 4)
    return json.loads(base64.urlsafe_b64decode(p))["sub"]


def signup():
    email = f"u_{uuid.uuid4().hex[:8]}@phase2test.local"
    _, body = req("POST", "/auth/v1/signup", body={"email": email, "password": "Test12345!"})
    tok = json.loads(body)["access_token"]
    return tok, jwt_sub(tok)


def main():
    passed = failed = 0

    def check(name, cond):
        nonlocal passed, failed
        print(("  PASS" if cond else "  FAIL") + f" — {name}")
        passed += bool(cond)
        failed += (not cond)

    ta, a = signup()
    tb, b = signup()
    print(f"user A={a[:8]}  user B={b[:8]}")
    req("POST", "/rest/v1/user_profiles", ta, {"user_id": a, "display_name": "Alice"})
    req("POST", "/rest/v1/user_profiles", tb, {"user_id": b, "display_name": "Bob"})

    s, _ = req("POST", "/rest/v1/follows", ta,
               {"id": str(uuid.uuid4()), "follower_id": a, "followee_id": b}, "return=representation")
    check("A can follow B (own insert)", s in (200, 201))

    s, _ = req("POST", "/rest/v1/follows", ta,
               {"id": str(uuid.uuid4()), "follower_id": b, "followee_id": a})
    check("A CANNOT follow as B (RLS blocks)", s in (401, 403))

    s, _ = req("POST", "/rest/v1/follows", tb,
               {"id": str(uuid.uuid4()), "follower_id": b, "followee_id": a}, "return=representation")
    check("B can follow A (own insert)", s in (200, 201))

    _, body = req("GET", f"/rest/v1/public_profiles?user_id=eq.{a}", tb)
    pa = json.loads(body)[0]
    check("A counts follower=1 following=1 friend=1",
          pa["follower_count"] == 1 and pa["following_count"] == 1 and pa["friend_count"] == 1)

    _, body = req("GET", f"/rest/v1/friends?user_id=eq.{a}", ta)
    fr = json.loads(body)
    check("friends view shows A-B mutual", len(fr) == 1 and fr[0]["friend_id"] == b)

    s, _ = req("DELETE", f"/rest/v1/follows?follower_id=eq.{b}&followee_id=eq.{a}", tb,
               prefer="return=representation")
    check("B can unfollow A (own delete)", s in (200, 204))

    _, body = req("GET", f"/rest/v1/public_profiles?user_id=eq.{a}", tb)
    pa = json.loads(body)[0]
    check("after unfollow A friend=0 follower=0",
          pa["friend_count"] == 0 and pa["follower_count"] == 0)

    print(f"\nRESULT: {passed} passed, {failed} failed")
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""End-to-end verification of the Phase 3 community feed against LOCAL Supabase.

Mirrors SupabaseCommunityRepository's exact queries through PostgREST with real
user JWTs (RLS enforced): signup auto-creates a profile (007 trigger), the trial
gate lets a user read the feed, a post by user A is visible to user B with the
correct author name, and like toggling updates the embedded count.

Requires `supabase start` running. Usage: python3 tool/verify_feed.py
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


def signup(name):
    email = f"feed_{uuid.uuid4().hex[:8]}@phase3test.local"
    _, b = req("POST", "/auth/v1/signup",
               body={"email": email, "password": "Test12345!", "data": {"display_name": name}})
    t = json.loads(b)["access_token"]
    return t, jwt_sub(t)


FEED_SELECT = ("id, user_id, content, image_url, created_at, "
               "post_likes(count), post_comments(count)")


def main():
    passed = failed = 0

    def check(name, cond):
        nonlocal passed, failed
        print(("  PASS" if cond else "  FAIL") + f" — {name}")
        passed += bool(cond); failed += (not cond)

    ta, a = signup("Alice Lifts")
    tb, b = signup("Bob Bench")

    # A posts (trial gate must allow insert + the trigger gave A a profile)
    s, _ = req("POST", "/rest/v1/posts", ta, {"user_id": a, "content": "Leg day 🦵"}, "return=representation")
    check("A (trial) can create a post", s in (200, 201))

    # B reads the feed with the repo's exact query and sees A's post
    s, body = req("GET", f"/rest/v1/posts?select={urllib.parse.quote(FEED_SELECT)}&deleted_at=is.null&order=created_at.desc&limit=30", tb)
    rows = json.loads(body) if s == 200 else []
    post = next((r for r in rows if r["content"] == "Leg day 🦵"), None)
    check("B (trial) can read the feed and sees A's post", post is not None)

    # Author name resolves via public_profiles
    s, body = req("GET", f"/rest/v1/public_profiles?user_id=eq.{a}&select=display_name", tb)
    pp = json.loads(body) if s == 200 else []
    check("author name resolves to 'Alice Lifts'", pp and pp[0]["display_name"] == "Alice Lifts")

    pid = post["id"] if post else None
    # B likes A's post
    s, _ = req("POST", "/rest/v1/post_likes", tb, {"post_id": pid, "user_id": b}, "return=representation")
    check("B can like A's post", s in (200, 201))
    s, body = req("GET", f"/rest/v1/posts?select=id,post_likes(count)&id=eq.{pid}", tb)
    cnt = json.loads(body)[0]["post_likes"][0]["count"] if s == 200 else None
    check(f"like count embeds as 1 (got {cnt})", cnt == 1)

    # B unlikes -> 0
    req("DELETE", f"/rest/v1/post_likes?post_id=eq.{pid}&user_id=eq.{b}", tb)
    s, body = req("GET", f"/rest/v1/posts?select=id,post_likes(count)&id=eq.{pid}", tb)
    cnt = json.loads(body)[0]["post_likes"][0]["count"] if s == 200 else None
    check(f"after unlike count is 0 (got {cnt})", cnt == 0)

    print(f"\nRESULT: {passed} passed, {failed} failed")
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    import urllib.parse
    main()

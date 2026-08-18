#!/usr/bin/env bash
# MyGymBro server-side integration test against the local Supabase stack.
# Simulates what real clients + RevenueCat webhooks would do, then asserts.
set -u
API=http://127.0.0.1:54321
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
SVC="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
DB=$(docker ps --format '{{.Names}}' | grep supabase_db)
PASS=0; FAIL=0

q() { docker exec "$DB" psql -U postgres -d postgres -tA -c "$1" 2>&1; }
# INSERT ... RETURNING prints the value AND the command tag — keep line 1 only.
qid() { q "$1" | head -1; }
jget() { node -pe "try{JSON.parse(require('fs').readFileSync(0,'utf8'))$1}catch(e){'PARSE_ERR'}"; }
check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1";
  else FAIL=$((FAIL+1)); echo "FAIL: $1  expected=[$2] got=[$3]"; fi
}

mkuser() { curl -s -X POST "$API/auth/v1/admin/users" \
  -H "apikey: $SVC" -H "Authorization: Bearer $SVC" -H "Content-Type: application/json" \
  -d "{\"email\":\"$1\",\"password\":\"pass12345\",\"email_confirm\":true}" | jget ".id"; }
login() { curl -s -X POST "$API/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d "{\"email\":\"$1\",\"password\":\"pass12345\"}" | jget ".access_token"; }

echo "== setup: users =="
U1=$(mkuser bro1@test.local); U2=$(mkuser bro2@test.local)
U3=$(mkuser bro3@test.local); U4=$(mkuser bro4@test.local); U5=$(mkuser bro5@test.local)
T1=$(login bro1@test.local); T2=$(login bro2@test.local)
T3=$(login bro3@test.local); T4=$(login bro4@test.local); T5=$(login bro5@test.local)
check "signup trigger created profiles" "5" "$(q "SELECT count(*) FROM user_profiles")"

# Subscribers: u1,u2,u3,u5 active; u4 explicitly expired (gate test).
q "UPDATE user_profiles SET subscription_status='active', subscription_expires_at=now()+interval '30 days' WHERE user_id IN ('$U1','$U2','$U3','$U5')" >/dev/null
q "UPDATE user_profiles SET subscription_status='expired', subscription_expires_at=now()-interval '1 day', trial_started_at=now()-interval '30 days' WHERE user_id='$U4'" >/dev/null
q "UPDATE user_profiles SET username='bro'||substr(user_id::text,1,4) WHERE username IS NULL" >/dev/null

echo "== setup: workout history =="
seed_session() { # user date volume-sets: weight reps setcount
  local uid=$1 day=$2 w=$3 r=$4 n=$5
  local sid seid
  sid=$(qid "INSERT INTO sessions (user_id, started_at, finished_at, duration_seconds, total_volume_kg)
           VALUES ('$uid','$day 10:00+00','$day 11:00+00',3600,$(node -pe "$w*$r*$n")) RETURNING id")
  seid=$(qid "INSERT INTO session_exercises (user_id, session_id, exercise_id, order_index)
            VALUES ('$uid','$sid','bench_press',0) RETURNING id")
  for i in $(seq 1 "$n"); do
    q "INSERT INTO sets (user_id, session_exercise_id, set_index, weight_kg, reps, completed_at)
       VALUES ('$uid','$seid',$i,$w,$r,'$day 10:30+00')" >/dev/null
  done
}
# u1: 12 sessions (10 before/inside last week incl. a 110kg PR on 08-15, 2 this week)
for d in 2026-08-04 2026-08-05 2026-08-06 2026-08-07 2026-08-08 2026-08-11 2026-08-12 2026-08-13 2026-08-14; do
  seed_session "$U1" "$d" 100 10 5
done
seed_session "$U1" 2026-08-15 110 10 5
seed_session "$U1" 2026-08-17 100 10 5
seed_session "$U1" 2026-08-18 100 10 5
# u2: 6 sessions, lower volume
for d in 2026-08-11 2026-08-12 2026-08-13 2026-08-14 2026-08-15 2026-08-17; do
  seed_session "$U2" "$d" 60 8 3
done
# u3: 2 tiny sessions in last week
seed_session "$U3" 2026-08-12 40 5 1
seed_session "$U3" 2026-08-13 40 5 1
check "sessions seeded" "20" "$(q "SELECT count(*) FROM sessions")"
check "sets seeded under sessions" "80" "$(q "SELECT count(*) FROM sets")"

echo "== payments / subscriptions =="
WH() { curl -s -o /dev/null -w "%{http_code}" -X POST "$API/functions/v1/revenuecat-webhook" \
  -H "Authorization: $1" -H "Content-Type: application/json" -d "$2"; }
check "webhook rejects wrong secret" "401" \
  "$(WH wrong-secret "{\"event\":{\"type\":\"INITIAL_PURCHASE\",\"app_user_id\":\"$U4\",\"product_id\":\"mgb_premium_monthly\",\"expiration_at_ms\":$(node -pe "Date.now()+2592000000")}}")"
check "webhook accepts INITIAL_PURCHASE" "200" \
  "$(WH test-webhook-secret "{\"event\":{\"type\":\"INITIAL_PURCHASE\",\"app_user_id\":\"$U4\",\"product_id\":\"mgb_premium_monthly\",\"expiration_at_ms\":$(node -pe "Date.now()+2592000000")}}")"
check "purchase activates gate" "t" "$(q "SELECT has_active_subscription('$U4')")"
check "webhook EXPIRATION" "200" \
  "$(WH test-webhook-secret "{\"event\":{\"type\":\"EXPIRATION\",\"app_user_id\":\"$U4\",\"product_id\":\"mgb_premium_monthly\",\"expiration_at_ms\":$(node -pe "Date.now()-1000")}}")"
check "expiration closes gate" "f" "$(q "SELECT has_active_subscription('$U4')")"
VS=$(curl -s "$API/functions/v1/verify-subscription" -H "apikey: $ANON" -H "Authorization: Bearer $T4")
check "verify-subscription reflects server truth" "expired" "$(echo "$VS" | jget ".status")"

echo "== challenges =="
q "SELECT seed_daily_challenge()" >/dev/null
CH=$(q "SELECT id FROM challenges WHERE source='curated' ORDER BY created_at DESC LIMIT 1")
JOIN=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/rest/v1/challenge_participants" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T1" -H "Content-Type: application/json" \
  -d "{\"challenge_id\":\"$CH\",\"user_id\":\"$U1\",\"progress\":0}")
check "subscriber can join a challenge (RLS)" "201" "$JOIN"
GOAL=$(q "SELECT goal_value FROM challenges WHERE id='$CH'")
# The real client stamps completed_at itself (ChallengeRepository) — the
# trigger validates it against progress/window and derives the points.
NOW=$(node -pe "new Date().toISOString()")
curl -s -o /dev/null -X PATCH "$API/rest/v1/challenge_participants?challenge_id=eq.$CH&user_id=eq.$U1" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T1" -H "Content-Type: application/json" \
  -d "{\"progress\":$GOAL,\"completed_at\":\"$NOW\"}"
check "award trigger completes + pays points" "t" \
  "$(q "SELECT completed_at IS NOT NULL AND points_awarded > 0 FROM challenge_participants WHERE challenge_id='$CH' AND user_id='$U1'")"
# moderation: community challenge by u2, hidden at 3 distinct reporters
CC=$(qid "INSERT INTO challenges (source, creator_id, title, goal_type, goal_value, starts_at, ends_at, points, status)
        VALUES ('community','$U2','Spam challenge','sessions',1,now(),now()+interval '7 days',10,'active') RETURNING id")
for tok_uid in "$T1:$U1" "$T3:$U3" "$T5:$U5"; do
  tok=${tok_uid%%:*}; uid=${tok_uid##*:}
  curl -s -o /dev/null -X POST "$API/rest/v1/challenge_reports" \
    -H "apikey: $ANON" -H "Authorization: Bearer $tok" -H "Content-Type: application/json" \
    -d "{\"challenge_id\":\"$CC\",\"reporter_id\":\"$uid\",\"reason\":\"spam\"}"
done
check "3 reporters hide a community challenge" "hidden" "$(q "SELECT status FROM challenges WHERE id='$CC'")"

echo "== leaderboard / ranks =="
q "SELECT compute_leaderboard_scores()" >/dev/null
check "scores computed for 3 boards" "t" "$(q "SELECT count(DISTINCT board)=3 FROM leaderboard_scores")"
GLOB=$(curl -s "$API/rest/v1/rpc/leaderboard_global" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T3" -H "Content-Type: application/json" -d '{"p_board":"all_time"}')
check "global all-time rank 1 is the strongest user" "$U1" "$(echo "$GLOB" | jget "[0].user_id")"
# friends: u2 requests, u1 accepts (RLS both directions), then u2's friends board
curl -s -o /dev/null -X POST "$API/rest/v1/friendships" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T2" -H "Content-Type: application/json" \
  -d "{\"requester_id\":\"$U2\",\"addressee_id\":\"$U1\",\"status\":\"pending\"}"
curl -s -o /dev/null -X PATCH "$API/rest/v1/friendships?requester_id=eq.$U2&addressee_id=eq.$U1" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T1" -H "Content-Type: application/json" \
  -d '{"status":"accepted"}'
FR=$(curl -s "$API/rest/v1/rpc/leaderboard_friends" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T2" -H "Content-Type: application/json" -d '{"p_board":"all_time"}')
check "friends board = self + mutual friend" "2" "$(echo "$FR" | jget ".length")"
q "SELECT assign_rivals()" >/dev/null
RIV=$(curl -s "$API/rest/v1/rpc/leaderboard_rivals" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T2" -H "Content-Type: application/json" -d '{"p_board":"weekly"}')
check "rivals pod ranks the caller" "true" "$(echo "$RIV" | jget ".length >= 1")"
q "SELECT finalize_season('weekly')" >/dev/null
check "season finalized with full standings" "t" "$(q "SELECT count(*) >= 3 FROM season_results WHERE board='weekly'")"
check "weekly season winner is u1" "$U1" "$(q "SELECT user_id FROM season_results WHERE board='weekly' AND final_rank=1 ORDER BY season_start DESC LIMIT 1")"
WIN=$(curl -s "$API/rest/v1/rpc/leaderboard_last_winner" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T2" -H "Content-Type: application/json" -d '{"p_board":"weekly","p_scope":"global"}')
check "last-winner RPC returns u1" "$U1" "$(echo "$WIN" | jget "[0].user_id")"

echo "== skins =="
GR=$(q "SELECT evaluate_earned_skins()")
check "earned-skin evaluation grants rows" "true" "$(node -pe "$GR >= 2")"
check "u1 earned carbon via 10+ sessions" "1" "$(q "SELECT count(*) FROM skin_ownership WHERE user_id='$U1' AND skin_id='carbon' AND source='earned'")"
check "u1 earned volkano via weekly season win" "1" "$(q "SELECT count(*) FROM skin_ownership WHERE user_id='$U1' AND skin_id='volkano' AND source='earned'")"
check "re-run grants nothing new (idempotent)" "0" "$(q "SELECT evaluate_earned_skins()")"
OWN2=$(curl -s "$API/rest/v1/skin_ownership?select=skin_id" -H "apikey: $ANON" -H "Authorization: Bearer $T2")
check "RLS: u2 sees only own ownership rows" "0" "$(echo "$OWN2" | jget ".length")"
SPOOF=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/rest/v1/skin_ownership" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T2" -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$U2\",\"skin_id\":\"gold\",\"source\":\"purchased\"}")
check "anti-spoof: client INSERT into skin_ownership denied" "403" "$SPOOF"
PS_NOAUTH=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/functions/v1/purchase-skin" -H "apikey: $ANON")
check "purchase-skin rejects missing auth" "401" "$PS_NOAUTH"
PS_NOKEY=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/functions/v1/purchase-skin" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T1")
check "purchase-skin fails soft without RC secret" "503" "$PS_NOKEY"
SEL=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$API/rest/v1/user_profiles?user_id=eq.$U1" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T1" -H "Content-Type: application/json" \
  -d '{"active_skin_id":"carbon"}')
check "skin selection PATCH by user_id allowed (column GRANT)" "204" "$SEL"
PUB=$(curl -s "$API/rest/v1/public_profiles?user_id=eq.$U1&select=active_skin_id" -H "apikey: $ANON" -H "Authorization: Bearer $T2")
check "public profile exposes the selected skin" "carbon" "$(echo "$PUB" | jget "[0].active_skin_id")"
LOCK=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$API/rest/v1/user_profiles?user_id=eq.$U1" \
  -H "apikey: $ANON" -H "Authorization: Bearer $T1" -H "Content-Type: application/json" \
  -d '{"subscription_status":"active"}')
check "subscription columns still locked (009)" "403" "$LOCK"

echo "== periodic reports =="
RW=$(q "SELECT generate_progress_reports('weekly')")
check "weekly reports for the 3 training subscribers" "3" "$RW"
check "u1 weekly volume metric correct" "25500.0" \
  "$(q "SELECT metrics->>'volume_kg' FROM progress_reports WHERE user_id='$U1' AND period_type='weekly'")"
check "u1 weekly pr_count = 1 (the 110kg session)" "1" \
  "$(q "SELECT metrics->>'pr_count' FROM progress_reports WHERE user_id='$U1' AND period_type='weekly'")"
check "delta = current - previous period (+500)" "500.0" \
  "$(q "SELECT deltas->>'volume_kg' FROM progress_reports WHERE user_id='$U1' AND period_type='weekly'")"
check "reports rerun is idempotent" "0" "$(q "SELECT generate_progress_reports('weekly')")"
RPT2=$(curl -s "$API/rest/v1/progress_reports?select=user_id" -H "apikey: $ANON" -H "Authorization: Bearer $T2")
check "RLS: u2 sees only own reports" "1" "$(echo "$RPT2" | jget ".length")"

echo "== workout push (019) =="
WSID=$(node -pe "require('crypto').randomUUID()")
WEXID=$(node -pe "require('crypto').randomUUID()")
WSETID=$(node -pe "require('crypto').randomUUID()")
PUSH() { curl -s -o /dev/null -w "%{http_code}" -X POST "$API/rest/v1/rpc/push_workout" \
  -H "apikey: $ANON" -H "Authorization: Bearer $1" -H "Content-Type: application/json" -d "$2"; }
WPAYLOAD() { echo "{\"p\":{\"session\":{\"id\":\"$WSID\",\"started_at\":\"2026-08-18T09:00:00Z\",\"finished_at\":\"2026-08-18T10:00:00Z\",\"duration_seconds\":3600,\"total_volume_kg\":$1},\"exercises\":[{\"id\":\"$WEXID\",\"exercise_id\":\"bench_press\",\"order_index\":0,\"sets\":[{\"id\":\"$WSETID\",\"set_index\":0,\"weight_kg\":$2,\"reps\":5,\"is_warmup\":false,\"completed_at\":\"2026-08-18T10:00:00Z\"}]}]}}"; }
check "push_workout uploads a session" "204" "$(PUSH "$T5" "$(WPAYLOAD 500 100)")"
check "pushed rows land under the caller" "t" \
  "$(q "SELECT (SELECT count(*)=1 FROM sessions WHERE id='$WSID' AND user_id='$U5') AND (SELECT count(*)=1 FROM sets WHERE id='$WSETID' AND user_id='$U5')")"
check "re-push heals edited set values" "204" "$(PUSH "$T5" "$(WPAYLOAD 550 110)")"
check "set updated in place, no duplicates" "110|1" \
  "$(q "SELECT (SELECT weight_kg FROM sets WHERE id='$WSETID') || '|' || (SELECT count(*) FROM sets WHERE session_exercise_id='$WEXID')")"
# Depending on server version the hijack dies on the function's P0001
# ownership guard (400) or RLS's conflict check (42501 → 403) — both are
# permanent-drop codes client-side, and nothing is written either way.
HJ=$(PUSH "$T2" "$(WPAYLOAD 500 100)")
if [ "$HJ" = "400" ] || [ "$HJ" = "403" ]; then
  check "hijack: pushing another user's session id fails" "$HJ" "$HJ"
else
  check "hijack: pushing another user's session id fails" "400-or-403" "$HJ"
fi
check "hijack changed nothing" "$U5" "$(q "SELECT user_id FROM sessions WHERE id='$WSID'")"
check "anon cannot execute push_workout" "401" \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/rest/v1/rpc/push_workout" -H "apikey: $ANON" -H "Content-Type: application/json" -d "$(WPAYLOAD 1 1)")"

echo "== account deletion =="
q "SELECT delete_account_data('$U3')" >/dev/null
check "delete_account_data wipes every u3 row" "0" \
  "$(q "SELECT (SELECT count(*) FROM sessions WHERE user_id='$U3') + (SELECT count(*) FROM user_profiles WHERE user_id='$U3') + (SELECT count(*) FROM skin_ownership WHERE user_id='$U3') + (SELECT count(*) FROM progress_reports WHERE user_id='$U3') + (SELECT count(*) FROM challenge_participants WHERE user_id='$U3')")"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"

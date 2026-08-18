-- ─────────────────────────────────────────────────────────────────────────────
-- 019 — push_workout(): the client's workout-data upload path
--
-- Until now NOTHING pushed workout data to the cloud (the SETUP-STATUS
-- blocker): the only sync op was a sessions UPDATE keyed on a remote id no
-- code ever assigned, so sessions/session_exercises/sets stayed empty and
-- every server-side consumer (leaderboard 008/015, challenges 014, bros
-- strip 012, earned skins 016, reports 017) ran on nothing.
--
-- The client now enqueues ONE outbox item per finished session — an RPC to
-- this function — instead of per-table INSERTs. Rationale: the sync queue
-- drops permanently-rejected items (23503 FK violations included), so a
-- transiently-failing parent INSERT followed by its children would get the
-- children permanently dropped. One atomic RPC removes the ordering hazard
-- and makes the whole session transactional.
--
-- Contract:
--   • SECURITY INVOKER — runs as the caller; RLS still applies to every
--     insert. user_id is ALWAYS auth.uid(); any client-supplied user id is
--     ignored.
--   • Ids are client-generated uuids stored in the client DB, so a re-push
--     is idempotent: the session summary and set values upsert (edits heal),
--     exercise rows are insert-once.
--   • Ownership: upserting into someone else's uuid is stopped twice over —
--     RLS's conflict check can raise 42501, and the NOT EXISTS guards below
--     raise P0001 (the path that fires on current stacks, verified by
--     supabase/tests/local_integration.sh). Both codes are in the client's
--     permanent-drop set; children can never be attached to another user's
--     session/exercise either way.
--   • Bounds: ≤ 50 exercises, ≤ 100 sets each — far above real workouts,
--     just an abuse ceiling.
--
-- NOT YET DEPLOYED — rides the first `supabase db push` (SETUP-STATUS).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.push_workout(p jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    uid uuid := auth.uid();
    s   jsonb := p -> 'session';
    sid uuid;
    ex  jsonb;
    st  jsonb;
    exid uuid;
    ex_count  integer := 0;
    set_count integer;
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'push_workout: not authenticated';
    END IF;
    IF s IS NULL OR s ->> 'id' IS NULL OR s ->> 'started_at' IS NULL THEN
        RAISE EXCEPTION 'push_workout: malformed session';
    END IF;
    sid := (s ->> 'id')::uuid;

    -- Session summary: insert-or-refresh. The WHERE guard means a conflict
    -- on a row the caller doesn't own updates nothing; the ownership check
    -- right after then raises instead of silently attaching children.
    INSERT INTO sessions
        (id, user_id, started_at, finished_at, duration_seconds, total_volume_kg, notes)
    VALUES (
        sid,
        uid,
        (s ->> 'started_at')::timestamptz,
        (s ->> 'finished_at')::timestamptz,
        (s ->> 'duration_seconds')::integer,
        (s ->> 'total_volume_kg')::real,
        left(s ->> 'notes', 2000)
    )
    ON CONFLICT (id) DO UPDATE SET
        finished_at      = EXCLUDED.finished_at,
        duration_seconds = EXCLUDED.duration_seconds,
        total_volume_kg  = EXCLUDED.total_volume_kg,
        notes            = EXCLUDED.notes,
        updated_at       = now()
    WHERE sessions.user_id = uid;

    IF NOT EXISTS (SELECT 1 FROM sessions WHERE id = sid AND user_id = uid) THEN
        RAISE EXCEPTION 'push_workout: session id belongs to another user';
    END IF;

    FOR ex IN SELECT * FROM jsonb_array_elements(coalesce(p -> 'exercises', '[]'::jsonb))
    LOOP
        ex_count := ex_count + 1;
        IF ex_count > 50 THEN
            RAISE EXCEPTION 'push_workout: too many exercises';
        END IF;
        IF ex ->> 'id' IS NULL OR ex ->> 'exercise_id' IS NULL THEN
            RAISE EXCEPTION 'push_workout: malformed exercise';
        END IF;
        exid := (ex ->> 'id')::uuid;

        INSERT INTO session_exercises (id, user_id, session_id, exercise_id, order_index)
        VALUES (
            exid,
            uid,
            sid,
            left(ex ->> 'exercise_id', 64),
            coalesce((ex ->> 'order_index')::integer, 0)
        )
        ON CONFLICT (id) DO NOTHING;

        IF NOT EXISTS (SELECT 1 FROM session_exercises
                       WHERE id = exid AND user_id = uid AND session_id = sid) THEN
            RAISE EXCEPTION 'push_workout: exercise id belongs to another user';
        END IF;

        set_count := 0;
        FOR st IN SELECT * FROM jsonb_array_elements(coalesce(ex -> 'sets', '[]'::jsonb))
        LOOP
            set_count := set_count + 1;
            IF set_count > 100 THEN
                RAISE EXCEPTION 'push_workout: too many sets';
            END IF;

            -- Set values upsert (WHERE-guarded like the session) so a
            -- re-push after a local edit heals the server copy.
            INSERT INTO sets
                (id, user_id, session_exercise_id, set_index, weight_kg, reps,
                 is_warmup, is_dropset, rpe, completed_at)
            VALUES (
                (st ->> 'id')::uuid,
                uid,
                exid,
                coalesce((st ->> 'set_index')::integer, 0),
                (st ->> 'weight_kg')::real,
                (st ->> 'reps')::integer,
                coalesce((st ->> 'is_warmup')::boolean, false),
                coalesce((st ->> 'is_dropset')::boolean, false),
                (st ->> 'rpe')::real,
                (st ->> 'completed_at')::timestamptz
            )
            ON CONFLICT (id) DO UPDATE SET
                set_index  = EXCLUDED.set_index,
                weight_kg  = EXCLUDED.weight_kg,
                reps       = EXCLUDED.reps,
                is_warmup  = EXCLUDED.is_warmup,
                is_dropset = EXCLUDED.is_dropset,
                rpe        = EXCLUDED.rpe,
                updated_at = now()
            WHERE sets.user_id = uid;
        END LOOP;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.push_workout(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.push_workout(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.push_workout(jsonb) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 024 — push_schedule(): back up workout routines (schedules) to the account
--
-- The schedules / schedule_days / scheduled_exercises tables have existed
-- since 001 with own-row RLS (001) and authenticated grants (018), but the
-- client never wrote to them: routines lived only in the device DB, so a
-- reinstall or a new phone lost every saved routine even though workout
-- history (019) came back.
--
-- The client now pushes ONE routine per call, whole: the schedule row plus
-- its days and their exercises. Rationale, as for push_workout (019): one
-- atomic RPC instead of per-table outbox inserts, so a transiently failing
-- parent can never get its children dropped on FK errors.
--
-- Contract:
--   • SECURITY INVOKER — RLS applies to every statement; user_id is ALWAYS
--     auth.uid().
--   • The schedule id is a client-generated uuid kept in the client DB
--     (schedules.remote_id), so a re-push is an idempotent upsert. A schedule
--     id owned by another user raises P0001 (the client's permanent-drop set).
--   • Children are REPLACED wholesale on every push. The client edits days and
--     exercises by delete-and-reinsert, so child ids carry no meaning; the
--     server generates them. Server sessions never set schedule_day_id
--     (push_workout leaves it NULL); any that do are detached first so the
--     replace can't fail on the FK.
--   • {"id": …, "deleted": true} soft-deletes the schedule (children stay,
--     the client's restore filters on the schedule's deleted_at). An upsert
--     never clears deleted_at, so a late push can't resurrect a deletion.
--   • Bounds: ≤ 31 days, ≤ 50 exercises a day, names ≤ 100 chars — an abuse
--     ceiling far above real routines.
--
-- Also adds the cardio targets the client has stored since its v16 schema
-- (target_duration_seconds / target_distance) so they survive a restore.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.scheduled_exercises
    ADD COLUMN IF NOT EXISTS target_duration_seconds INTEGER;
ALTER TABLE public.scheduled_exercises
    ADD COLUMN IF NOT EXISTS target_distance REAL;

CREATE OR REPLACE FUNCTION public.push_schedule(p jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    uid uuid := auth.uid();
    sid uuid;
    d   jsonb;
    e   jsonb;
    did uuid;
    day_count integer := 0;
    ex_count  integer;
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'push_schedule: not authenticated';
    END IF;
    IF p IS NULL OR p ->> 'id' IS NULL THEN
        RAISE EXCEPTION 'push_schedule: malformed schedule';
    END IF;
    sid := (p ->> 'id')::uuid;

    IF coalesce((p ->> 'deleted')::boolean, false) THEN
        UPDATE schedules
           SET deleted_at = now(), updated_at = now()
         WHERE id = sid AND user_id = uid AND deleted_at IS NULL;
        RETURN;
    END IF;

    IF p ->> 'name' IS NULL THEN
        RAISE EXCEPTION 'push_schedule: malformed schedule';
    END IF;

    INSERT INTO schedules (id, user_id, name, is_active)
    VALUES (
        sid,
        uid,
        left(p ->> 'name', 100),
        coalesce((p ->> 'is_active')::boolean, false)
    )
    ON CONFLICT (id) DO UPDATE SET
        name       = EXCLUDED.name,
        is_active  = EXCLUDED.is_active,
        updated_at = now()
    WHERE schedules.user_id = uid;

    IF NOT EXISTS (SELECT 1 FROM schedules WHERE id = sid AND user_id = uid) THEN
        RAISE EXCEPTION 'push_schedule: schedule id belongs to another user';
    END IF;

    -- Replace the children.
    UPDATE sessions
       SET schedule_day_id = NULL
     WHERE user_id = uid
       AND schedule_day_id IN (SELECT id FROM schedule_days WHERE schedule_id = sid);
    DELETE FROM scheduled_exercises
     WHERE user_id = uid
       AND schedule_day_id IN (SELECT id FROM schedule_days WHERE schedule_id = sid);
    DELETE FROM schedule_days WHERE schedule_id = sid AND user_id = uid;

    FOR d IN SELECT * FROM jsonb_array_elements(coalesce(p -> 'days', '[]'::jsonb))
    LOOP
        day_count := day_count + 1;
        IF day_count > 31 THEN
            RAISE EXCEPTION 'push_schedule: too many days';
        END IF;

        INSERT INTO schedule_days (user_id, schedule_id, day_index, label, is_rest_day)
        VALUES (
            uid,
            sid,
            coalesce((d ->> 'day_index')::integer, day_count - 1),
            left(d ->> 'label', 100),
            coalesce((d ->> 'is_rest_day')::boolean, false)
        )
        RETURNING id INTO did;

        ex_count := 0;
        FOR e IN SELECT * FROM jsonb_array_elements(coalesce(d -> 'exercises', '[]'::jsonb))
        LOOP
            ex_count := ex_count + 1;
            IF ex_count > 50 THEN
                RAISE EXCEPTION 'push_schedule: too many exercises';
            END IF;
            IF e ->> 'exercise_id' IS NULL THEN
                RAISE EXCEPTION 'push_schedule: malformed exercise';
            END IF;

            INSERT INTO scheduled_exercises
                (user_id, schedule_day_id, exercise_id, order_index,
                 target_sets, target_reps, target_duration_seconds, target_distance)
            VALUES (
                uid,
                did,
                left(e ->> 'exercise_id', 64),
                coalesce((e ->> 'order_index')::integer, ex_count - 1),
                coalesce((e ->> 'target_sets')::integer, 3),
                coalesce((e ->> 'target_reps')::integer, 10),
                (e ->> 'target_duration_seconds')::integer,
                (e ->> 'target_distance')::real
            );
        END LOOP;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.push_schedule(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.push_schedule(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.push_schedule(jsonb) TO authenticated;

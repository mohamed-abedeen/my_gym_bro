-- ─────────────────────────────────────────────────────────────────────────────
-- 020 — routine_shares: share a workout program/day via a short link
--
-- A share is an INDEPENDENT, IMMUTABLE SNAPSHOT of a local schedule (or one
-- day of it), uploaded on demand when the user taps Share. It deliberately
-- does NOT touch the dead remote schedules/schedule_days/scheduled_exercises
-- tables from 001 — nothing syncs those, and a share must not start to.
--
-- Flow: client encodes the schedule → create_routine_share(p) stores a
-- server-scrubbed copy and returns an 8-char code → the link is
-- https://mygymbro.app/s/<code> → the recipient (signed in; the app is
-- authenticated-only, anon keeps zero grants per 018) calls
-- get_routine_share(code) and imports the payload into their local DB.
--
-- Security contract:
--   • All four functions are SECURITY DEFINER with SET search_path = public;
--     the table has NO client INSERT/UPDATE/DELETE policies — writes only
--     happen through these functions. Owners can SELECT their own rows
--     (future "my shares" UI); recipients never touch the table directly.
--   • create_routine_share REBUILDS the payload from whitelisted keys with
--     length truncation, tag/control-char stripping and numeric clamps —
--     client JSON is never stored verbatim. Hard caps: 100 KB, 31 days,
--     50 exercises/day, 30 shares per owner per hour.
--   • get_routine_share never returns owner_id, and returns NULL for both
--     unknown AND revoked codes (doesn't confirm a code ever existed).
--   • Codes: 8 chars from a 31-char ambiguity-free alphabet (no i/l/o/0/1)
--     → 31^8 ≈ 8.5e11 combinations; enumeration at that sparsity is
--     impractical, so reads need no extra rate limit.
--   • Rows are soft-revoked (revoked_at), never client-deleted; account
--     deletion cascades via owner_id → auth.users.
--
-- NOT YET DEPLOYED — rides the first `supabase db push` (SETUP-STATUS).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.routine_shares (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code         text NOT NULL UNIQUE,
    owner_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kind         text NOT NULL CHECK (kind IN ('program', 'day')),
    title        text NOT NULL,
    payload      jsonb NOT NULL,
    import_count integer NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now(),
    revoked_at   timestamptz
);

CREATE INDEX routine_shares_owner_idx
    ON public.routine_shares (owner_id, created_at DESC);

ALTER TABLE public.routine_shares ENABLE ROW LEVEL SECURITY;

-- Owners can list their own shares; nobody else reads the table directly.
CREATE POLICY routine_shares_owner_select ON public.routine_shares
    FOR SELECT TO authenticated USING (owner_id = auth.uid());
-- No INSERT/UPDATE/DELETE policies on purpose — the DEFINER functions below
-- are the only write path.

-- 018-style explicit grants (service_role already covered by 018's default
-- privileges; repeated so this file is self-auditing). anon gets nothing.
GRANT ALL ON public.routine_shares TO service_role;
GRANT SELECT ON public.routine_shares TO authenticated;

-- ── internal text scrubber (not client-callable) ─────────────────────────────
-- Strip tag-like runs and control chars, trim, truncate. Defense mirrors the
-- client codec's InputSanitiser pass — the server copy is authoritative.
CREATE OR REPLACE FUNCTION public.routine_share_scrub(t text, max_len integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT left(
        btrim(regexp_replace(
            regexp_replace(coalesce(t, ''), '<[^>]*>', '', 'g'),
            '[\x00-\x1F\x7F]', ' ', 'g')),
        max_len)
$$;

REVOKE ALL ON FUNCTION public.routine_share_scrub(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.routine_share_scrub(text, integer) FROM anon;
REVOKE ALL ON FUNCTION public.routine_share_scrub(text, integer) FROM authenticated;

-- ── create_routine_share(p) → code ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_routine_share(p jsonb)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    uid       uuid := auth.uid();
    alphabet  constant text := 'abcdefghjkmnpqrstuvwxyz23456789';
    v_kind    text;
    v_title   text;
    clean_days jsonb := '[]'::jsonb;
    clean_exs  jsonb;
    d         jsonb;
    e         jsonb;
    day_count integer := 0;
    ex_count  integer;
    total_ex  integer := 0;
    v_label   text;
    v_rest    boolean;
    v_name    text;
    v_exid    text;
    v_muscle  text;
    v_sets    integer;
    v_reps    integer;
    v_dur     integer;
    v_dist    numeric;
    raw       text;
    v_code    text;
    bytes     bytea;
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'create_routine_share: not authenticated';
    END IF;

    -- Hard byte cap before any iteration.
    IF p IS NULL OR octet_length(p::text) > 100000 THEN
        RAISE EXCEPTION 'create_routine_share: payload too large';
    END IF;
    IF p ->> 'v' IS DISTINCT FROM '1' THEN
        RAISE EXCEPTION 'create_routine_share: unsupported payload version';
    END IF;

    v_kind := p ->> 'kind';
    IF v_kind NOT IN ('program', 'day') THEN
        RAISE EXCEPTION 'create_routine_share: malformed payload';
    END IF;

    v_title := routine_share_scrub(p ->> 'title', 80);
    IF v_title = '' THEN
        RAISE EXCEPTION 'create_routine_share: malformed payload';
    END IF;

    IF jsonb_typeof(p -> 'days') IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'create_routine_share: malformed payload';
    END IF;
    IF v_kind = 'day' AND jsonb_array_length(p -> 'days') <> 1 THEN
        RAISE EXCEPTION 'create_routine_share: malformed payload';
    END IF;

    -- Rate limit: 30 shares per owner per hour (keep it simple — one COUNT).
    IF (SELECT count(*) FROM routine_shares
        WHERE owner_id = uid
          AND created_at > now() - interval '1 hour') >= 30 THEN
        RAISE EXCEPTION 'create_routine_share: too many shares, try again later';
    END IF;

    -- Rebuild a clean payload from whitelisted keys only.
    FOR d IN SELECT * FROM jsonb_array_elements(p -> 'days')
    LOOP
        day_count := day_count + 1;
        IF day_count > 31 THEN
            RAISE EXCEPTION 'create_routine_share: too many days';
        END IF;
        IF jsonb_typeof(d) IS DISTINCT FROM 'object' THEN
            RAISE EXCEPTION 'create_routine_share: malformed payload';
        END IF;

        v_label := routine_share_scrub(d ->> 'label', 60);
        v_rest  := lower(coalesce(d ->> 'rest', 'false')) = 'true';
        clean_exs := '[]'::jsonb;
        ex_count := 0;

        IF NOT v_rest THEN
            FOR e IN SELECT * FROM jsonb_array_elements(coalesce(d -> 'exercises', '[]'::jsonb))
            LOOP
                ex_count := ex_count + 1;
                IF ex_count > 50 THEN
                    RAISE EXCEPTION 'create_routine_share: too many exercises';
                END IF;
                IF jsonb_typeof(e) IS DISTINCT FROM 'object' THEN
                    RAISE EXCEPTION 'create_routine_share: malformed payload';
                END IF;

                v_exid := e ->> 'id';
                IF v_exid IS NOT NULL AND v_exid !~ '^[A-Za-z0-9_-]{1,64}$' THEN
                    v_exid := NULL;
                END IF;
                v_name := routine_share_scrub(e ->> 'name', 120);
                IF v_name = '' THEN
                    IF v_exid IS NULL THEN
                        CONTINUE;   -- nothing to identify the exercise by — drop it
                    END IF;
                    v_name := v_exid;
                END IF;
                v_muscle := nullif(routine_share_scrub(e ->> 'muscle', 40), '');

                -- Regex-validate before casting so garbage never raises 22P02.
                raw := e ->> 'sets';
                v_sets := CASE WHEN raw ~ '^[0-9]{1,4}$' THEN raw::integer ELSE 3 END;
                v_sets := least(greatest(v_sets, 1), 30);
                raw := e ->> 'reps';
                v_reps := CASE WHEN raw ~ '^[0-9]{1,4}$' THEN raw::integer ELSE 10 END;
                v_reps := least(greatest(v_reps, 1), 999);
                raw := e ->> 'durationSeconds';
                v_dur := CASE WHEN raw ~ '^[0-9]{1,6}$' THEN raw::integer ELSE NULL END;
                IF v_dur IS NOT NULL THEN
                    v_dur := least(greatest(v_dur, 1), 86400);
                END IF;
                raw := e ->> 'distance';
                v_dist := CASE WHEN raw ~ '^[0-9]{1,5}(\.[0-9]{1,3})?$' THEN raw::numeric ELSE NULL END;
                IF v_dist IS NOT NULL THEN
                    v_dist := least(v_dist, 1000);
                END IF;

                clean_exs := clean_exs || jsonb_strip_nulls(jsonb_build_object(
                    'id',              v_exid,
                    'name',            v_name,
                    'muscle',          v_muscle,
                    'sets',            v_sets,
                    'reps',            v_reps,
                    'durationSeconds', v_dur,
                    'distance',        v_dist));
                total_ex := total_ex + 1;
            END LOOP;
        END IF;

        clean_days := clean_days || jsonb_build_object(
            'label',     v_label,
            'rest',      v_rest,
            'exercises', clean_exs);
    END LOOP;

    IF day_count = 0 OR total_ex = 0 THEN
        RAISE EXCEPTION 'create_routine_share: nothing to share';
    END IF;

    -- Allocate a code: 8 chars of uuid-derived CSPRNG entropy; the 256 % 31
    -- modulo bias is irrelevant at this scale. Collisions retry (5 attempts).
    FOR attempt IN 1..5 LOOP
        bytes := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
        v_code := '';
        FOR i IN 1..8 LOOP
            v_code := v_code || substr(alphabet, (get_byte(bytes, i - 1) % 31) + 1, 1);
        END LOOP;
        BEGIN
            INSERT INTO routine_shares (code, owner_id, kind, title, payload)
            VALUES (v_code, uid, v_kind, v_title, jsonb_build_object(
                'v',     1,
                'kind',  v_kind,
                'title', v_title,
                'days',  clean_days));
            RETURN v_code;
        EXCEPTION WHEN unique_violation THEN
            NULL;   -- collision — loop and try a fresh code
        END;
    END LOOP;
    RAISE EXCEPTION 'create_routine_share: could not allocate a code';
END;
$$;

REVOKE ALL ON FUNCTION public.create_routine_share(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_routine_share(jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_routine_share(jsonb) TO authenticated;

-- ── get_routine_share(code) → {kind, title, payload, created_at} | NULL ──────
CREATE OR REPLACE FUNCTION public.get_routine_share(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    uid uuid := auth.uid();
    c   text;
    r   record;
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'get_routine_share: not authenticated';
    END IF;
    c := lower(btrim(coalesce(p_code, '')));
    IF c !~ '^[a-z0-9]{4,16}$' THEN
        RETURN NULL;
    END IF;
    SELECT kind, title, payload, created_at INTO r
    FROM routine_shares
    WHERE code = c AND revoked_at IS NULL;
    IF NOT FOUND THEN
        RETURN NULL;   -- unknown and revoked are indistinguishable on purpose
    END IF;
    RETURN jsonb_build_object(
        'kind',       r.kind,
        'title',      r.title,
        'payload',    r.payload,
        'created_at', r.created_at);
END;
$$;

REVOKE ALL ON FUNCTION public.get_routine_share(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_routine_share(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_routine_share(text) TO authenticated;

-- ── increment_share_import(code) — best-effort counter after an import ───────
CREATE OR REPLACE FUNCTION public.increment_share_import(p_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    uid uuid := auth.uid();
    c   text;
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'increment_share_import: not authenticated';
    END IF;
    c := lower(btrim(coalesce(p_code, '')));
    IF c !~ '^[a-z0-9]{4,16}$' THEN
        RETURN;
    END IF;
    UPDATE routine_shares
    SET import_count = import_count + 1
    WHERE code = c AND revoked_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_share_import(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.increment_share_import(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.increment_share_import(text) TO authenticated;

-- ── revoke_routine_share(code) → did-revoke (owner only; soft) ───────────────
-- Server surface ships now; the owner-facing "my shares" revoke UI is a
-- follow-up.
CREATE OR REPLACE FUNCTION public.revoke_routine_share(p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    uid uuid := auth.uid();
    c   text;
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'revoke_routine_share: not authenticated';
    END IF;
    c := lower(btrim(coalesce(p_code, '')));
    IF c !~ '^[a-z0-9]{4,16}$' THEN
        RETURN false;
    END IF;
    UPDATE routine_shares
    SET revoked_at = now()
    WHERE code = c AND owner_id = uid AND revoked_at IS NULL;
    RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.revoke_routine_share(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_routine_share(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.revoke_routine_share(text) TO authenticated;

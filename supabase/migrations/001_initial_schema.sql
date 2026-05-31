-- ============================================================================
-- MY GYM BRO - Initial Schema Migration
-- ============================================================================

-- ============================================================================
-- 1. TABLES
-- ============================================================================

-- User Profiles
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    goal TEXT,
    experience TEXT,
    weight_unit TEXT DEFAULT 'kg',
    preferred_language TEXT DEFAULT 'system',
    trial_started_at TIMESTAMPTZ,
    subscription_status TEXT DEFAULT 'trial',
    subscription_expires_at TIMESTAMPTZ,
    default_rest_seconds INTEGER DEFAULT 90,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Schedules
CREATE TABLE schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Schedule Days
CREATE TABLE schedule_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    schedule_id UUID REFERENCES schedules(id) NOT NULL,
    day_index INTEGER NOT NULL,
    label TEXT,
    is_rest_day BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Scheduled Exercises
CREATE TABLE scheduled_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    schedule_day_id UUID REFERENCES schedule_days(id) NOT NULL,
    exercise_id TEXT NOT NULL,
    order_index INTEGER NOT NULL,
    target_sets INTEGER DEFAULT 3,
    target_reps INTEGER DEFAULT 10,
    target_weight_kg REAL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Sessions
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    schedule_id UUID REFERENCES schedules(id),
    schedule_day_id UUID REFERENCES schedule_days(id),
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    total_volume_kg REAL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Session Exercises
CREATE TABLE session_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    session_id UUID REFERENCES sessions(id) NOT NULL,
    exercise_id TEXT NOT NULL,
    order_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Sets
CREATE TABLE sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    session_exercise_id UUID REFERENCES session_exercises(id) NOT NULL,
    set_index INTEGER NOT NULL,
    weight_kg REAL,
    reps INTEGER,
    is_warmup BOOLEAN DEFAULT false,
    is_dropset BOOLEAN DEFAULT false,
    rpe REAL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Subscriptions
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users UNIQUE NOT NULL,
    status TEXT DEFAULT 'trial',
    product_id TEXT,
    platform TEXT,
    original_purchase_date TIMESTAMPTZ,
    expiration_date TIMESTAMPTZ,
    is_sandbox BOOLEAN DEFAULT false,
    store_transaction_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Posts
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users NOT NULL,
    content TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Post Likes
CREATE TABLE post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) NOT NULL,
    user_id UUID REFERENCES auth.users NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(post_id, user_id)
);

-- Post Comments
CREATE TABLE post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) NOT NULL,
    user_id UUID REFERENCES auth.users NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Notification Templates (global table - no user_id)
CREATE TABLE notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,
    message TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 2. AUTO-UPDATE TRIGGER FOR updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON schedule_days
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON scheduled_exercises
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON session_exercises
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON sets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON post_likes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON post_comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;

-- Helper: check if a user has an active subscription
CREATE OR REPLACE FUNCTION has_active_subscription(check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM subscriptions
        WHERE user_id = check_user_id
          AND (
              status = 'active'
              OR (status = 'trial' AND expiration_date > now())
          )
          AND deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---- user_profiles ----
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own profile"
    ON user_profiles FOR DELETE
    USING (auth.uid() = user_id);

-- ---- schedules ----
CREATE POLICY "Users can view own schedules"
    ON schedules FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own schedules"
    ON schedules FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own schedules"
    ON schedules FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own schedules"
    ON schedules FOR DELETE
    USING (auth.uid() = user_id);

-- ---- schedule_days ----
CREATE POLICY "Users can view own schedule_days"
    ON schedule_days FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own schedule_days"
    ON schedule_days FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own schedule_days"
    ON schedule_days FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own schedule_days"
    ON schedule_days FOR DELETE
    USING (auth.uid() = user_id);

-- ---- scheduled_exercises ----
CREATE POLICY "Users can view own scheduled_exercises"
    ON scheduled_exercises FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own scheduled_exercises"
    ON scheduled_exercises FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own scheduled_exercises"
    ON scheduled_exercises FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own scheduled_exercises"
    ON scheduled_exercises FOR DELETE
    USING (auth.uid() = user_id);

-- ---- sessions ----
CREATE POLICY "Users can view own sessions"
    ON sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
    ON sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions"
    ON sessions FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions"
    ON sessions FOR DELETE
    USING (auth.uid() = user_id);

-- ---- session_exercises ----
CREATE POLICY "Users can view own session_exercises"
    ON session_exercises FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own session_exercises"
    ON session_exercises FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own session_exercises"
    ON session_exercises FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own session_exercises"
    ON session_exercises FOR DELETE
    USING (auth.uid() = user_id);

-- ---- sets ----
CREATE POLICY "Users can view own sets"
    ON sets FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sets"
    ON sets FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sets"
    ON sets FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sets"
    ON sets FOR DELETE
    USING (auth.uid() = user_id);

-- ---- subscriptions (SELECT only - INSERT/UPDATE via webhook/service role) ----
CREATE POLICY "Users can view own subscription"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- ---- posts (own CRUD + readable by subscribed users) ----
CREATE POLICY "Users can view posts if subscribed"
    ON posts FOR SELECT
    USING (has_active_subscription(auth.uid()));

CREATE POLICY "Users can insert own posts"
    ON posts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own posts"
    ON posts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts"
    ON posts FOR DELETE
    USING (auth.uid() = user_id);

-- ---- post_likes (own CRUD + readable by subscribed users) ----
CREATE POLICY "Users can view post_likes if subscribed"
    ON post_likes FOR SELECT
    USING (has_active_subscription(auth.uid()));

CREATE POLICY "Users can insert own post_likes"
    ON post_likes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own post_likes"
    ON post_likes FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own post_likes"
    ON post_likes FOR DELETE
    USING (auth.uid() = user_id);

-- ---- post_comments (own CRUD + readable by subscribed users) ----
CREATE POLICY "Users can view post_comments if subscribed"
    ON post_comments FOR SELECT
    USING (has_active_subscription(auth.uid()));

CREATE POLICY "Users can insert own post_comments"
    ON post_comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own post_comments"
    ON post_comments FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own post_comments"
    ON post_comments FOR DELETE
    USING (auth.uid() = user_id);

-- ---- notification_templates (read-only for authenticated users) ----
CREATE POLICY "Authenticated users can view notification_templates"
    ON notification_templates FOR SELECT
    TO authenticated
    USING (true);

-- ============================================================================
-- 4. PERFORMANCE INDICES
-- ============================================================================

CREATE INDEX idx_sessions_user_started ON sessions (user_id, started_at);
CREATE INDEX idx_sets_session_exercise ON sets (session_exercise_id);
CREATE INDEX idx_schedules_user_active ON schedules (user_id, is_active);
CREATE INDEX idx_posts_created_at ON posts (created_at DESC);
CREATE INDEX idx_session_exercises_session ON session_exercises (session_id);

-- ============================================================================
-- 5. SEED NOTIFICATION TEMPLATES
-- ============================================================================

INSERT INTO notification_templates (category, message) VALUES
    -- general
    ('general', 'Today is a good day for training. Don''t waste it.'),
    ('general', 'Your muscles are recovered. Time to put them to work.'),
    ('general', 'The gym misses you. Get in there.'),
    ('general', 'Consistency beats intensity. Show up.'),
    ('general', 'Your future self will thank you for training today.'),
    ('general', 'No excuses. Just train.'),
    ('general', 'Every rep counts. Get after it.'),
    -- streak_at_risk
    ('streak_at_risk', 'Your streak is at risk. One session is all it takes.'),
    ('streak_at_risk', '2 days without training. Your muscles are getting cold.'),
    ('streak_at_risk', 'Don''t break the chain. Train today.'),
    ('streak_at_risk', 'Your consistency is slipping. Fix it now.'),
    -- morning
    ('morning', 'Good morning. You have a training session scheduled for today.'),
    ('morning', 'Start strong. Your workout is waiting.'),
    ('morning', 'Rise and grind. Today is a training day.'),
    ('morning', 'Morning. Time to earn your progress.'),
    -- evening
    ('evening', 'You haven''t trained yet today. There''s still time.'),
    ('evening', 'Don''t end the day with regret. Train.'),
    ('evening', 'Evening check-in: your workout is still waiting.'),
    ('evening', 'Last chance today. Make it count.');

-- ============================================================================
-- 6. pg_cron JOB (MANUAL SETUP REQUIRED)
-- ============================================================================

-- pg_cron must be enabled in your Supabase project before running this.
-- Go to Supabase Dashboard > Database > Extensions and enable pg_cron.
--
-- Then run the following SQL in the SQL Editor:
--
-- SELECT cron.schedule(
--     'schedule-notifications-hourly',
--     '0 * * * *',
--     $$
--     SELECT net.http_post(
--         url := 'https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/schedule-notifications',
--         headers := jsonb_build_object(
--             'Content-Type', 'application/json',
--             'Authorization', 'Bearer <YOUR_SUPABASE_SERVICE_ROLE_KEY>'
--         ),
--         body := '{}'::jsonb
--     ) AS request_id;
--     $$
-- );
--
-- Replace <YOUR_PROJECT_REF> with your Supabase project reference ID.
-- Replace <YOUR_SUPABASE_SERVICE_ROLE_KEY> with your service role key.
-- The pg_net extension is also required for net.http_post (enable it via Dashboard).

-- ============================================================================
-- 7. SUPABASE STORAGE BUCKET
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('community-images', 'community-images', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: allow authenticated users to upload to their own folder
DROP POLICY IF EXISTS "Users can upload community images" ON storage.objects;
CREATE POLICY "Users can upload community images"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'community-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage RLS: allow authenticated users to view community images
DROP POLICY IF EXISTS "Users can view community images" ON storage.objects;
CREATE POLICY "Users can view community images"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'community-images');

-- Storage RLS: allow users to update their own images
DROP POLICY IF EXISTS "Users can update own community images" ON storage.objects;
CREATE POLICY "Users can update own community images"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'community-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage RLS: allow users to delete their own images
DROP POLICY IF EXISTS "Users can delete own community images" ON storage.objects;
CREATE POLICY "Users can delete own community images"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'community-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

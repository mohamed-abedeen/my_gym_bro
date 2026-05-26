-- Add notification_tone to user_profiles.
-- Valid values: 'supportive', 'balanced', 'bold', 'savage'.
-- Default matches the Drift schema default so existing rows stay consistent.

ALTER TABLE user_profiles
  ADD COLUMN notification_tone TEXT NOT NULL DEFAULT 'balanced'
  CHECK (notification_tone IN ('supportive', 'balanced', 'bold', 'savage'));

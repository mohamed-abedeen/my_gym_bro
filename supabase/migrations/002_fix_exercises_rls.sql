-- ============================================================================
-- Fix: Enable RLS on exercises table
-- The exercises table is a global catalog of exercise definitions.
-- Users can read all exercises, but writes are restricted to service role only.
-- ============================================================================

ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;

-- Allow any authenticated user to read exercises (it's a shared catalog)
CREATE POLICY "Authenticated users can view exercises"
    ON exercises FOR SELECT
    TO authenticated
    USING (true);

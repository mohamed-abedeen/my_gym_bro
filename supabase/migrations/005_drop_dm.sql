-- ─────────────────────────────────────────────────────────────────────────────
-- 005 — Drop Direct Messaging
--
-- DMs were removed from the product (see docs/plan/01-PRD.md §7 and STATUS.md).
-- This supersedes 003_dm_rls.sql. Dropping the tables with CASCADE also removes
-- their RLS policies, indexes, and any dependent objects.
-- ─────────────────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS dm_messages CASCADE;
DROP TABLE IF EXISTS dm_conversations CASCADE;

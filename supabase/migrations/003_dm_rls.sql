-- ============================================================================
-- Enable RLS on DM tables
-- Users may only access conversations they participate in and messages
-- within those conversations.
-- ============================================================================

-- ── dm_conversations ────────────────────────────────────────────────────────

ALTER TABLE dm_conversations ENABLE ROW LEVEL SECURITY;

-- Users can only see conversations they are a participant of
CREATE POLICY "Users can view own conversations"
    ON dm_conversations FOR SELECT
    TO authenticated
    USING (
        auth.uid() = participant_a OR auth.uid() = participant_b
    );

-- Users can only create conversations where they are a participant
CREATE POLICY "Users can create own conversations"
    ON dm_conversations FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = participant_a OR auth.uid() = participant_b
    );

-- Users can update conversations they participate in (e.g. last_message_text)
CREATE POLICY "Users can update own conversations"
    ON dm_conversations FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = participant_a OR auth.uid() = participant_b
    )
    WITH CHECK (
        auth.uid() = participant_a OR auth.uid() = participant_b
    );

-- ── dm_messages ─────────────────────────────────────────────────────────────

ALTER TABLE dm_messages ENABLE ROW LEVEL SECURITY;

-- Users can read messages only in conversations they participate in
CREATE POLICY "Users can view messages in own conversations"
    ON dm_messages FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM dm_conversations c
            WHERE c.id = dm_messages.conversation_id
              AND (c.participant_a = auth.uid() OR c.participant_b = auth.uid())
        )
    );

-- Users can insert messages only as themselves, in conversations they belong to
CREATE POLICY "Users can send messages in own conversations"
    ON dm_messages FOR INSERT
    TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM dm_conversations c
            WHERE c.id = dm_messages.conversation_id
              AND (c.participant_a = auth.uid() OR c.participant_b = auth.uid())
        )
    );

-- ── Performance indexes ────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_dm_conversations_participant_a
    ON dm_conversations (participant_a);

CREATE INDEX IF NOT EXISTS idx_dm_conversations_participant_b
    ON dm_conversations (participant_b);

CREATE INDEX IF NOT EXISTS idx_dm_messages_conversation_created
    ON dm_messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dm_messages_sender
    ON dm_messages (sender_id);

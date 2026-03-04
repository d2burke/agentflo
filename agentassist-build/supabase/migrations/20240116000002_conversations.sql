-- Migration: Add conversations table for direct user-to-user messaging
-- Existing task-based messages keep working via task_id.
-- New direct messages use conversation_id.

-- 1. Conversations table
CREATE TABLE public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_1_id uuid NOT NULL REFERENCES public.users(id),
  participant_2_id uuid NOT NULL REFERENCES public.users(id),
  task_id uuid REFERENCES public.tasks(id),
  created_at timestamptz DEFAULT now(),
  CHECK (participant_1_id < participant_2_id),
  UNIQUE(participant_1_id, participant_2_id)
);

CREATE INDEX idx_conversations_participants ON public.conversations(participant_1_id, participant_2_id);

-- RLS: participants can read/write their own conversations
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY conversations_participant_select ON public.conversations
  FOR SELECT TO authenticated
  USING (
    auth.uid() = participant_1_id OR auth.uid() = participant_2_id
  );

CREATE POLICY conversations_participant_insert ON public.conversations
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = participant_1_id OR auth.uid() = participant_2_id
  );

-- 2. Add conversation_id to messages (nullable — existing messages keep task_id only)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS conversation_id uuid REFERENCES public.conversations(id);

-- Make task_id nullable for direct messages
ALTER TABLE public.messages ALTER COLUMN task_id DROP NOT NULL;

CREATE INDEX idx_messages_conversation ON public.messages(conversation_id, created_at)
  WHERE conversation_id IS NOT NULL;

-- 3. Update messages RLS to allow conversation-based messages
-- Existing policies handle task_id-based messages.
-- Add policy for conversation-based messages.
CREATE POLICY messages_conversation_select ON public.messages
  FOR SELECT TO authenticated
  USING (
    conversation_id IN (
      SELECT id FROM public.conversations
      WHERE participant_1_id = auth.uid() OR participant_2_id = auth.uid()
    )
  );

CREATE POLICY messages_conversation_insert ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND (
      task_id IS NOT NULL
      OR conversation_id IN (
        SELECT id FROM public.conversations
        WHERE participant_1_id = auth.uid() OR participant_2_id = auth.uid()
      )
    )
  );

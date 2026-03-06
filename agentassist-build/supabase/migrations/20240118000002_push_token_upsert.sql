-- Migration: Push token upsert support
-- Adds unique constraint for upsert and RLS for token registration

-- Unique constraint for upsert (one token per user+token combo)
ALTER TABLE public.push_tokens
  ADD CONSTRAINT push_tokens_user_token_unique UNIQUE (user_id, token);

-- RLS: Users can insert/update their own push tokens
CREATE POLICY push_tokens_insert_own ON public.push_tokens
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY push_tokens_update_own ON public.push_tokens
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY push_tokens_read_own ON public.push_tokens
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY push_tokens_delete_own ON public.push_tokens
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

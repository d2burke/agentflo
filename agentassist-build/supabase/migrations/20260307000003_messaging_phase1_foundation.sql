-- Messaging modernization phase 1 foundation:
-- - first-class direct and task conversations
-- - participant-level read state
-- - conversation summaries
-- - paginated thread/list RPCs
-- - compatibility backfill from legacy task-based messages

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS kind text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS last_message_id uuid REFERENCES public.messages(id),
  ADD COLUMN IF NOT EXISTS last_message_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_message_preview text,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.conversations
SET
  kind = CASE WHEN task_id IS NULL THEN 'direct' ELSE 'task' END,
  created_by = COALESCE(created_by, participant_1_id),
  updated_at = COALESCE(updated_at, created_at, now())
WHERE kind IS NULL
   OR created_by IS NULL
   OR updated_at IS NULL;

ALTER TABLE public.conversations
  ALTER COLUMN kind SET NOT NULL,
  ALTER COLUMN created_by SET NOT NULL;

ALTER TABLE public.conversations
  DROP CONSTRAINT IF EXISTS conversations_kind_check;

ALTER TABLE public.conversations
  ADD CONSTRAINT conversations_kind_check
  CHECK (
    (kind = 'direct' AND task_id IS NULL)
    OR
    (kind = 'task' AND task_id IS NOT NULL)
  );

ALTER TABLE public.conversations
  DROP CONSTRAINT IF EXISTS conversations_participant_1_id_participant_2_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_direct_unique_idx
  ON public.conversations(participant_1_id, participant_2_id)
  WHERE kind = 'direct';

CREATE UNIQUE INDEX IF NOT EXISTS conversations_task_unique_idx
  ON public.conversations(task_id)
  WHERE kind = 'task';

CREATE INDEX IF NOT EXISTS conversations_kind_updated_idx
  ON public.conversations(kind, updated_at DESC);

CREATE INDEX IF NOT EXISTS conversations_last_message_idx
  ON public.conversations(last_message_at DESC NULLS LAST, created_at DESC);

DROP TRIGGER IF EXISTS trg_conversations_updated ON public.conversations;
CREATE TRIGGER trg_conversations_updated
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS client_message_id uuid,
  ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS reply_to_message_id uuid REFERENCES public.messages(id),
  ADD COLUMN IF NOT EXISTS edited_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_message_type_check;

ALTER TABLE public.messages
  ADD CONSTRAINT messages_message_type_check
  CHECK (message_type IN ('text', 'image', 'file', 'system'));

DROP INDEX IF EXISTS idx_messages_conversation;
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_desc
  ON public.messages(conversation_id, created_at DESC, id DESC)
  WHERE conversation_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_messages_sender_created_desc
  ON public.messages(sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_reply_to
  ON public.messages(reply_to_message_id)
  WHERE reply_to_message_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_message_id
  ON public.messages(conversation_id, sender_id, client_message_id)
  WHERE client_message_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.conversation_participants (
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  last_read_message_id uuid REFERENCES public.messages(id),
  last_read_at timestamptz,
  last_delivered_at timestamptz,
  last_seen_at timestamptz,
  muted_until timestamptz,
  archived_at timestamptz,
  is_pinned boolean NOT NULL DEFAULT false,
  draft_body text,
  draft_updated_at timestamptz,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS conversation_participants_user_idx
  ON public.conversation_participants(user_id, archived_at, is_pinned, last_read_at DESC NULLS LAST);

ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS conversation_participants_select ON public.conversation_participants;
CREATE POLICY conversation_participants_select ON public.conversation_participants
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS conversation_participants_insert ON public.conversation_participants;
CREATE POLICY conversation_participants_insert ON public.conversation_participants
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.conversations c
      WHERE c.id = conversation_id
        AND (c.participant_1_id = auth.uid() OR c.participant_2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS conversation_participants_update ON public.conversation_participants;
CREATE POLICY conversation_participants_update ON public.conversation_participants
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.ensure_conversation_participants(p_conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation public.conversations;
BEGIN
  SELECT *
  INTO v_conversation
  FROM public.conversations
  WHERE id = p_conversation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conversation % not found', p_conversation_id;
  END IF;

  INSERT INTO public.conversation_participants (conversation_id, user_id, joined_at)
  VALUES
    (p_conversation_id, v_conversation.participant_1_id, COALESCE(v_conversation.created_at, now())),
    (p_conversation_id, v_conversation.participant_2_id, COALESCE(v_conversation.created_at, now()))
  ON CONFLICT (conversation_id, user_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_conversation_participants(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_conversation_participants(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.refresh_conversation_summary(p_conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_last_message RECORD;
BEGIN
  SELECT
    m.id,
    m.created_at,
    CASE
      WHEN m.deleted_at IS NOT NULL THEN '[deleted]'
      WHEN m.body IS NULL OR btrim(m.body) = '' THEN NULL
      ELSE left(m.body, 280)
    END AS preview
  INTO v_last_message
  FROM public.messages m
  WHERE m.conversation_id = p_conversation_id
  ORDER BY m.created_at DESC, m.id DESC
  LIMIT 1;

  UPDATE public.conversations
  SET
    last_message_id = v_last_message.id,
    last_message_at = v_last_message.created_at,
    last_message_preview = v_last_message.preview,
    updated_at = now()
  WHERE id = p_conversation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_conversation_summary(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.refresh_conversation_summary(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.assign_message_conversation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task public.tasks;
BEGIN
  IF NEW.conversation_id IS NULL THEN
    IF NEW.task_id IS NULL THEN
      RAISE EXCEPTION 'conversation_id or task_id is required';
    END IF;

    SELECT *
    INTO v_task
    FROM public.tasks
    WHERE id = NEW.task_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Task % not found', NEW.task_id;
    END IF;

    IF v_task.runner_id IS NULL THEN
      RAISE EXCEPTION 'Task % does not have both messaging participants yet', NEW.task_id;
    END IF;

    SELECT id
    INTO NEW.conversation_id
    FROM public.conversations
    WHERE kind = 'task'
      AND task_id = NEW.task_id
    LIMIT 1;

    IF NEW.conversation_id IS NULL THEN
      INSERT INTO public.conversations (
        participant_1_id,
        participant_2_id,
        kind,
        task_id,
        created_by
      )
      VALUES (
        LEAST(v_task.agent_id, v_task.runner_id),
        GREATEST(v_task.agent_id, v_task.runner_id),
        'task',
        v_task.id,
        v_task.agent_id
      )
      RETURNING id INTO NEW.conversation_id;
    END IF;
  END IF;

  IF NEW.task_id IS NULL THEN
    SELECT task_id
    INTO NEW.task_id
    FROM public.conversations
    WHERE id = NEW.conversation_id;
  END IF;

  PERFORM public.ensure_conversation_participants(NEW.conversation_id);

  IF NEW.message_type IS NULL THEN
    NEW.message_type := 'text';
  END IF;

  IF NEW.metadata IS NULL THEN
    NEW.metadata := '{}'::jsonb;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.after_message_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.ensure_conversation_participants(NEW.conversation_id);
  PERFORM public.refresh_conversation_summary(NEW.conversation_id);

  UPDATE public.conversation_participants
  SET
    last_delivered_at = GREATEST(COALESCE(last_delivered_at, NEW.created_at), NEW.created_at),
    last_read_message_id = CASE
      WHEN user_id = NEW.sender_id THEN NEW.id
      ELSE last_read_message_id
    END,
    last_read_at = CASE
      WHEN user_id = NEW.sender_id THEN GREATEST(COALESCE(last_read_at, NEW.created_at), NEW.created_at)
      ELSE last_read_at
    END
  WHERE conversation_id = NEW.conversation_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_messages_assign_conversation ON public.messages;
CREATE TRIGGER trg_messages_assign_conversation
  BEFORE INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.assign_message_conversation();

DROP TRIGGER IF EXISTS trg_messages_after_write ON public.messages;
CREATE TRIGGER trg_messages_after_write
  AFTER INSERT OR UPDATE OF body, deleted_at ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.after_message_write();

UPDATE public.conversations c
SET
  participant_1_id = LEAST(t.agent_id, t.runner_id),
  participant_2_id = GREATEST(t.agent_id, t.runner_id),
  created_by = COALESCE(c.created_by, t.agent_id),
  kind = 'task'
FROM public.tasks t
WHERE c.task_id = t.id
  AND t.runner_id IS NOT NULL;

WITH task_candidates AS (
  SELECT DISTINCT
    t.id AS task_id,
    LEAST(t.agent_id, t.runner_id) AS participant_1_id,
    GREATEST(t.agent_id, t.runner_id) AS participant_2_id,
    t.agent_id AS created_by,
    COALESCE((
      SELECT MIN(m.created_at)
      FROM public.messages m
      WHERE m.task_id = t.id
    ), t.created_at, now()) AS created_at
  FROM public.tasks t
  WHERE t.runner_id IS NOT NULL
    AND (
      EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.task_id = t.id
      )
      OR EXISTS (
        SELECT 1
        FROM public.conversations c
        WHERE c.task_id = t.id
      )
    )
)
INSERT INTO public.conversations (
  participant_1_id,
  participant_2_id,
  kind,
  task_id,
  created_by,
  created_at,
  updated_at
)
SELECT
  tc.participant_1_id,
  tc.participant_2_id,
  'task',
  tc.task_id,
  tc.created_by,
  tc.created_at,
  tc.created_at
FROM task_candidates tc
WHERE NOT EXISTS (
  SELECT 1
  FROM public.conversations c
  WHERE c.kind = 'task'
    AND c.task_id = tc.task_id
);

UPDATE public.messages m
SET conversation_id = c.id
FROM public.conversations c
WHERE m.task_id = c.task_id
  AND c.kind = 'task'
  AND m.task_id IS NOT NULL
  AND m.conversation_id IS DISTINCT FROM c.id;

INSERT INTO public.conversation_participants (conversation_id, user_id, joined_at)
SELECT c.id, c.participant_1_id, COALESCE(c.created_at, now())
FROM public.conversations c
ON CONFLICT (conversation_id, user_id) DO NOTHING;

INSERT INTO public.conversation_participants (conversation_id, user_id, joined_at)
SELECT c.id, c.participant_2_id, COALESCE(c.created_at, now())
FROM public.conversations c
ON CONFLICT (conversation_id, user_id) DO NOTHING;

WITH read_candidates AS (
  SELECT
    cp.conversation_id,
    cp.user_id,
    candidate.id AS message_id,
    candidate.read_marker_at AS read_marker_at
  FROM public.conversation_participants cp
  LEFT JOIN LATERAL (
    SELECT
      m.id,
      CASE
        WHEN m.sender_id = cp.user_id THEN m.created_at
        ELSE COALESCE(m.read_at, m.created_at)
      END AS read_marker_at
    FROM public.messages m
    WHERE m.conversation_id = cp.conversation_id
      AND (
        m.sender_id = cp.user_id
        OR (m.sender_id <> cp.user_id AND m.read_at IS NOT NULL)
      )
    ORDER BY
      CASE
        WHEN m.sender_id = cp.user_id THEN m.created_at
        ELSE COALESCE(m.read_at, m.created_at)
      END DESC,
      m.created_at DESC,
      m.id DESC
    LIMIT 1
  ) candidate ON true
)
UPDATE public.conversation_participants cp
SET
  last_read_message_id = rc.message_id,
  last_read_at = rc.read_marker_at
FROM read_candidates rc
WHERE cp.conversation_id = rc.conversation_id
  AND cp.user_id = rc.user_id
  AND rc.message_id IS NOT NULL;

DO $$
DECLARE
  v_conversation RECORD;
BEGIN
  FOR v_conversation IN
    SELECT id
    FROM public.conversations
  LOOP
    PERFORM public.refresh_conversation_summary(v_conversation.id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_or_create_direct_conversation_v2(p_other_user_id uuid)
RETURNS public.conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_participant_1 uuid;
  v_participant_2 uuid;
  v_conversation public.conversations;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_other_user_id IS NULL OR p_other_user_id = v_user_id THEN
    RAISE EXCEPTION 'A different participant is required';
  END IF;

  v_participant_1 := LEAST(v_user_id, p_other_user_id);
  v_participant_2 := GREATEST(v_user_id, p_other_user_id);

  SELECT *
  INTO v_conversation
  FROM public.conversations
  WHERE kind = 'direct'
    AND participant_1_id = v_participant_1
    AND participant_2_id = v_participant_2
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.conversations (
      participant_1_id,
      participant_2_id,
      kind,
      created_by
    )
    VALUES (
      v_participant_1,
      v_participant_2,
      'direct',
      v_user_id
    )
    RETURNING * INTO v_conversation;
  END IF;

  PERFORM public.ensure_conversation_participants(v_conversation.id);

  RETURN v_conversation;
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_direct_conversation_v2(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_conversation_v2(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_or_create_task_conversation_v2(p_task_id uuid)
RETURNS public.conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_task public.tasks;
  v_conversation public.conversations;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT *
  INTO v_task
  FROM public.tasks
  WHERE id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task % not found', p_task_id;
  END IF;

  IF v_task.runner_id IS NULL THEN
    RAISE EXCEPTION 'Task % does not have both messaging participants yet', p_task_id;
  END IF;

  IF v_user_id <> v_task.agent_id AND v_user_id <> v_task.runner_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT *
  INTO v_conversation
  FROM public.conversations
  WHERE kind = 'task'
    AND task_id = p_task_id
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.conversations (
      participant_1_id,
      participant_2_id,
      kind,
      task_id,
      created_by
    )
    VALUES (
      LEAST(v_task.agent_id, v_task.runner_id),
      GREATEST(v_task.agent_id, v_task.runner_id),
      'task',
      v_task.id,
      v_task.agent_id
    )
    RETURNING * INTO v_conversation;
  END IF;

  PERFORM public.ensure_conversation_participants(v_conversation.id);

  RETURN v_conversation;
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_task_conversation_v2(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_or_create_task_conversation_v2(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_messages_page_v2(
  p_conversation_id uuid,
  p_before_message_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS SETOF public.messages
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_cursor_created_at timestamptz;
  v_cursor_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.conversation_participants cp
    WHERE cp.conversation_id = p_conversation_id
      AND cp.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_before_message_id IS NOT NULL THEN
    SELECT m.created_at, m.id
    INTO v_cursor_created_at, v_cursor_id
    FROM public.messages m
    WHERE m.id = p_before_message_id
      AND m.conversation_id = p_conversation_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Cursor message % not found in conversation %', p_before_message_id, p_conversation_id;
    END IF;
  END IF;

  RETURN QUERY
  SELECT m.*
  FROM public.messages m
  WHERE m.conversation_id = p_conversation_id
    AND (
      p_before_message_id IS NULL
      OR (m.created_at, m.id) < (v_cursor_created_at, v_cursor_id)
    )
  ORDER BY m.created_at DESC, m.id DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_messages_page_v2(uuid, uuid, integer) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.mark_conversation_read_v2(
  p_conversation_id uuid,
  p_last_read_message_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_target_message public.messages;
  v_effective_read_at timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.conversation_participants cp
    WHERE cp.conversation_id = p_conversation_id
      AND cp.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_last_read_message_id IS NULL THEN
    SELECT *
    INTO v_target_message
    FROM public.messages m
    WHERE m.conversation_id = p_conversation_id
    ORDER BY m.created_at DESC, m.id DESC
    LIMIT 1;
  ELSE
    SELECT *
    INTO v_target_message
    FROM public.messages m
    WHERE m.id = p_last_read_message_id
      AND m.conversation_id = p_conversation_id;
  END IF;

  IF NOT FOUND THEN
    UPDATE public.conversation_participants
    SET last_seen_at = now()
    WHERE conversation_id = p_conversation_id
      AND user_id = v_user_id;
    RETURN;
  END IF;

  v_effective_read_at := COALESCE(v_target_message.created_at, now());

  UPDATE public.conversation_participants
  SET
    last_read_message_id = v_target_message.id,
    last_read_at = GREATEST(COALESCE(last_read_at, v_effective_read_at), v_effective_read_at),
    last_seen_at = now()
  WHERE conversation_id = p_conversation_id
    AND user_id = v_user_id;

  -- Keep the legacy per-message read marker in sync until old clients are retired.
  UPDATE public.messages
  SET read_at = COALESCE(read_at, now())
  WHERE conversation_id = p_conversation_id
    AND sender_id <> v_user_id
    AND created_at <= v_effective_read_at
    AND read_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_conversation_read_v2(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read_v2(uuid, uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_conversation_list_v2(
  p_user_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_cursor timestamptz DEFAULT NULL
)
RETURNS TABLE (
  conversation_id uuid,
  conversation_kind text,
  task_id uuid,
  other_user_id uuid,
  other_user_name text,
  other_user_avatar text,
  last_message_id uuid,
  last_message_body text,
  last_message_type text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count bigint,
  is_pinned boolean,
  archived_at timestamptz,
  draft_body text,
  sort_at timestamptz
)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_user_id IS NOT NULL AND p_user_id <> v_user_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    c.id AS conversation_id,
    c.kind AS conversation_kind,
    c.task_id,
    CASE
      WHEN c.participant_1_id = v_user_id THEN c.participant_2_id
      ELSE c.participant_1_id
    END AS other_user_id,
    other_user.full_name AS other_user_name,
    other_user.avatar_url AS other_user_avatar,
    c.last_message_id,
    c.last_message_preview AS last_message_body,
    COALESCE(last_message.message_type, 'text') AS last_message_type,
    c.last_message_at,
    last_message.sender_id AS last_message_sender_id,
    COALESCE(unread_stats.unread_count, 0)::bigint AS unread_count,
    cp.is_pinned,
    cp.archived_at,
    cp.draft_body,
    COALESCE(c.last_message_at, c.created_at) AS sort_at
  FROM public.conversation_participants cp
  JOIN public.conversations c
    ON c.id = cp.conversation_id
  JOIN public.users other_user
    ON other_user.id = CASE
      WHEN c.participant_1_id = v_user_id THEN c.participant_2_id
      ELSE c.participant_1_id
    END
  LEFT JOIN public.messages last_message
    ON last_message.id = c.last_message_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*) AS unread_count
    FROM public.messages unread_message
    WHERE unread_message.conversation_id = c.id
      AND unread_message.sender_id <> v_user_id
      AND (
        cp.last_read_at IS NULL
        OR unread_message.created_at > cp.last_read_at
      )
  ) unread_stats ON true
  WHERE cp.user_id = v_user_id
    AND cp.archived_at IS NULL
    AND (
      p_cursor IS NULL
      OR COALESCE(c.last_message_at, c.created_at) < p_cursor
    )
  ORDER BY
    cp.is_pinned DESC,
    COALESCE(c.last_message_at, c.created_at) DESC,
    c.id DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_conversation_list_v2(uuid, integer, timestamptz) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_conversation_list(p_user_id uuid)
RETURNS TABLE (
  conversation_id uuid,
  other_user_id uuid,
  other_user_name text,
  other_user_avatar text,
  last_message_body text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count bigint
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT
    conversation_id,
    other_user_id,
    other_user_name,
    other_user_avatar,
    last_message_body,
    last_message_at,
    last_message_sender_id,
    unread_count
  FROM public.get_conversation_list_v2(p_user_id, 100, NULL);
$$;

GRANT EXECUTE ON FUNCTION public.get_conversation_list(uuid) TO authenticated, service_role;

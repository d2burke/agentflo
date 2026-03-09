-- Make message activity records part of the DB write path, and ensure
-- messaging tables participate in Realtime publication.

CREATE OR REPLACE FUNCTION public.enqueue_message_notification_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation public.conversations;
  v_recipient_id uuid;
  v_sender_name text;
  v_message_preview text;
  v_notifications_enabled boolean;
  v_notification_id uuid;
BEGIN
  IF NEW.conversation_id IS NULL
     OR NEW.sender_id IS NULL
     OR NEW.deleted_at IS NOT NULL
     OR NEW.message_type = 'system' THEN
    RETURN NEW;
  END IF;

  SELECT *
  INTO v_conversation
  FROM public.conversations
  WHERE id = NEW.conversation_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF v_conversation.participant_1_id = NEW.sender_id THEN
    v_recipient_id := v_conversation.participant_2_id;
  ELSIF v_conversation.participant_2_id = NEW.sender_id THEN
    v_recipient_id := v_conversation.participant_1_id;
  ELSE
    RETURN NEW;
  END IF;

  IF v_recipient_id IS NULL OR v_recipient_id = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  SELECT np.messages
  INTO v_notifications_enabled
  FROM public.notification_preferences np
  WHERE np.user_id = v_recipient_id;

  IF v_notifications_enabled IS DISTINCT FROM false THEN
    SELECT u.full_name
    INTO v_sender_name
    FROM public.users u
    WHERE u.id = NEW.sender_id;

    v_message_preview := CASE
      WHEN btrim(COALESCE(NEW.body, '')) <> '' THEN left(NEW.body, 100)
      WHEN NEW.message_type = 'image' THEN 'Sent an image'
      WHEN NEW.message_type = 'file' THEN 'Sent a file'
      ELSE 'New message'
    END;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_recipient_id,
      'new_message',
      COALESCE(v_sender_name, 'Someone'),
      v_message_preview,
      jsonb_strip_nulls(
        jsonb_build_object(
          'sender_name', COALESCE(v_sender_name, 'Someone'),
          'message_preview', v_message_preview,
          'conversation_id', NEW.conversation_id,
          'task_id', NEW.task_id,
          'screen', 'messages'
        )
      )
    )
    RETURNING id INTO v_notification_id;
  END IF;

  INSERT INTO public.message_notification_jobs (
    message_id,
    conversation_id,
    sender_id,
    recipient_id,
    status,
    notification_id,
    last_error
  )
  VALUES (
    NEW.id,
    NEW.conversation_id,
    NEW.sender_id,
    v_recipient_id,
    CASE WHEN v_notifications_enabled IS DISTINCT FROM false THEN 'pending' ELSE 'skipped' END,
    v_notification_id,
    CASE WHEN v_notifications_enabled IS DISTINCT FROM false THEN NULL ELSE 'disabled_by_preference' END
  )
  ON CONFLICT (message_id) DO UPDATE
  SET
    notification_id = COALESCE(public.message_notification_jobs.notification_id, EXCLUDED.notification_id),
    status = EXCLUDED.status,
    last_error = EXCLUDED.last_error;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'conversation_participants'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'notifications'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
  END IF;
END
$$;

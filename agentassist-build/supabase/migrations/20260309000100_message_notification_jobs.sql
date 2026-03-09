-- Server-side message notification queue.
-- This lets every message write path enqueue one notification job and
-- keeps push dispatch out of the browser send flow.

CREATE TABLE IF NOT EXISTS public.message_notification_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  attempts integer NOT NULL DEFAULT 0,
  notification_id uuid REFERENCES public.notifications(id) ON DELETE SET NULL,
  push_sent boolean NOT NULL DEFAULT false,
  last_error text,
  locked_at timestamptz,
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT message_notification_jobs_status_check
    CHECK (status IN ('pending', 'processing', 'sent', 'skipped', 'failed')),
  CONSTRAINT message_notification_jobs_message_unique UNIQUE (message_id)
);

CREATE INDEX IF NOT EXISTS message_notification_jobs_status_created_idx
  ON public.message_notification_jobs(status, created_at ASC)
  WHERE processed_at IS NULL;

CREATE INDEX IF NOT EXISTS message_notification_jobs_recipient_created_idx
  ON public.message_notification_jobs(recipient_id, created_at DESC);

ALTER TABLE public.message_notification_jobs ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_message_notification_jobs_updated ON public.message_notification_jobs;
CREATE TRIGGER trg_message_notification_jobs_updated
  BEFORE UPDATE ON public.message_notification_jobs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE OR REPLACE FUNCTION public.enqueue_message_notification_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation public.conversations;
  v_recipient_id uuid;
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

  INSERT INTO public.message_notification_jobs (
    message_id,
    conversation_id,
    sender_id,
    recipient_id
  )
  VALUES (
    NEW.id,
    NEW.conversation_id,
    NEW.sender_id,
    v_recipient_id
  )
  ON CONFLICT (message_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_messages_enqueue_notification_job ON public.messages;
CREATE TRIGGER trg_messages_enqueue_notification_job
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.enqueue_message_notification_job();

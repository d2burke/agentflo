-- Migration: Add task status notification trigger + profile visibility for task counterparts

-- 1. Allow authenticated users to see profiles of users they share tasks with
--    (agents see their runners, runners see their agents)
CREATE POLICY users_select_task_counterparts ON public.users
  FOR SELECT TO authenticated
  USING (
    id IN (
      SELECT runner_id FROM public.tasks WHERE agent_id = auth.uid()
      UNION
      SELECT agent_id FROM public.tasks WHERE runner_id = auth.uid()
    )
  );

-- 2. Trigger function: create notification when task status changes
CREATE OR REPLACE FUNCTION notify_task_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_runner_name text;
  v_agent_name text;
  v_notification_title text;
  v_notification_body text;
  v_recipient uuid;
BEGIN
  -- Only fire on actual status change
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Fetch names for notification text
  IF NEW.runner_id IS NOT NULL THEN
    SELECT full_name INTO v_runner_name
      FROM public.users WHERE id = NEW.runner_id;
  END IF;

  SELECT full_name INTO v_agent_name
    FROM public.users WHERE id = NEW.agent_id;

  -- Determine notification based on new status
  CASE NEW.status
    WHEN 'accepted' THEN
      v_recipient := NEW.agent_id;
      v_notification_title := 'Task Accepted';
      v_notification_body := COALESCE(v_runner_name, 'A runner') || ' accepted your ' || NEW.category || ' task at ' || NEW.property_address;

    WHEN 'in_progress' THEN
      v_recipient := NEW.agent_id;
      v_notification_title := 'Task In Progress';
      v_notification_body := COALESCE(v_runner_name, 'Runner') || ' started working on ' || NEW.property_address;

    WHEN 'deliverables_submitted' THEN
      v_recipient := NEW.agent_id;
      v_notification_title := 'Deliverables Ready';
      v_notification_body := COALESCE(v_runner_name, 'Runner') || ' submitted deliverables for ' || NEW.property_address;

    WHEN 'completed' THEN
      IF NEW.runner_id IS NOT NULL THEN
        v_recipient := NEW.runner_id;
        v_notification_title := 'Payment Released';
        v_notification_body := 'Payment released for ' || NEW.property_address || '. Funds will arrive in 1-2 business days.';
      END IF;

    WHEN 'cancelled' THEN
      IF NEW.runner_id IS NOT NULL THEN
        v_recipient := NEW.runner_id;
        v_notification_title := 'Task Cancelled';
        v_notification_body := 'The ' || NEW.category || ' task at ' || NEW.property_address || ' was cancelled.';
      END IF;

    ELSE
      RETURN NEW;
  END CASE;

  -- Insert notification if we have a recipient
  IF v_recipient IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_recipient,
      'task_' || NEW.status,
      v_notification_title,
      v_notification_body,
      jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;

-- 3. Create the trigger on tasks table
CREATE TRIGGER trg_task_status_notify
  AFTER UPDATE OF status ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION notify_task_status_change();

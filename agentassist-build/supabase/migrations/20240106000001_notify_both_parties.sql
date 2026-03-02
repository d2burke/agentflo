-- Migration: Update notification trigger to notify BOTH agent and runner on status changes

CREATE OR REPLACE FUNCTION notify_task_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_runner_name text;
  v_agent_name text;
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

  -- Determine notifications based on new status
  CASE NEW.status
    WHEN 'accepted' THEN
      -- Notify agent: runner accepted their task
      INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
        NEW.agent_id,
        'task_accepted',
        'Task Accepted',
        COALESCE(v_runner_name, 'A runner') || ' accepted your ' || NEW.category || ' task at ' || NEW.property_address,
        jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
      );
      -- Notify runner: confirmation they got the task
      IF NEW.runner_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
          NEW.runner_id,
          'task_accepted',
          'You Got the Task!',
          'You''ve been assigned the ' || NEW.category || ' task at ' || NEW.property_address,
          jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
        );
      END IF;

    WHEN 'in_progress' THEN
      -- Notify agent
      INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
        NEW.agent_id,
        'task_in_progress',
        'Task In Progress',
        COALESCE(v_runner_name, 'Runner') || ' started working on ' || NEW.property_address,
        jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
      );

    WHEN 'deliverables_submitted' THEN
      -- Notify agent
      INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
        NEW.agent_id,
        'task_deliverables_submitted',
        'Deliverables Ready',
        COALESCE(v_runner_name, 'Runner') || ' submitted deliverables for ' || NEW.property_address,
        jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
      );

    WHEN 'completed' THEN
      -- Notify runner: payment released
      IF NEW.runner_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
          NEW.runner_id,
          'task_completed',
          'Payment Released',
          'Payment released for ' || NEW.property_address || '. Funds will arrive in 1-2 business days.',
          jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
        );
      END IF;
      -- Notify agent: task completed
      INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
        NEW.agent_id,
        'task_completed',
        'Task Completed',
        NEW.category || ' task at ' || NEW.property_address || ' has been completed.',
        jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
      );

    WHEN 'cancelled' THEN
      -- Notify runner if assigned
      IF NEW.runner_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
          NEW.runner_id,
          'task_cancelled',
          'Task Cancelled',
          'The ' || NEW.category || ' task at ' || NEW.property_address || ' was cancelled.',
          jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
        );
      END IF;
      -- Notify agent: confirmation of cancellation
      INSERT INTO public.notifications (user_id, type, title, body, data) VALUES (
        NEW.agent_id,
        'task_cancelled',
        'Task Cancelled',
        'Your ' || NEW.category || ' task at ' || NEW.property_address || ' has been cancelled.',
        jsonb_build_object('task_id', NEW.id::text, 'screen', 'detail')
      );

    ELSE
      RETURN NEW;
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;

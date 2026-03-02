-- RPC function: allows a runner to accept a posted task atomically
-- Inserts into task_applications, updates tasks.status and tasks.runner_id
-- Uses SECURITY DEFINER to bypass RLS (runners can't UPDATE tasks directly)

CREATE OR REPLACE FUNCTION public.accept_task(
  p_task_id uuid,
  p_runner_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task_status text;
  v_runner_role text;
BEGIN
  -- Verify the caller is a runner
  SELECT role INTO v_runner_role
    FROM public.users
   WHERE id = p_runner_id;

  IF v_runner_role IS NULL OR v_runner_role != 'runner' THEN
    RAISE EXCEPTION 'Only runners can accept tasks';
  END IF;

  -- Verify the task exists and is posted
  SELECT status INTO v_task_status
    FROM public.tasks
   WHERE id = p_task_id
   FOR UPDATE;  -- lock the row

  IF v_task_status IS NULL THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  IF v_task_status != 'posted' THEN
    RAISE EXCEPTION 'Task is no longer available (status: %)', v_task_status;
  END IF;

  -- Insert application record (accepted immediately)
  INSERT INTO public.task_applications (task_id, runner_id, status)
  VALUES (p_task_id, p_runner_id, 'accepted')
  ON CONFLICT (task_id, runner_id) DO UPDATE SET status = 'accepted';

  -- Update task: assign runner and mark accepted
  UPDATE public.tasks
     SET status = 'accepted',
         runner_id = p_runner_id,
         accepted_at = now(),
         updated_at = now()
   WHERE id = p_task_id;
END;
$$;

-- Also allow runners to update tasks they are assigned to
-- (for marking in_progress, submitting deliverables, etc.)
CREATE POLICY tasks_runner_update ON public.tasks
  FOR UPDATE USING (runner_id = auth.uid())
  WITH CHECK (runner_id = auth.uid());

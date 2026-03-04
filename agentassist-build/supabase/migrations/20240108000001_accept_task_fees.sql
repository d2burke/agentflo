-- Fix: accept_task RPC now calculates platform_fee and runner_payout (15% fee)
-- Previously these fields were left NULL, causing runner balance to show $0

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
  v_task_price int;
  v_runner_role text;
  v_fee int;
BEGIN
  -- Verify the caller is a runner
  SELECT role INTO v_runner_role
    FROM public.users
   WHERE id = p_runner_id;

  IF v_runner_role IS NULL OR v_runner_role != 'runner' THEN
    RAISE EXCEPTION 'Only runners can accept tasks';
  END IF;

  -- Verify the task exists and is posted
  SELECT status, price INTO v_task_status, v_task_price
    FROM public.tasks
   WHERE id = p_task_id
   FOR UPDATE;  -- lock the row

  IF v_task_status IS NULL THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  IF v_task_status != 'posted' THEN
    RAISE EXCEPTION 'Task is no longer available (status: %)', v_task_status;
  END IF;

  -- Calculate 15% platform fee
  v_fee := round(v_task_price * 0.15);

  -- Insert application record (accepted immediately)
  INSERT INTO public.task_applications (task_id, runner_id, status)
  VALUES (p_task_id, p_runner_id, 'accepted')
  ON CONFLICT (task_id, runner_id) DO UPDATE SET status = 'accepted';

  -- Update task: assign runner, mark accepted, set fee breakdown
  UPDATE public.tasks
     SET status = 'accepted',
         runner_id = p_runner_id,
         accepted_at = now(),
         platform_fee = v_fee,
         runner_payout = v_task_price - v_fee,
         updated_at = now()
   WHERE id = p_task_id;
END;
$$;

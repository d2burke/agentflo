-- Bind accept_task to the authenticated caller.
-- The legacy function trusted p_runner_id even though it runs as SECURITY DEFINER,
-- which allowed a caller to accept tasks on behalf of another runner.

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
  v_auth_uid uuid := auth.uid();
  v_task_status text;
  v_task_price int;
  v_runner_role text;
  v_runner_connect_id text;
  v_fee int;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_runner_id IS NOT NULL AND p_runner_id IS DISTINCT FROM v_auth_uid THEN
    RAISE EXCEPTION 'p_runner_id must match the authenticated user';
  END IF;

  -- Verify the caller is a runner with payout setup.
  SELECT role, stripe_connect_id
    INTO v_runner_role, v_runner_connect_id
    FROM public.users
   WHERE id = v_auth_uid;

  IF v_runner_role IS NULL OR v_runner_role != 'runner' THEN
    RAISE EXCEPTION 'Only runners can accept tasks';
  END IF;

  IF v_runner_connect_id IS NULL THEN
    RAISE EXCEPTION 'Please set up your payout method before accepting tasks';
  END IF;

  -- Verify the task exists and is posted.
  SELECT status, price
    INTO v_task_status, v_task_price
    FROM public.tasks
   WHERE id = p_task_id
   FOR UPDATE;

  IF v_task_status IS NULL THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  IF v_task_status != 'posted' THEN
    RAISE EXCEPTION 'Task is no longer available (status: %)', v_task_status;
  END IF;

  -- Agent pays the platform fee on top of the runner's price.
  v_fee := round(v_task_price * 0.15);

  INSERT INTO public.task_applications (task_id, runner_id, status)
  VALUES (p_task_id, v_auth_uid, 'accepted')
  ON CONFLICT (task_id, runner_id) DO UPDATE SET status = 'accepted';

  UPDATE public.tasks
     SET status = 'accepted',
         runner_id = v_auth_uid,
         accepted_at = now(),
         platform_fee = v_fee,
         runner_payout = v_task_price,
         updated_at = now()
   WHERE id = p_task_id;
END;
$$;

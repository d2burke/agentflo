-- Move platform fee from runner-side to agent-side.
-- Previously: runner_payout = price - fee (runner absorbs fee)
-- Now:        runner_payout = price (runner gets full amount)
--             platform_fee  = round(price * 0.15) (added on top, agent pays)
--
-- Agent total charge = price + platform_fee
-- Runner gets: runner_payout (= price)

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
  v_runner_connect_id text;
  v_fee int;
BEGIN
  -- Verify the caller is a runner with payout setup
  SELECT role, stripe_connect_id
    INTO v_runner_role, v_runner_connect_id
    FROM public.users
   WHERE id = p_runner_id;

  IF v_runner_role IS NULL OR v_runner_role != 'runner' THEN
    RAISE EXCEPTION 'Only runners can accept tasks';
  END IF;

  IF v_runner_connect_id IS NULL THEN
    RAISE EXCEPTION 'Please set up your payout method before accepting tasks';
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

  -- Calculate 15% platform fee (charged to agent on top of task price)
  v_fee := round(v_task_price * 0.15);

  -- Insert application record (accepted immediately)
  INSERT INTO public.task_applications (task_id, runner_id, status)
  VALUES (p_task_id, p_runner_id, 'accepted')
  ON CONFLICT (task_id, runner_id) DO UPDATE SET status = 'accepted';

  -- Update task: assign runner, mark accepted, set fee breakdown
  -- Runner gets full task price; agent pays price + fee
  UPDATE public.tasks
     SET status = 'accepted',
         runner_id = p_runner_id,
         accepted_at = now(),
         platform_fee = v_fee,
         runner_payout = v_task_price,
         updated_at = now()
   WHERE id = p_task_id;
END;
$$;

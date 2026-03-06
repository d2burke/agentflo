-- Phase 4: Rate limiting infrastructure
-- Provides per-user, per-action rate limiting via a PL/pgSQL function

CREATE TABLE IF NOT EXISTS public.rate_limits (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  identifier text NOT NULL,        -- user_id or IP
  action_type text NOT NULL,       -- 'read', 'write', 'auth'
  window_start timestamptz NOT NULL DEFAULT now(),
  request_count integer NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_lookup
  ON public.rate_limits (identifier, action_type, window_start);

-- Check and increment rate limit. Returns true if allowed, false if limit exceeded.
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_identifier text,
  p_action_type text,
  p_max_requests integer,
  p_window_seconds integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_window_start timestamptz;
  v_count integer;
BEGIN
  v_window_start := now() - (p_window_seconds || ' seconds')::interval;

  -- Get current count in the window
  SELECT COALESCE(SUM(request_count), 0)
  INTO v_count
  FROM public.rate_limits
  WHERE identifier = p_identifier
    AND action_type = p_action_type
    AND window_start >= v_window_start;

  -- Check if limit would be exceeded
  IF v_count >= p_max_requests THEN
    RETURN false;
  END IF;

  -- Insert new request record
  INSERT INTO public.rate_limits (identifier, action_type, window_start)
  VALUES (p_identifier, p_action_type, now());

  RETURN true;
END;
$$;

-- Cleanup function: remove records older than 1 hour
CREATE OR REPLACE FUNCTION cleanup_rate_limits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.rate_limits
  WHERE window_start < now() - interval '1 hour';
END;
$$;

-- No RLS needed — rate_limits is only accessed via SECURITY DEFINER functions
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Migration: Open house visitor check-in system
-- Visitors check in via a web form (QR code) — no app download needed.

CREATE TABLE public.open_house_visitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  visitor_name text NOT NULL,
  email text,
  phone text,
  interest_level text NOT NULL DEFAULT 'interested' CHECK (interest_level IN ('just_looking', 'interested', 'very_interested')),
  pre_approved boolean DEFAULT false,
  agent_represented boolean DEFAULT false,
  representing_agent_name text,
  notes text,
  created_at timestamptz DEFAULT now(),
  CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_visitors_task ON public.open_house_visitors(task_id, created_at DESC);

ALTER TABLE public.open_house_visitors ENABLE ROW LEVEL SECURITY;

-- Participants can read visitors for their tasks
CREATE POLICY visitors_participant_select ON public.open_house_visitors
  FOR SELECT TO authenticated
  USING (
    task_id IN (
      SELECT id FROM public.tasks WHERE agent_id = auth.uid() OR runner_id = auth.uid()
    )
  );

-- Allow anon inserts (public web form — visitors don't have accounts)
CREATE POLICY visitors_anon_insert ON public.open_house_visitors
  FOR INSERT TO anon
  WITH CHECK (true);

-- Also allow authenticated inserts (in case runner manually adds)
CREATE POLICY visitors_auth_insert ON public.open_house_visitors
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Add QR code token to tasks
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS qr_code_token text UNIQUE;
CREATE INDEX idx_tasks_qr_token ON public.tasks(qr_code_token) WHERE qr_code_token IS NOT NULL;

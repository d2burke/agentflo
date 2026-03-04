-- Migration: Showing reports — structured feedback after property showings

CREATE TYPE buyer_interest_level AS ENUM (
  'not_interested',
  'somewhat_interested',
  'very_interested',
  'likely_offer'
);

CREATE TABLE public.showing_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL UNIQUE REFERENCES public.tasks(id) ON DELETE CASCADE,
  runner_id uuid NOT NULL REFERENCES public.users(id),
  buyer_name text NOT NULL,
  buyer_interest buyer_interest_level NOT NULL DEFAULT 'somewhat_interested',
  questions jsonb DEFAULT '[]',
  property_feedback text,
  follow_up_notes text,
  next_steps text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_showing_reports_task ON public.showing_reports(task_id);

ALTER TABLE public.showing_reports ENABLE ROW LEVEL SECURITY;

-- Participants can read (runner who wrote it + owning agent)
CREATE POLICY showing_reports_participant_select ON public.showing_reports
  FOR SELECT TO authenticated
  USING (
    runner_id = auth.uid()
    OR task_id IN (SELECT id FROM public.tasks WHERE agent_id = auth.uid())
  );

-- Runner can insert their own report
CREATE POLICY showing_reports_runner_insert ON public.showing_reports
  FOR INSERT TO authenticated
  WITH CHECK (runner_id = auth.uid());

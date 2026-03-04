-- Migration: Inspection findings table for ASHI-compliant property inspections
-- Supports 10 system categories per ASHI standards

-- System category enum
DO $$ BEGIN
  CREATE TYPE inspection_system AS ENUM (
    'structure', 'exterior', 'roofing', 'plumbing', 'electrical',
    'heating', 'cooling', 'interior', 'insulation_ventilation', 'fireplaces'
  );
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Finding status enum
DO $$ BEGIN
  CREATE TYPE finding_status AS ENUM ('good', 'deficiency', 'not_inspected', 'na');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Finding severity enum
DO $$ BEGIN
  CREATE TYPE finding_severity AS ENUM ('critical', 'major', 'minor', 'monitor', 'good');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Inspection findings table
CREATE TABLE public.inspection_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id),
  runner_id uuid NOT NULL REFERENCES public.users(id),
  system_category inspection_system NOT NULL,
  sub_item text NOT NULL,
  status finding_status NOT NULL DEFAULT 'good',
  severity finding_severity,
  description text,
  recommendation text,
  not_inspected_reason text,
  photo_urls jsonb DEFAULT '[]'::jsonb,
  ai_insight_json jsonb,
  cost_json jsonb,
  sort_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_inspection_findings_task_system
  ON public.inspection_findings(task_id, system_category);

CREATE INDEX idx_inspection_findings_task_severity
  ON public.inspection_findings(task_id, severity)
  WHERE severity IS NOT NULL;

-- RLS
ALTER TABLE public.inspection_findings ENABLE ROW LEVEL SECURITY;

-- Participants can read findings (runner + owning agent)
CREATE POLICY inspection_findings_participant_select ON public.inspection_findings
  FOR SELECT TO authenticated
  USING (
    runner_id = auth.uid()
    OR task_id IN (
      SELECT id FROM public.tasks WHERE agent_id = auth.uid()
    )
  );

-- Runner can insert/update their own findings
CREATE POLICY inspection_findings_runner_insert ON public.inspection_findings
  FOR INSERT TO authenticated
  WITH CHECK (
    runner_id = auth.uid()
    AND task_id IN (
      SELECT id FROM public.tasks WHERE runner_id = auth.uid()
    )
  );

CREATE POLICY inspection_findings_runner_update ON public.inspection_findings
  FOR UPDATE TO authenticated
  USING (runner_id = auth.uid())
  WITH CHECK (runner_id = auth.uid());

CREATE POLICY inspection_findings_runner_delete ON public.inspection_findings
  FOR DELETE TO authenticated
  USING (runner_id = auth.uid());

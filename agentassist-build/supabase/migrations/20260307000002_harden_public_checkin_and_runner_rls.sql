-- Harden public open-house check-in and runner-owned row mutation policies.
-- Public visitor inserts must go through the token-validating edge function.
-- Runner task state changes should only happen through RPCs/edge functions.

-- Stop allowing anonymous clients to insert directly into open_house_visitors.
DROP POLICY IF EXISTS visitors_anon_insert ON public.open_house_visitors;

-- Keep authenticated manual inserts, but only for participants on the live open house.
DROP POLICY IF EXISTS visitors_auth_insert ON public.open_house_visitors;
CREATE POLICY visitors_auth_insert ON public.open_house_visitors
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.tasks
      WHERE id = task_id
        AND category = 'Open House'
        AND status = 'in_progress'
        AND (agent_id = auth.uid() OR runner_id = auth.uid())
    )
  );

-- Remove the broad runner task UPDATE policy.
DROP POLICY IF EXISTS tasks_runner_update ON public.tasks;

-- Tighten direct deliverable mutations to the runner's own active task only.
DROP POLICY IF EXISTS deliverables_runner_insert ON public.deliverables;
CREATE POLICY deliverables_runner_insert ON public.deliverables
  FOR INSERT TO authenticated
  WITH CHECK (
    runner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.tasks
      WHERE id = task_id
        AND runner_id = auth.uid()
        AND status IN ('in_progress', 'revision_requested')
    )
  );

DROP POLICY IF EXISTS deliverables_runner_update ON public.deliverables;
CREATE POLICY deliverables_runner_update ON public.deliverables
  FOR UPDATE TO authenticated
  USING (
    runner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.tasks
      WHERE id = task_id
        AND runner_id = auth.uid()
        AND status IN ('in_progress', 'deliverables_submitted', 'revision_requested')
    )
  )
  WITH CHECK (
    runner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.tasks
      WHERE id = task_id
        AND runner_id = auth.uid()
        AND status IN ('in_progress', 'deliverables_submitted', 'revision_requested')
    )
  );

DROP POLICY IF EXISTS deliverables_runner_delete ON public.deliverables;
CREATE POLICY deliverables_runner_delete ON public.deliverables
  FOR DELETE TO authenticated
  USING (
    runner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.tasks
      WHERE id = task_id
        AND runner_id = auth.uid()
        AND status IN ('in_progress', 'revision_requested')
    )
  );

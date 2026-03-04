-- Allow runners to see basic profile info of agents whose tasks are posted or assigned to them
-- This enables showing "Posted by {agent name}" on task cards in the runner view

CREATE POLICY users_runner_view_agent ON public.users
  FOR SELECT USING (
    role = 'agent'
    AND EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.agent_id = users.id
        AND (tasks.status = 'posted' OR tasks.runner_id = auth.uid())
    )
  );

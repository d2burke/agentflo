-- Allow message recipients to mark messages as read
-- Only the non-sender participant of a task can update read_at

CREATE POLICY messages_mark_read ON public.messages
  FOR UPDATE USING (
    sender_id != auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = task_id
        AND (agent_id = auth.uid() OR runner_id = auth.uid())
    )
  )
  WITH CHECK (
    sender_id != auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = task_id
        AND (agent_id = auth.uid() OR runner_id = auth.uid())
    )
  );

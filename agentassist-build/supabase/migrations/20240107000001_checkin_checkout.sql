-- Add check-in/check-out columns to tasks table
-- Used by all in-person task categories to record runner arrival/departure

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS checked_in_at  timestamptz,
  ADD COLUMN IF NOT EXISTS checked_in_lat float8,
  ADD COLUMN IF NOT EXISTS checked_in_lng float8,
  ADD COLUMN IF NOT EXISTS checked_out_at  timestamptz,
  ADD COLUMN IF NOT EXISTS checked_out_lat float8,
  ADD COLUMN IF NOT EXISTS checked_out_lng float8;

-- Create deliverables storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('deliverables', 'deliverables', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: use DROP IF EXISTS + CREATE to be idempotent
DROP POLICY IF EXISTS deliverables_runner_upload ON storage.objects;
CREATE POLICY deliverables_runner_upload ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'deliverables'
    AND EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = (string_to_array(name, '/'))[1]::uuid
        AND runner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS deliverables_participant_read ON storage.objects;
CREATE POLICY deliverables_participant_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'deliverables'
    AND EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = (string_to_array(name, '/'))[1]::uuid
        AND (agent_id = auth.uid() OR runner_id = auth.uid())
    )
  );

-- Vetting Submission: storage bucket + RLS policies for user self-service vetting

-- 1. Create vetting-documents storage bucket (private — only the user + admins can view)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('vetting-documents', 'vetting-documents', false, 10485760, ARRAY['image/jpeg', 'image/png', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 10485760, allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'application/pdf'];

-- 2. Storage policies for vetting-documents
CREATE POLICY "Users can upload own vetting docs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'vetting-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can view own vetting docs"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'vetting-documents' AND (
  (storage.foldername(name))[1] = auth.uid()::text
  OR public.is_admin()
));

CREATE POLICY "Users can update own vetting docs"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'vetting-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete own vetting docs"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'vetting-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

-- 3. Allow users to INSERT their own vetting records
CREATE POLICY vetting_insert_own ON public.vetting_records
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 4. Allow users to UPDATE their own pending vetting records (for resubmission after rejection)
CREATE POLICY vetting_update_own_pending ON public.vetting_records
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND status IN ('pending', 'rejected'))
  WITH CHECK (user_id = auth.uid());

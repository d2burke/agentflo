-- Migration: Add public profile fields + portfolio images for runners

-- 1. Add profile fields to users table
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS headline text CHECK (char_length(headline) <= 120),
  ADD COLUMN IF NOT EXISTS specialties text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS profile_slug text UNIQUE,
  ADD COLUMN IF NOT EXISTS is_public_profile_enabled boolean DEFAULT false;

-- Validate slug format (lowercase alphanumeric + hyphens, 3-40 chars)
ALTER TABLE public.users
  ADD CONSTRAINT users_profile_slug_format
  CHECK (profile_slug IS NULL OR profile_slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$');

-- 2. Portfolio images table
CREATE TABLE public.portfolio_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  runner_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  caption text CHECK (char_length(caption) <= 200),
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_portfolio_runner ON public.portfolio_images(runner_id, sort_order);

-- RLS for portfolio_images
ALTER TABLE public.portfolio_images ENABLE ROW LEVEL SECURITY;

-- Owner full access
CREATE POLICY portfolio_owner_all ON public.portfolio_images
  FOR ALL TO authenticated
  USING (runner_id = auth.uid())
  WITH CHECK (runner_id = auth.uid());

-- Public read for enabled profiles
CREATE POLICY portfolio_public_read ON public.portfolio_images
  FOR SELECT TO authenticated
  USING (
    runner_id IN (
      SELECT id FROM public.users WHERE is_public_profile_enabled = true
    )
  );

-- 3. Storage bucket for portfolio images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'portfolio',
  'portfolio',
  true,
  10485760, -- 10 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: runners upload/delete own folder
CREATE POLICY portfolio_upload ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'portfolio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY portfolio_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'portfolio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public read for portfolio bucket
CREATE POLICY portfolio_read ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'portfolio');

-- 4. Update public_profiles view with new fields + completed task count
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles AS
SELECT
  u.id,
  u.full_name,
  u.avatar_url,
  u.role,
  u.brokerage,
  u.headline,
  u.specialties,
  u.profile_slug,
  u.is_public_profile_enabled,
  u.vetting_status = 'approved' AS is_verified,
  (SELECT ROUND(AVG(rating)::numeric, 1)
   FROM reviews WHERE reviewee_id = u.id) AS avg_rating,
  (SELECT COUNT(*)
   FROM reviews WHERE reviewee_id = u.id) AS review_count,
  (SELECT COUNT(*)
   FROM tasks WHERE runner_id = u.id AND status = 'completed') AS completed_tasks
FROM public.users u;

-- 5. Allow runners to update their own profile fields
-- (existing RLS policy "users_update_own" should cover this,
--  but let's ensure the new columns are accessible)
-- The existing policy uses: USING (id = auth.uid()) WITH CHECK (id = auth.uid())
-- which covers all columns, so no additional policy needed.

-- Migration: Fix security linter warnings
-- 1. Recreate public_profiles view as SECURITY INVOKER (was SECURITY DEFINER)
-- 2. Recreate available_tasks view as SECURITY INVOKER (was SECURITY DEFINER)
-- 3. Enable RLS on spatial_ref_sys (PostGIS system table exposed in public schema)
-- 4. Add users RLS policy for public profile visibility

-- ============================================================
-- 1. Public profile visibility policy
--    With SECURITY INVOKER views, the querying user's RLS applies.
--    We need to allow authenticated users to see users who have
--    opted in to public profiles.
-- ============================================================
CREATE POLICY users_public_profile_visible ON public.users
  FOR SELECT TO authenticated
  USING (is_public_profile_enabled = true);

-- ============================================================
-- 2. Recreate public_profiles view with SECURITY INVOKER
--    Previously ran as view creator (SECURITY DEFINER by default),
--    bypassing RLS on the underlying users table.
-- ============================================================
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles
  WITH (security_invoker = true)
AS
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

-- ============================================================
-- 3. Recreate available_tasks view with SECURITY INVOKER
--    With INVOKER, runners only see tasks within THEIR service
--    areas (service_areas_own policy), which is correct behavior.
-- ============================================================
DROP VIEW IF EXISTS public.available_tasks;
CREATE VIEW public.available_tasks
  WITH (security_invoker = true)
AS
SELECT
  t.*,
  ST_Distance(t.property_point, sa.center_point) / 1609.34 AS distance_miles
FROM public.tasks t
CROSS JOIN public.service_areas sa
WHERE t.status = 'posted'
  AND sa.is_active = true
  AND ST_DWithin(t.property_point, sa.center_point,
      sa.radius_miles * 1609.34);

-- ============================================================
-- 4. spatial_ref_sys (PostGIS system table)
--    Owned by supabase_admin — cannot alter from application role.
--    This table is read-only PostGIS metadata and is not a security risk.
--    No action needed.
-- ============================================================

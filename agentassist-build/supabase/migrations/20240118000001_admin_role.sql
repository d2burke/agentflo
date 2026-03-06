-- Migration: Admin role + vetting management
-- Adds is_admin boolean to users, RLS policies for admin operations,
-- and find_nearby_runners RPC for Phase 2/5 service area matching.

-- ============================================================
-- 1. Add is_admin column to users
-- ============================================================
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

-- ============================================================
-- 2. RLS: Admins can read ALL users
-- ============================================================
CREATE POLICY users_admin_read_all ON public.users
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true)
  );

-- ============================================================
-- 3. RLS: Admins can read ALL vetting records
-- ============================================================
CREATE POLICY vetting_admin_read_all ON public.vetting_records
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true)
  );

-- ============================================================
-- 4. RLS: Admins can update vetting records
-- ============================================================
CREATE POLICY vetting_admin_update ON public.vetting_records
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true)
  );

-- ============================================================
-- 5. RLS: Admins can update user vetting_status
--    Restricted to only the vetting_status column change via edge function
-- ============================================================
CREATE POLICY users_admin_update_vetting ON public.users
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true)
  );

-- ============================================================
-- 6. PostGIS: Find nearby runners within their service areas
--    Used by post-task to notify runners and by available_tasks view
-- ============================================================
CREATE OR REPLACE FUNCTION find_nearby_runners(task_lat float8, task_lng float8)
RETURNS TABLE(runner_id uuid, distance_miles float8) AS $$
  SELECT
    sa.runner_id,
    MIN(
      ST_Distance(
        ST_SetSRID(ST_MakePoint(task_lng, task_lat), 4326)::geography,
        sa.center_point
      ) / 1609.34
    ) AS distance_miles
  FROM public.service_areas sa
  JOIN public.users u ON u.id = sa.runner_id
  WHERE sa.is_active = true
    AND u.vetting_status = 'approved'
    AND ST_DWithin(
      sa.center_point,
      ST_SetSRID(ST_MakePoint(task_lng, task_lat), 4326)::geography,
      sa.radius_miles * 1609.34
    )
  GROUP BY sa.runner_id;
$$ LANGUAGE sql STABLE;

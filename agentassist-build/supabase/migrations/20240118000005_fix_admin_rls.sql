-- Fix: Admin RLS policies cause infinite recursion
-- The policies query public.users to check is_admin, but that query
-- itself is subject to RLS, creating a loop. Fix by using a
-- SECURITY DEFINER function that bypasses RLS for the admin check.

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.users WHERE id = auth.uid()),
    false
  );
$$;

-- Drop and recreate the problematic policies using the helper function

DROP POLICY IF EXISTS users_admin_read_all ON public.users;
CREATE POLICY users_admin_read_all ON public.users
  FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS users_admin_update_vetting ON public.users;
CREATE POLICY users_admin_update_vetting ON public.users
  FOR UPDATE TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS vetting_admin_read_all ON public.vetting_records;
CREATE POLICY vetting_admin_read_all ON public.vetting_records
  FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS vetting_admin_update ON public.vetting_records;
CREATE POLICY vetting_admin_update ON public.vetting_records
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

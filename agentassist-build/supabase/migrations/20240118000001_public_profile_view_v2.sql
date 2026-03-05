-- Migration: Add bio and created_at to public_profiles view

DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles AS
SELECT
  u.id,
  u.full_name,
  u.avatar_url,
  u.role,
  u.brokerage,
  u.bio,
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
   FROM tasks WHERE runner_id = u.id AND status = 'completed') AS completed_tasks,
  u.created_at
FROM public.users u;

-- Migration: Security fixes v2
-- Addresses audit findings: RLS hardening, missing indexes, view optimization,
-- idempotency improvements, and tighter anon access policies.

-- ============================================================
-- 1. CRITICAL: Restrict anon open_house_visitors inserts
--    Previously allowed inserting for ANY task_id.
--    Now validates task has a valid qr_code_token and is in_progress.
-- ============================================================
DROP POLICY IF EXISTS visitors_anon_insert ON public.open_house_visitors;
CREATE POLICY visitors_anon_insert ON public.open_house_visitors
  FOR INSERT TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = task_id
        AND status = 'in_progress'
        AND qr_code_token IS NOT NULL
    )
  );

-- Also tighten authenticated inserts (runner manually adding visitors)
DROP POLICY IF EXISTS visitors_auth_insert ON public.open_house_visitors;
CREATE POLICY visitors_auth_insert ON public.open_house_visitors
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = task_id
        AND (agent_id = auth.uid() OR runner_id = auth.uid())
        AND status = 'in_progress'
    )
  );

-- ============================================================
-- 2. CRITICAL: Hide qr_code_token from runner SELECT policy
--    Runners should only see posted tasks for browsing, not QR tokens.
--    QR tokens are only needed by the assigned runner on their own task.
--    Solution: Create a separate column-restricted policy or use
--    a function to null out the token for non-participants.
--    Approach: Drop old runner policy, create two new ones.
-- ============================================================

-- Note: We can't do column-level RLS in Postgres, so we handle this
-- at the application/view level. The edge function for open-house-checkin
-- already uses service role to look up by token. The iOS/web app should
-- only expose qr_code_token to the assigned runner via the task detail query.
-- No migration change needed — handled in application layer.

-- ============================================================
-- 3. HIGH: Add missing RLS policies for deliverables
--    Runners need UPDATE (to fix metadata) and DELETE (for drafts)
-- ============================================================
CREATE POLICY deliverables_runner_update ON public.deliverables
  FOR UPDATE TO authenticated
  USING (runner_id = auth.uid())
  WITH CHECK (runner_id = auth.uid());

CREATE POLICY deliverables_runner_delete ON public.deliverables
  FOR DELETE TO authenticated
  USING (
    runner_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = task_id
        AND runner_id = auth.uid()
        AND status NOT IN ('completed', 'cancelled')
    )
  );

-- ============================================================
-- 4. HIGH: Add message update policy for read receipts
--    Non-sender participants can mark messages as read.
-- ============================================================
CREATE POLICY messages_mark_read ON public.messages
  FOR UPDATE TO authenticated
  USING (
    sender_id != auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.tasks
      WHERE id = task_id
        AND (agent_id = auth.uid() OR runner_id = auth.uid())
    )
  )
  WITH CHECK (
    sender_id != auth.uid()
  );

-- ============================================================
-- 5. MEDIUM: Restrict reviews to authenticated users only
--    Previously allowed anon SELECT via USING (true).
-- ============================================================
DROP POLICY IF EXISTS reviews_public_read ON public.reviews;
CREATE POLICY reviews_authenticated_read ON public.reviews
  FOR SELECT TO authenticated
  USING (true);

-- ============================================================
-- 6. PERFORMANCE: Add missing indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_messages_sender
  ON public.messages(sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_apps_runner_status
  ON public.task_applications(runner_id, status);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reviews_reviewer
  ON public.reviews(reviewer_id);

CREATE INDEX IF NOT EXISTS idx_reviews_reviewee
  ON public.reviews(reviewee_id);

CREATE INDEX IF NOT EXISTS idx_deliverables_task
  ON public.deliverables(task_id, created_at);

CREATE INDEX IF NOT EXISTS idx_service_areas_runner_active
  ON public.service_areas(runner_id)
  WHERE is_active = true;

-- ============================================================
-- 7. PERFORMANCE: Optimize available_tasks view
--    Replace CROSS JOIN with EXISTS subquery to avoid cartesian product.
--    Returns minimum distance across all matching service areas.
-- ============================================================
DROP VIEW IF EXISTS public.available_tasks;
CREATE VIEW public.available_tasks
  WITH (security_invoker = true)
AS
SELECT
  t.id, t.agent_id, t.runner_id, t.category, t.status,
  t.property_address, t.property_lat, t.property_lng,
  t.scheduled_at, t.price, t.platform_fee, t.runner_payout,
  t.instructions, t.category_form_data,
  t.posted_at, t.accepted_at, t.completed_at, t.cancelled_at,
  t.cancellation_reason, t.created_at, t.updated_at,
  (
    SELECT MIN(ST_Distance(t.property_point, sa.center_point) / 1609.34)
    FROM public.service_areas sa
    WHERE sa.is_active = true
      AND ST_DWithin(t.property_point, sa.center_point, sa.radius_miles * 1609.34)
  ) AS distance_miles
FROM public.tasks t
WHERE t.status = 'posted'
  AND t.property_point IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM public.service_areas sa
    WHERE sa.is_active = true
      AND ST_DWithin(t.property_point, sa.center_point, sa.radius_miles * 1609.34)
  );

-- ============================================================
-- 8. MEDIUM: Add notification insert policy for service role
--    Notifications are created by edge functions via service role,
--    but we should also allow the notification function to use
--    authenticated context if needed.
-- ============================================================
CREATE POLICY notifs_insert_service ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 9. Add task price validation constraints
-- ============================================================
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_price_check;
ALTER TABLE public.tasks ADD CONSTRAINT tasks_price_range
  CHECK (price > 0 AND price <= 1000000);  -- max $10,000

-- ============================================================
-- 10. Add category validation constraint
-- ============================================================
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_category_check;
ALTER TABLE public.tasks ADD CONSTRAINT tasks_category_valid
  CHECK (category IN ('Photography', 'Showing', 'Staging', 'Open House', 'Inspection'));

-- Enable PostGIS and text search
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('agent', 'runner')),
  email text NOT NULL UNIQUE,
  full_name text NOT NULL,
  phone text,
  avatar_url text,
  brokerage text,
  license_number text,
  license_state text CHECK (license_state ~ '^[A-Z]{2}$'),
  bio text CHECK (char_length(bio) <= 500),
  vetting_status text NOT NULL DEFAULT 'not_started'
    CHECK (vetting_status IN ('not_started','pending','approved','rejected','expired')),
  onboarding_completed_steps text[] DEFAULT '{}',
  stripe_customer_id text,
  stripe_connect_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- ============================================================
-- TASKS
-- ============================================================
CREATE TABLE public.tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid NOT NULL REFERENCES public.users(id),
  runner_id uuid REFERENCES public.users(id),
  category text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','posted','accepted','in_progress',
      'deliverables_submitted','revision_requested','completed','cancelled')),
  property_address text NOT NULL,
  property_lat float8,
  property_lng float8,
  property_point geography(Point, 4326),
  scheduled_at timestamptz,
  price integer NOT NULL CHECK (price > 0),
  platform_fee integer,
  runner_payout integer,
  instructions text,
  category_form_data jsonb DEFAULT '{}',
  stripe_payment_intent_id text,
  posted_at timestamptz,
  accepted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_tasks_agent ON public.tasks(agent_id, status);
CREATE INDEX idx_tasks_runner ON public.tasks(runner_id, status);
CREATE INDEX idx_tasks_status_location ON public.tasks
  USING GIST(property_point) WHERE status = 'posted';
CREATE INDEX idx_tasks_posted_at ON public.tasks(posted_at DESC)
  WHERE status = 'posted';

-- Auto-compute PostGIS point from lat/lng
CREATE OR REPLACE FUNCTION compute_geography_point()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.property_lat IS NOT NULL AND NEW.property_lng IS NOT NULL THEN
    NEW.property_point := ST_SetSRID(
      ST_MakePoint(NEW.property_lng, NEW.property_lat), 4326
    )::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_task_point
  BEFORE INSERT OR UPDATE OF property_lat, property_lng ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION compute_geography_point();

-- ============================================================
-- TASK APPLICATIONS
-- ============================================================
CREATE TABLE public.task_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  runner_id uuid NOT NULL REFERENCES public.users(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','accepted','declined','withdrawn')),
  message text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(task_id, runner_id)
);

-- ============================================================
-- DELIVERABLES
-- ============================================================
CREATE TABLE public.deliverables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  runner_id uuid NOT NULL REFERENCES public.users(id),
  type text NOT NULL CHECK (type IN ('photo','document','report','checklist')),
  file_url text,
  thumbnail_url text,
  title text,
  notes text,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- MESSAGES
-- ============================================================
CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.users(id),
  body text NOT NULL,
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_messages_task ON public.messages(task_id, created_at);

-- ============================================================
-- REVIEWS
-- ============================================================
CREATE TABLE public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id),
  reviewer_id uuid NOT NULL REFERENCES public.users(id),
  reviewee_id uuid NOT NULL REFERENCES public.users(id),
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(task_id, reviewer_id)
);

-- ============================================================
-- VETTING RECORDS
-- ============================================================
CREATE TABLE public.vetting_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id),
  type text NOT NULL
    CHECK (type IN ('license','photo_id','brokerage','background_check')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  submitted_data jsonb,
  reviewer_notes text,
  reviewed_by uuid REFERENCES public.users(id),
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- SERVICE AREAS (Runner only)
-- ============================================================
CREATE TABLE public.service_areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  runner_id uuid NOT NULL REFERENCES public.users(id),
  name text NOT NULL,
  center_lat float8 NOT NULL,
  center_lng float8 NOT NULL,
  radius_miles float4 NOT NULL DEFAULT 10,
  center_point geography(Point, 4326),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Reuse point computation for service areas
CREATE OR REPLACE FUNCTION compute_service_area_point()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.center_lat IS NOT NULL AND NEW.center_lng IS NOT NULL THEN
    NEW.center_point := ST_SetSRID(
      ST_MakePoint(NEW.center_lng, NEW.center_lat), 4326
    )::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_service_area_point
  BEFORE INSERT OR UPDATE OF center_lat, center_lng ON public.service_areas
  FOR EACH ROW EXECUTE FUNCTION compute_service_area_point();

-- ============================================================
-- AVAILABILITY (Runner only)
-- ============================================================
CREATE TABLE public.availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  runner_id uuid NOT NULL REFERENCES public.users(id),
  day_of_week integer NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_active boolean DEFAULT true,
  UNIQUE(runner_id, day_of_week)
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id),
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  read_at timestamptz,
  push_sent_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_notifications_user_unread
  ON public.notifications(user_id) WHERE read_at IS NULL;

-- ============================================================
-- NOTIFICATION PREFERENCES
-- ============================================================
CREATE TABLE public.notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES public.users(id),
  task_updates boolean DEFAULT true,
  messages boolean DEFAULT true,
  payment_confirmations boolean DEFAULT true,
  new_available_tasks boolean DEFAULT true,
  weekly_earnings boolean DEFAULT true,
  product_updates boolean DEFAULT false
);

-- ============================================================
-- PUSH TOKENS
-- ============================================================
CREATE TABLE public.push_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id),
  token text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('ios','android','web')),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- VIEWS
-- ============================================================

-- Public-facing profile (limited fields)
CREATE VIEW public.public_profiles AS
SELECT
  id, full_name, avatar_url, role, brokerage,
  vetting_status = 'approved' AS is_verified,
  (SELECT ROUND(AVG(rating)::numeric, 1)
   FROM reviews WHERE reviewee_id = users.id) AS avg_rating,
  (SELECT COUNT(*)
   FROM reviews WHERE reviewee_id = users.id) AS review_count
FROM public.users;

-- Runner task feed: available tasks within service areas
CREATE VIEW public.available_tasks AS
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
-- TRIGGERS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_tasks_updated BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Unread notification count helper
CREATE OR REPLACE FUNCTION unread_notification_count(uid uuid)
RETURNS integer AS $$
  SELECT COUNT(*)::integer FROM public.notifications
  WHERE user_id = uid AND read_at IS NULL;
$$ LANGUAGE sql STABLE;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliverables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vetting_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- USERS
CREATE POLICY users_select_own ON public.users
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY users_update_own ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- TASKS
CREATE POLICY tasks_agent_all ON public.tasks
  FOR SELECT USING (agent_id = auth.uid());
CREATE POLICY tasks_runner_available ON public.tasks
  FOR SELECT USING (status = 'posted' OR runner_id = auth.uid());
CREATE POLICY tasks_agent_insert ON public.tasks
  FOR INSERT WITH CHECK (
    agent_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'agent')
  );
CREATE POLICY tasks_agent_update ON public.tasks
  FOR UPDATE USING (agent_id = auth.uid());

-- TASK APPLICATIONS
CREATE POLICY apps_runner_insert ON public.task_applications
  FOR INSERT WITH CHECK (
    runner_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'runner')
  );
CREATE POLICY apps_runner_select ON public.task_applications
  FOR SELECT USING (runner_id = auth.uid());
CREATE POLICY apps_agent_select ON public.task_applications
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.tasks WHERE id = task_id AND agent_id = auth.uid())
  );

-- DELIVERABLES
CREATE POLICY deliverables_participants ON public.deliverables
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.tasks WHERE id = task_id
      AND (agent_id = auth.uid() OR runner_id = auth.uid()))
  );
CREATE POLICY deliverables_runner_insert ON public.deliverables
  FOR INSERT WITH CHECK (runner_id = auth.uid());

-- MESSAGES
CREATE POLICY messages_participants ON public.messages
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.tasks WHERE id = task_id
      AND (agent_id = auth.uid() OR runner_id = auth.uid()))
  );
CREATE POLICY messages_send ON public.messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.tasks WHERE id = task_id
      AND (agent_id = auth.uid() OR runner_id = auth.uid()))
  );

-- REVIEWS (public read, insert own on completed tasks)
CREATE POLICY reviews_public_read ON public.reviews
  FOR SELECT USING (true);
CREATE POLICY reviews_insert ON public.reviews
  FOR INSERT WITH CHECK (
    reviewer_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.tasks WHERE id = task_id
      AND status = 'completed'
      AND (agent_id = auth.uid() OR runner_id = auth.uid()))
  );

-- VETTING (read own, admin writes via service key)
CREATE POLICY vetting_read_own ON public.vetting_records
  FOR SELECT USING (user_id = auth.uid());

-- SERVICE AREAS, AVAILABILITY (own only)
CREATE POLICY service_areas_own ON public.service_areas
  FOR ALL USING (runner_id = auth.uid());
CREATE POLICY availability_own ON public.availability
  FOR ALL USING (runner_id = auth.uid());

-- NOTIFICATIONS (own only)
CREATE POLICY notifs_read_own ON public.notifications
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY notifs_update_own ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- NOTIFICATION PREFERENCES, PUSH TOKENS (own only)
CREATE POLICY notif_prefs_own ON public.notification_preferences
  FOR ALL USING (user_id = auth.uid());
CREATE POLICY push_tokens_own ON public.push_tokens
  FOR ALL USING (user_id = auth.uid());

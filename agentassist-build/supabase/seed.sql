-- AgentAssist Seed Data
-- Run after 00001_initial_schema.sql
-- Creates realistic test data for local development
--
-- NOTE: In production, users are created via Supabase Auth.
-- For seeding, we insert directly into auth.users + auth.identities
-- first (to satisfy the FK on public.users), then into public.users.
-- All seed users share password: password123

-- ============================================================
-- TEST USER UUIDs
-- ============================================================
-- Agent 1: Daniel (primary test agent)
-- Agent 2: Sarah (secondary agent)
-- Runner 1: Marcus (approved, active)
-- Runner 2: Elena (approved, active)
-- Runner 3: James (pending vetting)

DO $$
DECLARE
  agent1_id uuid := '00000000-0000-0000-0000-000000000001';
  agent2_id uuid := '00000000-0000-0000-0000-000000000002';
  runner1_id uuid := '00000000-0000-0000-0000-000000000003';
  runner2_id uuid := '00000000-0000-0000-0000-000000000004';
  runner3_id uuid := '00000000-0000-0000-0000-000000000005';
  task1_id uuid;
  task2_id uuid;
  task3_id uuid;
  task4_id uuid;
  task5_id uuid;
  task6_id uuid;
  task7_id uuid;
BEGIN

-- ============================================================
-- AUTH USERS (must exist before public.users due to FK)
-- ============================================================
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, raw_app_meta_data, raw_user_meta_data)
VALUES
  (agent1_id,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'daniel@example.com',  crypt('password123', gen_salt('bf')), now(), now(), now(), '', '{"provider":"email","providers":["email"]}', '{}'),
  (agent2_id,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sarah@example.com',   crypt('password123', gen_salt('bf')), now(), now(), now(), '', '{"provider":"email","providers":["email"]}', '{}'),
  (runner1_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'marcus@example.com',  crypt('password123', gen_salt('bf')), now(), now(), now(), '', '{"provider":"email","providers":["email"]}', '{}'),
  (runner2_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elena@example.com',   crypt('password123', gen_salt('bf')), now(), now(), now(), '', '{"provider":"email","providers":["email"]}', '{}'),
  (runner3_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'james@example.com',   crypt('password123', gen_salt('bf')), now(), now(), now(), '', '{"provider":"email","providers":["email"]}', '{}');

INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
VALUES
  (gen_random_uuid(), agent1_id,  'daniel@example.com', jsonb_build_object('sub', agent1_id::text,  'email', 'daniel@example.com'),  'email', now(), now(), now()),
  (gen_random_uuid(), agent2_id,  'sarah@example.com',  jsonb_build_object('sub', agent2_id::text,  'email', 'sarah@example.com'),   'email', now(), now(), now()),
  (gen_random_uuid(), runner1_id, 'marcus@example.com', jsonb_build_object('sub', runner1_id::text, 'email', 'marcus@example.com'),  'email', now(), now(), now()),
  (gen_random_uuid(), runner2_id, 'elena@example.com',  jsonb_build_object('sub', runner2_id::text, 'email', 'elena@example.com'),   'email', now(), now(), now()),
  (gen_random_uuid(), runner3_id, 'james@example.com',  jsonb_build_object('sub', runner3_id::text, 'email', 'james@example.com'),   'email', now(), now(), now());

-- ============================================================
-- USERS
-- ============================================================
INSERT INTO public.users (id, role, email, full_name, phone, brokerage, license_number, license_state, vetting_status, onboarding_completed_steps) VALUES
  (agent1_id, 'agent', 'daniel@example.com', 'Daniel Mitchell', '+15125551001', 'Keller Williams Austin', 'TX-789456', 'TX', 'approved', ARRAY['photo','brokerage','license','payment','first_task']),
  (agent2_id, 'agent', 'sarah@example.com', 'Sarah Chen', '+12125551002', 'Compass NYC', 'NY-123789', 'NY', 'approved', ARRAY['photo','brokerage','license','payment']),
  (runner1_id, 'runner', 'marcus@example.com', 'Marcus Johnson', '+15125551003', 'eXp Realty', 'TX-456123', 'TX', 'approved', ARRAY['photo','license','payout','service_area']),
  (runner2_id, 'runner', 'elena@example.com', 'Elena Rodriguez', '+15125551004', 'RE/MAX Austin', 'TX-321654', 'TX', 'approved', ARRAY['photo','license','payout','service_area']),
  (runner3_id, 'runner', 'james@example.com', 'James Park', '+12125551005', NULL, NULL, NULL, 'pending', ARRAY['photo']);

-- ============================================================
-- SERVICE AREAS
-- ============================================================
INSERT INTO public.service_areas (runner_id, name, center_lat, center_lng, radius_miles) VALUES
  (runner1_id, 'Downtown Austin', 30.2672, -97.7431, 15),
  (runner1_id, 'South Austin', 30.2100, -97.7700, 10),
  (runner2_id, 'Central Austin', 30.2850, -97.7350, 12);

-- ============================================================
-- AVAILABILITY
-- ============================================================
INSERT INTO public.availability (runner_id, day_of_week, start_time, end_time) VALUES
  (runner1_id, 0, '08:00', '18:00'),  -- Monday
  (runner1_id, 1, '08:00', '18:00'),  -- Tuesday
  (runner1_id, 2, '08:00', '18:00'),  -- Wednesday
  (runner1_id, 3, '08:00', '18:00'),  -- Thursday
  (runner1_id, 4, '08:00', '15:00'),  -- Friday
  (runner2_id, 0, '09:00', '17:00'),
  (runner2_id, 1, '09:00', '17:00'),
  (runner2_id, 2, '09:00', '17:00'),
  (runner2_id, 3, '09:00', '17:00'),
  (runner2_id, 4, '09:00', '17:00'),
  (runner2_id, 5, '10:00', '14:00');  -- Saturday

-- ============================================================
-- TASKS (all statuses represented)
-- ============================================================

-- Task 1: Draft (agent1)
INSERT INTO public.tasks (agent_id, category, status, property_address, property_lat, property_lng, price, instructions)
VALUES (agent1_id, 'Photography', 'draft', '742 Evergreen Terrace, Austin TX 78701', 30.2672, -97.7431, 15000, 'Need exterior and interior shots, 20 photos minimum')
RETURNING id INTO task1_id;

-- Task 2: Posted (agent1)
INSERT INTO public.tasks (agent_id, category, status, property_address, property_lat, property_lng, price, instructions, posted_at)
VALUES (agent1_id, 'Showing', 'posted', '1200 Barton Springs Rd, Austin TX 78704', 30.2610, -97.7560, 7500, 'Buyer arriving at 2pm, confirm lockbox code is 1234', now() - interval '2 hours')
RETURNING id INTO task2_id;

-- Task 3: Accepted (agent1, runner1)
INSERT INTO public.tasks (agent_id, runner_id, category, status, property_address, property_lat, property_lng, price, platform_fee, runner_payout, instructions, posted_at, accepted_at)
VALUES (agent1_id, runner1_id, 'Photography', 'accepted', '500 W 2nd St, Austin TX 78701', 30.2655, -97.7475, 20000, 3000, 17000, 'Twilight shots needed. Property vacant.', now() - interval '1 day', now() - interval '3 hours')
RETURNING id INTO task3_id;

-- Task 4: In Progress (agent1, runner2)
INSERT INTO public.tasks (agent_id, runner_id, category, status, property_address, property_lat, property_lng, price, platform_fee, runner_payout, instructions, posted_at, accepted_at, scheduled_at)
VALUES (agent1_id, runner2_id, 'Staging', 'in_progress', '1800 S Congress Ave, Austin TX 78704', 30.2470, -97.7540, 35000, 5250, 29750, 'Living room and master bedroom only. Furniture in garage.', now() - interval '3 days', now() - interval '2 days', now() + interval '1 hour')
RETURNING id INTO task4_id;

-- Task 5: Deliverables Submitted (agent2, runner1)
INSERT INTO public.tasks (agent_id, runner_id, category, status, property_address, property_lat, property_lng, price, platform_fee, runner_payout, instructions, posted_at, accepted_at, completed_at)
VALUES (agent2_id, runner1_id, 'Photography', 'deliverables_submitted', '350 E Cesar Chavez St, Austin TX 78701', 30.2625, -97.7380, 18000, 2700, 15300, 'Downtown condo, 25 photos, include rooftop amenity.', now() - interval '5 days', now() - interval '4 days', NULL)
RETURNING id INTO task5_id;

-- Task 6: Completed (agent1, runner1)
INSERT INTO public.tasks (agent_id, runner_id, category, status, property_address, property_lat, property_lng, price, platform_fee, runner_payout, posted_at, accepted_at, completed_at)
VALUES (agent1_id, runner1_id, 'Open House', 'completed', '2400 Exposition Blvd, Austin TX 78703', 30.2920, -97.7670, 12500, 1875, 10625, now() - interval '10 days', now() - interval '9 days', now() - interval '7 days')
RETURNING id INTO task6_id;

-- Task 7: Cancelled (agent1)
INSERT INTO public.tasks (agent_id, category, status, property_address, property_lat, property_lng, price, posted_at, cancelled_at, cancellation_reason)
VALUES (agent1_id, 'Showing', 'cancelled', '900 W 5th St, Austin TX 78703', 30.2710, -97.7530, 5000, now() - interval '6 days', now() - interval '5 days', 'Listing fell through')
RETURNING id INTO task7_id;

-- ============================================================
-- TASK APPLICATIONS
-- ============================================================
INSERT INTO public.task_applications (task_id, runner_id, status, message) VALUES
  (task2_id, runner1_id, 'pending', 'Available this afternoon. I know the area well.'),
  (task2_id, runner2_id, 'pending', 'Can be there by 1:30pm.'),
  (task3_id, runner1_id, 'accepted', 'I specialize in real estate photography.'),
  (task3_id, runner2_id, 'declined', NULL);

-- ============================================================
-- DELIVERABLES (for completed/submitted tasks)
-- ============================================================
INSERT INTO public.deliverables (task_id, runner_id, type, file_url, title, sort_order) VALUES
  (task5_id, runner1_id, 'photo', '/deliverables/task5/exterior-front.jpg', 'Exterior - Front', 1),
  (task5_id, runner1_id, 'photo', '/deliverables/task5/living-room.jpg', 'Living Room', 2),
  (task5_id, runner1_id, 'photo', '/deliverables/task5/kitchen.jpg', 'Kitchen', 3),
  (task5_id, runner1_id, 'photo', '/deliverables/task5/master-bed.jpg', 'Master Bedroom', 4),
  (task5_id, runner1_id, 'photo', '/deliverables/task5/rooftop.jpg', 'Rooftop Amenity', 5),
  (task6_id, runner1_id, 'report', '/deliverables/task6/open-house-summary.pdf', 'Open House Summary Report', 1);

-- ============================================================
-- MESSAGES
-- ============================================================
INSERT INTO public.messages (task_id, sender_id, body, created_at) VALUES
  (task4_id, agent1_id, 'Hey Elena, the furniture is in the attached garage. Key is under the mat.', now() - interval '1 day'),
  (task4_id, runner2_id, 'Got it! I''ll start with the living room. Any preferred color palette?', now() - interval '23 hours'),
  (task4_id, agent1_id, 'Neutral tones — whites and grays. The buyer is a minimalist.', now() - interval '22 hours'),
  (task3_id, agent1_id, 'Marcus, can you do twilight shots around 7:30pm?', now() - interval '2 hours'),
  (task3_id, runner1_id, 'Perfect, I''ll plan for golden hour through twilight. Will bring drone too.', now() - interval '1 hour');

-- ============================================================
-- REVIEWS (on completed task)
-- ============================================================
INSERT INTO public.reviews (task_id, reviewer_id, reviewee_id, rating, comment) VALUES
  (task6_id, agent1_id, runner1_id, 5, 'Marcus was professional and the open house went great. 12 groups came through.'),
  (task6_id, runner1_id, agent1_id, 5, 'Clear instructions and quick payment. Would work with Daniel again.');

-- ============================================================
-- VETTING RECORDS
-- ============================================================
INSERT INTO public.vetting_records (user_id, type, status, submitted_data, reviewed_at) VALUES
  (runner1_id, 'license', 'approved', '{"license_number": "TX-456123", "state": "TX", "expiry": "2027-03-15"}', now() - interval '30 days'),
  (runner1_id, 'photo_id', 'approved', '{"file_url": "/vetting/runner1/id.jpg"}', now() - interval '30 days'),
  (runner2_id, 'license', 'approved', '{"license_number": "TX-321654", "state": "TX", "expiry": "2026-11-30"}', now() - interval '20 days'),
  (runner3_id, 'license', 'pending', '{"license_number": null, "state": null}', NULL);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
INSERT INTO public.notifications (user_id, type, title, body, data, read_at) VALUES
  (agent1_id, 'task_application', 'New Application', 'Marcus applied for your Showing task at 1200 Barton Springs Rd', jsonb_build_object('task_id', task2_id, 'screen', 'detail'), NULL),
  (agent1_id, 'task_application', 'New Application', 'Elena applied for your Showing task at 1200 Barton Springs Rd', jsonb_build_object('task_id', task2_id, 'screen', 'detail'), NULL),
  (agent1_id, 'deliverables_ready', 'Deliverables Ready', 'Marcus submitted photos for 350 E Cesar Chavez St', jsonb_build_object('task_id', task5_id, 'screen', 'detail'), NULL),
  (agent1_id, 'task_completed', 'Task Completed', 'Open house at 2400 Exposition Blvd is complete', jsonb_build_object('task_id', task6_id, 'screen', 'detail'), now() - interval '7 days'),
  (runner1_id, 'task_accepted', 'You Got the Task!', 'Daniel accepted your application for Photography at 500 W 2nd St', jsonb_build_object('task_id', task3_id, 'screen', 'detail'), now() - interval '3 hours'),
  (runner1_id, 'new_task_nearby', 'New Task Nearby', 'Showing task posted 2.1 miles away — $75', jsonb_build_object('task_id', task2_id, 'screen', 'detail'), NULL);

-- ============================================================
-- NOTIFICATION PREFERENCES
-- ============================================================
INSERT INTO public.notification_preferences (user_id) VALUES
  (agent1_id), (agent2_id), (runner1_id), (runner2_id), (runner3_id);

END $$;

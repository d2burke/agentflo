# Architecture Decisions

Key decisions made during spec development and their rationale. Reference this when a decision seems arbitrary — there's usually a reason.

## Data & Storage

**Supabase over Firebase/custom backend**
Postgres gives us PostGIS for location queries, RLS for row-level security without middleware, pg_graphql for auto-generated API, and Realtime for chat. All in one managed service with a generous free tier for MVP.

**Prices stored in cents (integer)**
Avoids floating-point rounding errors. $150.00 = 15000 cents. Display formatting is always a client concern. This is standard practice (Stripe uses cents too).

**PostGIS for all location queries**
Never calculate distance in application code. `ST_DWithin` handles radius queries, `ST_Distance` calculates miles. The `property_point` column is auto-computed from lat/lng via trigger, so we never have stale spatial data.

**`category_form_data` as JSONB**
Different task categories need different form fields (photography needs "number of rooms", showings need "buyer name"). Rather than creating category-specific tables, we use a JSONB column. The schema of this JSON is defined by the category config (Section 14.1). This is explicitly designed for extensibility.

**Separate `task_applications` table (not just runner_id on tasks)**
Supports the marketplace model where multiple runners can apply and the agent chooses. This is critical for quality — agents pick the best-rated runner, not just the first one who clicks "accept."

## Auth & Security

**RLS over middleware authorization**
Row-Level Security is enforced at the database layer, meaning even a compromised edge function can't read another user's data. This is defense-in-depth. Policies are defined in the migration file and version-controlled.

**Edge functions for all status transitions**
Never `UPDATE tasks SET status = 'completed'` from the client. Every transition has side effects (notifications, payments, state validation). Edge functions are the single point of enforcement. This prevents race conditions and ensures business rules are always applied.

**Service role key only in edge functions**
The client never has the service role key. It uses the anon key + JWT, which means RLS applies. Edge functions use the service role key for cross-user operations (like notifying a runner about an agent's action).

## Payments

**Stripe PaymentIntent with manual capture**
When an agent posts a task, we create a PaymentIntent but don't capture it (i.e., we authorize the card but don't charge it). This holds the funds. When the agent approves deliverables, we capture. This is the escrow pattern without needing a separate escrow account.

**Stripe Connect for runner payouts**
Runners connect their bank account via Stripe Connect. When a task is completed, we transfer funds minus our platform fee. This handles 1099 reporting and KYC compliance automatically.

**Platform fee calculated on acceptance, not on posting**
The fee is locked in when the agent accepts a runner, not when the task is posted. This allows fee flexibility (e.g., promotional rates, volume discounts) without needing to update posted tasks.

## Navigation

**`deepLink(tab, screen)` paradigm**
All cross-tab navigation uses a single function that atomically sets both the active tab and the target screen. This means the notification settings gear icon on the Notifications tab switches you to Profile → Notification Settings, and the tab bar reflects "Profile" as active. Back returns to Profile root, not Notifications. This is intentional — it matches the mental model of "I'm now in my Profile settings" rather than "I'm temporarily looking at settings from Notifications."

## Design

**DM Sans over SF Pro**
The prototype uses DM Sans for web. iOS builds will use the system font (SF Pro) for native feel. The design tokens are font-agnostic — they specify size/weight/spacing, not font family.

**No avatar in tab bar or greeting header**
The Profile tab is the entry point for identity. Putting an avatar in the tab bar or greeting header creates visual clutter and redundancy. The greeting uses text only: "Good afternoon, Daniel."

**Floating glass tab bar over standard tab bar**
Matches iOS 26 Liquid Glass design language. The tab bar is a floating capsule with backdrop blur, not a full-width bar. This gives more screen real estate for content.

## What We Explicitly Deferred

- **Multi-market support** — Cities are seeded data for now, not a dynamic config system
- **Dynamic categories from server** — Categories are in the DB but not served from a config API endpoint. Client can hardcode the 4 launch categories and read from DB in Iteration 4
- **AI features** — Image quality analysis, smart pricing, voice input are all Iteration 4+
- **SSO** — Email + password only for Iteration 1. Apple/Google SSO in Iteration 2+

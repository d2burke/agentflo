# AgentAssist — Claude Code Build Guide

## What This Is

AgentAssist is a TaskRabbit-style marketplace for real estate agents. Agents post operational tasks (photography, showings, staging, open houses) and vetted runners complete them. Built on Supabase (Postgres + Auth + Storage + Realtime + Edge Functions) with SwiftUI (iOS) and React (web) clients.

## Project Structure

```
agentassist-build/
├── CLAUDE.md                          ← You are here
├── docs/
│   ├── AgentAssist_Master_Spec.md     ← FULL product spec (3000+ lines, source of truth)
│   └── ARCHITECTURE_DECISIONS.md      ← Key decisions & rationale
├── reference/
│   ├── agentassist-prototype.jsx      ← Interactive UI prototype (visual reference only)
│   └── design-tokens.ts              ← Design system tokens (colors, typography, spacing)
├── supabase/
│   ├── config.toml                    ← Supabase project config
│   ├── migrations/
│   │   └── 00001_initial_schema.sql   ← Full DDL + RLS — run this first
│   ├── seed.sql                       ← Dev seed data (2 agents, 3 runners, tasks in all statuses)
│   └── functions/
│       ├── post-task/index.ts
│       ├── accept-runner/index.ts
│       ├── approve-and-pay/index.ts
│       ├── cancel-task/index.ts
│       ├── submit-deliverables/index.ts
│       └── send-notification/index.ts
```

## Build Order

### Phase 1: Database & Auth (Start Here)
1. Create Supabase project (or `supabase init` locally)
2. Run `supabase/migrations/00001_initial_schema.sql` — creates all 12 tables, indexes, triggers, views, and RLS policies
3. Enable `pg_graphql` extension (for GraphQL API auto-generation)
4. Set up Supabase Auth with email + password provider
5. Run `supabase/seed.sql` for development data
6. **Verify:** Create a user via Auth → confirm `users` row exists → confirm RLS blocks cross-user reads

### Phase 2: Edge Functions (Core Business Logic)
Build in this order — each builds on the previous:
1. **post-task** — validate → geocode → create PaymentIntent (stub) → update status → notify
2. **accept-runner** — assign runner → decline others → notify
3. **cancel-task** — evaluate fee rules → void/refund payment → notify
4. **approve-and-pay** — capture payment → calculate fee → schedule payout → notify
5. **submit-deliverables** — validate files → generate thumbnails → update status → notify
6. **send-notification** — resolve template → check prefs → push → insert DB record

### Phase 3: GraphQL & Realtime
1. Verify `pg_graphql` auto-generated queries match Section 13.6 of spec
2. Set up Realtime channels for `messages` and `tasks` tables
3. Test subscriptions with two browser windows

### Phase 4: Storage Buckets
1. Create buckets: `avatars`, `deliverables`, `vetting-documents`
2. Storage policies: avatars = public read/user write, deliverables = task participants, vetting = user + admin
3. Wire upload paths in edge functions

## Critical Architecture Rules

**READ SECTION 14 OF THE SPEC** before writing any code. Summary:

1. **Never hardcode category lists** — categories are data, not code. Query from DB, don't switch on strings
2. **Never hardcode prices or fee percentages** — all configurable per market/category
3. **Wrap Stripe in a PaymentProvider interface** — swappable without rewriting logic
4. **All status transitions go through edge functions** — never `UPDATE tasks SET status = ...` from client
5. **Prices are in cents** — $150.00 = `15000`. Display formatting is a client concern
6. **Timestamps are UTC** — always `timestamptz`. Display timezone is a client concern
7. **PostGIS for all location queries** — never calculate distance in application code
8. **Use feature flags** for any behavior that might be A/B tested or rolled out gradually

## Spec Quick Reference

| Topic | Spec Section |
|---|---|
| Product intent & constraints | 1–2 |
| User roles & permissions | 4 |
| Navigation & deep linking | 5 |
| Onboarding flows | 6 |
| Core user flows | 7 |
| Edge cases & error handling | 8 |
| Payment architecture | 9 |
| Iteration roadmap | 10 |
| Design system (tokens, components) | 11 |
| Screen-by-screen view specs | 12 |
| **Data model, SQL, GraphQL, Edge Functions** | **13** |
| Architecture extensibility | 14 |
| Security posture | 15 |
| Accessibility | 16 |

## Task State Machine

```
draft → posted → accepted → in_progress → deliverables_submitted → completed
                                                   ↕
                                          revision_requested
Any active status → cancelled
```

Every transition has side effects (notifications, payments, etc.). See Section 13.3 for the full table.

## Environment Variables

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Stripe (test keys for dev)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Google Maps (geocoding in post-task)
GOOGLE_MAPS_API_KEY=

# Push (Phase 3+)
FCM_SERVER_KEY=
APNS_KEY_ID=
APNS_TEAM_ID=
```

## What NOT to Build Yet

Specced but deferred: MFA (Iteration 2), rich push with actions (Iteration 3), proximity alerts (Iteration 3), Live Activity (Iteration 3), AI quality analysis (Iteration 4), multi-market (Iteration 5). For now, categories can be seeded in DB rather than served from a config endpoint.

## Testing

Every edge function needs at minimum: one happy-path test, one error-path test (bad status transition, unauthorized, missing fields). Use Supabase test helpers and Stripe test mode.

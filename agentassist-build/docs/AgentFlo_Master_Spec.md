# Agent Flo — Master Spec (v1.0)

**Status:** In Development — iOS MVP
**Last Updated:** March 4, 2026
**Author:** Daniel
**Platforms:** iOS (SwiftUI), Web (React — planned)

---

## 1. Intent

Agent Flo is a marketplace that enables solo and small-team real estate agents to outsource operational, on-site tasks—starting with photography and showings—to vetted service providers, so agents can focus on client relationships and closing deals.

**Core analogy:** TaskRabbit for real estate agents.

**Problem statement:** Real estate agents juggle dozens of operational tasks that require physical presence at properties. These tasks are time-consuming, repeatable, and don't require the listing agent's personal expertise. Agents need a trusted way to delegate this work quickly and affordably.

---

## 2. Constraints

### Market Constraints
- Launch in two markets only: Austin, TX and Virginia Beach, VA
- Start with five static task categories: Photography, Showings, Staging, Open House, and Inspections
- Task categories are hardcoded for MVP; dynamic, server-driven categories are a future iteration

### Economic Constraints
- Self-funded with break-even economics from day one
- No employees or engineers hired; built entirely with AI-assisted development
- Infrastructure costs must be covered by user revenue
- No expensive third-party integrations unless revenue-positive

### Trust & Safety Constraints
- Both agents and task runners must be vetted before gaining full platform access — see Section 10.1 (Vetting Framework)
- Task runners must be licensed real estate agents to be verified on the platform at launch
- Vetting includes real estate license verification, brokerage confirmation, and photo ID — see Section 10.1 for states and admin interface
- Manual admin vetting via web interface for MVP; automated license verification API planned for Iteration 4
- Workers who fail vetting are rejected with a reason; they may appeal within 7 days (one review allowed) via in-app form or email support; appeals are manually reviewed and resolved within 5 business days.

### Technical Constraints
- Asynchronous task matching (no real-time Uber-style matching at launch)
- All multi-step flows auto-save as drafts; no user work is ever lost
- Single app with branching UI based on user role (agent vs. task runner)
- Business logic is platform-agnostic; iOS and web implementation specs layer on top of this master spec

---

## 3. Success Criteria

### Launch Success (Month 1, per city)
- 10 agents posting tasks at least twice in the first month
- 80% of interested task runners complete the full onboarding process

### Leading Indicators
- Agents who start the task posting flow complete it (low abandonment)
- Task runners who download the app complete onboarding
- Tasks posted receive at least one qualified application within a reasonable timeframe: target <= 30 minutes in metro areas and <= 2 hours in non-metro areas (configurable). If no application by target, the system auto-expands search radius and notifies the agent with next steps.

### Lagging Indicators
- Repeat transactions from agents (2+ tasks posted)
- Task runners being selected for successive tasks
- Low dispute rate on completed tasks

---

## 4. User Roles

### Agent (Primary User)
- Posts tasks that need to be completed at properties
- Manages payment sources
- Reviews task runner deliverables
- Primary design focus of the app

### Task Runner (Service Provider)
- Browses available tasks and submits applications
- Must be a licensed real estate agent
- Submits deliverables (photos, confirmation of showings, etc.)
- Receives payment upon task completion

---

## 5. Navigation Architecture

### Tab Bar (Bottom Navigation — Both Roles)

The tab bar uses the **iOS 26 Liquid Glass** design language:

- **Dashboard** (primary tab, default on launch) — `house` SF Symbol
- **Notifications** — `bell` SF Symbol, with unread count badge
- **Profile / Account** — `person` SF Symbol

#### Liquid Glass Tab Bar Behavior
- Tab bar is a floating capsule shape, inset from screen edges, positioned at bottom-center
- Translucent glass material with backdrop blur and specular highlight edge
- Active tab shows: icon + text label with tinted pill background
- Inactive tabs show: icon only
- Content scrolls underneath the tab bar (100px bottom padding on content area)
- Standard SF Symbol icons for all tabs — no custom photo avatars or non-standard elements in the tab bar

### Dashboard — Agent View
- Greeting header (text only — no avatar element; Profile tab is the entry point for identity)
- Progressive onboarding card (profile completeness, payment setup, photo, etc.) — **dismissable via × button**
- Task status widgets: posted, in progress, completed
- Tapping a widget navigates to filtered task list (pushes onto navigation stack)
- Tapping a task pushes task detail onto the stack
- "Create Task" button (full-width, primary pill)

### Dashboard — Task Runner View
- Greeting header (text only — no avatar element)
- Earnings summary card (gradient)
- Available tasks with search and filter functionality
- Accepted tasks, completed tasks
- Same navigation stack pattern as agent view

### Tab Behavior
- Double-tap on Dashboard tab pops to root of navigation stack
- Third tap scrolls to top if already at root
- This is standard iOS convention and should be replicated on web

### Task Creation Flow
- **Post-login:** Uses sheet/modal presentation (slides up from bottom with drag handle)
- Dismissed via × button (top-right circle) or swipe down — **no back button in the sheet**
- Within the sheet, stepping between category selection and the form wizard uses internal state (not navigation stack)
- **During onboarding:** Uses navigation stack (inline with onboarding steps)
- Task creation components are reusable and context-agnostic — they work in both stack and sheet contexts

### Routing & Deep Linking

The app uses a **deep link paradigm** for all cross-context navigation. Any screen can be reached from any other screen — the system resolves the correct tab and screen state automatically.

#### Deep Link Model
A deep link is a `(tab, screen)` tuple:
- `deepLink("Profile", "notifSettings")` → switches to Profile tab, pushes Notification Settings
- `deepLink("Dashboard", null)` → switches to Dashboard tab at root
- `deepLink("Profile", "security")` → switches to Profile tab, pushes Account & Security

#### Cross-Tab Navigation Rules
1. **Tab always switches first**, then the screen renders within that tab's context
2. The **tab bar reflects the destination tab** immediately — the user should always know where they are
3. The **back button returns to the destination tab's root**, not to the source screen. This is intentional: once you've crossed tabs, back means "up within this tab" not "back to where I came from."
4. This paradigm applies everywhere: notification gear icon → Profile/notifSettings, notification deep links → Dashboard/detail, profile completion steps → Profile/personal, etc.

#### Deep Link Choreography
When a deep link arrives (from notification tap, in-app cross-reference, or universal link):
1. Dismiss any open sheet (no animation)
2. Pop to root of current tab (no animation)
3. Switch to target tab (animated tab bar transition)
4. Push target screen within that tab (animated push)
5. Avoid animating multiple stack pushes; animate only the final destination

#### URL Scheme & Universal Linking
- App registers the `agentflo://` custom URL scheme (configured in Info.plist via `CFBundleURLTypes`)
- `onOpenURL` handler in `Agent FloApp.swift` resolves incoming URLs and triggers deep link choreography
- Stripe Connect return flow uses `agentflo://stripe-connect` — on return, the app refreshes the user profile and navigates to Profile → Payout Settings
- App supports deep linking for tasks, notifications, and profile sections
- Universal linking enabled for web-to-app routing (planned)
- Centralized router handles all navigation from any entry point

#### Current Deep Link Inventory

| Source | Trigger | Deep Link Target | Behavior |
|---|---|---|---|
| Notifications tab | Gear icon tap | Profile → Notification Settings | Tab switches to Profile, settings screen pushed |
| Notifications tab | Notification tap (task) | Dashboard → Task Detail | Tab switches to Dashboard, task detail pushed |
| Notifications tab | Notification tap (message) | Dashboard → Chat | Tab switches to Dashboard, chat pushed |
| Dashboard | Profile completion pill tap | Profile → [target screen] | Tab switches to Profile, target screen pushed |
| Push notification | Tap from lock screen | [Resolved by payload] | App opens, deep link choreography executes |
| Stripe Connect | Return from hosted onboarding | Profile → Payout Settings | Refreshes user profile, navigates to Payout Settings |
| `agentflo://stripe-connect` | External URL scheme | Profile → Payout Settings | `onOpenURL` handler processes return |

---

## 6. Onboarding Flow

### 6.1 Pre-Auth Screens (Unauthenticated)

#### 6.1.1 Splash Screen
- App icon (A logo, 72px, red rounded square) + "Agent Flo" wordmark centered vertically
- Loading spinner below wordmark (red accent, circular)
- Duration: ~2 seconds, auto-transitions to Landing
- Purpose: brand impression while app initializes and checks auth state

#### 6.1.2 Landing Screen

The Landing screen is the first substantive surface unauthenticated users see after the Splash transition. It serves as the product's storefront: communicating what Agent Flo does, building confidence, and routing users to the correct sign-up path. No tab bar or navigation chrome appears on this screen.

**Layout (top to bottom):**
1. Logo + wordmark — centered in upper portion, seamless transition from Splash
2. Tagline — "Delegate tasks. Close deals." below wordmark (muted, small)
3. **Informational Feature Carousel** — horizontally swipeable card set (see 6.1.2.1 below)
4. **Role selection buttons** — full-width, stacked at bottom:
   - **"I'm a Real Estate Agent"** — primary red pill button → begins Agent sign-up
   - **"I'm a Task Runner"** — secondary outlined pill button → begins Runner sign-up
5. **Log In link** — "Already have an account? **Log In**" — navigates to Log In screen (6.1.6)

---

#### 6.1.2.1 Informational Feature Carousel

A horizontally swipeable carousel that introduces the platform's four core capabilities to unauthenticated users. The carousel is informational only — no buttons, no tappable CTAs within the cards. Users advance slides by swiping left/right. A page indicator shows position.

**Interaction Model**
- Swipe left/right to advance or go back
- Auto-advances every 4.5 seconds; pauses on user interaction, resumes 2 seconds after
- No previous/next arrow buttons — swipe only
- A thin progress bar at the top of the carousel card fills across the current slide's duration, resets on advance
- Page indicator dots at the bottom of the card: active dot expands to a pill (18px wide, 6px tall, red); inactive dots are 6×6 circles (muted white, 18% opacity)

**Slide Count:** 4 slides

---

**Slide 1 — Showings**

*Illustration:* `illustration-showing.svg`
A house silhouette with a stylized eye hovering above it — scan lines emanating from the eye toward the property, a glowing red pupil, and a "LIVE" badge in the lower-left corner of the house. Warm window-glow accents on the right window. Dark palette consistent with app design system.

| Element | Value |
|---|---|
| Tag label | `MOST POPULAR` |
| Headline | Schedule showings without lifting a finger |
| Body | Post a showing task and get a vetted runner to your property within hours — complete with photos and a walkthrough report. |

---

**Slide 2 — Inspections**

*Illustration:* `illustration-inspection.svg`
A clipboard with a checklist (three items checked in red, two unchecked) overlapping a large magnifying glass in the lower-right. The lens contains a green-style found-checkmark, and three sparkle dots accent the composition.

| Element | Value |
|---|---|
| Tag label | `HIGH VALUE` |
| Headline | Stay ahead of every property inspection |
| Body | Assign inspection support tasks to reliable professionals. Get real-time updates so you're never caught off guard. |

---

**Slide 3 — Messaging**

*Illustration:* `illustration-messaging.svg`
Two chat bubbles — an agent bubble (dark, left-aligned) and a runner bubble (red-tinted, right-aligned) — connected by a dashed red line. A typing indicator appears below the agent bubble. Double-check read-receipt appears below the runner bubble.

| Element | Value |
|---|---|
| Tag label | `BUILT IN` |
| Headline | Direct line to your task runner |
| Body | Chat with your assigned runner in real time. Coordinate details, share updates, and confirm completion — all in one thread. |

---

**Slide 4 — Profile & Trust**

*Illustration:* `illustration-profile.svg`
A profile card with a stylized avatar, a red verified badge, name and brokerage bars, a stats row (tasks, rating, reviews), a divider, and four filled / one empty star rating. The card has a subtle red-tinted header band.

| Element | Value |
|---|---|
| Tag label | `TRUST LAYER` |
| Headline | Build your reputation on every task |
| Body | Ratings and reviews follow every completed job. A strong profile means more trust, better runners, and faster assignments. |

---

**Carousel Design Tokens**

| Property | Value |
|---|---|
| Card background | `#0F1923` |
| Card border | `rgba(255,255,255,0.06)`, 1px |
| Card border-radius | `26px` |
| Illustration area height | `178px` |
| Tag background | `rgba(232,49,74,0.12)` |
| Tag border | `rgba(232,49,74,0.2)`, 1px |
| Tag text | `#E8314A`, 10px, 700 weight, all-caps, 1px letter-spacing |
| Headline | `#FFFFFF`, 22px, 700 weight, −0.7px letter-spacing |
| Body | `rgba(255,255,255,0.52)`, 13px, 400 weight, 1.6 line-height |
| Progress bar | `#E8314A`, 2px height, 70% opacity |
| Active dot | `#E8314A`, 18×6px pill |
| Inactive dot | `rgba(255,255,255,0.18)`, 6×6px circle |
| Auto-advance interval | 4,500ms |
| Transition | Fade + 24px horizontal translate, 320ms ease |

**Illustration Asset References**

All four illustrations are exported as standalone SVGs at 220×180px viewBox. They use the app design system palette (`#E8314A` accent, `#1C2A3A`/`#0D1B2A` darks, `#2D4A68` mid fills) and contain no text other than the "LIVE" badge in Slide 1.

| Slide | Asset filename |
|---|---|
| Showings | `illustration-showing.svg` |
| Inspections | `illustration-inspection.svg` |
| Messaging | `illustration-messaging.svg` |
| Profile & Trust | `illustration-profile.svg` |

#### 6.1.3 Create Account (Step 1 of 3)
- Back arrow (top-left) → returns to Landing
- Header: "Step 1 of 3" (red, 14px) + "Create your account" (H1) + "Let's start with the basics." (subtitle)
- 3-segment progress bar (first segment filled red)
- Form fields:
  - **Full Name** — text input, required, validates non-empty
  - **Email Address** — email input, required, validates email format
  - **Phone Number** — tel input, required, validates US phone format with auto-formatting
- "Continue" button (primary, full-width) at bottom
- Legal text below button: "By continuing, you agree to our Terms of Service and Privacy Policy" (linked in red)
- All fields auto-save on blur (no work lost if user backgrounds the app)

#### 6.1.4 Set Password (Step 2 of 3)
- Back arrow → returns to Step 1 (preserves field data)
- Header: "Step 2 of 3" + "Set your password"
- 3-segment progress bar (two segments filled)
- Form fields:
  - **Password** — password input with show/hide toggle (eye icon), required
  - **Confirm Password** — password input, must match
- Password requirements checklist (inline, below fields):
  - At least 8 characters
  - One uppercase letter
  - One number or symbol
  - Each requirement shows a check circle; filled green when met, light gray when unmet
- "Create Account" button (primary, full-width)
- On tap: creates account in backend, sends verification email, advances to Step 3

#### 6.1.5 Verify Email (Step 3 of 3)
- Back arrow → returns to Step 2
- Header: "Step 3 of 3" + "Verify your email"
- Subtitle: "We sent a 6-digit code to **you@example.com**" (dynamic, uses entered email)
- 3-segment progress bar (all segments filled)
- 6-digit OTP input: 6 individual boxes (48×56px, rounded corners), auto-advance on digit entry, first box focused with red border + glow
- "Didn't receive a code? **Resend**" text link (rate-limited: 60-second cooldown)
- "Verify & Continue" button (primary, full-width)
- On success: advances to Welcome screen
- On failure (3 incorrect attempts): shows error toast, offers "Resend" again
- **Alternative:** Phone verification via SMS OTP (same UI, different header text). Backend determines which channel based on user's primary contact.

#### 6.1.6 Log In Screen
- Back arrow → returns to Landing
- Header: "Welcome back" (H1) + "Log in to your account" (subtitle)
- Form fields:
  - **Email Address** — email input
  - **Password** — password input with show/hide toggle
- "Log In" button (primary, full-width)
- Text link below: "Forgot your password?" → navigates to password reset flow (sends email)
- Text link below: "Don't have an account? **Sign Up**" → returns to Landing
- On success: navigates to Dashboard (role determined by account)
- **Prototype behavior:** Tapping "Log In" on Landing skips to Dashboard as agent

### 6.2 Welcome Screen (Post-Verification, Pre-Dashboard)

Shown once after account verification. Role-specific value props introduce the platform.

#### Agent Welcome
- Icon: briefcase in red-glow circle
- Heading: "Welcome, [First Name]!"
- Subtitle: "Here's how Agent Flo works for you"
- 3 value prop rows (icon + title + description):
  1. ✚ **Post Tasks in Seconds** — "Photography, showings, staging — describe what you need and set your price."
  2. ✓ **Vetted Runners Only** — "Every task runner is a licensed real estate professional, verified on the platform."
  3. 🛡 **Secure Payments** — "Funds are held in escrow until you approve the work. Pay with confidence."
- CTA: "Post Your First Task" (primary, full-width) → First Task Creation (6.2.5)
- Skip link: "Skip for now →" → Dashboard (bypasses task creation)

#### Runner Welcome
- Icon: trending arrow in red-glow circle
- Heading: "Welcome, [First Name]!"
- Subtitle: "Here's what you can do as a Task Runner"
- 3 value prop rows:
  1. 💲 **Earn on Your Schedule** — "Pick up tasks that fit your availability and specialties. Get paid weekly."
  2. 📍 **Tasks Near You** — "See available tasks in your service areas with real-time distance and payout info."
  3. 📈 **Build Your Reputation** — "Earn ratings and unlock priority access to higher-paying tasks over time."
- CTA: "Find Available Tasks" (primary, full-width) → Dashboard
- Subtitle: "You can complete your profile anytime"

#### 6.2.5 First Task Creation (Agent Only, During Onboarding)

After the Welcome screen, agents are invited to create their first task inline — before entering the Dashboard. This gives agents an immediate sense of accomplishment and increases the likelihood of completing the full posting flow.

**Step 1: Category Selection**
- Back arrow → Welcome screen
- "Skip" link (top-right, red text) → Dashboard (auto-saves any partial data as draft)
- Header: "Post your first task" + "What do you need help with?"
- Five category cards: Photography, Showing, Staging, Open House, Inspections (same layout as Task Creation Sheet 12.7)
- Footer: "You can also do this later from your Dashboard"

**Step 2: Task Details Form**
- Back arrow → Category Selection (preserves selection)
- "Skip" link (top-right) → if any field has data, auto-saves as draft with "Draft Saved!" confirmation → Dashboard; if no data, navigates to Dashboard directly
- Category icon + name as header
- Progress bar: 2 of 3 segments filled
- Fields:
  - Property Address — text input
  - Date & Time — date/time picker placeholder
  - Your Price — numeric input with dollar icon, avg. price hint below
  - Special Instructions — multiline text input
- Two buttons:
  - "Save Draft" (secondary) → shows "Draft Saved!" confirmation screen (green check icon + message "You'll find it on your Dashboard") → auto-navigates to Dashboard after 1.2 seconds
  - "Post Task" (primary) → posts task and navigates to Dashboard
- Auto-save indicator: check icon + "Auto-saving your progress"

**Auto-Save Behavior:**
- If the user taps "Skip" at any point during task creation, any partial data (selected category, filled fields) is automatically saved as a draft
- Draft appears on the Agent Dashboard as a task card with "Draft" status badge
- The "Draft Saved!" confirmation screen is shown only when there is data to save; otherwise, the user is taken directly to the Dashboard

### 6.3 Post-Auth: Progressive Onboarding

Once in the app, onboarding continues via the **profile completion card** on the Dashboard (not a separate flow). This card tracks remaining setup steps and gates key actions.

#### Agent Steps (6 total)
1. **Add profile photo** → opens photo picker (Camera or Photo Library)
2. **Enter brokerage** → navigates to Personal Information, focuses brokerage field
3. **Verify your license** → inline form: license number + state selector. Displays "Verification" badge. Submits to admin queue. ← vetting
4. **Upload photo ID** → camera capture or photo library. Image sent to admin for review. ← vetting
5. **Set up payment method** → opens Stripe Elements sheet (Add Payment Method)
6. **Post your first task** → opens Task Creation Sheet

#### Runner Steps (7 total)
1. **Add profile photo** → opens photo picker
2. **Enter brokerage** → navigates to Personal Information
3. **Verify your license** → same inline form as agent ← vetting
4. **Upload photo ID** → camera capture or photo library ← vetting
5. **Set up payout account** → opens Stripe Connect onboarding (hosted)
6. **Configure service areas** → navigates to Service Areas screen
7. **Set availability** → navigates to Availability screen

#### Card Behavior
- Dashboard displays a navy gradient card with: title ("Complete your profile"), progress ("3 of 6"), progress bar, and remaining step pills
- Tapping a step pill navigates to the relevant screen or opens an inline form
- Steps that require vetting display a small "Verification" badge on the pill
- **Dismissable:** × button hides the card for the current session
- **Reappears** on next session if steps remain incomplete
- **Disappears permanently** once all steps are complete

#### Gating Rules
- **Agent:** Cannot post a task (only save drafts) until vetting status = `approved` AND payment method is added
- **Runner:** Cannot apply to a task until vetting status = `approved` AND payout account is added AND at least one service area is configured
- Attempting a gated action shows an inline banner: "Complete your profile to [post tasks / apply to tasks]" with a "Complete Now" link

### 6.4 Key Principles
- Onboarding can stop at any point and resume later
- All progress is saved; no work is lost (auto-save on every field blur and step transition)
- Agents and runners can enter the app and explore without full commitment — browsing the dashboard, viewing task details, and reading notifications require no profile completion
- The progressive onboarding card is the single source of truth for what's left to do; there is no separate "onboarding wizard" after account creation

---

## 7. Core Flows

### Task Posting (Agent)
1. Agent taps "Create Task" on Dashboard (or + in nav bar)
2. **Sheet/modal slides up from bottom** with drag handle and × dismiss button
3. Agent selects category (Photography, Showings, Staging, Open House, Inspections)
4. Sheet transitions to form wizard (internal state change, not navigation push)
5. Agent enters description, location, price, and any special instructions
6. If payment source exists → task posts immediately
7. If no payment source → task remains in `draft` state
8. All fields auto-save throughout the flow
9. Dismissing the sheet (× or swipe down) preserves the draft

### Task Application & Assignment
1. Task runner browses available tasks via search/filter on Dashboard
2. Task runner taps a task to view details
3. Task runner applies to the task (optional note)
4. Application is inserted with `pending` status (`task_id`, `runner_id` unique)
5. Agent receives a notification that a new runner applied
6. Agent reviews applicants and selects one
7. Atomic server-side write accepts the selected application, assigns `runner_id`, and declines remaining pending applications

### Task Completion
1. Task runner completes the work on-site
2. Task runner submits deliverables through the app (photos, confirmations)
3. Task completion is defined by deliverable submission, not communication
4. Agent reviews deliverables
5. If satisfied → payment is released
6. If not satisfied → dispute flow (see Edge Cases)

### Messaging
- Per-task chat available for clarification
- Optional, not required for task completion
- Functions like comments on a social media post
- Accessible from task detail view

### In-App Notifications

Notifications are generated server-side by a PostgreSQL trigger (`trg_task_status_notify`) that fires `AFTER UPDATE OF status ON tasks`. The trigger function `notify_task_status_change()` runs as `SECURITY DEFINER` to bypass RLS and insert into the `notifications` table.
The remote `notifications` table is the source of truth for notification history and read state; push delivery is a downstream fan-out channel.

**Both-Party Notification Model:** Every status change notifies both the agent and runner (where applicable):

| Status Change | Agent Notification | Runner Notification |
|---|---|---|
| `accepted` | "Runner Assigned" — "[runner] was assigned to your [category] task at [address]" | "You're Assigned" — "You were selected for the [category] task at [address]" |
| `in_progress` | "Task In Progress" — "[runner] started working on [address]" | — |
| `deliverables_submitted` | "Deliverables Ready" — "[runner] submitted deliverables for [address]" | — |
| `completed` | "Task Completed" — "[category] task at [address] has been completed." | "Payment Released" — "Payment released for [address]. Included in your next Friday payout batch." |
| `cancelled` | "Task Cancelled" — "Your [category] task at [address] has been cancelled." | "Task Cancelled" — "The [category] task at [address] was cancelled." |

**Client Behavior:**
- Notifications load on tab appearance and refresh on each subsequent `onAppear`
- Pull-to-refresh support on the notification list
- Tapping a notification marks it as read (updates `read_at` timestamp via Supabase) and navigates to the target screen
- `isRead` is a computed property derived from `readAt != nil` — mutations update `readAt`, not a boolean flag
- Notification data payload includes `task_id` and `screen` for deep link resolution

---

## 8. Edge Cases & Failure Modes

### Cancellations
- Agent cancels within 24 hours of runner assignment (`status = accepted`) → runner receives cancellation fee: 20% of task price (min $15). If canceled within 2 hours of start time → 50% (min $25).
- Agent cancels before any runner is assigned → no fee, task is removed
- Worker cancels → task returns to available pool, agent is notified

### Simultaneous Assignment (Race Condition)
- Agent assignment uses atomic server-side updates against `tasks` + `task_applications`
- Only one pending application can be accepted for a given task; concurrent assignment attempts fail with conflict
- Losing operation receives a clear conflict response (for example: "This task is no longer available for assignment")

### Quality Disputes (Photography)
- Deliverables are shown to agents as watermarked previews or low-resolution until payment is confirmed
- Prevents agents from keeping work without paying
- Basic technical validation (codeable, iteration 1): minimum resolution, minimum file size, submitted within defined timeframe
- If agent disputes quality → one revision request allowed
- If agent disputes after revision → escalated to human reviewer (manual, founder handles initially)
- Future iteration: AI-powered image analysis for quality, composition, spacing

### Draft Preservation
- All multi-step flows auto-save as drafts
- If a user navigates away mid-task creation, the draft is saved
- User resumes from exactly where they left off
- Drafts appear on Dashboard in "pending" state

### Payment Gating
- Tasks cannot be posted (made visible to runners) without a payment source
- Tasks without payment source save as drafts
- Agent is prompted to set up payment when attempting to post

---

## 9. Payments

### Agent Side — Payment Source (Implemented)
- Payment source required before posting tasks
- Uses **Stripe SetupIntent** flow to save a payment method without an immediate charge
- `create-setup-intent` edge function: creates Stripe Customer (if needed), creates SetupIntent, returns `{ setupIntent, ephemeralKey, customer, publishableKey }`
- iOS uses `StripePaymentSheet` SDK — `PaymentSheet(setupIntentClientSecret:configuration:)` presents the native Stripe UI
- On task posting: a Stripe PaymentIntent is created with `capture_method: manual` (authorized but not captured)
- On task approval: the PaymentIntent is captured via `approve-and-pay` edge function, releasing funds
- Payment held in escrow upon task acceptance (authorized but not captured)
- All edge function calls go through `TaskService.authHeaders()` which refreshes the JWT session before each call to prevent 401 errors

### Task Runner Side — Payout Destination (Implemented)
- Uses **Stripe Connect Express** accounts for runner payouts
- `create-connect-link` edge function: creates Stripe Connect account (if needed), generates hosted onboarding link with `agentflo://stripe-connect` return URL
- Runner completes Stripe Connect onboarding in an external browser
- On return via `agentflo://` URL scheme, the app refreshes the user profile and navigates to Payout Settings
- Earnings visible on Dashboard
- Cancellation fees credited automatically

### Revenue Model
- Platform takes a percentage of each transaction (default 12%, configurable 10–15% via admin settings).
- Fee fields: `platform_fee` and `runner_payout` calculated on task acceptance (`runner_payout = price - platform_fee`)
- Must cover infrastructure costs to maintain break-even constraint

### Edge Function Auth Pattern
All Supabase edge functions require a fresh JWT token. The iOS `TaskService` implements a centralized `authHeaders()` method that calls `supabase.auth.refreshSession()` before every edge function invocation. This prevents stale token 401 errors. All edge function calls must route through `TaskService`, never call `supabase.functions.invoke()` directly from views.

### CORS Policy
All edge functions include CORS headers and handle `OPTIONS` preflight requests. Development may use wildcard origins; launch/production must restrict `Access-Control-Allow-Origin` to approved app origins per Section 15.2.

---

## 10. Iteration Roadmap

### Iteration 1 — Core Marketplace (MVP)
- Agent task posting (Photography, Showings, Staging, Open House, Inspections)
- Task runner application, agent assignment, and completion
- Basic deliverable submission and review
- Draft auto-save across all flows
- Progressive onboarding with vetting (Section 10.1)
- Per-task messaging (text only)
- Basic push notifications (standard iOS/Android alerts)
- Manual identity and license vetting via admin interface (Section 10.1)
- **Architecture:** Server-driven category config, pricing strategy protocol, discovery provider abstraction — see Section 14
- **Security baseline:** Rate limiting, input validation, admin auth with MFA, file upload security, RLS policies, audit logging — see Section 15.2
- **Accessibility baseline:** WCAG 2.1 AA color contrast, 44pt touch targets, VoiceOver/TalkBack screen reader support, keyboard navigation (web), form error announcements — see Section 16.2
- **Testing:** Unit tests on all business logic (validation, state machines, pricing, matching) at 80% coverage; integration tests on auth flow, task lifecycle, RLS policies, rate limiting; UI automation on all 8 critical user journeys; CI pipeline: unit on commit, integration on PR merge, UI nightly — see Section 17

### Iteration 2 — Payments & Trust
- Stripe Connect integration for both payment source (agent) and payout destination (runner) — see Section 10.2
- Escrow: funds held on task acceptance, released on agent approval
- Payout schedule: weekly ACH to runner's connected bank account via Stripe
- Agent and task runner rating system (post-task, Lyft-style: 5-star + structured tag feedback + optional text; see Section 12.17 Reviews Tab)
- Cancellation fee enforcement (percentage-based, configurable per market)
- MFA via SMS OTP for all accounts — see Section 10.3
- **Security:** Account lockout, password policy enforcement, third-party pentest, dependency scanning, CSP headers, photo ID encryption + auto-deletion — see Section 15.2
- **Accessibility:** Dynamic Type / font scaling support, `prefers-reduced-motion` support, Voice Control compatibility — see Section 16.2
- **Testing:** Unit tests for payment calculations (escrow, fees, payouts, cancellation), MFA validation, rating aggregation (target 800+); integration tests for Stripe lifecycle, MFA flow, rating submission; UI automation for secondary journeys (filter, draft, profile completion, payment setup); visual regression screenshots — see Section 17

### Iteration 3 — Notifications & Real-Time
- Rich push notifications with media and custom actions — see Section 10.4
  - Runner: "Apply" / "Snooze" actions on new task notifications
  - Agent: "Review Applicant" action when a runner applies
  - Delivery receipt thumbnail in deliverable notifications
- Proximity-based runner alerts — see Section 10.5
  - Alert nearby runners when a new task matches their specialties or typical task history
  - Configurable alert radius per runner (linked to Service Areas)
  - Frequency cap: max 3 proximity alerts per runner per hour
- Lock screen and Live Activity widgets for task progress — see Section 10.6
  - Agent: real-time task status (posted → accepted → in progress → deliverables submitted → complete)
  - Runner: active task countdown, next steps, payout amount
  - Modeled after Uber/Lyft ride tracking and Panera order progress
- **Security:** TOTP authenticator app, API key rotation, anomaly detection, device fingerprinting — see Section 15.2
- **Testing:** Unit tests for proximity matching, notification template rendering, Live Activity payloads (target 1000+); integration tests for proximity alert pipeline, rich notification delivery, real-time chat; UI automation for Live Activity widgets, notification actions; load testing at 100 agents + 500 runners; API contract testing — see Section 17

### Iteration 4 — Intelligence & Quality
- AI-powered image quality analysis for photography deliverables
- AI-assisted task description writing (voice input, suggestions)
- Dynamic, server-driven task categories per market
- Smart pricing recommendations based on market data and task complexity
- Automated license verification via third-party API (replaces manual vetting)
- **Accessibility:** Cognitive accessibility audit, reading level audit, localization foundation (string externalization, RTL support) — see Section 16.2
- **Testing:** Unit tests for AI result parsing, smart pricing models, dynamic category resolution; integration tests for AI service + license verification API; chaos testing for third-party service failures (Stripe down, AI timeout); localization string rendering + RTL spot checks — see Section 17

### Iteration 5 — Analytics & Scale
- Agent and task runner analytics dashboards
- Market demand signals to promote task categories by region
- Expand to additional cities
- Real-time matching as liquidity increases
- Video call vetting for non-licensed task runners (expanded runner pool)
- **Security:** Passkey/biometric auth (FIDO2), SOC 2 Type II preparation, data residency, incident response plan — see Section 15.2
- **Testing:** Load testing at 1000 concurrent users across 5 markets (p99 < 2s); automated OWASP ZAP scans + input fuzzing; Android automation (Espresso) + iPad coverage; synthetic monitoring on critical journeys in production every 5 minutes — see Section 17

---

### 10.1 Vetting Framework

Both agents and runners must be vetted before gaining full platform access. Vetting is integrated into the Progressive Onboarding flow (Section 6) as a required step before posting tasks (agents) or applying to tasks (runners).

#### Vetting Steps — Agent
1. **Real estate license lookup** — Agent enters their license number and state
2. **Brokerage verification** — Agent searches for and selects their brokerage (see data sources below)
3. **Identity confirmation** — Photo ID upload matched against profile name
4. **Admin review** — Manual review in admin interface; approved/rejected within 24 hours

#### Vetting Steps — Runner
1. **Real estate license lookup** — Runner enters their license number and state (same flow as agent)
2. **Brokerage verification** — Runner searches for and selects their brokerage
3. **Identity confirmation** — Photo ID upload matched against profile name
4. **Background check consent** — Runner consents to background screening (provider: Checkr in v1, behind a `BackgroundCheckProvider` interface).
5. **Admin review** — Manual review in admin interface; approved/rejected within 24 hours

#### License & Brokerage Search — Data Sources
The license lookup and brokerage search are powered by the following, evaluated in order of feasibility:

**Option A: ARELLO API (preferred)**
ARELLO (Association of Real Estate License Law Officials) maintains a national database of real estate licensees. Their Licensee Search API enables lookup by name, license number, or state. This would power both the license verification and brokerage association.

**Option B: State-specific APIs**
Each state's Real Estate Commission publishes licensee databases. For MVP launch markets:
- Texas: TREC license lookup (trec.texas.gov) — public, scrapeable, no official API
- Virginia: DPOR license search (dpor.virginia.gov) — public lookup

Integration approach: build a scraper/adapter per state for MVP; migrate to ARELLO or a third-party verification service (e.g., Evident, Cobalt Intelligence) in Iteration 4.

**Option C: Manual entry + admin verification (MVP fallback)**
User enters license number, state, and brokerage name as free text. Admin verifies manually against state databases. This is the simplest MVP path and can be enhanced incrementally.

**Brokerage search:** For MVP, brokerage is a free-text field with optional autocomplete powered by a static list of the top 200 brokerages per launch market. In future iterations, integrate with Realogy/Anywhere, Keller Williams, or MLS board APIs for a comprehensive brokerage directory.

#### Vetting States
- `not_started` — user has not begun vetting
- `pending` — user has submitted information, awaiting admin review
- `approved` — user has been verified; full platform access granted
- `rejected` — user has been denied; shown rejection reason and support contact
- `expired` — license has expired; user must re-verify (checked annually)

#### Admin Vetting Interface (MVP)
A minimal web-based admin tool (not in the mobile app) where the operator can:
- View pending vetting requests sorted by submission date
- See submitted documents: license number, state, brokerage, photo ID
- Cross-reference against state license lookup (external link)
- Approve or reject with a reason
- View all users by vetting status
- Revoke previously approved users if needed

#### Profile Completion Integration
Vetting is embedded in the progressive onboarding card. Updated step inventories:

**Agent onboarding steps (6 total):**
1. Add profile photo
2. Enter brokerage name
3. Submit real estate license for verification ← **vetting**
4. Upload photo ID ← **vetting**
5. Set up payment method (Stripe)
6. Post your first task

**Runner onboarding steps (7 total):**
1. Add profile photo
2. Enter brokerage name
3. Submit real estate license for verification ← **vetting**
4. Upload photo ID ← **vetting**
5. Set up payout account (Stripe Connect)
6. Configure service areas
7. Set availability and categories

Tasks cannot be posted (agent) or applied to (runner) until vetting status = `approved`. Draft creation and app exploration are permitted in all vetting states.

---

### 10.2 Stripe Payment Architecture (Implemented)

#### Agent — Payment Source
- Integration: **Stripe SetupIntent** via `StripePaymentSheet` iOS SDK
- `create-setup-intent` edge function handles Stripe Customer creation (idempotent) + SetupIntent + ephemeral key generation
- Cards are tokenized client-side via Stripe's native PaymentSheet; no raw card data touches the Agent Flo backend
- On task posting: a Stripe PaymentIntent is created with `capture_method: manual` (authorized but not captured) via `post-task` edge function
- On task approval: the PaymentIntent is captured via `approve-and-pay` edge function, releasing funds
- On cancellation: the PaymentIntent is cancelled (no charge) or partially captured (cancellation fee) via `cancel-task` edge function

#### Runner — Payout Destination
- Integration: **Stripe Connect Express** accounts
- `create-connect-link` edge function creates a Stripe Connect Express account (if needed) and generates a hosted onboarding URL
- Return URL: `agentflo://stripe-connect` — triggers profile refresh and navigation to Payout Settings
- Runner completes Stripe Connect onboarding in Safari (external browser)
- On task completion + agent approval: platform transfers payout to runner's connected account
- Payout schedule: weekly batch (every Friday for tasks completed through prior Sunday)
- Platform fee: deducted before payout (default 12%, configurable 10–15% via admin settings).

#### Implementation Details
- All Stripe edge function calls route through `TaskService.authHeaders()` to ensure fresh JWT tokens
- `stripe_customer_id` stored on `users` table for agents; `stripe_connect_id` stored for runners
- Edge functions use `SUPABASE_SERVICE_ROLE_KEY` for writing to the `users` table (bypasses RLS)
- Stripe API version: `2023-10-16`

#### Future: Instant Payouts
Stripe Connect supports instant payouts to debit cards. Planned for Iteration 5 as a premium feature (small fee per instant payout).

---

### 10.3 Multi-Factor Authentication

MFA is introduced in Iteration 2 as an optional security enhancement, becoming mandatory for admin accounts.

#### Implementation Plan
- **Method:** SMS OTP (6-digit code, 60-second expiry, 3 retry limit)
- **Trigger:** Login from a new device, sensitive account changes (email, password, payout account)
- **Setup flow:** Profile → Account & Security → Two-Factor Authentication → enter phone number → receive OTP → confirm → enabled
- **Recovery:** Backup codes generated on setup (8 single-use codes); account recovery via support email if codes are lost
- **Future:** Add authenticator app support (TOTP) in Iteration 4; add passkey/biometric support in Iteration 5

---

### 10.4 Rich Push Notifications

Rich notifications extend standard push with media attachments and custom action buttons.

#### Runner Notification Actions

| Notification Type | Media | Action 1 | Action 2 |
|---|---|---|---|
| New Task Available | Map thumbnail of task location | **Apply** (opens task detail) | **Snooze 1hr** (suppresses re-alert) |
| Task Assigned | Agent's profile photo | **View Task** | **Message Agent** |
| Revision Requested | Deliverable thumbnail | **View Revisions** | — |

#### Agent Notification Actions

| Notification Type | Media | Action 1 | Action 2 |
|---|---|---|---|
| Runner Applied | Runner's profile photo | **Review Applicant** (opens task applicants) | **View Profile** |
| Deliverables Ready | First deliverable thumbnail | **Review** (opens review screen) | — |
| Payment Processed | — | **View Receipt** | — |

#### Technical Approach
- iOS: UNNotificationServiceExtension for media attachments + UNNotificationContentExtension for custom UI
- Android: Rich notification with BigPictureStyle + action buttons via PendingIntent
- Backend: Firebase Cloud Messaging (FCM) or APNs with payload containing `mutable-content: 1` and media URL

---

### 10.5 Proximity-Based Runner Alerts

A background service that matches newly posted tasks against nearby runners based on location, preferences, and history.

#### Matching Criteria
1. **Location:** Runner's current location or center of active service areas within the task's area
2. **Category match:** Task type matches runner's enabled categories (from Availability settings)
3. **Historical affinity:** Runner has completed 2+ tasks of this type (weighted boost)
4. **Availability:** Runner's schedule shows them as available at the task's scheduled time
5. **Capacity:** Runner has fewer than 3 active tasks (prevents overload)

#### Alert Behavior
- Delivered as a rich push notification (Section 10.4) with map thumbnail
- Frequency cap: max 3 proximity alerts per runner per hour
- Cooldown: if runner snoozes, suppress alerts for that task category for 1 hour
- Runner can disable proximity alerts entirely in Notification Settings

#### Technical Approach
- iOS: Background location updates (significant location change) + server-side geofence matching
- Server: PostGIS spatial queries against runner locations + task addresses; evaluated on new task creation
- Privacy: Location is only used for matching; never exposed to agents; runner controls granularity

---

### 10.6 Lock Screen & Live Activity Widgets

Live Activities (iOS) and ongoing notifications (Android) provide at-a-glance task progress without opening the app.

#### Agent — Task Progress Widget

Displays the lifecycle of the agent's most recent active task:

```
┌──────────────────────────────────────┐
│  📸 Photography · 4521 Riverside Dr  │
│  ● Posted → ● Accepted → ○ In Prog  │
│  Runner: Maria Santos · ETA 2:00 PM  │
└──────────────────────────────────────┘
```

**States displayed:**
Posted → Accepted → In Progress → Deliverables Submitted → Review → Complete

**Update triggers:** Task status changes push ActivityKit updates (iOS) or notification channel updates (Android).

#### Runner — Active Task Widget

Displays the runner's currently active task with countdown and next action:

```
┌──────────────────────────────────────┐
│  🏠 Showing · 812 Congress Ave       │
│  Starts in 1h 30m · $75 payout      │
│  [Get Directions]  [Mark Complete]   │
└──────────────────────────────────────┘
```

**Dynamic elements:** Countdown timer, payout amount, quick-action buttons

#### Technical Approach
- iOS: ActivityKit (iOS 16.1+) with `ActivityConfiguration` for each widget type
- Android: Ongoing notification with custom layout + Foreground Service for timer updates
- Widget Design: Follows iOS 26 Liquid Glass material; uses the Agent Flo color palette (red accent on dark background)
- Updates: Push-triggered via APNs (priority: `.timeSensitive`) or FCM high-priority messages

---

## 11. Design System Spec

### 11.1 Design Principles

Evaluated in priority order. When principles conflict, higher-ranked principles win.

1. **Clarity Over Cleverness** — Every screen communicates its purpose within two seconds. Labels say exactly what they mean. Icons always have text companions in navigation contexts.
2. **Trust Through Transparency** — Every state is visible: where a task stands, who accepted it, what the deliverables look like, how much they're paying. No hidden flows.
3. **Efficiency Through Async** — Post a task and walk away. Accept a task from your car. Review deliverables at midnight. Messaging is optional, never required.
4. **Progressive Disclosure** — Show only what's needed for the current decision. Complexity is always available but never forced.

### 11.2 Visual Tokens

#### Color Palette

Derived from Rocket Mortgage brand identity. All text colors meet WCAG 2.1 AA contrast ratios.

**Primary**

| Token | Hex | Usage |
|---|---|---|
| `red` | `#C8102E` | Primary CTAs, active tab icons/labels |
| `red-hover` | `#A00D24` | Hover/pressed state on primary buttons |
| `red-light` | `#FDE8EC` | Category icon backgrounds, subtle accents |
| `red-glow` | `rgba(200,16,46,0.15)` | Focus rings, unread notification card backgrounds |

**Neutrals**

| Token | Hex | Usage |
|---|---|---|
| `navy` | `#0A1628` | Primary text, headings, dynamic island. Semantic color — flips to near-white in dark mode for text legibility. |
| `navy-solid` | Light: `#0A1628` / Dark: `#122039` | Dark-mode-safe background fill. Stays dark in both modes. Used for: onboarding card background, outgoing message bubbles, selected filter pills, selected tag chips, visitor avatar backgrounds. |
| `navy-light` | `#12203A` | Gradient start (onboarding/earnings cards) |
| `navy-mid` | `#1A2D4D` | Gradient end, H3 text |
| `slate` | `#64748B` | Body text, secondary icons |
| `slate-light` | `#94A3B8` | Placeholders, timestamps, captions |
| `border` | `#E2E8F0` | Card borders, dividers |
| `border-light` | `#F1F5F9` | Section backgrounds, skeleton loading |
| `bg` | `#F8FAFC` | App background |
| `white` | `#FFFFFF` | Card surfaces, button text |

**Semantic**

| Token | Hex | Usage |
|---|---|---|
| `green` | `#16A34A` | Success, completed status |
| `green-light` | `#DCFCE7` | Completed badge background |
| `amber` | `#D97706` | In-progress, warning |
| `amber-light` | `#FEF3C7` | In-progress badge background |
| `blue` | `#2563EB` | Posted status, informational |
| `blue-light` | `#DBEAFE` | Posted badge background |
| `error-red` | `#DC2626` | Error states, validation |
| `error-bg` | `#FEE2E2` | Error field background |

**Gradient**

```
linear-gradient(135deg, navy 0%, navy-mid 100%)
```
Used for: onboarding progress card (agent), earnings card (runner).

#### Typography Scale

Single typeface: **DM Sans** across all contexts. iOS fallback: SF Pro. Weights used: 400 (Regular), 500 (Medium), 600 (SemiBold), 700 (Bold), 800 (ExtraBold).

| Token | Size | Weight | Tracking | Usage |
|---|---|---|---|---|
| `display` | 26pt | 800 | -0.5 | Greeting name ("Daniel") |
| `title-lg` | 22pt | 800 | -0.5 | Detail headers, section titles |
| `title` | 17pt | 700 | 0 | Section headers ("Recent Tasks") |
| `body` | 15pt | 600 | 0 | Card type labels, emphasized body |
| `body-sm` | 14pt | 500 | 0 | Inputs, descriptions, menu items |
| `caption` | 13pt | 500 | 0 | Addresses, timestamps, descriptions |
| `caption-sm` | 12pt | 600 | 0.3 | Badges, footnotes, helper text |
| `micro` | 11pt | 600 | 0 | Tab bar labels (active state) |
| `price-lg` | 36pt | 800 | -1 | Task payout (detail view) |
| `price` | 32pt | 800 | -1 | Earnings summary |
| `price-sm` | 17pt | 800 | 0 | Inline task price |

#### Spacing System

4px base unit. All padding, margins, and gaps reference this scale.

| Token | Value | Common Usage |
|---|---|---|
| `2xs` | 2px | Tight inline gaps |
| `xs` | 4px | Icon-to-text gap (small) |
| `sm` | 6px | Step indicator gap |
| `md` | 8px | Badge padding, filter pill gap |
| `base` | 10px | Card grid gap |
| `lg` | 12px | Icon container padding |
| `xl` | 14px | Card content gap, list item padding |
| `2xl` | 16px | Card padding (compact), input padding |
| `3xl` | 20px | Screen horizontal padding, card padding (standard) |
| `4xl` | 24px | Vertical section gap, profile top padding |

**Layout Constants**

| Constant | Value |
|---|---|
| Screen horizontal padding | 20px |
| Vertical section gap | 24px |
| Tab bar floating inset | 16px from bottom, centered horizontally |
| Status bar height | 54px |
| Card padding (standard) | 20px |
| Card padding (compact) | 16px |
| Touch target minimum | 44px |

#### Shadows

Minimal elevation strategy. Cards use borders, not shadows. Only floating elements and modals cast shadows.

| Token | CSS Value | Usage |
|---|---|---|
| `none` | `none` | Cards, inputs (default) |
| `low` | `0 2px 8px rgba(10,22,40,0.06)` | Tooltips |
| `mid` | `0 8px 32px rgba(10,22,40,0.12)` | Liquid Glass tab bar, sheets |
| `high` | `0 25px 80px rgba(10,22,40,0.25)` | Phone frame (prototype only) |

**Liquid Glass Shadows (Tab Bar):**
```
0 0.5px 0 0 rgba(255,255,255,0.7) inset,
0 -0.5px 0 0 rgba(0,0,0,0.03) inset,
0 8px 32px rgba(10,22,40,0.12),
0 2px 8px rgba(10,22,40,0.06)
```

#### Border Radii

| Token | Value | Usage |
|---|---|---|
| `sm` | 3px | Progress bar tracks and fills |
| `md` | 8px | Small buttons (deprecated — see pill) |
| `base` | 10px | Status widgets, icon containers |
| `lg` | 12px | Input fields, search bars, category icons |
| `xl` | 14px | Cards, category icon containers (detail) |
| `pill` | 9999px | **All buttons**, filter pills, badges, tab bar capsule |
| `circle` | 50% | Avatars, dismiss buttons |

> **Design Decision:** All interactive buttons use full pill radius (`9999px`). This applies to primary, secondary, ghost, and small button variants. No rectangular or slightly-rounded buttons exist in the system.

### 11.3 Component Library

#### Buttons

Five variants. All use **pill radius (9999px)**. Minimum 44px touch target.

| Variant | Background | Text | Border | Padding | Font |
|---|---|---|---|---|---|
| `primary` | red | white | none | 12px 20px | 14/600 |
| `primary-lg` | red | white | none | 16px 28px | 16/600 |
| `secondary` | white | navy | 1.5px border | 12px 20px | 14/600 |
| `ghost` | transparent | slate | none | 8px 12px | 14/600 |
| `small` | red-light | red | none | 6px 14px | 13/600 |

**Button States:**
- **Default** — standard appearance
- **Hover** — `red-hover` background (primary variants); subtle background tint (secondary)
- **Pressed** — `scale(0.98)` transform
- **Disabled** — 50% opacity, `cursor: not-allowed`
- **Loading** — 16px spinner replaces text, white on primary

**Paired Buttons:** Secondary left, primary right — always. Equal flex width. 10px gap.

**Icon + Text:** Icons are 16–18px, 8px gap before text. Icon inherits button text color.

#### Cards

Five variants, all with 14px border-radius.

| Variant | Background | Border | Usage |
|---|---|---|---|
| Standard | white | 1px border | Task cards, settings rows |
| Gradient | navy → navy-mid | none | Onboarding progress, earnings summary |
| Accent | red-glow | 1.5px red-light | Task payout, price highlight |
| Muted | border-light | none | Special instructions, read-only content |
| Dashed | border-light | 1.5px dashed slate-light | Demo/dev-only elements |

**Task Card Anatomy:**
- 42px category icon container (12px radius, red-light background)
- Content area: row 1 = type label + status badge; row 2 = address; row 3 = time + price
- 14px gap between icon and content
- 16px padding (compact variant)

**Gradient Card — Dismissable Onboarding:**
- × dismiss button: 28px circle, top-right, `rgba(255,255,255,0.12)` background
- Progress bar: 6px track on `rgba(255,255,255,0.15)`, red fill
- Remaining step pills: `rgba(255,255,255,0.12)` background, 20px border-radius

#### Status Badges

Non-interactive, informational only. 12px font, 600 weight, pill shape, 0.3px letter-spacing.

| Status | Background | Text Color |
|---|---|---|
| Posted | blue-light | blue |
| In Progress | amber-light | amber |
| Completed | green-light | green |
| Draft | border-light | slate |
| Disputed | error-bg | error-red |
| Cancelled | border-light | slate-light |

#### Form Inputs

Four variants. 48px height, 12px radius, 1.5px border.

| Variant | Left Element | Placeholder Style |
|---|---|---|
| Text | 16px icon (slate-light) | 14pt/500 slate-light |
| Textarea | none | 14pt/500 slate-light, 80px min-height |
| Search | 18px search icon | 14pt/500 slate-light |
| Price | 16px dollar icon (red) | 22pt/800 navy (value) |

**Focus State:** `1.5px solid red` border + `0 0 0 3px red-glow` ring. Icon tints to red.

**Error State:** `1.5px solid error-red` border + `0 0 0 3px error-bg` ring. Helper text below in error-red, 12pt.

**Clear Button:** All non-secure text inputs display a clear button (`xmark.circle.fill`, `slate-light` color) on the trailing edge when the field is non-empty. Tapping clears the field value. The clear button does not appear on secure (password) fields.

**Helper Text:** 12pt caption, slate-light (default) or error-red (error). 6px top margin.

**Autocomplete Locking:** Fields with autocomplete suggestions (address, brokerage) implement a lock-after-selection pattern:
- When the user selects a suggestion from the dropdown, the field locks (becomes non-editable, `.disabled` appearance)
- A clear button (`xmark.circle.fill`) appears on the trailing edge to reset the field
- Tapping clear unlocks the field, clears the value, and re-enables autocomplete search
- The `onChange` handler is guarded by a lock flag to prevent re-triggering search when programmatically setting the value from a suggestion selection
- This prevents the autocomplete dropdown from reappearing after a selection is made

#### Navigation

**Liquid Glass Tab Bar (iOS 26)**

| Property | Value |
|---|---|
| Position | Absolute, bottom 16px, centered |
| Shape | Capsule (26px border-radius) |
| Background | `linear-gradient(180deg, rgba(255,255,255,0.75), rgba(245,247,250,0.6))` |
| Backdrop | `blur(40px) saturate(1.8)` |
| Border | `0.5px solid rgba(255,255,255,0.55)` |
| Padding | 5px |
| Active tab | Icon + label, tinted pill (`rgba(200,16,46,0.1)`), 8px 18px padding |
| Inactive tab | Icon only, `rgba(10,22,40,0.5)` color, 8px 14px padding |
| Active label | 10pt/700 red |
| Notification badge | 15px circle, red, white 9pt/700 count, 2px white border |
| Animation | `0.35s cubic-bezier(0.32, 0.72, 0, 1)` |

All three tab icons use standard SF Symbol equivalents: `house`, `bell`, `person`. No custom avatars or photos in the tab bar.

**Navigation Bar:**
- 54px height
- Back button: `chevron.left` SF Symbol, red, left-aligned
- Title: 17pt/700 navy, centered
- Right action: contextual icon (e.g., `plus` for create), red

**Sheet/Modal:**
- Slides up from bottom with `translateY(100%) → translateY(0)` animation
- `0.35s cubic-bezier(0.32, 0.72, 0, 1)` timing
- Backdrop: `rgba(10,22,40,0.45)` with `blur(4px)`
- Sheet: white background, `20px 20px 0 0` border-radius
- Drag handle: 36px × 5px, border color, centered, 3px radius
- × dismiss button: 30px circle, border-light background, centered × icon
- Max height: 92% of screen
- Tap backdrop to dismiss; swipe down to dismiss
- **No back button inside sheets** — internal navigation uses state, not stack

#### Icons

**Source:** SF Symbols (iOS native) / Lucide stroke equivalents (web)

**Style:** 1.5–2px stroke weight, round caps and joins.

**Category-to-Icon Mapping:**

| Category | SF Symbol | Lucide Equivalent |
|---|---|---|
| Photography | `camera` | camera |
| Showing | `eye` | eye |
| Staging | `shippingbox` | box |
| Open House | `house` | home |

**Notification-to-Icon Mapping:**

| Notification Type | Icon |
|---|---|
| Task Accepted | `checkmark` (check) |
| Deliverables Ready | `camera` |
| Payment Processed | `dollarsign` (dollar) |
| New Message | `paperplane` (send) |

> **Design Rule:** No emoji anywhere in the app. All iconography uses SF Symbols (iOS) or Lucide equivalents (web). This ensures consistent rendering, accessibility, and platform-native appearance.

**Icon Container Sizes:**

| Context | Container | Icon Size | Radius |
|---|---|---|---|
| Task list | 42px | 20px | 12px |
| Detail header | 48px | 24px | 14px |
| Info row | 36px | 16px | 10px |
| Notification | 40px | 18px | 12px |

#### Avatars

Reusable `AvatarView` component (`Theme/Components/AvatarView.swift`). Displays a user's photo if available, or falls back to a circle with initial.

**With image:** Circle-clipped, `scaledToFill`, sized to container.
**Without image (fallback):** Circle shape, `red-light` background, first initial of name in `red` text. Font size scales: `display` for 72px+, `bodyEmphasis` for 44px, `captionSM` for smaller.

| Context | Size |
|---|---|
| Profile screen | 72px |
| Header/inline (runner info on task detail) | 44px |
| Compact | 36px |

Avatar is used on the **Profile screen** and **Task Detail runner info section**. Not used on dashboards or in the tab bar. Runner avatars on Task Detail are loaded from Supabase Storage using the runner's `avatar_url` path.

#### Progress Indicators

**Progress Bar:**
- Track: 6px height, `rgba(255,255,255,0.15)` on dark backgrounds or `border-light` on white
- Fill: red, 3px border-radius
- Animation: `width 0.5s ease`

**Step Indicator (Wizard):**
- 3 bars (for 3-step wizard), 4px height, 6px gap
- Active/completed: red fill
- Remaining: border-light fill

**Spinners:**
- Button: 16px, 2px border
- Inline: 24px, 2.5px border
- Full-screen: 32px, 3px border
- Track: border-light, top-border: red
- Animation: `rotate 0.8s linear infinite`

**Skeleton Loading:**
- Shapes match content layout (rectangles for text, squares for icons)
- Color: border-light
- Animation: `opacity pulse 1.5s ease-in-out infinite` (1.0 → 0.4 → 1.0)
- Stagger: 0.1s delay per element

### 11.4 Interaction Patterns

#### Sheet Presentation
- Trigger: "Create Task" button or + nav bar icon
- Slides up from bottom of screen
- Drag handle at top for swipe-to-dismiss affordance
- × button (top-right circle) to dismiss
- Tapping the backdrop dismisses the sheet
- Auto-saves all form state on dismiss — draft preserved
- **No back button inside sheets.** Multi-step flows use internal state transitions.

#### Navigation Stack
- Right-slide push for drilling into content (task list → task detail)
- Left-slide pop to go back (back button or swipe-from-left-edge)
- Double-tap on tab pops to root of navigation stack
- Triple-tap scrolls to top if already at root

#### Tab Behavior
- Single tap switches tab
- Double tap pops navigation stack to root
- Triple tap scrolls to top
- Active tab: red icon + label with tinted pill background
- Inactive tab: semi-transparent icon only

#### Auto-Save
- Triggers: field blur or 1-second debounce after last keystroke
- Visual feedback: green checkmark + "Auto-saving your progress" caption
- Drafts preserved across app sessions
- Resume from exact point when returning to draft

#### Filter/Search (Runner Dashboard)
- Single-select filter pills (pill radius, secondary style by default, primary when active)
- Real-time search with 300ms debounce
- Empty state when no results match

### 11.5 Component States

#### Loading
- **Skeleton screens:** border-light shapes with pulse animation for initial loads
- **Inline spinners:** 16px red spinner for button loading, 24px for inline content
- **Full-screen loader:** 32px centered spinner (rare — prefer skeletons)

#### Empty States
- Per-screen illustrations using icon in a large container (64px, 20px radius, border-light background)
- Heading: 16pt/700 navy
- Description: 13pt/500 slate
- CTA: primary pill button
- Examples: "Post your first task" (agent), "No available tasks nearby" (runner), "No notifications yet"

#### Error States
- **Field validation:** red border + red focus ring + error helper text below
- **Network errors:** toast banner — red-light background, alert icon, error message, × to dismiss
- **Race conditions:** amber-light banner — alert icon, message ("This task is no longer available for assignment"), suggestion text

#### Success States
- **Brief animations:** green checkmark scale-in
- **Confirmation banners:** green-light background, checkmark circle, title + description
- **Auto-navigation:** after posting a task, return to dashboard after brief confirmation

### 11.6 Platform Implementation Notes

#### iOS (SwiftUI) — Current Implementation

- **Build target:** iOS 26, Xcode 26.2, Swift 5 language mode
- **Build destination:** `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2`
- **Development team:** 973RBN29J8, bundle ID: `app.agentflo`
- **Supabase project ref:** `giloreldlxdpqsvmqiqh`
- Register DM Sans via Info.plist; fall back to SF Pro
- Use `TabView` with standard `Tab(...)` API — **Liquid Glass applies automatically** when compiled with Xcode 26 SDK
- Tab icons use SF Symbols: `house`, `bell`, `person`
- `.tabBarMinimizeBehavior(.onScrollDown)` for scroll-to-compact behavior
- `NavigationStack` with type-safe routing and `navigationDestination`
- `.sheet()` with `PresentationDetent.large` for task creation
- Sheet dismissal via `.presentationDragIndicator(.visible)` + × button
- Color and Spacing tokens as `Color` and `CGFloat` extensions
- Haptic feedback: `.impact(.light)` on tab switch, `.impact(.medium)` on button press, `.notification(.success)` on task post
- Spring animations: `response: 0.35, dampingFraction: 0.85`
- All buttons: `.clipShape(Capsule())`
- **Scroll indicators hidden globally:** All `ScrollView` instances use `.scrollIndicators(.hidden)` — no visible scroll bars anywhere in the app
- **State management:** `@Observable` classes (`AppState`, `AuthService`, `TaskService`) with `@Environment` injection
- **Supabase Swift SDK v2:** `FunctionInvokeOptions` for edge function calls with `headers` and `body` params
- **MapKit integration:** `CLGeocoder` for address geocoding, `Map` view with `Marker` annotations
- **Stripe integration:** `StripePaymentSheet` SDK for SetupIntent flow, `STPAPIClient.shared.publishableKey` set from server response
- **URL scheme:** `agentflo://` registered in Info.plist via `CFBundleURLTypes`, handled by `onOpenURL` in `Agent FloApp.swift`
- **Time display:** Use `RelativeDateTimeFormatter` for static time-ago strings, not SwiftUI's live-ticking `Text(date, style: .relative)`

#### Web (React)

- Google Fonts import for DM Sans (400, 500, 600, 700, 800)
- Lucide React for all icons (no emoji)
- CSS custom properties for all design tokens
- URL-based routing with React Router
- Sheet/modal: portal-based with CSS `transform: translateY()` and backdrop
- Tab bar: `position: fixed; bottom: 16px` with backdrop-filter for glass effect
- Buttons: `border-radius: 9999px` globally
- Mobile-first layout, 480px max content width
- Desktop breakpoint at 768px: side navigation replaces bottom tabs
- CSS spring timing: `cubic-bezier(0.32, 0.72, 0, 1)` for iOS-like transitions

---

## 12. View Specifications

This section defines every screen in the app, its content, data requirements, and interactive behavior. Each view is listed with its role scope (Agent, Runner, or Both).

---

### 12.0 Onboarding Screens

**Role:** Both (unauthenticated)
**Navigation:** Standalone stack, no tab bar

#### 12.0.1 Splash Screen
- **Layout:** Centered vertically, white background, no navigation chrome
- **Content:**
  - App icon: 72×72px, red rounded square (20px radius), white "A" (36px, 800 weight), drop shadow `0 12px 32px rgba(200,16,46,0.3)`
  - Wordmark: "Agent Flo" — "Agent" in navy-800, "Assist" in red-600, 32px, 800 weight, -0.5 letter-spacing
  - Loading spinner: 32×32px, 3px border, `borderLight` base, `red` top, CSS `spin` animation 0.8s linear infinite
- **Behavior:** Auto-advances to Landing after ~2 seconds (or when auth check completes)
- **Dynamic island:** Rendered but no back button or title

#### 12.0.2 Landing Screen
- **Layout:** Flex column, logo/wordmark centered in `flex: 1` area, buttons anchored to bottom
- **Content — Upper (centered):**
  - Same icon + wordmark as Splash
  - Tagline: "Delegate tasks. Close deals." — 15px, `slate`, 6px below wordmark
- **Content — Lower (bottom-anchored, 32px padding-bottom):**
  - "I'm a Real Estate Agent" — primary red button, full-width, `lg` size → sets role to `agent`, advances to Create Account
  - "I'm a Task Runner" — secondary outlined button, full-width, `lg` size → sets role to `runner`, advances to Create Account
  - "Already have an account? **Log In**" — centered text, 14px, "Log In" in red-600 weight → navigates to Log In screen (or Dashboard in prototype)
- **Animations:** Buttons animate in with `fadeUp` (0→1 opacity, 20px→0 translateY, 0.5s ease)

#### 12.0.3 Create Account (Step 1 of 3)
- **Layout:** Full-height flex column, 24px horizontal padding
- **Header area:**
  - Back arrow (top-left, `navy` color) → returns to Landing
  - Step indicator: "Step 1 of 3" — 14px, red, 600 weight
  - Title: "Create your account" — 26px, 800 weight, navy
  - Subtitle: "Let's start with the basics." — 14px, slate
  - Progress bar: 3-segment, first segment red, 4px gap between segments
- **Form fields (18px gap):**
  - Full Name — text input, placeholder "Your full name"
  - Email Address — email input, placeholder "you@example.com"
  - Phone Number — tel input, placeholder "(512) 555-0000", auto-format on blur
- **Input styling:** full-width, 14px 16px padding, 1.5px `border` color border, 12px radius, 15px font
- **Bottom area (40px padding-bottom):**
  - "Continue" — primary button, full-width
  - Legal: "By continuing, you agree to our Terms of Service and Privacy Policy" — 12px, `slateLight`, links in red
- **Validation:** "Continue" disabled (0.5 opacity) until all three fields are non-empty and email validates
- **Auto-save:** field values persist if user navigates back and returns

#### 12.0.4 Set Password (Step 2 of 3)
- **Header:** Same structure as Step 1, "Step 2 of 3", "Set your password", progress bar 2/3 filled
- **Form fields:**
  - Password — password input, show/hide eye toggle (absolute positioned, right: 14px), placeholder "Minimum 8 characters"
  - Confirm Password — password input, placeholder "Re-enter your password"
- **Password requirements (below fields, 8px gap between items):**
  - "At least 8 characters" — check circle icon (18px, `borderLight` bg) + 13px text
  - "One uppercase letter"
  - "One number or symbol"
  - Icons switch from gray to green-filled when requirement is met (real-time validation as user types)
- **Bottom:** "Create Account" button — disabled until password meets all requirements AND confirmation matches
- **On submit:** Creates account in backend → sends verification code → advances to Step 3

#### 12.0.5 Verify Email (Step 3 of 3)
- **Header:** "Step 3 of 3", "Verify your email", progress bar 3/3 filled
- **Subtitle:** "We sent a 6-digit code to **{email}**" — email in navy bold
- **OTP input:** 6 individual boxes, 48×56px each, 12px radius, 2px border
  - First box has red border + red glow shadow (focused state)
  - On digit entry: auto-advance focus to next box
  - On paste: fills all 6 boxes from clipboard
- **Resend:** "Didn't receive a code? **Resend**" — 60-second cooldown, link disabled during cooldown with countdown text
- **Bottom:** "Verify & Continue" — disabled until all 6 digits entered
- **Error handling:** After 3 incorrect attempts: red error toast "Incorrect code. Please try again." + "Resend" link highlighted

#### 12.0.6 Welcome Screen
- **Layout:** Centered icon/text at top, value props in middle, CTA at bottom
- **Header:**
  - Role icon: 56×56px circle, `redLight` bg, briefcase (agent) or trending (runner) icon in red
  - "Welcome, {First Name}!" — 26px, 800 weight, navy
  - Role-specific subtitle (15px, slate)
- **Value props (3 rows, 16px gap):**
  - Each row: 44×44px icon circle (`redGlow` bg) + title (15px, 700 weight) + description (13px, slate, 1.5 line-height)
  - Agent props: Post Tasks in Seconds, Vetted Runners Only, Secure Payments
  - Runner props: Earn on Your Schedule, Tasks Near You, Build Your Reputation
- **Bottom:**
  - CTA: "Start Posting Tasks" (agent) or "Find Available Tasks" (runner) — primary, full-width
  - "You can complete your profile anytime" — 13px, slateLight, centered

#### 12.0.7 Log In Screen (not in prototype — placeholder)
- Back arrow → Landing
- "Welcome back" (H1) + "Log in to your account"
- Email input + Password input (with show/hide toggle)
- "Log In" primary button
- "Forgot your password?" link → password reset email flow
- "Don't have an account? **Sign Up**" → Landing
- **Prototype behavior:** "Log In" on Landing skips directly to Agent Dashboard

#### 12.0.8 First Task Creation — Category Selection (Agent Only)
- **Layout:** Full-height flex column, 24px horizontal padding
- **Header:**
  - Back arrow (top-left) → Welcome screen
  - "Skip" link (top-right, red, 14px/600 weight) → auto-saves draft if any data exists, then Dashboard
  - "Post your first task" (H1) + "What do you need help with?" (subtitle)
- **Category cards (4, stacked, 10px gap):**
  - Same layout as Task Creation Sheet (12.7): 48×48 icon circle + name + description + price range
  - Photography, Showing, Staging, Open House
  - Tapping a card advances to Task Details form
- **Footer:** "You can also do this later from your Dashboard" (12px, slateLight, centered)

#### 12.0.9 First Task Creation — Task Details (Agent Only)
- **Header:**
  - Back arrow → Category Selection (preserves category)
  - "Skip" link → auto-saves draft, shows confirmation, Dashboard
  - Category icon + name (36px icon circle + H1)
  - Progress bar: 2 of 3 segments filled
- **Form fields (16px gap):**
  - Property Address — text input, placeholder "Enter property address"
  - Date & Time — date/time picker (placeholder in prototype)
  - Your Price — numeric input with dollar icon, focus ring, avg. price hint
  - Special Instructions — multiline textarea, 3 rows
- **Buttons (two, side-by-side, 10px gap):**
  - "Save Draft" (secondary) → Draft Saved confirmation → Dashboard after 1.2s
  - "Post Task" (primary) → posts task → Dashboard
- **Auto-save indicator:** check icon + "Auto-saving your progress" (12px, slateLight)

#### 12.0.10 Draft Saved Confirmation
- **Layout:** Centered vertically, white background
- **Content:**
  - Green check circle (64px, `greenLight` bg, `green` icon)
  - "Draft Saved!" (H2, 22px/800, navy)
  - "You'll find it on your Dashboard. Finish and post whenever you're ready." (14px, slate, centered)
- **Behavior:** Auto-navigates to Dashboard after 1.2 seconds
- **Animation:** `fadeUp` (0→1 opacity, 20px→0 translateY)

---

### 12.1 Agent Dashboard

**Role:** Agent
**Tab:** Dashboard (default on launch)
**Route:** `/dashboard`

#### Content Sections (top to bottom)

**Greeting Header**
- Line 1: Time-of-day greeting — "Good morning" (5 AM–12 PM), "Good afternoon" (12 PM–5 PM), "Good evening" (5 PM–9 PM), "Good night" (9 PM–5 AM)
- Line 2: User's first name, `display` typography (26pt/800)
- No avatar in header — profile photo lives on Profile screen only

**Post-Onboarding Acknowledgement Banner** (conditional — appears once after completing onboarding)
- Shown only on the first Dashboard load after onboarding completion
- **Presentation:** Inline card (not a toast) — persists until dismissed or tapped. Positioned between greeting header and onboarding card.
- Two variants based on how the agent exited the First Task Creation step:
  - **Task Posted:** Green border + `greenLight` background. Check icon. "🎉 Your first task is live!" + "Nearby runners are being notified." + **"View Task →"** link (green, 13px/600). Tapping the card navigates to the newly created task detail.
  - **Draft Saved:** Amber border + `amberLight` background. Edit icon. "📝 Draft saved!" + "Your task draft is ready to finish." + **"Finish Draft →"** link (amber, 13px/600). Tapping the card navigates to the draft task detail (shows "Edit & Post Task" CTA).
  - **Skipped (no data entered):** No banner shown
- × dismiss button (top-right, stops propagation — does not navigate)
- Dismisses permanently on × tap or on card tap (navigates then clears)
- `fadeUp` animation on appearance (0→1 opacity, 12px→0 translateY)

**Progressive Onboarding Card** (conditional — appears when steps remain incomplete)
- Gradient card (navy → navy-mid)
- × dismiss button (top-right, semi-transparent circle)
- Title: "Complete your profile" with step count ("3 of 5")
- Progress bar showing completion percentage
- Remaining step pills below the bar — **each pill is tappable**
- Tapping a step pill **deep links** to the appropriate screen within the Profile tab: `deepLink("Profile", targetScreen)`. The tab bar switches to Profile and the target screen pushes onto the Profile navigation stack.

Onboarding steps (ordered, with deep link targets):
1. Add profile photo → `deepLink("Profile", "personal")`
2. Add brokerage name → `deepLink("Profile", "personal")`
3. Verify real estate license number → `deepLink("Profile", "personal")`
4. Set up payment method → `deepLink("Profile", "payment")`
5. Post your first task → opens Task Creation Sheet (stays on Dashboard)

Card reappears on next session if dismissed while steps remain incomplete. Card is permanently hidden once all 5 steps are complete.

**Status Widgets** (3-column grid)
- Posted — blue accent, count of tasks with `status = posted`
- In Progress — amber accent, count of tasks with `status = in_progress`
- Completed — green accent, count of tasks with `status = completed`
- Tapping a widget pushes the **Filtered Task List** view (Section 12.3) with the corresponding filter applied

**Create Task Button**
- Full-width primary pill button
- Label: "Create Task" with `plus` icon
- Opens Task Creation Sheet (Section 12.7) as modal overlay

**Recent Tasks List**
- Section header: "Recent Tasks" with "View All" action link
- **Filter pills** below header: Active (default), Completed, All. Single-select, pill-shaped toggle buttons. Selected: `navy-solid` background, white text. Unselected: `surface` background, `slate` text, `border` stroke. Animated transition on tap.
  - **Active:** Excludes completed tasks (`status != completed`). Default selection.
  - **Completed:** Shows only completed tasks.
  - **All:** Shows all tasks unfiltered.
- Shows the 4 most recently created tasks matching the active filter, sorted by creation date descending
- Each task renders as a Task Card (see Section 11.3 Component Library)
- "View All" pushes Filtered Task List with `filter = all`
- Tapping a task card pushes Task Detail (Section 12.5)

---

### 12.2 Task Runner Dashboard

**Role:** Runner
**Tab:** Dashboard (default on launch)
**Route:** `/dashboard`

#### Content Sections (top to bottom)

**Greeting Header**
- Line 1: "Good [morning/afternoon/evening]" — `caption` typography
- Line 2: User's first name — `display` typography

**Earnings Summary Card**
- Gradient card (navy → navy-mid)
- Two columns: "This Week" (sum of completed task payouts, Mon–Sun) and "Completed" (count of tasks completed this week)
- `price` typography for numbers (32pt/800, white)
- Tapping the card pushes Earnings & Payouts (Section 12.12)

**Location Bar**
- Red-glow background pill (`redGlow` + `redLight` border, 12px radius)
- Map pin icon (left) + current location name (center, 13px/600 weight) + "Change" link (right, red text)
- Tapping anywhere on the bar opens the Location Picker sheet (Section 12.2.1)
- Updates the available tasks feed when location changes

**Search Bar**
- Standard search input (Section 11.3)
- Placeholder: "Search tasks by location or type..."
- Searches against: task type, property address, agent name
- Debounce: 300ms after last keystroke
- Results filter the Available Tasks list below in real-time

**Filter Pills**
- Horizontal scrollable row
- Options: All, Photography, Showings, Staging (matches task categories from Section 2)
- Single-select — tapping one deselects the previous
- "All" selected by default
- Active pill: primary style (red background, white text)
- Inactive pill: secondary style (white background, border)

**Available Tasks List**
- Section header: "Available Tasks"
- Lists all tasks with `status = posted` in the runner's active service areas
- Default sort: newest first (by `posted` timestamp)
- Each card shows: category icon, type, address, price, agent name, time since posted, distance from runner
- Distance calculated from runner's current location (or center of primary service area if location unavailable)
- Pull-to-refresh reloads the task feed
- Tapping a card pushes Task Detail — Runner View (Section 12.6)

#### 12.2.1 Location Picker Sheet

**Role:** Runner
**Presentation:** Bottom sheet (modal) from Runner Dashboard location bar tap

**Header:** "Change Location" (H2) + × close button

**Mode Toggle:**
- Two cards side-by-side: "Search" (search icon) and "Use My Location" (crosshair icon)
- Active card: red border + redGlow background
- Tapping switches between modes

**Auto Mode ("Use My Location"):**
- Shows green confirmation pill: "Detected: [current city]" with crosshair icon
- "Use Current Location" primary button → sets location and closes sheet
- Uses device geolocation API (with permission prompt on first use)

**Search Mode:**
- Search input: "Search city or ZIP code..." with search icon and clear button
- City list below (pre-populated with launch markets and common selections):
  - Austin, TX (Current location)
  - Virginia Beach, VA (Oceanfront, Town Center)
  - Norfolk, VA (Ghent, Downtown, Ocean View)
  - Dallas, TX (Uptown, Deep Ellum, Bishop Arts)
  - San Antonio, TX (Pearl District, Riverwalk)
  - Chesapeake, VA (Great Bridge, Greenbrier)
- Each city row: map pin icon + city name (14px/600) + subtitle neighborhoods (12px, slateLight)
- Current selection has red border + redGlow background + red check icon
- Tapping a city sets location and closes sheet
- Search filters the list in real-time
- Empty state: "No results for '[query]'"

**On Location Change:**
- Updates the location bar on Runner Dashboard
- Updates "Using current location: [city]" in Filter Sheet
- Re-fetches available tasks for the new location (in production)

---

### 12.3 All Tasks (Filtered Task List)

**Role:** Agent
**Route:** `/tasks?filter={status}`
**Presentation:** Pushed onto navigation stack from Dashboard widget tap or "View All"

#### Content

**Header**
- Title: "All Tasks" (always — the filter chips handle sub-filtering)
- Task count subtitle: "[n] tasks"

**Filter Chips**
- Horizontal scrollable row of filter chips
- Options: All, Draft, Posted, Accepted, In Progress, Completed, Cancelled
- Single-select — tapping one deselects the previous
- "All" selected by default; initial filter can be set from Dashboard widget tap
- Active chip: primary style (red background, white text)
- Inactive chip: secondary style (white background, border)
- Chips filter the task list in real-time (client-side filter on already-fetched data)

**Task Cards**
- Full list of agent's tasks matching the active filter
- Sorted by: creation date descending (default)
- Each card: Task Card component with status badge and runner attribution (when assigned)
- Tapping pushes Task Detail (Section 12.5)

**Empty State**
- Icon: `search` in 64px container
- Heading: "No tasks found"
- Description: "Tasks with this status will appear here"

---

### 12.4 Notifications

**Role:** Both
**Tab:** Notifications
**Route:** `/notifications`

#### Content

**Header Row:**
- Left: "Notifications" — `title-lg` typography
- Right: Settings gear icon (36×36px, 12px radius, bordered, `slate` color) → tapping deep links to Notification Settings within the Profile tab: `deepLink("Profile", "notifSettings")`. This switches the active tab to Profile and pushes Notification Settings onto the Profile navigation stack. Back button returns to Profile root, not to Notifications tab. (See Section 5, Routing & Deep Linking.)

**Notification List**
- Sorted by timestamp descending (newest first)
- Unread notifications: `red-glow` background, `red-light` border, red icon container, unread dot (8px red circle)
- Read notifications: white background, standard border, `border-light` icon container

**Notification Types — Agent:**

| Type | Icon | Trigger | Tap Destination |
|---|---|---|---|
| Task Accepted | `check` | Runner accepts agent's task | Task Detail |
| Deliverables Ready | `camera` | Runner submits deliverables | Task Detail (review mode) |
| Payment Processed | `dollar` | Payment released to runner | Task Detail |
| New Message | `send` | Runner sends message on task | Task Detail (messaging) |
| Task Cancelled | `x` | Runner cancels accepted task | Task Detail |

**Notification Types — Runner:**

| Type | Icon | Trigger | Tap Destination |
|---|---|---|---|
| Task Available | `camera`/`eye`/`box` | New task in runner's area | Task Detail |
| Task Assigned | `check` | Agent's task assigned to runner | Task Detail |
| Revision Requested | `refresh` | Agent requests revision | Task Detail (deliverables) |
| Payout Deposited | `dollar` | Weekly payout processed | Earnings & Payouts |
| Task Cancelled | `x` | Agent cancels task | Dashboard |

**Mark as Read:** Tapping a notification marks it as read (updates `read_at` timestamp in the database via Supabase client), updates the local model immediately for instant UI feedback, and navigates to the destination. No bulk mark-as-read in MVP.

**Data Loading & Refresh:**
- Notifications load on first appearance via `.task { }` and track `hasLoadedOnce` state
- On subsequent `onAppear` calls (tab re-selection), notifications reload automatically
- Pull-to-refresh (`.refreshable`) triggers a full reload from the database
- Notification list is sorted by `created_at` descending

**Empty State:**
- Icon: `bell` in 64px container
- Heading: "No notifications yet"
- Description: "You'll see updates about your tasks here"

---

### 12.5 Task Detail — Agent View

**Role:** Agent
**Route:** `/tasks/{id}`
**Presentation:** Pushed onto navigation stack

#### Content Sections

**Task Header**
- 48px category icon container (14px radius, `red-light` background)
- Type name: `title-lg` typography
- Assignment status: "Assigned to [runner name]" or "Awaiting runner selection"
- Status badge (right-aligned)

**Task Payout Card**
- Accent card style (`red-glow` background, `red-light` border)
- Label: "Task Payout"
- Amount: `price-lg` typography (36pt/800, red)

**Map Section**
- When a property address is present, a MapKit `Map` view displays with a `Marker` at the geocoded address
- Address is geocoded on appear using `CLGeocoder.geocodeAddressString()`
- Map is 180px tall, clipped to `RoundedRectangle(cornerRadius: Radius.card)`, non-interactive (`allowsHitTesting(false)`)
- Camera position auto-centers on the marker with `0.005` lat/lng span
- Map appears above the Task Details section

**Assigned Runner Section** (conditional — shown when task has a runner)
- `AvatarView` (44px) showing runner's actual photo loaded from Supabase Storage, or initials fallback
- Runner name in `bodyEmphasis` typography
- "Accepted [time ago]" using `RelativeDateTimeFormatter` with `.full` units style — displays a **static** string (e.g., "2 hours ago"), not a live-ticking SwiftUI `Text(date, style: .relative)` which causes constant UI updates
- Chevron disclosure indicator for future profile navigation

**Task Details Section**
- Section header: "Task Details"
- Detail rows (icon container + label + value):

| Field | Icon | Required | Source |
|---|---|---|---|
| Location | `map` | Yes | Property address |
| Scheduled | `clock` | Yes | Date and time or "Flexible" |
| Category | `camera`/`eye`/`box` | Yes | Task type |
| Posted | `calendar` | Yes | Creation timestamp |

**Special Instructions Card**
- Muted card style (`border-light` background)
- Label: "Special Instructions"
- Body text: agent's instructions, `caption` typography, 1.5 line height
- Max length: 500 characters

**Action Buttons** (varies by task status)

| Task Status | Button Layout |
|---|---|
| `posted` | "Cancel Task" secondary (destructive) |
| `in_progress` | "Message [Runner]" secondary, full-width |
| `deliverables_submitted` | "Request Revision" secondary + "Approve & Pay" primary (paired) |
| `completed` | "View Receipt" secondary, full-width |
| `cancelled` | No buttons |

**Post-Action Behavior:**
- "Approve & Pay" → confirmation banner (green-light) → auto-navigate to Dashboard after 2 seconds
- "Request Revision" → sheet with revision notes textarea → submit → returns to task detail with `in_progress` status
- "Cancel Task" → confirmation dialog → cancellation fee warning if runner assigned → confirm → navigate to Dashboard

---

### 12.6 Task Detail — Runner View

**Role:** Runner
**Route:** `/tasks/{id}`
**Presentation:** Pushed onto navigation stack

Same layout as Agent View (Section 12.5) with these differences:

- Attribution line: "Posted by [agent name]" instead of runner assignment
- No "Cancel Task" or "Approve & Pay" buttons

**Action Buttons by Status:**

| Task Status | Button Layout |
|---|---|
| `posted` (available) | "Apply to Task" primary, full-width |
| `in_progress` (runner's task) | "Submit Deliverables" primary + "Message Agent" secondary (paired) |
| `revision_requested` | "Resubmit Deliverables" primary, full-width |
| `completed` | "View Payout Details" secondary, full-width |

**Post-Apply Behavior:**
- "Apply to Task" → loading state → success: confirmation banner + application status updates to `pending`
- If task can no longer accept applications, show amber banner: "This task is no longer available" and disable apply action

---

### 12.7 Task Creation Sheet

**Role:** Agent
**Route:** N/A (modal overlay)
**Presentation:** Sheet modal — slides up from bottom, 92% screen height

#### Step 1: Category Selection

**Header:** "New Task" with × dismiss button
**Subtitle:** "What do you need help with?"

**Category Cards** (vertical list, tap to advance):

| Category | Icon | Description | Price Range |
|---|---|---|---|
| Photography | `camera` | Professional listing photos | $100–$300 |
| Showing | `eye` | Represent you at a buyer showing | $50–$100 |
| Staging | `box` | Stage a property for listing | $200–$500 |
| Open House | `home` | Host an open house event | $75–$150 |

Tapping a category transitions to Step 2 (internal state change, not navigation push).

#### Step 2: Task Details Form

**Header:** Selected category name with × dismiss button
**Step Indicator:** 3-bar progress (bar 1 filled = step 2 active)

**Form Fields:**

| Field | Type | Input | Required | Validation |
|---|---|---|---|---|
| Property Address | Text | Autocomplete (future) / manual entry (MVP) | Yes | Non-empty |
| Date & Time | Picker | Date picker + time slot selector | Yes | Must be future |
| Your Price | Price input | Numeric with dollar icon | Yes | Min $25, max $2,000 |
| Special Instructions | Textarea | Freeform text | No | Max 500 chars |

**Price Helper Text:** "Avg. for [category] in [market]: $[low]–$[high]" — ranges defined per category per market.

**Auto-save:** All fields debounce-save after 1 second of inactivity. Green checkmark + "Auto-saving your progress" confirmation.

#### Step 3: Review & Post (future iteration — not in MVP)

In MVP, the paired buttons at the bottom of Step 2 handle posting:
- "Save Draft" (secondary) — saves task as draft, closes sheet, draft appears on Dashboard
- "Post Task" (primary) — if payment source exists, posts immediately; if not, saves as draft and prompts payment setup

---

### 12.8 Profile — Home

**Role:** Both
**Tab:** Profile
**Route:** `/profile`

#### Content Sections

**Account Summary Card**
- Avatar: 72px circle, navy background, white initials. Online indicator: green dot (16px) at bottom-right when `is_online = true`, gray when offline (derived from availability settings — see Section 12.15).
- Full name: `title-lg` typography
- Account type + email: "Agent · jane@example.com" or "Task Runner · jane@example.com"
- Summary stats row: "X Tasks Posted · Y Active" (agent) or "X Tasks Completed · Y Active" (runner)
- "View Public Profile" secondary button — opens the user's own public profile (Section 12.17). Back button reads "Profile" and returns here.

**Menu Card** (grouped list with chevron disclosure indicators)

| Row | Icon | Label (Agent) | Label (Runner) | Destination |
|---|---|---|---|---|
| 1 | `user` | Personal Information | Personal Information | Section 12.9 |
| 2 | `creditcard` | Payment Methods | Payout Settings | Section 12.10 |
| 3 | `bell` | Notification Settings | Notification Settings | Section 12.11 |
| 4 | `clock` / `trending` | Task History | Earnings & Payouts | Section 12.12 / 12.13 |
| 5 | `mappin` | — | Service Areas | Section 12.14 |
| 6 | `calendar` | — | Availability | Section 12.15 |
| 7 | `shield` | Account & Security | Account & Security | Section 12.16 |

Runner-only rows (5, 6) do not appear for agents.

**Profile Completeness Card** (dismissible)
Shown when the user's profile is incomplete (missing bio, certifications, equipment, or cover photo). Displays a progress indicator (e.g., "3 of 6 complete") with a checklist of remaining items. Tapping an item navigates to the relevant edit screen. Dismissible via × button; dismissal persists via `onboarding_completed_steps` array (add `'profile_completeness_dismissed'`). Reappears if new completable items are added.

---

### 12.9 Personal Information

**Role:** Both
**Route:** `/profile/personal`
**Presentation:** Pushed onto navigation stack

#### Content

**Avatar Section** (centered)
- 72px avatar
- "Change Photo" small button — opens system photo picker (camera or library)
- Photo requirements: minimum 200×200px, JPEG or PNG, max 5 MB

**Information Fields** (read-only card with edit button at bottom)

| Field | Type | Required | Both Roles |
|---|---|---|---|
| Full Name | Text | Yes | Yes |
| Email Address | Email | Yes | Yes |
| Phone Number | Phone | Yes | Yes |
| Brokerage | Text | Yes | Yes |
| Real Estate License # | Text | Yes | Yes |
| License State | Picker (US states) | Yes | Agent only |
| License Verified | Read-only status | — | Runner only (shows verification date) |
| Bio | Textarea | No | Yes |

**Bio:** Max 250 characters. Visible to the other party on task detail views (future iteration).

**Edit Mode:** Tapping "Edit Information" makes fields editable inline. Save button replaces edit button. Cancel returns to read-only. All changes auto-save on field blur.

---

### 12.10 Payment Methods (Agent) / Payout Settings (Runner)

**Role:** Both (different content per role)
**Route:** `/profile/payment`

#### Agent — Payment Methods (Implemented)

Payment methods are used to pay for posted tasks.

**Has Payment Method State:**
- Shows a confirmation card: credit card icon + "Payment method on file" + "Default payment method" subtitle + green checkmark
- "Update Payment Method" secondary pill button below
- "Secured by Stripe" lock icon + text at bottom

**No Payment Method State:**
- `EmptyStateView`: credit card icon, "No Payment Methods" heading, "Add a card to pay for tasks. Your card will be charged when you approve deliverables." description
- "Add Payment Method" primary button
- "Secured by Stripe" badge

**Add/Update Flow:**
- Calls `TaskService.createSetupIntent()` which invokes the `create-setup-intent` edge function
- Configures `PaymentSheet` with `setupIntentClientSecret`, customer ID, and ephemeral key
- Presents Stripe's native `PaymentSheet` UI (handles card entry, validation, 3DS)
- On completion: sets `hasPaymentMethod = true`, shows success toast, refreshes user profile
- Payment method presence is determined by `user.stripeCustomerId != nil`

#### Runner — Payout Settings (Implemented)

Payout accounts receive earnings from completed tasks via Stripe Connect Express.

**Has Connect Account State:**
- Shows account card with "Connected" status badge and Stripe Connect account ID
- Payout schedule note: "Payouts every Friday"

**No Connect Account State:**
- `EmptyStateView` with payout setup prompt
- "Set Up Payouts" primary button

**Setup Flow:**
- Calls `TaskService.createConnectLink()` which invokes the `create-connect-link` edge function
- Opens the returned hosted onboarding URL in Safari
- Runner completes Stripe Connect onboarding externally
- On return via `agentflo://stripe-connect` URL scheme: app refreshes user profile and navigates to Payout Settings
- Connect account presence is determined by `user.stripeConnectId != nil`

---

### 12.11 Notification Settings

**Role:** Both
**Route:** `/profile/notifications`

#### Push Notifications (toggle rows)

| Setting | Description | Default | Agent | Runner |
|---|---|---|---|---|
| Task Updates | Acceptance, completion, cancellation | On | Yes | Yes |
| Messages | New messages on active tasks | On | Yes | Yes |
| Payment Confirmations / Payout Notifications | Payment processed / earnings deposited | On | Yes | Yes |
| New Available Tasks | Tasks posted in your area | On | — | Yes |
| Weekly Earnings Summary | Monday morning summary | On | — | Yes |
| Product Updates | Features, tips, promotions | Off | Yes | Yes |

#### Email Notifications (toggle rows)

| Setting | Description | Default | Agent | Runner |
|---|---|---|---|---|
| Task Receipts | Confirmation on post / accept | On | Yes | Yes |
| Invoice Summaries / Earnings Statements | Monthly / weekly reports | On | Yes | Yes |

---

### 12.12 Task History (Agent)

**Role:** Agent
**Route:** `/profile/history`

#### Content

**Header:** "Task History" with task count subtitle

**Export Button** — small pill button, top-right: "Export" with `download` icon. Exports CSV of all tasks.

**Filter Pills:** All, Posted, In Progress, Completed (single-select, same behavior as Runner Dashboard filters)

**Summary Card**
- Two columns: "Total Spent" (sum of all completed task payouts) and "Avg. per Task"
- `title-lg` typography for amounts

**Task List**
- All agent's tasks matching active filter
- Sorted by creation date descending
- Task Card component with runner attribution
- Tapping pushes Task Detail (Section 12.5)

---

### 12.13 Earnings & Payouts (Runner)

**Role:** Runner
**Route:** `/profile/earnings`

#### Content

**Header:** "Earnings & Payouts"

**Earnings Summary Card** (gradient)
- 2×2 grid:
  - This Week: sum of tasks completed Mon–Sun
  - This Month: sum of tasks completed in current calendar month
  - All Time: lifetime total
  - Tasks Done: lifetime completed count
- `price` typography for values (28pt/800, white)

**Recent Payouts Section**
- Section header: "Recent Payouts"
- Payout cards showing: amount, date, task count, status badge
- Status: "Processing" (amber) or "Deposited" (green)

**Completed Tasks Section**
- Section header: "Completed Tasks"
- Task Cards for runner's completed tasks with agent attribution
- Tapping pushes Task Detail — Runner View (Section 12.6)

---

### 12.14 Service Areas (Runner)

**Role:** Runner
**Route:** `/profile/service-areas`

#### Content

**Header:** "Service Areas" with subtitle "Areas where you accept tasks"

**Service Area Cards**
- Each card: map pin icon container, area name, radius, active/inactive toggle
- Active areas: `red-light` icon background, green toggle
- Inactive areas: `border-light` icon background, gray toggle
- Toggling off an area stops showing tasks from that area on the Dashboard

**Add Service Area** — secondary pill button. Opens sheet with:
- Area name (text input with autocomplete for neighborhoods/ZIP codes)
- Radius picker: 3 mi, 5 mi, 8 mi, 10 mi, 15 mi (default: 5 mi)
- "Add Area" primary button

**Constraints:**
- Minimum 1 active service area required
- Maximum 5 service areas in MVP
- Areas can overlap

---

### 12.15 Availability (Runner)

**Role:** Runner
**Route:** `/profile/availability`

#### Content

**Header:** "Availability" with subtitle "Set when you're available for tasks"

**Weekly Schedule Card**
- 7 rows (Monday–Sunday)
- Each row: day name, time range, active/inactive toggle
- Active days show the configured time range
- Inactive days show "Unavailable"
- Tapping a row (when active) opens a time range picker: start time and end time in 30-minute increments
- Default: Monday–Friday 9:00 AM – 6:00 PM, Saturday 10:00 AM – 3:00 PM, Sunday off

**Task Categories Card**
- Section title: "Task Categories" with subtitle "Categories you're willing to accept"
- Pill-shaped toggles for each category: Photography, Showings, Staging, Open House
- Active: primary style (red). Inactive: secondary style (bordered)
- Minimum 1 category must remain active
- Changes save immediately on toggle

---

### 12.16 Account & Security

**Role:** Both
**Route:** `/profile/security`

#### Content

**Header:** "Account & Security" with subtitle "Manage your account settings"

**Settings Menu Card:**

| Row | Icon | Label | Behavior |
|---|---|---|---|
| Change Email | `mail` | Opens inline edit with verification flow |
| Change Password | `shield` | Opens password change form (current + new + confirm) |
| Two-Factor Auth | `phone` | Toggles 2FA setup — SMS-based in MVP |
| Privacy Policy | `filetext` | Opens in-app web view |
| Terms of Service | `filetext` | Opens in-app web view |

**Sign Out Button** — full-width secondary pill, `errorRed` text + border, `logout` icon. Tapping shows inline confirmation card:
- Card style: `errorRed` border + `errorBg` background
- Heading: "Sign out of Agent Flo?" (15px, 700 weight)
- Body: "You'll need to log in again to access your account." (13px, slate)
- Two buttons side-by-side: "Cancel" (secondary, dismisses) + "Sign Out" (primary, `errorRed` background, signs out)
- On sign out: clears session, resets all state, returns to Landing screen (Section 6.1.2)

**Delete Account** — text link below sign-out, centered, `caption` typography in `slate-light`. Opens confirmation sheet with warning: "This action is permanent. All your data, tasks, and payment information will be deleted." Requires typing "DELETE" to confirm.

---

### 12.17 Public Profile

**Role:** Both (viewable by either role)
**Route:** `/profile/:userId/public`
**Presentation:** Pushed onto navigation stack. Tab bar hides when active, reappears on dismissal.

#### Entry Points

| Source | Back Button Label | Returns To |
|---|---|---|
| Profile tab → "View Public Profile" (self-view) | "Profile" | Profile Home (12.8), Profile tab stays active |
| Task Detail → assigned runner card (assignment flow) | "Task" | Task Detail (12.5/12.6), Tasks tab stays active |

#### Header Region

Full-width cover image (edge-to-edge within card frame, aspect ratio ~2:1). Default: auto-suggested from the user's best portfolio photo; user may upload a custom cover photo via profile edit. Dark gradient overlay for navigation legibility.

**Floating navigation bar** over the header:
- Translucent pill-style back button (rgba(0,0,0,0.3) with backdrop blur)
- Three-dot overflow menu (share profile, report)

Scrollable content area overlaps the header by 48px, creating a card that rises out of the image.

#### Identity Block

Inside the top card, avatar pulls up into the header overlap zone:

- **Avatar:** 76px circle with 4px white `surface` border, `red`-to-#E8405A gradient fill, initials as placeholder. Online indicator (16px circle) at bottom-right: `green` when online, `slate-light` when offline. Online/offline derived from user's availability settings (see Section 12.15). Subtle shadow for depth against header.
- **Name + Verification:** Name in 21px/700 with verified badge inline (checkmark-in-shield icon, `red`). Verified badge displays when all three criteria are met: photo uploaded, full name confirmed, real estate license validated via vetting (see Section 10.1).
- **Subtitle:** "{City, ST} · Since {Month Year}" — location from `users.location_city`/`location_state`, tenure from `users.created_at`.

#### Service Tags

Horizontally wrapping pill tags below the identity block. `red` text on `red-light` background, `caption` typography (13px/500), pill radius (9999px). Tags map to the platform's task category taxonomy via `user_service_tags` (Section 13.2). User-managed from profile edit.

#### Stats Row

Four-column bar on `border-light` background, 14px radius, below the tags:

| Stat | Label | Format |
|---|---|---|
| Tasks completed | Tasks | Integer |
| Average rating | Rating | Decimal (X.X) |
| On-time rate | On-time | Percentage |
| Repeat client rate | Repeat | Percentage |

Percentile badges ("Top X%") display above the numeric value in `amber` text for users at or above the 10th percentile. Columns separated by 0.5px `border` dividers. Data sourced from `user_stats` materialized view (Section 13.2).

#### Call-to-Action Buttons

Two equally-weighted buttons, full card width, side-by-side with `sm` (8px) gap:

- **Request Task** (primary): `red` fill, white text, calendar icon. Initiates task posting flow (Section 12.7) pre-assigned to this user.
- **Message** (secondary): `surface` fill, 1.5px `border` color border, `navy` text, chat bubble icon. Opens direct message thread.

Both: `body` typography (15px/600), 13px vertical padding, 12px border-radius.

**Self-view behavior:** When viewing your own profile, CTAs are replaced with an "Edit Profile" primary button that navigates to Personal Information (Section 12.9).

#### Tab Content

Segmented control below the profile card. Active tab: `red` fill, white text. Inactive: transparent, `slate` text. Two tabs: **Reviews** and **About**.

#### Reviews Tab

**Summary Card:**
- Aggregate rating (`display` typography, 36px/800), 5-star visual (`amber` fill), total review count
- Horizontal bar chart: distribution across 1–5 stars, `amber` fill bars

**Review Cards** (reverse-chronological):
- Only reviews with non-empty comments are displayed; silent ratings (star-only) contribute to the aggregate score but are not shown in the list.
- **Top row:** Reviewer 36px avatar (`CachedAvatarView`) + reviewer display name (`captionSM`/semibold/`navy`) + relative time (`caption`/`slate-light`, e.g. "2d ago") on left; 5-star rating on right (`12px`, `amber` fill / `slate-light` empty).
- **Went-well tags:** Green capsule chips (`caption`/`green` text, `green-light` background). Always shown when present.
- **Could-improve tags:** Amber capsule chips (`caption`/`amber` text, `amber-light` background). **Only shown when rating < 4 stars.** Hidden for 4–5 star reviews.
- **Review text:** Free-form "other" text below tags (`bodySM`/`navy`). Shown when present.
- **Comment storage:** The `comment` column stores structured JSON: `{"went_well":["tag1","tag2"],"could_improve":["tag3"],"other":"free text"}`. Falls back to plain text display if JSON parse fails.
- Reviews are fetched with a reviewer profile join: `select("*, reviewer:users!reviewer_id(id, full_name, avatar_url)")`.
- **Pagination:** First 10 reviews loaded. "Show More" button loads next 10. No infinite scroll.

#### Review Submission (Lyft-style)

Post-task review is presented as a modal sheet. UX modeled after Lyft's driver review flow.

**Flow:**
1. **Star rating** (required, 1–5): Large tappable stars (`36px`, `amber` fill). Must select before tags appear.
2. **Primary tags section:**
   - **4–5 stars:** Header: "What went well?" Tags: On time, Great communication, Quality work, Professional, Above & beyond, Followed instructions.
   - **1–3 stars:** Header: "What could they have done better?" Same tags as above.
3. **Improvement tags section:** Header: "What could have been improved?" Tags: Punctuality, Communication, Work quality, Professionalism, Following instructions. Shown for all ratings.
4. **Other text field** (optional): Free-form textarea ("Share more details...").
5. **Submit button:** Disabled until star rating selected. Only star rating is required; tags and text are optional.

**Tag chips:** Capsule-shaped toggle buttons. Selected state: `navy-solid` background, white text. Unselected: `surface` background, `slate` text, `border` stroke. Uses `FlowLayout` for wrapping.

**Auto-trigger:** Review sheet auto-opens after agent approves & pays. Also accessible via "Leave Review" button on completed task detail (both agent and runner roles). Button hidden once a review exists for the current user.

**Data model:** Comment encoded as JSON in the existing `comment` TEXT column (no schema migration). If no tags or text selected, `comment` is NULL (silent rating).

#### About Tab

Three content sections, each in its own card (14px radius):

**Bio:** Free-form text with preserved line breaks (white-space: pre-line). `body` typography, `slate` text, 1.6 line-height.

**Task History:** Horizontal bar chart showing task count by category. Each row: category label, count, proportional progress bar (`red` gradient fill). Bars scale relative to total tasks. Data from `task_history_by_category` view (Section 13.2).

**Certifications & Equipment:** Checklist layout. Each item: `red` checkmark icon + `caption` typography `slate` text. Items cover professional licenses, camera/drone equipment, and insurance. Data from `user_certifications` table (Section 13.2).

---

## 13. Data Model, Schema & API

### 13.1 Entity Relationship Overview

```
┌──────────┐     ┌──────────┐     ┌──────────────┐
│  users   │────<│  tasks   │────<│ deliverables │
│          │     │          │     └──────────────┘
│ agent OR │     │ agent_id │────<┌──────────────┐
│ runner   │     │runner_id │     │   messages   │
└──────────┘     └──────────┘     └──────────────┘
     │                │
     │           ┌────┴────┐
     │           │ reviews │
     │           └─────────┘
     │
     ├──<┌──────────────────┐
     │   │ vetting_records  │
     │   └──────────────────┘
     ├──<┌──────────────────┐
     │   │  service_areas   │  (runner only)
     │   └──────────────────┘
     ├──<┌──────────────────┐
     │   │  availability    │  (runner only)
     │   └──────────────────┘
     ├──<┌──────────────────┐
     │   │  notifications   │
     │   └──────────────────┘
     ├──<┌──────────────────────┐
     │   │  user_service_tags   │──> task_categories
     │   └──────────────────────┘
     ├──<┌──────────────────────┐
     │   │ user_certifications  │
     │   └──────────────────────┘
     └──<┌──────────────────────┐
         │  user_stats (view)   │
         └──────────────────────┘
```

### 13.2 Entities

#### `users`
Central identity. Every user has exactly one role. Extends Supabase Auth (`auth.users`).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | Matches `auth.users.id` |
| `role` | `text` | NOT NULL, CHECK IN ('agent', 'runner') | Immutable after creation |
| `email` | `text` | NOT NULL, UNIQUE | From auth, denormalized for queries |
| `full_name` | `text` | NOT NULL | |
| `phone` | `text` | | US format, nullable |
| `avatar_url` | `text` | | Supabase Storage path |
| `brokerage` | `text` | | Required for vetting |
| `license_number` | `text` | | Required for vetting |
| `license_state` | `text` | | Two-letter state code |
| `bio` | `text` | | Max 500 chars |
| `cover_photo_url` | `text` | | Supabase Storage path; falls back to auto-suggested portfolio photo or default |
| `location_city` | `text` | | Display city for public profile (e.g., "Austin") |
| `location_state` | `text` | | Two-letter state code for public profile (e.g., "TX") |
| `is_online` | `boolean` | DEFAULT false | Derived from availability settings; green/gray indicator on profile |
| `response_time` | `interval` | | Average response time to task requests, computed |
| `vetting_status` | `text` | NOT NULL, DEFAULT 'not_started', CHECK IN ('not_started', 'pending', 'approved', 'rejected', 'expired') | |
| `onboarding_completed_steps` | `text[]` | DEFAULT '{}' | Array of completed step IDs |
| `stripe_customer_id` | `text` | | Agents: Stripe Customer for payments |
| `stripe_connect_id` | `text` | | Runners: Stripe Connect account for payouts |
| `created_at` | `timestamptz` | DEFAULT now() | Also serves as `member_since` on public profile |
| `updated_at` | `timestamptz` | DEFAULT now() | Trigger-maintained |

#### `tasks`
Central work unit. Created by agents, claimed by runners.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | |
| `agent_id` | `uuid` | NOT NULL, FK → users(id) | Creator |
| `runner_id` | `uuid` | FK → users(id) | Assigned runner (null until accepted) |
| `category` | `text` | NOT NULL | Server-driven, maps to category config |
| `status` | `text` | NOT NULL, DEFAULT 'draft', CHECK IN ('draft', 'posted', 'accepted', 'in_progress', 'deliverables_submitted', 'revision_requested', 'completed', 'cancelled') | |
| `property_address` | `text` | NOT NULL | |
| `property_lat` | `float8` | | Geocoded, for proximity queries |
| `property_lng` | `float8` | | Geocoded, for proximity queries |
| `property_point` | `geography(Point, 4326)` | | PostGIS, computed from lat/lng |
| `scheduled_at` | `timestamptz` | | Requested date/time |
| `price` | `integer` | NOT NULL, CHECK (price > 0) | Cents (e.g., 15000 = $150.00) |
| `platform_fee` | `integer` | | Cents, calculated on acceptance |
| `runner_payout` | `integer` | | Cents, price - platform_fee |
| `instructions` | `text` | | Special instructions from agent |
| `category_form_data` | `jsonb` | DEFAULT '{}' | Category-specific fields (extensible per Section 14.1) |
| `stripe_payment_intent_id` | `text` | | Created on post, captured on approval |
| `posted_at` | `timestamptz` | | When status changed from draft → posted |
| `accepted_at` | `timestamptz` | | |
| `completed_at` | `timestamptz` | | |
| `cancelled_at` | `timestamptz` | | |
| `cancellation_reason` | `text` | | |
| `created_at` | `timestamptz` | DEFAULT now() | |
| `updated_at` | `timestamptz` | DEFAULT now() | |

**Indexes:**
- `idx_tasks_agent` on `(agent_id, status)` — agent dashboard queries
- `idx_tasks_status_location` on `(status, property_point)` using GIST — runner discovery
- `idx_tasks_runner` on `(runner_id, status)` — runner active tasks
- `idx_tasks_posted_at` on `(posted_at DESC)` WHERE status = 'posted' — feed ordering

#### `task_applications`
Runner expresses interest in a task. Agent selects from applicants.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `task_id` | `uuid` | NOT NULL, FK → tasks(id) ON DELETE CASCADE | |
| `runner_id` | `uuid` | NOT NULL, FK → users(id) | |
| `status` | `text` | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'accepted', 'declined', 'withdrawn') | |
| `message` | `text` | | Optional note from runner |
| `created_at` | `timestamptz` | DEFAULT now() | |

**Unique constraint:** `(task_id, runner_id)` — one application per runner per task.

#### `deliverables`
Files and content submitted by runners to complete a task.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `task_id` | `uuid` | NOT NULL, FK → tasks(id) ON DELETE CASCADE | |
| `runner_id` | `uuid` | NOT NULL, FK → users(id) | |
| `type` | `text` | NOT NULL, CHECK IN ('photo', 'document', 'report', 'checklist') | |
| `file_url` | `text` | | Supabase Storage path |
| `thumbnail_url` | `text` | | Generated for images |
| `title` | `text` | | |
| `notes` | `text` | | |
| `sort_order` | `integer` | DEFAULT 0 | For photo galleries |
| `created_at` | `timestamptz` | DEFAULT now() | |

#### `messages`
Per-task chat between agent and runner.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `task_id` | `uuid` | NOT NULL, FK → tasks(id) ON DELETE CASCADE | |
| `sender_id` | `uuid` | NOT NULL, FK → users(id) | |
| `body` | `text` | NOT NULL | |
| `read_at` | `timestamptz` | | NULL = unread |
| `created_at` | `timestamptz` | DEFAULT now() | |

**Index:** `idx_messages_task_created` on `(task_id, created_at)` — chat history ordering.
**Realtime:** Supabase Realtime subscription on `messages` filtered by `task_id` for live chat.

#### `reviews`
Mutual post-task ratings. One review per person per task.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `task_id` | `uuid` | NOT NULL, FK → tasks(id) | |
| `reviewer_id` | `uuid` | NOT NULL, FK → users(id) | Who wrote it |
| `reviewee_id` | `uuid` | NOT NULL, FK → users(id) | Who is being reviewed |
| `rating` | `integer` | NOT NULL, CHECK 1–5 | |
| `comment` | `text` | | Optional; stores JSON: `{"went_well":[...],"could_improve":[...],"other":"..."}`. NULL for silent ratings. Falls back to plain text. |
| `created_at` | `timestamptz` | DEFAULT now() | |

**Unique constraint:** `(task_id, reviewer_id)`

**Query pattern:** Reviews are fetched with reviewer profile join: `select("*, reviewer:users!reviewer_id(id, full_name, avatar_url)")`. The `Review` model includes an optional `reviewer: PublicProfile?` field.

#### `vetting_records`
Audit trail for identity and license verification.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `user_id` | `uuid` | NOT NULL, FK → users(id) | |
| `type` | `text` | NOT NULL, CHECK IN ('license', 'photo_id', 'brokerage', 'background_check') | |
| `status` | `text` | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'approved', 'rejected') | |
| `submitted_data` | `jsonb` | | License #, state, file URL, etc. |
| `reviewer_notes` | `text` | | Admin notes |
| `reviewed_by` | `uuid` | FK → users(id) | Admin who reviewed |
| `reviewed_at` | `timestamptz` | | |
| `expires_at` | `timestamptz` | | License expiry |
| `created_at` | `timestamptz` | DEFAULT now() | |

#### `service_areas` (Runner only)
Geographic zones where a runner accepts tasks.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `runner_id` | `uuid` | NOT NULL, FK → users(id) | |
| `name` | `text` | NOT NULL | e.g., "Downtown Austin" |
| `center_lat` | `float8` | NOT NULL | |
| `center_lng` | `float8` | NOT NULL | |
| `radius_miles` | `float4` | NOT NULL, DEFAULT 10 | |
| `center_point` | `geography(Point, 4326)` | | Computed from lat/lng via trigger |
| `is_active` | `boolean` | DEFAULT true | |
| `created_at` | `timestamptz` | DEFAULT now() | |

#### `availability` (Runner only)
Weekly recurring schedule.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `runner_id` | `uuid` | NOT NULL, FK → users(id) | |
| `day_of_week` | `integer` | NOT NULL, CHECK 0–6 | 0 = Monday |
| `start_time` | `time` | NOT NULL | |
| `end_time` | `time` | NOT NULL | |
| `is_active` | `boolean` | DEFAULT true | |

**Unique constraint:** `(runner_id, day_of_week)`

#### `notifications`
Push notification history and in-app feed.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `user_id` | `uuid` | NOT NULL, FK → users(id) | Recipient |
| `type` | `text` | NOT NULL | e.g., 'task_accepted', 'deliverables_ready' |
| `title` | `text` | NOT NULL | |
| `body` | `text` | NOT NULL | |
| `data` | `jsonb` | DEFAULT '{}' | Deep link payload: `{ task_id, screen }` |
| `read_at` | `timestamptz` | | NULL = unread |
| `push_sent_at` | `timestamptz` | | When push was delivered |
| `created_at` | `timestamptz` | DEFAULT now() | |

**Index:** `idx_notifications_user_unread` on `(user_id)` WHERE `read_at IS NULL`

#### `notification_preferences`

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | `uuid` | PK, FK → users(id) | |
| `task_updates` | `boolean` | DEFAULT true | |
| `messages` | `boolean` | DEFAULT true | |
| `payment_confirmations` | `boolean` | DEFAULT true | |
| `new_available_tasks` | `boolean` | DEFAULT true | Runner only |
| `weekly_earnings` | `boolean` | DEFAULT true | Runner only |
| `product_updates` | `boolean` | DEFAULT false | |

#### `push_tokens`

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK | |
| `user_id` | `uuid` | NOT NULL, FK → users(id) | |
| `token` | `text` | NOT NULL | |
| `platform` | `text` | NOT NULL, CHECK IN ('ios', 'android', 'web') | |
| `is_active` | `boolean` | DEFAULT true | Deactivated on sign-out |
| `created_at` | `timestamptz` | DEFAULT now() | |

#### `user_service_tags`
Maps users to task categories they offer as services. Displayed as pill tags on the public profile (Section 12.17).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | `uuid` | NOT NULL, FK → users(id) ON DELETE CASCADE | |
| `category` | `text` | NOT NULL | Maps to task category taxonomy (e.g., 'photography', 'staging') |
| `created_at` | `timestamptz` | DEFAULT now() | |

**Unique constraint:** `(user_id, category)` — one tag per category per user.

> **Design note:** The mini spec proposed `agent_service_tags` with a FK to a `task_categories` table. Since task categories are currently stored as `text` on the `tasks` table (Section 14.1 — server-driven config), service tags use the same `text` values rather than a separate FK. When task categories become a first-class table (future iteration), this FK can be added.

#### `user_certifications`
Public-facing credentials displayed on the profile About tab. Separate from `vetting_records` (which is an admin audit trail for identity verification).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` | |
| `user_id` | `uuid` | NOT NULL, FK → users(id) ON DELETE CASCADE | |
| `label` | `text` | NOT NULL | Display text (e.g., "Licensed Real Estate Agent — TX") |
| `type` | `text` | NOT NULL, CHECK IN ('license', 'equipment', 'insurance') | |
| `verified` | `boolean` | DEFAULT false | Cross-referenced with `vetting_records` for licenses |
| `created_at` | `timestamptz` | DEFAULT now() | |

#### `user_stats` (materialized view)
Computed profile statistics for the public profile stats row. Refreshed periodically (e.g., every 15 minutes via cron or on task completion trigger).

| Column | Type | Notes |
|---|---|---|
| `user_id` | `uuid` | PK |
| `tasks_completed` | `integer` | Count of tasks with status = 'completed' where user is runner |
| `avg_rating` | `decimal(2,1)` | Average of `reviews.rating` WHERE `reviewee_id = user_id` |
| `on_time_pct` | `integer` | Percentage of tasks completed by `scheduled_at` deadline |
| `repeat_client_pct` | `integer` | Percentage of completed tasks from repeat agents |
| `tasks_percentile` | `integer` | Nullable; set when ≥ 90th percentile (displays as "Top X%") |
| `rating_percentile` | `integer` | Nullable |
| `ontime_percentile` | `integer` | Nullable |
| `repeat_percentile` | `integer` | Nullable |

**Index:** `idx_user_stats_user` on `(user_id)` — profile page lookup.

#### `task_history_by_category` (view)
Aggregated task counts by category for the profile About tab bar chart.

```sql
CREATE VIEW task_history_by_category AS
SELECT runner_id AS user_id, category, COUNT(*) AS count
FROM tasks
WHERE status = 'completed'
GROUP BY runner_id, category;
```

### 13.3 State Machines

#### Task Status

```
draft ──→ posted ──→ accepted ──→ in_progress ──→ deliverables_submitted
  │         │          │             │                     │
  │         │          │             │              ┌──────┴──────┐
  │         │          │             │              ▼             ▼
  │         │          │             │      revision_requested  completed
  │         │          │             │              │
  │         │          │             │              └──→ deliverables_submitted
  │         ▼          ▼             ▼
  └──→ cancelled  cancelled     cancelled
```

| Transition | Actor | Side Effects |
|---|---|---|
| draft → posted | Agent | Geocode address, create PaymentIntent (uncaptured), notify nearby runners |
| draft → cancelled | Agent | Soft delete |
| posted → accepted | Agent (selects runner) | Assign runner_id, decline other applications, notify runner |
| posted → cancelled | Agent | Void PaymentIntent, notify applicants |
| accepted → in_progress | Runner | Notify agent |
| accepted → cancelled | Either | Cancellation fee logic, notify other party |
| in_progress → deliverables_submitted | Runner | Notify agent |
| in_progress → cancelled | Either | Cancellation fee logic |
| deliverables_submitted → completed | Agent ("Approve & Pay") | Capture PaymentIntent, trigger payout, notify runner, prompt reviews |
| deliverables_submitted → revision_requested | Agent | Notify runner with revision notes |
| revision_requested → deliverables_submitted | Runner | Notify agent |

#### Vetting Status (per user)

```
not_started ──→ pending ──→ approved
                   │              │
                   ▼              ▼
               rejected       expired ──→ pending (re-verification)
```

### 13.4 Row-Level Security (RLS) Policies

All tables have RLS enabled. Authorization is enforced at the database layer.

**`users`**
- SELECT own row: `auth.uid() = id`
- SELECT task counterparts: `users_select_task_counterparts` policy — agents can see profiles of runners assigned to their tasks, runners can see profiles of agents who posted tasks they're assigned to. Uses subquery: `id IN (SELECT runner_id FROM tasks WHERE agent_id = auth.uid() UNION SELECT agent_id FROM tasks WHERE runner_id = auth.uid())`
- SELECT others: limited fields via `public_profiles` view (name, avatar, rating)
- UPDATE own row only: `auth.uid() = id`

**`tasks`**
- SELECT (agent): `agent_id = auth.uid()` — own tasks, any status
- SELECT (runner): `status = 'posted'` OR `runner_id = auth.uid()` — available + own assigned
- INSERT: `agent_id = auth.uid()` AND user role = 'agent'
- UPDATE: `agent_id = auth.uid()` — status transitions validated by edge functions

**`messages`**
- SELECT/INSERT: only task participants (agent_id or runner_id matches auth.uid())
- INSERT: `sender_id = auth.uid()`

**`deliverables`**
- SELECT: task participants only
- INSERT: `runner_id = auth.uid()` AND task in correct status

**`reviews`**
- SELECT: all (public)
- INSERT: `reviewer_id = auth.uid()` AND task.status = 'completed' AND no existing review

**`vetting_records`**
- SELECT own: `user_id = auth.uid()`
- INSERT/UPDATE: admin service key only (not client-accessible)

**`notifications`, `notification_preferences`, `push_tokens`**
- All operations: `user_id = auth.uid()`

### 13.5 Supabase SQL Schema

```sql
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
```

### 13.6 GraphQL API

Agent Flo uses Supabase's `pg_graphql` extension, which auto-generates a GraphQL API from the schema. Custom resolvers are added via Edge Functions for multi-step business logic.

#### Key Queries

```graphql
# Agent dashboard
query AgentDashboard($agentId: UUID!) {
  tasks(
    filter: { agent_id: { eq: $agentId } }
    orderBy: { created_at: DescNullsLast }
  ) {
    edges { node {
      id, category, status, property_address, price,
      scheduled_at, posted_at, created_at,
      runner { id, full_name, avatar_url }
    }}
  }
  draft: tasksCollection(
    filter: { agent_id: { eq: $agentId }, status: { eq: "draft" } }
  ) { totalCount }
  posted: tasksCollection(
    filter: { agent_id: { eq: $agentId }, status: { eq: "posted" } }
  ) { totalCount }
  in_progress: tasksCollection(
    filter: { agent_id: { eq: $agentId }, status: { eq: "in_progress" } }
  ) { totalCount }
  completed: tasksCollection(
    filter: { agent_id: { eq: $agentId }, status: { eq: "completed" } }
  ) { totalCount }
}

# Runner: nearby available tasks (via Edge Function — PostGIS)
query AvailableTasks(
  $lat: Float!, $lng: Float!,
  $radiusMiles: Float!, $category: String
) {
  nearbyTasks(
    lat: $lat, lng: $lng,
    radius: $radiusMiles, category: $category
  ) {
    id, category, status, property_address, price,
    scheduled_at, distance_miles,
    agent { full_name, avg_rating }
  }
}

# Task detail with all related data
query TaskDetail($taskId: UUID!) {
  task(id: $taskId) {
    id, category, status, property_address,
    property_lat, property_lng, price, platform_fee,
    runner_payout, instructions, category_form_data,
    scheduled_at, posted_at, accepted_at, completed_at,
    agent { id, full_name, avatar_url, brokerage },
    runner { id, full_name, avatar_url },
    deliverables(orderBy: { sort_order: AscNullsLast }) {
      id, type, file_url, thumbnail_url, title, notes
    },
    messages(orderBy: { created_at: AscNullsLast }) {
      id, sender_id, body, read_at, created_at
    },
    task_applications {
      id, runner_id, status, message,
      runner { full_name, avatar_url, avg_rating }
    },
    reviews { reviewer_id, reviewee_id, rating, comment }
  }
}

# Notification feed (paginated)
query Notifications($userId: UUID!, $limit: Int = 20, $cursor: Cursor) {
  notifications(
    filter: { user_id: { eq: $userId } }
    orderBy: { created_at: DescNullsLast }
    first: $limit, after: $cursor
  ) {
    edges { node { id, type, title, body, data, read_at, created_at } }
    pageInfo { hasNextPage, endCursor }
  }
}

# User profile with stats
query UserProfile($userId: UUID!) {
  user(id: $userId) {
    id, full_name, email, phone, avatar_url, role,
    brokerage, license_number, license_state, bio,
    vetting_status, onboarding_completed_steps, created_at
  }
  publicProfile: public_profiles(filter: { id: { eq: $userId } }) {
    edges { node { avg_rating, review_count, is_verified } }
  }
}
```

#### Key Mutations

```graphql
# Create task (draft or posted)
mutation CreateTask($input: TaskInput!) {
  insertIntoTasksCollection(objects: [$input]) {
    records { id, status, created_at }
  }
}

# Post a draft → Edge Function handles geocoding, PaymentIntent, notifications
mutation PostTask($taskId: UUID!) {
  postTask(taskId: $taskId) {
    id, status, stripe_payment_intent_id, posted_at
  }
}

# Runner applies to a task
mutation ApplyToTask($taskId: UUID!, $message: String) {
  insertIntoTask_applicationsCollection(objects: [{
    task_id: $taskId, runner_id: $currentUserId, message: $message
  }]) { records { id, status } }
}

# Agent accepts a runner → Edge Function handles cascading updates
mutation AcceptRunner($applicationId: UUID!) {
  acceptRunner(applicationId: $applicationId) {
    task { id, status, runner_id, accepted_at }
  }
}

# Runner submits deliverables → Edge Function validates + generates thumbnails
mutation SubmitDeliverables($taskId: UUID!, $deliverables: [DeliverableInput!]!) {
  submitDeliverables(taskId: $taskId, deliverables: $deliverables) {
    task { id, status }
    deliverables { id, file_url, thumbnail_url }
  }
}

# Agent approves → Edge Function captures payment, schedules payout
mutation ApproveAndPay($taskId: UUID!) {
  approveAndPay(taskId: $taskId) {
    task { id, status, completed_at }
  }
}

# Agent requests revision
mutation RequestRevision($taskId: UUID!, $notes: String!) {
  requestRevision(taskId: $taskId, notes: $notes) {
    task { id, status }
  }
}

# Send chat message
mutation SendMessage($taskId: UUID!, $body: String!) {
  insertIntoMessagesCollection(objects: [{
    task_id: $taskId, sender_id: $currentUserId, body: $body
  }]) { records { id, body, created_at } }
}

# Mark notifications read
mutation MarkNotificationsRead($ids: [UUID!]!) {
  updateNotificationsCollection(
    filter: { id: { in: $ids } }
    set: { read_at: "now()" }
  ) { affectedCount }
}

# Submit review
# comment is JSON-encoded: {"went_well":["tag1"],"could_improve":["tag2"],"other":"text"}
# or NULL for silent (star-only) ratings
mutation SubmitReview(
  $taskId: UUID!, $revieweeId: UUID!,
  $rating: Int!, $comment: String
) {
  insertIntoReviewsCollection(objects: [{
    task_id: $taskId, reviewer_id: $currentUserId,
    reviewee_id: $revieweeId, rating: $rating, comment: $comment
  }]) { records { id } }
}

# Update profile
mutation UpdateProfile($userId: UUID!, $updates: UserPatch!) {
  updateUsersCollection(
    filter: { id: { eq: $userId } }
    set: $updates
  ) { records { id, full_name, avatar_url, bio, updated_at } }
}

# Update notification preferences
mutation UpdateNotifPrefs($userId: UUID!, $prefs: NotificationPreferencesPatch!) {
  updateNotification_preferencesCollection(
    filter: { user_id: { eq: $userId } }
    set: $prefs
  ) { records { user_id } }
}
```

#### Realtime Subscriptions

```graphql
# Live chat
subscription TaskMessages($taskId: UUID!) {
  messages(filter: { task_id: { eq: $taskId } }) {
    id, sender_id, body, created_at
  }
}

# Task status changes (for Live Activity / push)
subscription TaskStatus($taskId: UUID!) {
  tasks(filter: { id: { eq: $taskId } }) {
    id, status, runner_id, updated_at
  }
}
```

### 13.7 Edge Functions (Business Logic)

Supabase Edge Functions (Deno runtime) handle multi-step operations beyond CRUD. All edge functions include CORS headers and `OPTIONS` preflight handling. All require a valid Bearer token in the `Authorization` header.

| Function | Trigger | Logic | Status |
|---|---|---|---|
| `post-task` | Agent posts a draft | Validate required fields → geocode address → create Stripe PaymentIntent (uncaptured) → update status → notify nearby runners | Deployed |
| `accept-runner` | Agent picks a runner | Update application → assign runner_id → decline other applicants → notify accepted runner → notify declined | Deployed |
| `approve-and-pay` | Agent approves deliverables | Capture PaymentIntent → calculate fee → schedule payout → update status → notify runner → prompt reviews | Deployed |
| `cancel-task` | Either party cancels | Evaluate cancellation fee → void/refund PaymentIntent → update status → notify other party | Deployed |
| `submit-deliverables` | Runner uploads | Validate file types/sizes → generate thumbnails → update status → notify agent | Deployed |
| `create-setup-intent` | Agent adds payment method | Get/create Stripe Customer → create ephemeral key → create SetupIntent → return client secret + keys | Deployed |
| `create-connect-link` | Runner sets up payouts | Get/create Stripe Connect Express account → generate hosted onboarding link with `agentflo://stripe-connect` return URL → return URL + account ID | Deployed |
| `send-notification` | Push fan-out worker | Read unsent rows from `notifications` → resolve template → send push via FCM/APNs → set `push_sent_at` (does not create canonical notification rows) | Planned |

**Database Triggers (server-side, not edge functions):**

| Trigger | Table | Event | Logic |
|---|---|---|---|
| `trg_task_status_notify` | `tasks` | `AFTER UPDATE OF status` | Calls `notify_task_status_change()` — inserts notification rows for both agent and runner based on new status (see Section 7, In-App Notifications) |
| `trg_task_point` | `tasks` | `BEFORE INSERT OR UPDATE OF property_lat, property_lng` | Computes `property_point` PostGIS geography from lat/lng |
| `trg_users_updated` / `trg_tasks_updated` | `users` / `tasks` | `BEFORE UPDATE` | Updates `updated_at` timestamp |

### 13.8 Platform Implementation Notes

#### iOS (SwiftUI)
- Supabase Swift SDK for auth, database, storage, and realtime
- Navigation stack and sheet patterns per Section 5
- Deep linking via Universal Links, resolved by centralized router
- Xcode 26 SDK with Liquid Glass opt-in
- Design tokens mapped from Section 11

#### Web (React)
- Supabase JS SDK for auth, database, storage, and realtime
- React Router for navigation
- urql or Apollo Client for GraphQL layer
- Progressive Web App for runner mobile experience
- Design tokens mapped from Section 11

---

## 14. Architecture Flexibility & Extensibility

This section identifies areas of the platform most likely to require experimentation, additional options, or customization. The goal is to ensure build agents architect these systems with configuration and extensibility in mind — avoiding hardcoded assumptions that would require refactoring.

### 14.1 High-Variability Surfaces

These are the areas most likely to change post-launch. Each should be designed as data-driven and configurable rather than hardcoded.

#### Task Categories (CRITICAL)
**Current state:** 5 hardcoded categories (Photography, Showings, Staging, Open House, Inspections)
**Why it changes:** Market research, agent feedback, and geographic expansion will surface new categories (inspections, lockbox management, flyer distribution, virtual tours, drone photography, etc.)
**Architecture requirement:**
- Categories must be server-driven, not hardcoded in client
- Each category is a data object: `{ id, name, icon, description, priceRange, deliverableSchema, formFields }`
- Category-specific form fields (e.g., photography needs "number of rooms", showings needs "buyer name") must be configurable per category
- Category-specific deliverable types (photo gallery vs. report vs. before/after) must be pluggable
- **Milestone:** Iteration 3 (dynamic categories)
- **Build agent guidance:** Use a `TaskCategoryConfig` protocol/interface. Never switch on category name — always resolve behavior from config.

#### Pricing Model
**Current state:** Agent sets a flat price
**Why it changes:** Market dynamics will push toward suggested pricing, bidding, tiered pricing (standard/rush), and surge pricing
**Architecture requirement:**
- Pricing is a strategy pattern: `PricingStrategy` that can be flat, suggested, auction, or tiered
- Price suggestions are server-driven (market-specific, category-specific, time-of-day)
- Platform fee percentage must be configurable per market and per category
- **Milestone:** Iteration 3 (smart pricing), Iteration 5 (dynamic pricing)
- **Build agent guidance:** Never hardcode prices or fee percentages. Use a `PricingService` that resolves the pricing model, suggestions, and fees from server config.

#### Task Matching & Discovery
**Current state:** Manual browsing + search/filter
**Why it changes:** As liquidity increases, matching becomes more valuable. Will evolve from manual → proximity alerts → algorithmic matching → real-time dispatch
**Architecture requirement:**
- Task discovery is a pluggable pipeline: `DiscoveryProvider` that can be manual browse, filtered search, push-based alerts, or algorithmic recommendations
- Ranking/scoring logic must be server-side and swappable (newest-first → score-ranked → ML-ranked)
- **Milestone:** Iteration 3 (proximity alerts), Iteration 5 (real-time matching)
- **Build agent guidance:** Abstract the task feed as a `TaskFeedProvider`. The UI should consume a ranked list without knowing the ranking strategy.

#### Deliverable Submission & Review
**Current state:** Unspecified (placeholder buttons)
**Why it changes:** Different categories need different deliverable types, quality checks, and review workflows
**Architecture requirement:**
- Deliverable schema is defined per category: `DeliverableSchema { fields: [photo_gallery | file_upload | text_report | checklist], qualityChecks: [ai_image_analysis | none], reviewSteps: [approve | revision_loop] }`
- File upload, photo gallery, and report submission must be separate composable components
- Review flow must support: approve, request revision (with notes), reject, auto-approve (future)
- **Milestone:** Iteration 1 (basic submission), Iteration 3 (AI quality checks)
- **Build agent guidance:** Build a `DeliverableSubmissionView` that renders dynamically from `DeliverableSchema`. Never hardcode "upload photos" — render from config.

#### Notification Content & Actions
**Current state:** Defined notification types per role (Section 10.4)
**Why it changes:** New task types, new flows, A/B testing of notification copy, new action buttons
**Architecture requirement:**
- Notification templates are server-driven: `{ type, title_template, body_template, media_url, actions: [{label, deeplink}] }`
- Client renders notifications from templates, not from hardcoded switch statements
- Action buttons are deeplink-driven (the client resolves the deeplink, doesn't know the action semantics)
- **Milestone:** Iteration 3 (rich notifications)
- **Build agent guidance:** Build a `NotificationRenderer` that takes a template and renders it. Never switch on notification type to decide layout.

#### Onboarding Steps
**Current state:** 6 agent steps, 7 runner steps (Section 6.3)
**Why it changes:** Vetting requirements may change by market, new verification providers, A/B testing of step order, adding/removing steps
**Architecture requirement:**
- Onboarding steps are a server-driven ordered list: `[{ id, title, description, type: "form" | "upload" | "external", required, gating, completionCheck }]`
- Step completion is tracked per-user as a set of completed step IDs
- Gating rules (what's blocked until which steps complete) are configurable
- **Milestone:** Iteration 2 (configurable gating), Iteration 4 (automated verification)
- **Build agent guidance:** Build `OnboardingStepRenderer` that resolves step type to a component. Store completion as `Set<StepID>`. Never hardcode step count or order.

#### Geographic Expansion
**Current state:** Austin, TX and Virginia Beach, VA
**Why it changes:** Every new market may have different categories, pricing norms, regulations, and vetting requirements
**Architecture requirement:**
- Market is a first-class entity: `Market { id, name, region, categories: [CategoryConfig], pricingDefaults, vettingRequirements, brokerageList }`
- All market-specific behavior (categories, pricing, brokerages) resolves from the Market config
- User's active market is determined by location or manual selection
- **Milestone:** Iteration 5 (expansion)
- **Build agent guidance:** Never assume Austin or Virginia Beach. All market-specific data must come from a `MarketConfig` lookup.

### 14.2 Medium-Variability Surfaces

These change less frequently but should still avoid hardcoding.

- **Payment provider:** Currently Stripe. Wrap in a `PaymentProvider` protocol so a switch to Adyen or Square doesn't require rewriting business logic
- **Auth provider:** Currently email + password + SMS OTP. Wrap in an `AuthProvider` protocol to add Apple/Google SSO, passkeys, or magic links without rewiring
- **Chat/messaging:** Currently basic text. Will evolve to include images, voice, templates, and possibly AI-suggested responses. Use a `MessageType` enum that's extensible
- **Rating system:** Currently 5-star + text. May change to thumbs-up/down, multi-dimensional ratings, or NPS. Abstract as `ReviewSchema`
- **Background check provider:** Use Checkr in v1. Wrap in a `BackgroundCheckProvider` protocol so it can be swapped without impacting the domain model.

### 14.3 Build Agent Guidance Summary

When building any feature, the agent should ask: "If this value, list, or behavior needed to change, would I need to modify client code?" If yes, refactor to resolve from server config or a protocol/interface. Specifically:

1. **Never switch on enum string values** for business logic — resolve behavior from config objects
2. **Never hardcode lists** (categories, cities, steps, notification types) — fetch from server or config
3. **Wrap all third-party services** in a protocol/interface with a single implementation
4. **Make all fee percentages, thresholds, and limits server-configurable**
5. **Use feature flags** for any behavior that might be A/B tested or rolled out gradually

---

## 15. Security Posture

### 15.1 Current Security Profile (Iteration 1)

| Area | Status | Risk Level |
|---|---|---|
| Authentication | Email + password (bcrypt hash) | 🟡 Medium — no MFA yet, password-only |
| Session management | JWT with refresh tokens | 🟢 Standard — needs expiry policy |
| Data at rest | Supabase (Postgres) with RLS | 🟢 Good — row-level security by default |
| Data in transit | TLS 1.3 everywhere | 🟢 Standard |
| Payment data | Stripe handles PCI — no card data on our servers | 🟢 Good |
| File uploads (photo ID, deliverables) | Stored in Supabase Storage | 🟡 Medium — needs access control policy |
| API authorization | Role-based (agent vs. runner) | 🟡 Medium — needs per-resource ownership checks |
| Admin interface | Web-based, no auth spec yet | 🔴 High — must be secured before launch |
| Rate limiting | Not specified | 🔴 High — APIs are open to abuse |
| Input validation | Not specified | 🔴 High — must be comprehensive |
| Dependency scanning | Not specified | 🟡 Medium — standard for MVP |

### 15.2 Security Roadmap

#### Iteration 1 — Baseline (Must-Have Before Launch)
- **Rate limiting** on all API endpoints: 60 req/min per user for reads, 10 req/min for writes, 3 req/min for auth attempts
- **Input validation** and sanitization on all user inputs (addresses, names, descriptions, chat messages)
- **Admin interface authentication:** Email + password + mandatory MFA (TOTP). IP allowlisting for admin endpoints
- **File upload security:** Validate file types (images only for photo ID and deliverables), max 10MB per file, virus scanning via ClamAV or cloud equivalent
- **Session management:** JWT access tokens (15-min expiry) + refresh tokens (30-day expiry, rotated on use). Revocation on password change or sign-out
- **CORS policy:** Restrict to known origins (app domains only)
- **Supabase RLS policies:** Agents can only read/write their own tasks. Runners can only read available tasks and their own accepted tasks. Neither role can access the other's payment data.
- **Logging:** All auth events (login, logout, failed attempts), all payment events, all admin actions logged to an immutable audit trail

#### Iteration 2 — Hardening
- **MFA for all users** (SMS OTP) — see Section 10.3
- **Account lockout:** 5 failed login attempts → 15-minute lockout → escalating cooldown
- **Password policy enforcement:** Minimum 8 chars, 1 uppercase, 1 number/symbol (validated client + server)
- **Penetration testing:** Third-party pentest before Iteration 2 launch
- **Dependency audit:** Automated scanning (Dependabot or Snyk) on all dependencies
- **CSP headers:** Content Security Policy on web interface
- **Photo ID handling:** Encrypted at rest (AES-256), auto-deleted 90 days after verification, access restricted to admin role only

#### Iteration 3 — Advanced
- **TOTP authenticator app** as MFA option (in addition to SMS)
- **API key rotation** for all third-party integrations
- **Anomaly detection:** Flag unusual patterns (rapid task creation, mass applications, location spoofing)
- **Device fingerprinting:** Track trusted devices, prompt MFA on new device login
- **Bug bounty program:** Responsible disclosure policy with rewards

#### Iteration 5 — Scale
- **Passkey/biometric auth** (FIDO2/WebAuthn)
- **SOC 2 Type II compliance** preparation (required for enterprise real estate brokerage partnerships)
- **Data residency:** Ensure PII is stored in-region for compliance
- **Incident response plan:** Documented runbook for data breaches, account compromises, platform abuse

### 15.3 Sensitive Data Inventory

| Data Type | Storage | Encryption | Retention | Access |
|---|---|---|---|---|
| Passwords | Supabase Auth (bcrypt) | Hashed, not reversible | Indefinite | None (hash only) |
| Photo IDs | Supabase Storage | AES-256 at rest | 90 days post-verification | Admin only |
| Payment tokens | Stripe (never on our servers) | Stripe-managed | Stripe-managed | None |
| Payout account info | Stripe Connect | Stripe-managed | Stripe-managed | None |
| Chat messages | Supabase (Postgres) | TLS in transit, encrypted at rest | 1 year | Participants + admin |
| Task deliverables (photos) | Supabase Storage | Encrypted at rest | 1 year after task completion | Agent + runner + admin |
| Location data | Supabase (Postgres) | Encrypted at rest | Current session only (not historicized) | Runner only (never exposed to agents) |
| License numbers | Supabase (Postgres) | Encrypted at rest | Indefinite (for re-verification) | User + admin |

---

## 16. Accessibility

### 16.1 Current Accessibility Profile

The design system (Section 11) was built with visual clarity in mind but has not been formally audited against WCAG 2.1. Here's an honest assessment:

| Area | Status | Issues |
|---|---|---|
| Color contrast | 🟢 Good — navy-on-white and red-on-white pass AA for large text | Red (#C8102E) on white is 4.6:1 — passes AA for large text, **fails AA for small text** (needs 4.5:1 body, 3:1 large) |
| Color-only indicators | 🔴 Problem — status badges rely on color alone (green/amber/red) | Need secondary indicator (icon or text) |
| Touch targets | 🟡 Mixed — most buttons are 44pt+, but some icon-only buttons (filter, settings) are 36×36 | Should be 44×44 minimum per WCAG 2.5.5 |
| Screen reader support | 🔴 Not specified — no ARIA labels, roles, or live regions defined | Must be added before launch |
| Keyboard navigation | 🟡 Not tested — web implementation needs focus management | Tab order, focus indicators, skip links needed |
| Dynamic content | 🔴 Not specified — modals, sheets, and toast notifications need aria-live regions | Screen readers won't announce status changes |
| Text scaling | 🟡 Mixed — most text uses relative sizing but some absolute px values | Needs audit for Dynamic Type (iOS) support |
| Motion sensitivity | 🟡 Partial — animations exist but no `prefers-reduced-motion` support | Need motion toggle |
| Form errors | 🔴 Not specified — validation feedback is visual only | Need inline error text with `aria-describedby` |

### 16.2 Accessibility Roadmap

#### Iteration 1 — WCAG 2.1 AA Baseline (Must-Have Before Launch)

**Color & Contrast:**
- Audit all text/background combinations against WCAG AA (4.5:1 body text, 3:1 large text, 3:1 UI components)
- Red (#C8102E) on white is 4.6:1 — passes for body text but is tight. Consider darkening to #B00D25 (5.2:1) for small text
- All status indicators must have a non-color secondary cue: icon (✓ for completed, ↻ for in-progress, • for posted) + text label
- Error states must not rely on red alone — include error icon + descriptive text

**Touch Targets:**
- All interactive elements: minimum 44×44pt hit area (even if visually smaller)
- The settings gear (currently 36×36), filter button (36×36), and OTP input boxes (48×56) need padding to reach 44pt minimum
- Spacing between adjacent tap targets: minimum 8pt gap

**Screen Reader Support (iOS: VoiceOver, Android: TalkBack):**
- All images: `accessibilityLabel` describing content (not file name)
- All buttons: descriptive labels (not just icon). E.g., filter button = "Filter available tasks", settings gear = "Notification settings"
- All status badges: read as "Status: Completed" not just the color
- Task cards: read as a single unit with combined label: "[type], [address], $[price], [status]"
- Navigation: announce screen title on push/pop transitions
- Modals/sheets: trap focus inside, announce on open, return focus on close
- Tab bar: announce current tab, badge count ("Notifications, 3 unread")
- Forms: label-input association via `accessibilityLabel` or `for/id` pairing
- Errors: announce immediately via `aria-live="assertive"` (web) or `UIAccessibility.post(.announcement)` (iOS)

**Keyboard Navigation (Web):**
- All interactive elements must be focusable and operable via keyboard
- Visible focus indicator (2px red outline, 2px offset)
- Tab order follows visual layout (top-to-bottom, left-to-right)
- Skip link to main content on every screen
- Escape closes modals/sheets
- Enter/Space activates buttons and cards

#### Iteration 2 — Enhanced

**Dynamic Type (iOS) / Font Scaling (Android/Web):**
- Support system font size preferences up to 200%
- All layouts must reflow without truncation at largest font size
- Test with Accessibility Inspector at all Dynamic Type sizes
- Fixed-height elements (status badges, tab bar) must grow with text

**Reduced Motion:**
- Respect `prefers-reduced-motion` / `UIAccessibility.isReduceMotionEnabled`
- Replace slide animations with instant transitions
- Stop any auto-advancing content (loading spinner is fine; auto-carousel is not)
- Document motion policy in design system (Section 11)

**Voice Control (iOS/web):**
- All buttons and links must have visible text labels (no icon-only buttons without labels)
- Support "Tap [button name]" voice commands

#### Iteration 4 — Advanced

**Cognitive Accessibility:**
- Reading level audit: all UI text at or below 8th-grade reading level
- Consistent navigation patterns across all screens (no novel interaction paradigms)
- Clear undo/cancel for all destructive actions (already partially done: sign-out confirmation)
- Progress indicators for all multi-step flows (already present)

**Localization Foundation:**
- All user-facing strings externalized (no inline text in components)
- RTL layout support (flexbox-based layouts are largely RTL-ready)
- Date, time, currency formatting via locale-aware formatters

### 16.3 Design System Updates Required

The following additions should be made to Section 11 (Design System Spec) before build:

1. **Add `accessibilityLabel` field** to every component in Section 11.3 (Component Library)
2. **Add focus state** to all interactive components (buttons, cards, inputs, tab bar items)
3. **Add `reducedMotion` variant** for all animated components
4. **Document minimum touch target sizes** in Section 11.6 (Platform Implementation Notes)
5. **Add semantic color roles** beyond visual: `successIndicator` (icon + color), `warningIndicator`, `errorIndicator`, `infoIndicator` — each with both color AND icon
6. **Add screen reader announcement patterns** for: navigation transitions, modal open/close, form validation, task status changes, notification arrival

---

## 17. Testing Strategy

This spec is intended to be re-implementable and testable. The minimum test suite for a compliant implementation is:

### 17.1 Test layers
- **Unit tests (domain + pricing):** pricing rules, state transitions, time-window fee logic, eligibility gates, notification routing decisions.
- **Contract tests (provider adapters):** Stripe Connect, Twilio/Push provider, Map/geocoding, BackgroundCheckProvider (Checkr), Storage (image uploads). Use recorded fixtures or sandbox environments.
- **Integration tests (API):** end-to-end flows against a test database: Agent creates task → Runner applies → Agent assigns runner → Runner submits deliverables → Agent approves completion → payout created; plus cancellation/refund paths.
- **UI automation (iOS):** critical happy paths + one failure path per key screen (login, task create, apply, complete, payout).

### 17.2 Deterministic test data
- Use fixed clocks (`TestClock`) for all time-window rules (cancellation tiers, application/assignment SLA, notification retries).
- Use seeded geo fixtures (known coordinates + travel times) for matching; do not rely on live map traffic in tests.
- Use idempotency keys in payment tests; assert idempotency behavior.

### 17.3 Acceptance criteria mapping
Each requirement in **Sections 7–10 (functional behavior)** and **Sections 15–16 (non-functional requirements)** must map to at least one automated test. Maintain a traceability table (Requirement → Test IDs) in the repo.

### 17.4 Minimum automated scenarios (must-pass)
1. **Auth:** agent and runner can sign up/sign in; session persists; logout revokes refresh token.
2. **Vetting gate:** runner cannot apply to tasks until vetting passes; rejection shows reason; appeal request can be submitted.
3. **Task lifecycle:** create → posted → application submitted → accepted (assigned) → in_progress → deliverables_submitted → completed; invalid transitions rejected with explicit error codes.
4. **Matching + assignment:** only eligible runners inside coverage are notified; multiple applications can be pending; only one application can be accepted and assignment is atomic.
5. **Cancellation:** fees apply correctly for <24h and <2h windows; payouts/refunds reflect policy.
6. **Payout:** runner payout uses Stripe Connect; platform fee deducted; payout status is visible to runner; retries on transient failures.
7. **Notifications:** DB notification rows are created for application/assignment, cancellation, completion, and approval; push/SMS fan-out retries with backoff; audit log captured.

---
## 18. iOS Implementation Status

This section tracks what has been built and deployed for the iOS MVP.

### 18.1 Supabase Backend (Deployed)

| Component | Status | Notes |
|---|---|---|
| Database schema (core tables + incremental migrations) | Deployed | PostGIS, triggers, indexes, views |
| RLS policies | Deployed | All tables, including `users_select_task_counterparts` |
| `notify_task_status_change()` trigger | Deployed | Both-party notifications on all status changes |
| `post-task` edge function | Deployed | With geocoding, PaymentIntent |
| `accept-runner` edge function | Deployed | Atomic runner assignment |
| `approve-and-pay` edge function | Deployed | PaymentIntent capture + payout |
| `cancel-task` edge function | Deployed | Cancellation with fee logic |
| `submit-deliverables` edge function | Deployed | File validation + status update |
| `create-setup-intent` edge function | Deployed | Stripe Customer + SetupIntent |
| `create-connect-link` edge function | Deployed | Stripe Connect Express onboarding |
| `accept_task` RPC function | Deployed (legacy) | Legacy first-accept helper from earlier flow; superseded by application + `accept-runner` assignment model |
| Supabase Storage | Deployed | Avatar uploads, deliverable storage |
| CORS headers | Deployed | All edge functions |

### 18.2 iOS App (Built — 22+ Swift Files)

| Screen / Feature | Status | Key File(s) |
|---|---|---|
| Splash + Landing | Built | `SplashView.swift`, `LandingView.swift` |
| Create Account (3-step) | Built | `CreateAccountView.swift` |
| Login | Built | `LoginView.swift` |
| Onboarding flow (welcome → category → task form) | Built | `OnboardingFlowView.swift`, `OnboardingWelcomeView.swift`, `OnboardingCategoryView.swift`, `OnboardingTaskFormView.swift` |
| Agent Dashboard | Built | `AgentDashboardView.swift` |
| Runner Dashboard | Built | `RunnerDashboardView.swift` |
| All Tasks (filtered list) | Built | `AllTasksView.swift`, `FilteredTaskListView.swift` |
| Task Detail (agent + runner views) | Built | `TaskDetailView.swift` — includes MapKit map, runner avatar, static time display |
| Task Creation Sheet | Built | `TaskCreationSheet.swift` — with address autocomplete + locking |
| Notifications | Built | `NotificationsView.swift` — pull-to-refresh, mark-as-read, settings deep link |
| Per-task messaging / chat | Built (MVP text chat) | `MessagingView.swift`, `MessageService.swift` |
| Profile Home | Built | `ProfileHomeView.swift` |
| Personal Information | Built | `PersonalInfoView.swift` — with brokerage autocomplete + locking |
| Payment Methods (agent) | Built | `PaymentMethodsView.swift` — Stripe PaymentSheet integration |
| Payout Settings (runner) | Built | `PayoutSettingsView.swift` — Stripe Connect Express |
| Notification Settings | Built | `NotificationSettingsView.swift` |
| Account & Security | Built | `AccountSecurityView.swift`, `ChangePasswordSheet.swift` |
| Task History (agent) | Built | `TaskHistoryView.swift` |
| Earnings & Payouts (runner) | Built | `EarningsView.swift` |
| Service Areas (runner) | Built (UI) | `ServiceAreasView.swift` |
| Availability (runner) | Built (UI) | `AvailabilityView.swift` |
| Design system (colors, typography, spacing, shadows) | Built | `Theme/` directory |
| Reusable components (PillButton, InputField, StatusBadge, etc.) | Built | `Theme/Components/` directory |
| AvatarView component | Built | `Theme/Components/AvatarView.swift` |
| Deep linking (URL scheme + handler) | Built | `Info.plist`, `AgentFloApp.swift` |
| Centralized auth for edge functions | Built | `TaskService.authHeaders()` pattern |
| Rating & review system (Lyft-style) | Built | `ReviewSheet.swift` (iOS), `review-modal.tsx` (web) — Lyft-style star rating + tag chips + optional text. See Section 12.17 |
| Review display on public profile | Built | `PublicProfileReadOnlyView.swift` — reviewer avatar, name, relative time, stars, went-well tags, conditional could-improve tags, review text |
| Runner Public Profile | Built | `RunnerPublicProfileView.swift` — runner-facing profile with stats and portfolio |
| Photography capture & upload | Built | `CameraView.swift`, `PhotoUploadView.swift`, `PhotoGalleryView.swift` — on-site photo capture, upload, gallery review |
| Document upload & list | Built | `DocumentUploadView.swift`, `DocumentListView.swift` — non-photo deliverable upload and viewing |
| Staging photo workflow | Built | `StagingPhotoView.swift`, `StagingComparisonView.swift` — room-by-room guided capture, before/after comparison |
| Showing report form | Built | `ShowingReportForm.swift` — structured buyer feedback, interest level, follow-up notes |
| Open House QR & visitor dashboard | Built | `OpenHouseQRView.swift`, `OpenHouseVisitorDashboard.swift` — QR generation, live check-in dashboard, interest tracking |
| Check-in/check-out card | Built | `CheckInCheckOutCard.swift` — GPS-verified check-in/out timestamps and coordinates |
| Inspection checklist & reporting | Built | `InspectionChecklistView.swift`, `InspectionReportView.swift`, `InspectionFindingForm.swift`, `InspectionSystemCard.swift` — ASHI 10-system checklist, findings form, tabbed report viewer |
| Chat message bubble | Built | `MessageBubble.swift` — outgoing/incoming bubble styling with `navy-solid` background (dark-mode safe) |

### 18.3 Not Yet Built

| Feature | Section | Priority |
|---|---|---|
| ~~Open House check-in/check-out flow~~ | — | **Built** — see 18.2 |
| Public Profile data integration (stats/tags/certifications) | 12.17, Appendix B | Next |
| Push notifications (remote) | 10.4 | Future |
| Deliverable photo gallery review | 12.5 | Future |
| Service Areas persistence + geospatial matching integration | 12.14, 13.2 | Future |
| Availability persistence + availability gating integration | 12.15, 13.2 | Future |
| ~~Rating & review system~~ | 13.2, 12.17 | **Built** — see 18.2 |
| Profile stats materialized view (`user_stats`) | 13.2 | Future |
| User certifications & service tags | 13.2, 12.17 | Future |
| Profile completeness prompt | 12.8 | Future |
| Admin vetting interface | 10.1 | Future |
| Web app (React) | 11.6 | Future |

---

## Appendix A — Deliverable Type Mini Specs

**Functional Requirements for Task Completion & Submission**
**v1.0 | March 2026**
**Covers:** Photography, Property Showings, Staging, Open Houses, Inspections

---

### A.1 Photography

#### A.1.1 Overview

The Photography deliverable captures professional listing photos for MLS, marketing, and agent use. Task runners (photographers) receive a shot list defined by the agent, execute the shoot on-site, edit photos to spec, and deliver the final gallery through the app. This is the most deliverable-heavy task type with the strictest quality requirements.

#### A.1.2 Deliverable Requirements

| Component | Requirement |
|---|---|
| Photo Gallery | Full set of edited photos uploaded as JPG/HEIC. Minimum resolution: 3000x2000px. |
| Highlight Reel | Agent-selectable subset (5–10 photos) auto-tagged as MLS-ready. Runner can pre-select. |
| Shot List Completion | Checklist verification that all rooms/angles from the agent brief were captured. |
| Metadata | Each photo tagged with: room name, orientation, shot type (wide/detail/aerial). |
| Editing Standard | White-balanced, lens-corrected, verticals straightened. HDR blending if specified in brief. |

#### A.1.3 Agent Brief Configuration

When posting a Photography task, the agent defines:

- Shot list by room (e.g., Kitchen — wide + detail, Master — 3 angles)
- Editing style preference: Natural, Bright & Airy, Twilight, HDR
- Output format: MLS-optimized (auto-crop to 4:3), Social (1:1, 9:16), or Full Resolution
- Delivery deadline (default: 24 hours post-shoot)
- Special instructions: drone shots, virtual staging prep, specific angles

#### A.1.4 In-App Workflow

**Runner Side:** Accept task → Review shot list & property details → Check in on-site (GPS + timestamp) → Shoot (app tracks room-by-room progress against shot list) → Upload raw + edited photos → Tag each photo by room/type → Mark highlight reel selections → Submit for review.

**Agent Side:** Receive notification → Review full gallery with room-by-room navigation → Approve, request re-edits on specific photos (annotate with markup), or reject with notes → Download approved photos individually or as ZIP → One-tap export to MLS format.

#### A.1.5 Completion Gate

Task cannot be marked complete until: all shot list items are checked off, minimum photo count is met, and at least 5 photos are tagged as highlight reel. Payment releases upon agent approval or auto-approves after 48 hours with no response.

---

### A.2 Property Showings

#### A.2.1 Overview

A Showing task delegates a property tour to a runner on behalf of the listing or buyer's agent. The deliverable is a structured showing report that captures buyer feedback, interest level, and any questions or concerns raised during the visit. The goal is to give the agent the same quality of insight they'd get if they conducted the showing themselves.

#### A.2.2 Deliverable Requirements

| Component | Requirement |
|---|---|
| Showing Report | Structured form: buyer name, interest level (1–5), key questions asked, property feedback, and next steps. |
| Time Log | GPS-verified check-in and check-out with timestamps. Total time on-site calculated automatically. |
| Buyer Interest Rating | Categorical: Not Interested, Somewhat Interested, Very Interested, Likely to Make Offer. |
| Follow-up Notes | Any requested information (comps, HOA docs, school district info) the buyer asked about. |
| Photos (Optional) | Runner can attach photos of property condition, damage, or items the buyer flagged. |

#### A.2.3 Agent Brief Configuration

- Buyer contact info and preferences (pre-populated from CRM if connected)
- Property access instructions (lockbox code, gate code, contact for entry)
- Talking points or features to highlight during the tour
- Disclosure documents to share with buyer (auto-attached to runner's task view)
- Showing window (date/time range buyer is available)

#### A.2.4 In-App Workflow

**Runner Side:** Accept task → Review property details, access instructions, and talking points → GPS check-in at property → Conduct showing → Complete structured report form on-site (optimized for quick entry with pre-filled templates) → Rate buyer interest level → Add follow-up notes → GPS check-out → Submit.

**Agent Side:** Receive showing report notification (push + email) → Review buyer feedback and interest level → View time log for accountability → Follow up with buyer directly using provided notes → Approve report to release payment.

#### A.2.5 Completion Gate

Task requires: GPS-verified check-in/check-out, completed showing report form (all required fields), and buyer interest rating. Auto-approval after 24 hours if agent does not respond.

---

### A.3 Staging

#### A.3.1 Overview

Staging tasks involve a runner setting up furniture, décor, and accessories in a property to prepare it for listing photos and showings. Deliverables focus on documentation: before/after photos, an inventory of placed items, and a condition report that protects both the agent and the staging provider.

#### A.3.2 Deliverable Requirements

| Component | Requirement |
|---|---|
| Before/After Photos | Photo pairs for each staged room. Before photo taken at arrival, after photo from same angle post-staging. |
| Inventory List | Itemized list of all placed items with room assignment, item description, and quantity. |
| Condition Report | Pre-existing property damage documented with photos before staging begins. Protects both parties. |
| Setup Confirmation | Room-by-room checklist confirming placement matches the staging plan from the agent brief. |
| De-stage Schedule | Agreed removal date logged. Triggers automated reminder to agent 3 days before de-stage. |

#### A.3.3 Agent Brief Configuration

- Staging plan: which rooms, style (modern, farmhouse, coastal, etc.)
- Inventory source: runner's own inventory, third-party rental, or agent-provided
- Property access instructions and staging window
- Budget ceiling for rental items (if applicable)
- Duration: how long staging should remain in place before de-stage

#### A.3.4 In-App Workflow

**Runner Side:** Accept task → Review staging plan and room assignments → GPS check-in → Document pre-existing conditions (guided photo capture by room) → Execute staging per plan → Capture before/after photo pairs → Complete inventory checklist → Submit for review.

**Agent Side:** Review before/after gallery → Verify staging matches plan → Approve or request adjustments → Confirm de-stage date → Receive automated reminders before de-stage deadline.

#### A.3.5 Completion Gate

Task requires: before/after photo pairs for all rooms in the staging plan, completed inventory list, condition report with at least one pre-staging walkthrough photo per room, and confirmed de-stage date. Payment releases upon agent approval.

---

### A.4 Open Houses

#### A.4.1 Overview

Open House tasks are the most complex deliverable type, combining on-site event management with real-time lead capture and post-event reporting. The key innovation is the QR Check-In App Clip, which automates visitor sign-in and syncs data directly to the runner's dashboard and the agent's task view — eliminating paper sign-in sheets entirely.

#### A.4.2 Deliverable Requirements

| Component | Requirement |
|---|---|
| Visitor Data | Auto-collected via QR check-in: name, email, phone, pre-approval status, agent representation, interest level. |
| Event Summary Report | Total visitors, avg. time on-site, pre-approved count, top questions/feedback themes, overall sentiment. |
| Lead Export | One-tap export of all visitor contacts as CSV or direct-to-CRM push. Segmented by interest level. |
| Photos | Event photos showing foot traffic, signage placement, property presentation. |
| Follow-up Queue | AI-generated suggested follow-up messages for each visitor based on their interest level and questions. |

#### A.4.3 QR Check-In App Clip

The QR Check-In is a lightweight web experience (iOS App Clip or Android Instant App) that loads when visitors scan a QR code displayed at the open house. Key design principles:

- No app download required — loads instantly from QR scan via mobile browser
- Minimal friction: name + email/phone required, everything else optional
- Pre-approval status and agent representation captured via toggle buttons
- Interest level selector (Just Looking / Interested / Very Interested)
- Confirmation screen shows property highlights and listing agent info
- Data syncs to runner dashboard in real-time via Supabase Realtime
- Privacy-compliant: visitor consent captured at submission, opt-out link included

#### A.4.4 In-App Workflow

**Runner Side:** Accept task → Review property details and open house schedule → GPS check-in → Generate unique QR code for event (app auto-generates, printable) → Display QR at entry points → Monitor live check-in dashboard during event → Capture event photos → Complete summary report (pre-populated with check-in stats) → Submit.

**Agent Side:** Optionally monitor live check-in feed during event → Receive post-event summary report → Review visitor data with interest-level segmentation → Export leads to CRM → Review AI-suggested follow-up messages → Approve report.

#### A.4.5 Completion Gate

Task requires: GPS-verified check-in/check-out spanning the full open house window, QR code activation (system verifies code was generated), completed summary report, and at least 2 event photos. Visitor data auto-populates from QR check-ins. Payment releases upon agent approval or auto-approves after 48 hours.

---

### A.5 Inspections

#### A.5.1 Overview

Inspection tasks connect agents with licensed home inspectors who deliver ASHI-compliant inspection reports enhanced by AI intelligence. The deliverable follows the industry-standard 10-system checklist (Structure, Exterior, Roofing, Plumbing, Electrical, HVAC, Interior, Insulation & Ventilation, Fireplaces, Site/Grounds) but wraps findings in an interactive, media-rich experience with AI-generated cost estimates, plain-English explanations, and negotiation insights.

#### A.5.2 Deliverable Requirements

| Component | Requirement |
|---|---|
| ASHI-Compliant Report | All 10 ASHI system categories inspected. Each finding includes: deficiency description, severity (Critical/Major/Minor/Monitor/Good), recommendation, and reasoning. |
| Photo Documentation | Photos attached to each finding. Annotated where applicable (circles, arrows pointing to defects). |
| AI Insight Layer | Auto-generated for each finding: localized cost estimate (low/typical/high), contextual explanation (why this defect occurs in this home type/region), and priority classification. |
| Interactive Report | In-app report viewer with severity filtering, system-by-system navigation, score rings, and cost breakdown dashboard. |
| Chat with Report | ContractIQ-powered conversational interface. Users can ask about deal-breakers, total costs, negotiation strategy, or get plain-English explanations. |
| PDF Export | Traditional PDF report generated from structured data for lender/legal requirements. Includes all photos, findings, and AI summaries. |

#### A.5.3 ASHI System Categories & Checklist

Inspectors complete a structured checklist aligned to the ASHI Standard of Practice (effective March 2014). Each category contains sub-items that the inspector marks as: **Inspected — Good**, **Inspected — Deficiency Found**, **Not Inspected** (with reason), or **Not Applicable**.

| # | System | Key Sub-Items |
|---|---|---|
| 1 | Structure/Foundation | Foundation walls, floor framing, wall framing, columns, ceiling framing, roof framing |
| 2 | Exterior | Wall coverings, flashing, trim, doors, decks/balconies, eaves/soffits, grading/drainage, walkways |
| 3 | Roofing | Roofing materials, drainage systems, flashings, skylights, chimneys, penetrations |
| 4 | Plumbing | Supply/distribution, fixtures, drains/waste/vents, water heater, fuel storage/distribution |
| 5 | Electrical | Service drop, main panel, sub-panels, branch circuits, receptacles, GFCI/AFCI, grounding |
| 6 | Heating | Heat source, distribution, controls, chimneys/vents, fuel storage |
| 7 | Cooling | Central AC, distribution, controls, refrigerant lines |
| 8 | Interior | Walls, ceilings, floors, stairs/railings, countertops, cabinets, doors, windows |
| 9 | Insulation & Ventilation | Insulation in unfinished spaces, vapor retarders, ventilation systems, exhaust fans |
| 10 | Fireplaces & Chimneys | Fuel-burning fireplaces/stoves/inserts, dampers, hearth extensions, vents/flues |

#### A.5.4 AI Enhancement Pipeline

When an inspector submits raw findings, the AI layer processes each deficiency through three enrichment stages:

- **Cost Estimation:** Cross-references defect type, property age, square footage, and regional labor/material rates to generate low/typical/high repair cost ranges. Updated quarterly with market data.
- **Contextual Explanation:** Explains why this defect commonly occurs in homes of this type, age, and geographic area. Helps buyers understand severity without relying on inspector jargon.
- **Priority Classification:** Groups findings into Immediate (safety), Short-term (6–12 months), Long-term (1–3 years), and Monitor categories. Calculates total estimated repair costs and percentage of list price.

Additionally, the **Chat with Report** feature (powered by ContractIQ) enables conversational queries against the full report data. Pre-built quick-ask prompts include: deal-breaker identification, total cost summary, negotiation strategy suggestions, and adaptive explain-like-I'm modes (first-time buyer, investor, agent).

#### A.5.5 In-App Workflow

**Inspector (Runner) Side:** Accept task → Review property details and any agent notes → GPS check-in → Conduct inspection using ASHI-structured checklist (room-by-room guided flow in app) → Capture photos inline with findings (annotate on-device) → Log each deficiency with severity rating and description → Submit raw report → AI layer auto-enriches within 60 seconds.

**Agent/Buyer Side:** Receive enriched report notification → Open interactive report viewer (Overview / Findings / Costs tabs) → Tap into any system category for detailed findings with AI insights → Use Chat with Report to ask questions in natural language → Export PDF for lender or legal use → Generate repair request list directly from flagged items → Share report with buyer/seller as interactive link or PDF.

#### A.5.6 Completion Gate

Task requires: GPS-verified on-site presence for minimum 2 hours, all 10 ASHI system categories addressed (inspected or marked N/A with reason), at least 25 photos attached to findings, and inspector license number verified against state registry. AI enrichment runs automatically post-submission. Agent review is informational only — inspectors maintain professional independence per ASHI Code of Ethics (agent cannot require changes to findings). Payment releases upon submission.

---

### A.6 Cross-Cutting Patterns

#### A.6.1 Universal Completion Requirements

All deliverable types share these requirements before a task can be marked complete:

- GPS-verified check-in and check-out at the property address
- All required deliverable components submitted (type-specific, see above)
- Minimum photo documentation attached where required
- Time-stamped submission within the task deadline

#### A.6.2 Payment Release Flow

Deliverable submission gates payment release through a consistent approval workflow:

Runner submits deliverables → Agent receives notification → Agent reviews & approves/requests revisions → Payment releases to runner

Auto-approval timers vary by task type: Photography and Open Houses auto-approve after 48 hours, Showings after 24 hours, Staging after 48 hours, Inspections release immediately upon submission (inspector independence).

#### A.6.3 Revision Workflow

When an agent requests revisions, the runner receives a notification with specific, annotated feedback. The runner can:

- **Accept** the revision request (re-opens the deliverable for editing)
- **Dispute** the request (escalates to Agent Flo support)
- **Revision window expires** after 72 hours (auto-approves original submission)

#### A.6.4 Data Architecture

All deliverables are stored in a unified schema with type-specific extensions:

| Table | Scope | Key Fields |
|---|---|---|
| `task_deliverables` | All types | task_id, type, status, submitted_at, approved_at, revision_count |
| `deliverable_photos` | All types | deliverable_id, url, room, tags[], annotations_json, sort_order |
| `deliverable_checkins` | Open House | deliverable_id, visitor_name, email, phone, interest_level, pre_approved |
| `deliverable_inspection_findings` | Inspections | deliverable_id, system_category, severity, description, ai_insight_json, cost_json |
| `deliverable_showing_reports` | Showings | deliverable_id, buyer_interest, questions_json, follow_up_notes, time_on_site |
| `deliverable_staging_inventory` | Staging | deliverable_id, item_description, room, quantity, condition, destage_date |

---

## Appendix B — Public Profile Mini Spec

**Feature: Public Profile**
**v1.0 | March 2026**
**View Spec:** Section 12.17 | **Data Model:** Section 13.2

### B.1 Overview

The Public Profile is the public-facing identity for users on Agent Flo. It serves two core purposes: helping task-posting agents evaluate and select runners for their jobs, and giving task runners a professional presence that drives repeat business. The profile is accessible from multiple entry points and adapts its navigation context accordingly. See Section 12.17 for the complete view specification.

### B.2 Data Model Integration

The mini spec proposed six new tables. After analysis against the existing schema (Section 13.2), the following resolutions were applied to avoid duplication:

#### Resolved: `agent_profile` → Extended `users` table

The mini spec proposed a standalone `agent_profile` table. This would duplicate fields already present in `users` (`full_name`, `avatar_url`, `bio`) and create a 1:1 relationship that adds query complexity without benefit. Instead, the following columns were added directly to `users`:

| New Column | Type | Mini Spec Equivalent | Resolution |
|---|---|---|---|
| `cover_photo_url` | `text` | `agent_profile.cover_photo_url` | New column on `users` |
| `location_city` | `text` | `agent_profile.location_city` | New column on `users` |
| `location_state` | `text` | `agent_profile.location_state` | New column on `users`. Note: existing `license_state` is for vetting; `location_state` is for display. |
| `is_online` | `boolean` | `agent_profile.is_online` | New column on `users`. Derived from availability settings. |
| `response_time` | `interval` | `agent_profile.response_time` | New column on `users` |
| — | — | `agent_profile.display_name` | **Dropped.** Use `users.full_name`. |
| — | — | `agent_profile.member_since` | **Dropped.** Use `users.created_at`. |
| — | — | `agent_profile.is_verified` | **Dropped.** Derive from `users.vetting_status = 'approved'`. Verified badge criteria: photo uploaded, full name confirmed, real estate license validated. |

#### Resolved: `reviews` → Existing table sufficient

The mini spec proposed a `reviews` table with `agent_id`/`author_id` columns. The existing `reviews` table (Section 13.2) uses `reviewer_id`/`reviewee_id`, which is more flexible — it supports bidirectional reviews (agent reviews runner AND runner reviews agent). The existing schema is retained.

| Mini Spec Field | Existing Equivalent | Resolution |
|---|---|---|
| `agent_id` | `reviewee_id` | Same semantics, existing name is role-agnostic |
| `author_id` | `reviewer_id` | Same semantics |
| `text` | `comment` | Same semantics, existing name retained |
| `task_type` | — | **Not denormalized.** Derive via `JOIN tasks ON reviews.task_id = tasks.id` → `tasks.category`. This avoids data duplication and stays consistent with the existing schema pattern. |

#### New tables added to Section 13.2

| Table | Mini Spec Name | Resolution |
|---|---|---|
| `user_service_tags` | `agent_service_tags` | Renamed to `user_` prefix for role-agnosticism. Uses `text` category (matching `tasks.category`) instead of FK to nonexistent `task_categories` table. |
| `user_certifications` | `agent_certifications` | Renamed to `user_` prefix. Separate from `vetting_records` — certifications are public-facing display; vetting records are admin audit trail. |
| `user_stats` | `agent_stats` | Renamed to `user_` prefix. Materialized view, not a table. Refreshed periodically or on task completion. |
| `task_history_by_category` | `task_history` | SQL view aggregating completed tasks by runner and category. |

### B.3 Design Token Resolution

The mini spec prototype used iOS system colors (UIKit defaults) that differ from the master spec's design system (Section 11.2). All prototype tokens are mapped to the canonical palette:

| Mini Spec Token | Prototype Value | Canonical Token | Canonical Value | Action |
|---|---|---|---|---|
| Primary accent | `#C8102E` | `red` | `#C8102E` | Match — no change |
| Primary light | `#FEF0F2` | `red-light` | `#FDE8EC` | **Use `red-light`.** Prototype value was an iOS approximation. |
| Background | `#F2F2F7` | `border-light` | `#F1F5F9` | **Use `border-light`.** Nearest equivalent in the existing palette. |
| Card | `#FFFFFF` | `surface` | `#FFFFFF` | Match — no change |
| Text primary | `#1C1C1E` | `navy` | `#0A1628` | **Use `navy`.** Prototype used iOS `label` color. |
| Text secondary | `#636366` | `slate` | `#64748B` | **Use `slate`.** Prototype used iOS `secondaryLabel`. |
| Text tertiary | `#AEAEB2` | `slate-light` | `#94A3B8` | **Use `slate-light`.** Prototype used iOS `tertiaryLabel`. |
| Separator | `#E5E5EA` | `border` | `#E2E8F0` | **Use `border`.** |
| Online/success | `#34C759` | `green` | `#10B981` | **Use `green`.** Prototype used iOS system green. |
| Gold/rating | `#FF9500` | `amber` | `#F59E0B` | **Use `amber`.** Prototype used iOS system orange. |
| Font family | DM Sans | SF Pro (iOS default) | — | **Use system font.** DM Sans was a prototype choice; iOS apps should use the system font per Section 11 principles. |
| Button radius | 12px | Pill | 9999px | **Use pill (9999px).** Per Section 11.3, all buttons use pill radius. |
| Tag radius | 20px | Pill | 9999px | **Use pill (9999px).** |
| Card radius | 14px | — | — | **New token.** Added as `card-radius: 14px` for content cards. |

### B.4 Open Questions (Resolved)

| # | Question | Resolution |
|---|---|---|
| 1 | Cover photo: custom upload or auto-generate? | Auto-suggest best portfolio shot as default; user may upload custom cover photo. |
| 2 | Portfolio tab as third tab for deliverable samples? | No. Two tabs only (Reviews + About). |
| 3 | Review pagination: infinite scroll vs. "Show more"? | "Show more" — loads 10 at a time. |
| 4 | Availability/online indicator display? | Online dot derived from availability settings: green when within active availability window, gray otherwise. No manual toggle. |
| 5 | Profile completeness progress indicator? | Yes — dismissible card on Profile Home (Section 12.8) with progress indicator and checklist of incomplete items. |
| 6 | Verified badge criteria? | Three requirements: photo uploaded, full name confirmed, real estate license validated via vetting (Section 10.1). |

---

### v1.2 (March 3, 2026)
- **Appendix B:** New — Public Profile Mini Spec. Full feature spec for the public-facing user profile with entry points from Profile tab (self-view) and Task Detail (assignment flow). Includes data model integration analysis resolving 6 proposed tables against existing schema, design token resolution mapping prototype iOS colors to canonical palette, and resolved open questions.
- **Section 12.8 (Profile Home):** Rewritten header as Account Summary Card with online indicator, account type, email, task stats, and "View Public Profile" button. Added Profile Completeness Card (dismissible) with progress indicator for incomplete profiles.
- **Section 12.17:** New — Public Profile view spec. Full screen specification covering header region with cover photo, identity block with verified badge, service tags, stats row with percentile badges, dual CTA buttons (Request Task + Message), and tabbed content (Reviews with "Show more" pagination, About with bio/task history/certifications).
- **Section 13.1 (ER Diagram):** Updated to include `user_service_tags`, `user_certifications`, and `user_stats` entities.
- **Section 13.2 (Entities):** `users` table extended with 5 new columns: `cover_photo_url`, `location_city`, `location_state`, `is_online`, `response_time`. 4 new entities added: `user_service_tags` (junction table to task categories), `user_certifications` (public-facing credentials), `user_stats` (materialized view for profile stats), `task_history_by_category` (SQL view).
- **Section 18.3 (Not Yet Built):** Added Public Profile, rating & review system, profile stats view, certifications & service tags, and profile completeness prompt.

### v1.1 (March 3, 2026)
- **Appendix A:** New — Deliverable Type Mini Specs. Complete functional requirements for task completion and submission across all 5 task types: Photography (A.1), Property Showings (A.2), Staging (A.3), Open Houses (A.4), and Inspections (A.5). Each type specifies deliverable requirements, agent brief configuration, in-app workflow (runner + agent sides), and completion gates. Cross-cutting patterns (A.6) cover universal completion requirements, payment release flow with per-type auto-approval timers, revision workflow, and unified data architecture with 6 deliverable tables.

### v1.0 (March 1, 2026)
- **Status:** Changed from "Draft — Pre-Development" to "In Development — iOS MVP"
- **Section 2 (Constraints):** Fourth category confirmed as Open House (was "TBD")
- **Section 5 (Navigation):** Added `agentflo://` URL scheme registration, Stripe Connect deep link (`agentflo://stripe-connect`), `onOpenURL` handler. Deep link inventory expanded with Stripe Connect entries.
- **Section 7 (Core Flows):** Added In-App Notifications subsection documenting the PostgreSQL trigger-based notification system. Both-party notification model: every status change notifies both agent and runner. Notification table with trigger details, client loading behavior (pull-to-refresh, `onAppear` reload, `hasLoadedOnce` guard), mark-as-read via `read_at` timestamp update.
- **Section 9 (Payments):** Rewritten with implementation details. Agent payment source uses Stripe SetupIntent + PaymentSheet SDK. Runner payout uses Stripe Connect Express with hosted onboarding. Centralized `TaskService.authHeaders()` pattern documented. CORS policy documented.
- **Section 10.2 (Stripe):** Updated with implementation specifics — SetupIntent flow, Connect Express accounts, `create-setup-intent` and `create-connect-link` edge functions, return URL scheme, service role key usage, Stripe API version.
- **Section 11.3 (Components):** Added InputField clear button spec (`xmark.circle.fill` on trailing edge for non-empty, non-secure fields). Added Autocomplete Locking pattern (lock-after-selection with clear-to-reset for address and brokerage fields). AvatarView updated with implementation details — `red-light` background with initial fallback, image loading from Supabase Storage, usage on Task Detail runner info section.
- **Section 11.6 (Platform Notes):** iOS section expanded with build target details (iOS 26, Xcode 26.2, Swift 5), Supabase project ref, bundle ID, team ID. Added: scroll indicators hidden globally, `@Observable` state management, Supabase Swift SDK v2 details, MapKit integration, Stripe SDK integration, URL scheme, `RelativeDateTimeFormatter` usage.
- **Section 12.3 (Filtered Task List):** Renamed to "All Tasks". Filter chips expanded to include all statuses: All, Draft, Posted, Accepted, In Progress, Completed, Cancelled.
- **Section 12.4 (Notifications):** Added data loading and refresh behavior — `hasLoadedOnce` guard, `onAppear` reload, pull-to-refresh. Mark-as-read updates `read_at` timestamp with immediate local model update.
- **Section 12.5 (Task Detail):** Added Map Section (MapKit `Map` with `CLGeocoder` address geocoding, 180px height, `Marker` annotation). Added Assigned Runner Section with `AvatarView` (loaded from Supabase Storage), runner name, and static time-ago display using `RelativeDateTimeFormatter`.
- **Section 12.10 (Payment/Payout):** Rewritten with implementation details for both roles. Agent: PaymentSheet flow, has/no payment method states, Stripe UI presentation. Runner: Connect Express flow, hosted onboarding, return URL scheme handling.
- **Section 13.4 (RLS):** Added `users_select_task_counterparts` policy for cross-role profile visibility.
- **Section 13.7 (Edge Functions):** Added `create-setup-intent` and `create-connect-link` functions with status. Added Database Triggers table documenting `trg_task_status_notify`, `trg_task_point`, and `updated_at` triggers. Added CORS and Deno runtime notes.
- **Section 18:** New — iOS Implementation Status. Tracks all deployed backend components, all built iOS screens/features, and remaining work.

### v1.1 (March 4, 2026)
- **Section 6.1.2 (Landing Screen):** Expanded from stub to full screen specification. Added informational feature carousel (Section 6.1.2.1) — four horizontally swipeable slides introducing Showings, Inspections, Messaging, and Profile & Trust. Carousel is pre-authentication only; swipe interaction, no nav buttons. Auto-advances every 4.5 seconds. Full slide copy, tag labels, and design token table documented. Illustration asset reference table added with filenames for all four SVG exports.

### v0.9 (February 28, 2026)
- **Section 13:** Replaced placeholder with complete Data Model, Schema & API. 12 database tables with full column definitions, types, constraints, and indexes. 2 state machine diagrams (task lifecycle, vetting). RLS policies for all tables. Complete Supabase SQL schema (production-ready DDL with PostGIS, triggers, views, helper functions). GraphQL API with 5 queries, 10 mutations, 2 realtime subscriptions. 6 Edge Functions for business logic. Platform implementation notes for iOS and web.
- **Section 12.1:** Post-onboarding banner changed from dismissable card to tappable card with navigation. "View Task →" (posted) and "Finish Draft →" (draft) links navigate to newly created task detail. × dismiss stops propagation. Explicitly documented as inline card, not toast.
- **Prototype v9:** Celebration banner now tappable — navigates to mock task detail (id: 99, Photography, $150). Posted tasks show status "posted", drafts show status "draft". × dismiss button stops propagation so it doesn't trigger navigation. Added `draft` status badge (slate/borderLight). TaskDetail shows "Edit & Post Task" CTA for draft status. Added `onViewNewTask` prop to AgentDash.

### v0.8 (February 28, 2026)
- **Section 5 (Navigation):** Routing & Deep Linking rewritten. Established `deepLink(tab, screen)` paradigm as the universal cross-tab navigation model. Documented 5 rules (tab switches first, tab bar reflects destination, back returns to tab root not source, applies everywhere). Added deep link choreography sequence and current deep link inventory table (5 entries: notif gear, notif tap task, notif tap message, profile completion pill, push notification).
- **Section 12.1 (Agent Dashboard):** Added Post-Onboarding Acknowledgement Banner — conditional card shown once after onboarding with two variants: "Your first task is live!" (green, task posted) or "Draft saved!" (amber, draft saved). Dismissable, fadeUp animation. Progressive Onboarding Card pills are now tappable — each deep links to the target screen within Profile tab.
- **Section 12.4 (Notifications):** Updated settings gear behavior to specify deep link paradigm explicitly — switches to Profile tab, pushes Notification Settings, back returns to Profile root.
- **Section 17:** Testing Strategy collapsed to placeholder (deferred to future session).
- **Prototype v8:**
  - Post-onboarding celebration: "Post Task" from onboarding → green banner on Dashboard ("🎉 Your first task is live!"). "Save Draft" or "Skip with data" → amber banner ("📝 Draft saved!"). Skip without data → no banner. Dismissable.
  - Profile completion pills: "Add photo" and "Payment method" pills now deep-link to Profile → Personal Information and Profile → Payment Methods respectively.
  - Notification settings deep link: Gear icon on Notifications tab now switches to Profile tab and opens Notification Settings. Tab bar reflects Profile as active. Back returns to Profile home.
  - Added `deepLink(tab, screen)` function to main app — sets both tab and screen atomically for cross-tab navigation.

### v0.7 (February 28, 2026)
- **Prototype:** Fixed React hooks violation — extracted `FirstTaskStep` into standalone component (was using `useState` inside conditional block)
- **Section 14:** New — Architecture Flexibility & Extensibility. Identifies 7 high-variability surfaces (task categories, pricing, matching, deliverables, notifications, onboarding steps, geographic expansion) and 5 medium-variability surfaces with specific architecture patterns and build agent guidance for each. Summary: "Never switch on enum string values, never hardcode lists, wrap all third-party services, make all thresholds configurable, use feature flags."
- **Section 15:** New — Security Posture. Includes current risk assessment (11 areas audited with red/yellow/green), 4-iteration security roadmap (baseline → hardening → advanced → scale), and sensitive data inventory (8 data types with storage, encryption, retention, and access policies). Key Iteration 1 must-haves: rate limiting, input validation, admin auth + MFA, file upload security, RLS policies, audit logging.
- **Section 16:** New — Accessibility. Includes current WCAG 2.1 assessment (9 areas audited), 3-iteration accessibility roadmap, and 6 design system updates required. Key finding: red (#C8102E) passes AA for large text but is tight for small text (4.6:1); status badges rely on color alone (needs fix); several touch targets are under 44pt minimum. Iteration 1 must-haves: AA contrast, touch targets, screen reader labels, keyboard nav, error announcements.
- **Section 10 (Iterations):** All 5 iterations updated with architecture, security, and accessibility line items cross-referencing Sections 14-16.

### v0.6 (February 28, 2026)
- **Section 6.2:** Agent Welcome CTA changed from "Start Posting Tasks" → "Post Your First Task" + "Skip for now →" link
- **Section 6.2.5:** New — First Task Creation during onboarding (agent only). Two-step flow: category selection → task details form. Skip auto-saves as draft. Save Draft shows confirmation screen. Auto-save indicator on form.
- **Section 12.2:** Runner Dashboard location bar added to spec with tap-to-change behavior
- **Section 12.2.1:** New — Location Picker Sheet view spec. Auto/Search mode toggle, city list with search, current selection highlighting, on-change behavior
- **Section 12.4:** Notifications header updated — settings gear icon added, navigates to Notification Settings (12.11)
- **Section 12.16:** Sign Out expanded with inline confirmation card specification (errorRed border, cancel/confirm buttons, state reset behavior)
- **Prototype v6:** 
  - Sign out: Profile → Account & Security → Sign Out → confirmation dialog → returns to Landing
  - Onboarding task creation: Welcome → "Post Your First Task" → category picker → detail form (address, price, instructions) → Save Draft / Post Task / Skip (auto-saves)
  - Notification settings: gear icon on Notifications tab → navigates to Notification Settings
  - Location picker: Runner Dashboard → tap location bar → sheet with Search/Auto modes, 6 cities, search filter, current selection → updates dashboard location display and filter sheet

### v0.5 (February 28, 2026)
- **Section 6:** Complete rewrite — expanded from 28 lines to full screen-by-screen onboarding specification
  - 6.1: Pre-auth screens (Splash, Landing, Create Account 3-step, Log In) with field-level detail, validation rules, input styling, animations, and error handling
  - 6.2: Welcome screen with role-specific value props (3 per role)
  - 6.3: Post-auth progressive onboarding — step inventories for both roles (6 agent, 7 runner), card behavior, gating rules with specific action-blocking and inline banners
  - 6.4: Key principles (resume-anywhere, auto-save, explore-before-commitment)
- **Section 12:** Added 12.0 (Onboarding Screens) — 7 view specifications covering Splash, Landing, Create Account, Set Password, Verify Email, Welcome, and Log In, each with layout, content, field definitions, validation, and interaction behavior
- **Prototype:** Full onboarding flow added — Splash → Landing → Create Account → Set Password → Verify Email → Welcome → Dashboard. "Log In" link on Landing skips to Dashboard as agent.

### v0.4 (February 28, 2026)
- **Section 2:** Trust & Safety constraints expanded to reference vetting framework (Section 10.1) and admin interface
- **Section 6:** Progressive onboarding rewritten with explicit step inventories (6 agent, 7 runner), vetting badges, and gating rules
- **Section 10:** Iteration Roadmap restructured into 5 iterations with detailed sub-sections:
  - 10.1: Vetting Framework — agent/runner vetting steps, license/brokerage search data sources (ARELLO, state APIs, manual fallback), vetting states, admin interface spec, profile completion integration
  - 10.2: Stripe Payment Architecture — agent payment source (PaymentIntent with manual capture), runner payout destination (Stripe Connect Express), escrow flow, weekly payout schedule, platform fee, future instant payouts
  - 10.3: Multi-Factor Authentication — SMS OTP, trigger conditions, setup flow, backup codes, future TOTP/passkey
  - 10.4: Rich Push Notifications — media attachments and custom actions per notification type per role (runner: Accept/Snooze, agent: Confirm), technical approach (iOS/Android)
  - 10.5: Proximity-Based Runner Alerts — matching criteria (location, category, history, availability, capacity), frequency caps, cooldown, PostGIS architecture
  - 10.6: Lock Screen & Live Activity Widgets — agent task progress widget, runner active task widget with countdown, ActivityKit (iOS) and ongoing notification (Android) implementation

### v0.3 (February 28, 2026)
- **Section 12:** Complete View Specifications added — 16 screen definitions covering both roles
- **Section 12:** Agent Dashboard fully specified: greeting logic, onboarding steps (5 defined), widget tap behavior, recent tasks sort/count
- **Section 12:** Runner Dashboard fully specified: earnings card period, search behavior, filter mechanics, task feed sort/distance
- **Section 12:** Profile ecosystem defined: Personal Information (9 fields), Payment Methods, Payout Settings, Notification Settings (8 toggle options), Task History, Earnings & Payouts, Service Areas, Availability, Account & Security
- **Section 12:** Runner-specific views added: Service Areas (max 5, radius options), Availability (weekly schedule + category prefs)
- **Section 12:** Notification types inventoried: 5 agent types, 5 runner types with tap destinations
- **Section 12:** Task Detail action buttons fully specified per status per role
- **Section 12:** Task Creation Sheet step-by-step: category selection fields, form fields with validation rules, price ranges per category

### v0.2 (February 28, 2026)
- **Section 5:** Updated tab bar spec to iOS 26 Liquid Glass; removed avatar from dashboard headers; specified standard SF Symbol icons for all tabs
- **Section 5:** Task creation flow clarified as sheet/modal with × dismiss (no back button)
- **Section 6:** Progressive onboarding card is now dismissable
- **Section 7:** Task posting flow updated to reflect sheet presentation pattern
- **Section 11:** Complete Design System Spec added — principles, visual tokens, component library, interaction patterns, states, platform notes
- **Section 11:** All buttons updated to pill radius (9999px)
- **Section 11:** No emoji rule — all icons use SF Symbols / Lucide
- **Section 11:** Sheet/modal spec: no back button, × dismiss + swipe + backdrop tap
- **Section 11:** Liquid Glass tab bar fully specified

### v0.1 (February 28, 2026)
- Initial draft — Sections 1–10 complete, Sections 11–12 marked TBD

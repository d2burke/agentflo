# Messaging Modernization Spec

Status: Draft for review
Date: 2026-03-07
Owner: Product + Engineering

## 1. Purpose

This document defines the target architecture, product scope, rollout plan, and implementation boundaries for modernizing AgentFlo messaging.

The current system is functional MVP chat, but it is not a strong foundation for a modern messaging experience:

- Web uses raw `conversations` reads and per-row profile queries instead of a server-side summary feed.
- Both clients load full thread history instead of paginating.
- Read state is tracked per message via `read_at`, which makes unread counts and mark-all-read heavier than necessary.
- Conversations are globally unique per user pair, which weakens task-specific messaging.
- The message model only supports plain text, so richer messaging features have no clean schema path.

This spec aims to fix maturity and speed first, then add missing product features on top of a stronger data model.

## 2. Current Constraints

The current implementation is split across:

- Web list/thread UI: [page.tsx](/Users/burke/Documents/agentflo/web/src/app/(app)/messages/page.tsx)
- Web client service: [message-service.ts](/Users/burke/Documents/agentflo/web/src/services/message-service.ts)
- iOS client service: [MessageService.swift](/Users/burke/Documents/agentflo/ios/AgentFlo/Services/MessageService.swift)
- Direct conversation schema: [20240116000002_conversations.sql](/Users/burke/Documents/agentflo/agentassist-build/supabase/migrations/20240116000002_conversations.sql)
- Conversation summary RPC: [20240119000001_conversation_list.sql](/Users/burke/Documents/agentflo/agentassist-build/supabase/migrations/20240119000001_conversation_list.sql)
- Current send path: [send-message/index.ts](/Users/burke/Documents/agentflo/agentassist-build/supabase/functions/send-message/index.ts)

Important current limitations:

1. Web conversation list is N+1 and lacks unread counts and message previews.
2. Web refetches the whole thread on every realtime insert.
3. Message history is always loaded in full.
4. Conversation uniqueness is currently per user pair, not per context.
5. Direct messages and task messages are not modeled as first-class conversation types.

## 3. Goals

### Product Goals

1. Support modern 1:1 messaging with task threads and direct threads as distinct concepts.
2. Provide consistent behavior across web and iOS.
3. Add the feature primitives required for attachments, replies, edits, delivery states, reactions, and search.
4. Make messaging feel fast even for long-lived conversations.

### Performance Goals

1. Conversation list API p95 under 250 ms for users with up to 200 conversations.
2. Initial thread load p95 under 300 ms for the latest 50 messages.
3. New message send-to-render under 150 ms in the steady state.
4. No full-thread refetch on normal incoming realtime messages.

### Reliability Goals

1. Message send must be idempotent.
2. Read state must remain consistent across devices.
3. Old messaging data must remain visible during rollout.
4. Push notifications must continue working during and after migration.

## 4. Non-Goals

These are explicitly out of scope for the first implementation wave:

1. Group chat
2. Voice or video calling
3. End-to-end encryption
4. AI-generated replies
5. Cross-app federation
6. Full-text global search in phase 1

## 5. Product Model

### Conversation Types

The system should support two first-class thread types:

1. `direct`
   One persistent 1:1 conversation between two users outside of a specific task.

2. `task`
   One conversation bound to a specific task. This is the canonical thread opened from task detail.

Rules:

1. Each task has exactly one task conversation.
2. A user pair can have one direct conversation plus many task conversations.
3. Messages must belong to exactly one conversation.
4. Task context should live on the conversation, not on the message row.

## 6. Target Data Model

### 6.1 Conversations

Evolve `public.conversations` to include:

- `kind text not null check (kind in ('direct','task'))`
- `task_id uuid null references public.tasks(id)`
- `created_by uuid null references public.users(id)`
- `last_message_id uuid null`
- `last_message_at timestamptz null`
- `last_message_preview text null`
- `updated_at timestamptz default now()`

Constraints:

1. `kind = 'task'` requires `task_id is not null`
2. `kind = 'direct'` requires `task_id is null`
3. Task conversations are unique on `task_id`
4. Direct conversations are unique on canonical participant pair

### 6.2 Conversation Participants

Add `public.conversation_participants`:

- `conversation_id uuid not null references public.conversations(id) on delete cascade`
- `user_id uuid not null references public.users(id) on delete cascade`
- `joined_at timestamptz default now()`
- `last_read_message_id uuid null references public.messages(id)`
- `last_read_at timestamptz null`
- `last_delivered_at timestamptz null`
- `last_seen_at timestamptz null`
- `muted_until timestamptz null`
- `archived_at timestamptz null`
- `is_pinned boolean not null default false`
- `draft_body text null`
- `draft_updated_at timestamptz null`
- primary key `(conversation_id, user_id)`

This table replaces per-message read tracking as the primary unread model.

### 6.3 Messages

Evolve `public.messages`:

- keep existing `id`, `sender_id`, `body`, `created_at`
- require `conversation_id not null`
- deprecate `task_id` after migration
- add `client_message_id uuid null`
- add `message_type text not null default 'text'`
- add `metadata jsonb not null default '{}'::jsonb`
- add `reply_to_message_id uuid null references public.messages(id)`
- add `edited_at timestamptz null`
- add `deleted_at timestamptz null`

`message_type` initial values:

1. `text`
2. `image`
3. `file`
4. `system`

Notes:

1. System messages should use the same thread model as user messages.
2. Soft-delete via `deleted_at`; do not hard-delete message rows.
3. `client_message_id` enables idempotent sends and retry-safe client queues.

### 6.4 Message Attachments

Add `public.message_attachments`:

- `id uuid primary key default gen_random_uuid()`
- `message_id uuid not null references public.messages(id) on delete cascade`
- `storage_path text not null`
- `file_name text not null`
- `mime_type text not null`
- `size_bytes integer not null`
- `width integer null`
- `height integer null`
- `duration_ms integer null`
- `created_at timestamptz default now()`

## 7. Indexing Strategy

Add or update indexes:

1. `messages(conversation_id, created_at desc, id desc)`
2. `messages(sender_id, created_at desc)`
3. `messages(reply_to_message_id)` where not null
4. `conversation_participants(user_id, archived_at, is_pinned, last_read_at)`
5. `conversations(task_id)` where `kind = 'task'`
6. `conversations(last_message_at desc)`

The goal is to make the conversation list and latest-page thread load index-driven.

## 8. Read / Unread Model

### Current Model

Unread is currently based on `messages.read_at`, and clients bulk-update message rows.

### Target Model

Unread is based on participant position in the conversation:

1. When a user opens a thread, client calls `mark_conversation_read`.
2. Server stores `last_read_message_id` and `last_read_at` on `conversation_participants`.
3. Unread count is computed as messages newer than the participant's read pointer and not sent by that participant.

Benefits:

1. One write per read action instead of many
2. Better unread count performance
3. Easier multi-device consistency
4. Cleaner foundation for read receipts later

## 9. API Surface

### 9.1 RPC: `get_conversation_list_v2`

Input:

- `p_user_id uuid`
- `p_limit integer default 50`
- `p_cursor timestamptz default null`

Returns one row per visible conversation:

- conversation metadata
- other participant profile
- `last_message_id`
- `last_message_body`
- `last_message_type`
- `last_message_at`
- `last_message_sender_id`
- `unread_count`
- `is_pinned`
- `archived_at`
- `draft_body`

Web and iOS should both use this API.

### 9.2 RPC: `get_messages_page_v2`

Input:

- `p_conversation_id uuid`
- `p_before_message_id uuid default null`
- `p_limit integer default 50`

Behavior:

1. Returns newest-first page when cursor is null.
2. Returns older messages when cursor is set.
3. Client reverses for display order.

### 9.3 RPC: `get_or_create_direct_conversation_v2`

Input:

- `p_other_user_id uuid`

Behavior:

1. Canonicalizes participant order.
2. Returns existing direct conversation if present.
3. Creates participant rows if conversation is newly created.

### 9.4 RPC: `get_or_create_task_conversation_v2`

Input:

- `p_task_id uuid`

Behavior:

1. Finds the agent and runner for the task.
2. Returns the unique task conversation.
3. Creates participant rows if needed.

### 9.5 Edge Function: `send-message-v2`

Request:

- `conversationId`
- `clientMessageId`
- `body`
- `messageType`
- `replyToMessageId`
- `metadata`
- `attachments`

Responsibilities:

1. Auth and participant validation
2. Idempotent insert using `clientMessageId`
3. Conversation summary update
4. Push notification fan-out
5. Optional system-message generation

Response:

- canonical message row
- attachment rows
- normalized conversation summary fields needed by clients

### 9.6 RPC: `mark_conversation_read_v2`

Input:

- `p_conversation_id uuid`
- `p_last_read_message_id uuid`

Behavior:

1. Updates only the caller's participant row.
2. Never updates individual message rows in bulk.

## 10. Realtime Model

### Phase 1

Use Supabase realtime on:

1. `messages` inserts and updates for the active conversation
2. `conversations` summary updates for the list
3. `conversation_participants` updates for unread changes on the current user

Client behavior:

1. Append incoming message locally instead of invalidating full thread
2. Patch conversation preview and unread badge in place
3. Use optimistic local send and reconcile on ack

### Phase 2

Add broadcast/presence for:

1. typing state
2. last seen / active presence

## 11. Client Changes

### 11.1 Web

Replace current web behavior with:

1. `get_conversation_list_v2` for the list
2. infinite query for `get_messages_page_v2`
3. optimistic thread append on send
4. realtime patching instead of `invalidateQueries` on every insert
5. explicit read-pointer updates when thread becomes visible and at bottom
6. shared thread UI primitives for text, attachments, reply state, and send failures

### 11.2 iOS

Keep the current server-driven list approach, but migrate to the new contracts:

1. replace `markAsRead(messageId:)` and bulk row updates with `mark_conversation_read_v2`
2. replace full-thread fetches with paginated fetch
3. add local send queue with `clientMessageId`
4. unify task and direct thread creation on the server

### 11.3 Cross-Platform UX Baseline

Required after phase 1:

1. last message preview in conversation list
2. unread badge
3. date separators
4. sending and failed states
5. retry on failed send
6. reply target UI placeholder, even if full reply rendering lands in phase 2

## 12. Performance Plan

### Immediate Wins

1. Web switches to server-side conversation summaries.
2. Threads become paginated.
3. Realtime stops triggering full thread refetches.
4. Read state becomes one participant-row write instead of many message-row writes.

### Additional Optimizations

1. Update `conversations.last_message_*` on message insert so list queries avoid scanning the full message table.
2. Keep message queries cursor-based, not offset-based.
3. Limit initial list page and thread page size.
4. Add client-side local cache hydration between navigation events where possible.

## 13. Migration Strategy

### 13.1 Compatibility Phase

1. Add new columns and tables without removing old ones.
2. Keep `messages.task_id` readable during transition.
3. Keep existing `send-message` behavior operational until both clients switch.

### 13.2 Backfill Rules

Backfill must treat existing message data carefully:

1. If a message has `task_id`, the source of truth is the task. It should belong to that task conversation.
2. If a message has `conversation_id` and no `task_id`, it should belong to a direct conversation.
3. If an existing conversation row has `task_id` but its messages span multiple tasks, use each message's `task_id` as the source of truth and split them into distinct task conversations.
4. Existing pair-unique direct conversations should remain intact after backfill.

### 13.3 Rollout Order

1. Ship schema additions and backfill scripts.
2. Ship `get_conversation_list_v2`, `get_messages_page_v2`, and `mark_conversation_read_v2`.
3. Switch web reads first.
4. Switch iOS reads.
5. Ship `send-message-v2`.
6. Migrate clients to new send path.
7. Remove old `read_at` behavior and old list/thread code paths.

## 14. Security and Authorization

1. All send and read-pointer mutations remain server-validated.
2. Conversation membership must be enforced in RPCs and edge functions.
3. Task conversations must only include task participants.
4. Direct conversation creation must prevent spoofed participant IDs.
5. Attachment access must be scoped to conversation participants through storage policies or signed URLs.

## 15. Telemetry

Track:

1. conversation list API latency
2. thread page API latency
3. send success rate
4. send retry rate
5. unread count mismatches
6. duplicate-message incidents
7. realtime event lag
8. attachment upload failure rate

## 16. Testing Strategy

### Database and API

1. migration tests for backfill correctness
2. RLS tests for conversation membership
3. RPC tests for unread counts and pagination cursors
4. send idempotency tests using repeated `clientMessageId`

### Client

1. optimistic send tests
2. pagination and scroll-position tests
3. unread badge update tests
4. retry/failure-state tests
5. attachment rendering tests

### Load

1. 200-conversation list user
2. 10,000-message thread pagination
3. burst send tests across realtime subscribers

## 17. Implementation Phases

### Phase 1: Foundation and Speed

Scope:

1. new conversation list API
2. paginated thread API
3. participant read model
4. conversation summary denormalization
5. web migration off N+1 and full-thread refetch
6. iOS migration off per-message read writes

Exit criteria:

1. web and iOS both use the same list and thread contracts
2. no full-thread refetch on standard incoming message events
3. unread counts come from participant state

### Phase 2: Rich Message Model

Scope:

1. `send-message-v2`
2. attachments
3. reply-to
4. edit/delete
5. richer rendering primitives

Exit criteria:

1. images and files work end-to-end
2. client sends are idempotent and retry-safe
3. old message rows remain visible

### Phase 3: Modern Messaging Polish

Scope:

1. typing indicators
2. reactions
3. mute/archive/pin
4. search
5. drafts across devices

## 18. Decisions Needed Before Implementation

1. Do we want one task thread per task, with a separate direct thread for the same user pair? Recommendation: yes.
2. Should attachments ship in the first implementation wave or only after the performance foundation? Recommendation: after the foundation.
3. Do we want search in the first implementation wave? Recommendation: no.
4. Should web or iOS migrate first? Recommendation: web first because it has the larger performance gap.

## 19. Recommended Next Step

If this spec is approved, the next document should be a build plan that breaks phase 1 into exact migrations, RPCs, edge functions, client milestones, and acceptance tests.

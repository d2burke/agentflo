# Messaging Phase 1 Deployment

This runbook deploys the phase-1 messaging modernization from the `messaging` branch.

## Scope

- Migration: `supabase/migrations/20260307000003_messaging_phase1_foundation.sql`
- Function: `supabase/functions/send-message`
- Web app messaging client updates
- iOS messaging client updates

## Changed Files

- `agentassist-build/supabase/migrations/20260307000003_messaging_phase1_foundation.sql`
- `agentassist-build/supabase/functions/send-message/index.ts`
- `web/src/app/(app)/messages/page.tsx`
- `web/src/services/message-service.ts`
- `web/src/types/models.ts`
- `ios/AgentFlo/Services/MessageService.swift`
- `ios/AgentFlo/Views/Messaging/MessagingView.swift`
- `ios/AgentFlo/Models/Models.swift`
- `ios/AgentFlo/Models/ConversationPreview.swift`

## Prerequisites

- Supabase CLI logged in
- Vercel CLI logged in
- iOS release process available in Xcode/App Store Connect
- Production Supabase project ref: `giloreldlxdpqsvmqiqh`
- Staging Supabase project ref: fill in before use

## Local Verification

Run from `web/`:

```bash
npm ci
npx tsc --noEmit
npx vitest run src/services/__tests__/message-service.test.ts src/types/__tests__/models.test.ts
npx eslint src/app/'(app)'/messages/page.tsx src/services/message-service.ts src/services/__tests__/message-service.test.ts src/types/models.ts src/types/__tests__/models.test.ts
```

## Staging Deployment

### 1. Push branch

```bash
cd /tmp/agentflo-messaging
git push origin messaging
```

### 2. Apply migration

Replace `<staging-project-ref>` first.

```bash
cd /tmp/agentflo-messaging/agentassist-build
supabase db push --project-ref <staging-project-ref>
```

### 3. Validate migration

Run in Supabase SQL editor or with `psql`:

```sql
select count(*) as messages_missing_conversation_id
from public.messages
where conversation_id is null;

select count(*) as task_conversations_without_participants
from public.conversations c
where c.kind = 'task'
  and not exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = c.id
  );

select count(*) as task_messages_without_task_thread
from public.messages m
where m.task_id is not null
  and not exists (
    select 1
    from public.conversations c
    where c.kind = 'task'
      and c.task_id = m.task_id
  );
```

Expected result: all `0`.

### 4. Deploy `send-message`

```bash
cd /tmp/agentflo-messaging/agentassist-build
supabase functions deploy send-message --project-ref <staging-project-ref>
```

### 5. Deploy web

If the Vercel project is already linked:

```bash
cd /tmp/agentflo-messaging/web
vercel
```

If you use explicit preview deploys:

```bash
cd /tmp/agentflo-messaging/web
vercel --target preview
```

### 6. Staging QA

- Open `/messages`
- Open `/messages?conversationId=<conversation-id>`
- Open `/messages?taskId=<task-id>`
- Send message from web and verify:
  - optimistic send appears immediately
  - realtime append does not full-refresh thread
  - unread count clears when thread opens
  - older messages load
- Send message from iOS staging build if available
- Verify push notification payload opens correct thread

## Production Deployment

### 1. Apply migration

```bash
cd /tmp/agentflo-messaging/agentassist-build
supabase db push --project-ref giloreldlxdpqsvmqiqh
```

### 2. Re-run migration validation queries

Use the same SQL as staging. All results must be `0`.

### 3. Deploy `send-message`

```bash
cd /tmp/agentflo-messaging/agentassist-build
supabase functions deploy send-message --project-ref giloreldlxdpqsvmqiqh
```

### 4. Deploy web

If the Vercel production project is linked:

```bash
cd /tmp/agentflo-messaging/web
vercel --prod
```

If your team uses prebuilt deploys:

```bash
cd /tmp/agentflo-messaging/web
vercel pull --environment=production
vercel build --prod
vercel deploy --prebuilt --prod
```

### 5. Release iOS

- Build from the `messaging` branch
- Ship to TestFlight first
- Verify:
  - direct messages
  - task messages
  - unread clearing across devices
  - deep links from push open the correct thread
  - older messages page correctly
- Promote to production after QA signoff

## Post-Deploy Checks

Run these SQL spot checks:

```sql
select id, conversation_id, task_id, sender_id, client_message_id, message_type, created_at
from public.messages
order by created_at desc
limit 20;

select conversation_id, user_id, last_read_message_id, last_read_at, last_seen_at
from public.conversation_participants
order by last_seen_at desc nulls last
limit 20;
```

Check application behavior:

- direct thread opens from profile
- task thread opens from task CTA
- same message is not inserted twice on retry
- push payloads include `conversation_id`

## Rollback

There is no clean schema rollback for this migration without data loss risk. The practical rollback is:

1. Stop client rollout
2. Redeploy the previous web version if needed
3. Redeploy the previous `send-message` function if needed
4. Leave the new schema in place

The migration is additive and keeps compatibility paths, so rollback should be application-level, not destructive database rollback.

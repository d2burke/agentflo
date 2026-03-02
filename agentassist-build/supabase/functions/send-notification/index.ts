// supabase/functions/send-notification/index.ts
// Edge Function: Central notification dispatcher
//
// Called by other edge functions (not directly by clients).
// Uses service role key for cross-user operations.
//
// Business Logic:
//   1. Resolve notification template from type (e.g., 'task_accepted' → title + body template)
//   2. Check recipient's notification_preferences — skip if disabled for this type
//   3. Insert notification record into notifications table
//   4. Look up recipient's push_tokens (active ones)
//   5. Send push notification via FCM (Android/Web) or APNs (iOS)
//   6. Update push_sent_at on the notification record
//
// Input: { userId: string, type: string, data: { task_id?, screen?, ... }, customTitle?: string, customBody?: string }
// Output: { notification_id: string, push_sent: boolean }
//
// NOTE: This function is internal — called by other edge functions, not exposed to clients.
// It uses SUPABASE_SERVICE_ROLE_KEY to bypass RLS for cross-user notification insertion.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Notification templates — move to DB/config in Iteration 3
const TEMPLATES: Record<string, { title: string; body: string }> = {
  task_accepted:       { title: 'You Got the Task!',       body: '{agent_name} accepted your application for {category} at {address}' },
  task_application:    { title: 'New Application',          body: '{runner_name} applied for your {category} task at {address}' },
  deliverables_ready:  { title: 'Deliverables Ready',       body: '{runner_name} submitted deliverables for {address}' },
  task_completed:      { title: 'Task Completed',           body: '{category} at {address} is complete. Payment of ${amount} processed.' },
  payment_received:    { title: 'Payment Received!',        body: '${amount} has been deposited for {category} at {address}' },
  new_task_nearby:     { title: 'New Task Nearby',          body: '{category} task posted {distance} away — ${price}' },
  task_cancelled:      { title: 'Task Cancelled',           body: '{category} at {address} has been cancelled. {reason}' },
  revision_requested:  { title: 'Revision Requested',       body: '{agent_name} requested changes to your deliverables for {address}' },
  review_prompt:       { title: 'How Did It Go?',           body: 'Rate your experience with {other_name} for {category} at {address}' },
}

// Maps notification type → notification_preferences column
const PREF_MAP: Record<string, string> = {
  task_accepted: 'task_updates',
  task_application: 'task_updates',
  deliverables_ready: 'task_updates',
  task_completed: 'task_updates',
  payment_received: 'payment_confirmations',
  new_task_nearby: 'new_available_tasks',
  task_cancelled: 'task_updates',
  revision_requested: 'task_updates',
  review_prompt: 'task_updates',
}

function resolveTemplate(
  type: string,
  data: Record<string, string>,
  customTitle?: string,
  customBody?: string,
): { title: string; body: string } {
  const template = TEMPLATES[type]
  if (!template && !customTitle) {
    return { title: 'Notification', body: '' }
  }

  let title = customTitle ?? template.title
  let body = customBody ?? template.body

  // Replace placeholders like {agent_name}, {address}, etc.
  for (const [key, value] of Object.entries(data)) {
    title = title.replace(`{${key}}`, value ?? '')
    body = body.replace(`{${key}}`, value ?? '')
    // Handle ${amount} and ${price} patterns (dollar sign prefix)
    title = title.replace(`\${${key}}`, value ?? '')
    body = body.replace(`\${${key}}`, value ?? '')
  }

  return { title, body }
}

serve(async (req) => {
  try {
    const { userId, type, data, customTitle, customBody } = await req.json()

    if (!userId || !type) {
      return new Response(
        JSON.stringify({ error: 'userId and type are required' }),
        { status: 400 },
      )
    }

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Check notification preferences
    const prefColumn = PREF_MAP[type]
    if (prefColumn) {
      const { data: prefs } = await serviceClient
        .from('notification_preferences')
        .select(prefColumn)
        .eq('user_id', userId)
        .single()

      if (prefs && prefs[prefColumn] === false) {
        return new Response(
          JSON.stringify({ notification_id: null, push_sent: false, skipped: 'disabled_by_preference' }),
          { headers: { 'Content-Type': 'application/json' } },
        )
      }
    }

    // Resolve template
    const { title, body } = resolveTemplate(type, data ?? {}, customTitle, customBody)

    // Insert notification record
    const { data: notification, error: insertError } = await serviceClient
      .from('notifications')
      .insert({
        user_id: userId,
        type,
        title,
        body,
        data: data ?? {},
      })
      .select('id')
      .single()

    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), { status: 500 })
    }

    // Look up active push tokens
    const { data: tokens } = await serviceClient
      .from('push_tokens')
      .select('token, platform')
      .eq('user_id', userId)
      .eq('is_active', true)

    let pushSent = false

    if (tokens && tokens.length > 0) {
      // TODO: Send via FCM (Android/Web) or APNs (iOS)
      // For now, log that push would be sent
      console.log(`[send-notification] Would send push to ${tokens.length} device(s) for user ${userId}: ${title}`)

      // Update push_sent_at when push delivery is implemented
      // await serviceClient.from('notifications')
      //   .update({ push_sent_at: new Date().toISOString() })
      //   .eq('id', notification.id)
    }

    return new Response(
      JSON.stringify({ notification_id: notification.id, push_sent: pushSent }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})

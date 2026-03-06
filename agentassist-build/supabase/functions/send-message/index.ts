// supabase/functions/send-message/index.ts
// Edge Function: Send a message and trigger push notification to recipient
//
// Replaces direct client-side INSERT into messages table.
// After inserting the message, resolves the recipient and calls send-notification
// with a new_message type so the other user gets a push.
//
// Input: { body, taskId?, conversationId? }
// Output: { message: Message, notification_sent: boolean }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getCorsHeaders, handleCorsPreFlight } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/rate-limit.ts'
import { sanitizeString, isValidUUID } from '../_shared/validation.ts'

serve(async (req) => {
  // CORS
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse
  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    // Auth — get the sender from the JWT
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers })
    }

    const senderId = user.id

    // Rate limit: 30 messages per minute
    const rateLimited = await checkRateLimit(senderId, 'write')
    if (rateLimited) return rateLimited

    // Parse and validate input
    const input = await req.json()
    const body = sanitizeString(input.body, 5000)
    const taskId = input.taskId ?? input.task_id ?? null
    const conversationId = input.conversationId ?? input.conversation_id ?? null

    if (!body) {
      return new Response(JSON.stringify({ error: 'Message body is required' }), { status: 400, headers })
    }

    if (!taskId && !conversationId) {
      return new Response(
        JSON.stringify({ error: 'Either taskId or conversationId is required' }),
        { status: 400, headers },
      )
    }

    if (taskId && !isValidUUID(taskId)) {
      return new Response(JSON.stringify({ error: 'Invalid taskId' }), { status: 400, headers })
    }

    if (conversationId && !isValidUUID(conversationId)) {
      return new Response(JSON.stringify({ error: 'Invalid conversationId' }), { status: 400, headers })
    }

    // Service client for cross-user operations
    const serviceClient = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Insert the message
    const insertPayload: Record<string, unknown> = {
      sender_id: senderId,
      body,
    }
    if (taskId) insertPayload.task_id = taskId
    if (conversationId) insertPayload.conversation_id = conversationId

    const { data: message, error: insertError } = await serviceClient
      .from('messages')
      .insert(insertPayload)
      .select()
      .single()

    if (insertError) {
      console.error('[send-message] Insert error:', insertError)
      return new Response(JSON.stringify({ error: insertError.message }), { status: 500, headers })
    }

    // Resolve the recipient (the other participant)
    let recipientId: string | null = null
    let senderName = 'Someone'

    // Get sender's name
    const { data: senderProfile } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', senderId)
      .single()

    if (senderProfile?.full_name) {
      senderName = senderProfile.full_name
    }

    if (conversationId) {
      // Direct conversation: recipient is the other participant
      const { data: conversation } = await serviceClient
        .from('conversations')
        .select('participant_1_id, participant_2_id')
        .eq('id', conversationId)
        .single()

      if (conversation) {
        recipientId = conversation.participant_1_id === senderId
          ? conversation.participant_2_id
          : conversation.participant_1_id
      }
    } else if (taskId) {
      // Task-based message: find the other party from the task
      const { data: task } = await serviceClient
        .from('tasks')
        .select('agent_id, runner_id')
        .eq('id', taskId)
        .single()

      if (task) {
        // If sender is the agent, notify the runner; if sender is the runner, notify the agent
        if (task.agent_id === senderId) {
          recipientId = task.runner_id
        } else if (task.runner_id === senderId) {
          recipientId = task.agent_id
        }
      }
    }

    // Send push notification to recipient
    let notificationSent = false

    if (recipientId && recipientId !== senderId) {
      try {
        // Truncate message preview for push notification
        const messagePreview = body.length > 100 ? body.slice(0, 97) + '...' : body

        const notifPayload: Record<string, string> = {
          sender_name: senderName,
          message_preview: messagePreview,
        }

        // Include routing data for deep linking
        if (conversationId) {
          notifPayload.conversation_id = conversationId
          notifPayload.screen = 'messages'
        }
        if (taskId) {
          notifPayload.task_id = taskId
          notifPayload.screen = 'messages'
        }

        const notifResponse = await serviceClient.functions.invoke('send-notification', {
          body: {
            userId: recipientId,
            type: 'new_message',
            data: notifPayload,
          },
        })

        if (notifResponse.error) {
          console.error('[send-message] Notification error:', notifResponse.error)
        } else {
          notificationSent = true
        }
      } catch (notifErr) {
        console.error('[send-message] Failed to send notification:', notifErr)
      }
    }

    return new Response(
      JSON.stringify({ message, notification_sent: notificationSent }),
      { status: 201, headers },
    )
  } catch (err) {
    console.error('[send-message] Unexpected error:', err)
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...getCorsHeaders(req), 'Content-Type': 'application/json' } },
    )
  }
})

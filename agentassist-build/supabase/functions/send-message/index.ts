// supabase/functions/send-message/index.ts
// Edge Function: Send a message and trigger push notification to recipient.
//
// Input: { body, taskId?, conversationId?, clientMessageId?, messageType?, metadata? }
// Output: { message: Message, notification_sent: boolean }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getCorsHeaders, handleCorsPreFlight } from '../_shared/cors.ts'
import { checkRateLimit } from '../_shared/rate-limit.ts'
import { sanitizeString, isValidUUID } from '../_shared/validation.ts'

type ConversationRow = {
  id: string
  kind: 'direct' | 'task'
  task_id: string | null
  participant_1_id: string
  participant_2_id: string
}

type TaskRow = {
  id: string
  agent_id: string
  runner_id: string | null
}

function canonicalizeParticipants(firstId: string, secondId: string) {
  return firstId < secondId
    ? { participant1: firstId, participant2: secondId }
    : { participant1: secondId, participant2: firstId }
}

serve(async (req) => {
  const corsResponse = handleCorsPreFlight(req)
  if (corsResponse) return corsResponse

  const headers = { ...getCorsHeaders(req), 'Content-Type': 'application/json' }

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser()

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers })
    }

    const senderId = user.id
    const rateLimited = await checkRateLimit(senderId, 'write')
    if (rateLimited) return rateLimited

    const input = await req.json()
    const body = sanitizeString(input.body, 5000)
    const taskId = input.taskId ?? input.task_id ?? null
    const conversationId = input.conversationId ?? input.conversation_id ?? null
    const clientMessageId = input.clientMessageId ?? input.client_message_id ?? null
    const messageType = sanitizeString(input.messageType ?? input.message_type ?? 'text', 32) || 'text'
    const metadata = input.metadata && typeof input.metadata === 'object' && !Array.isArray(input.metadata)
      ? input.metadata
      : {}

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

    if (clientMessageId && !isValidUUID(clientMessageId)) {
      return new Response(JSON.stringify({ error: 'Invalid clientMessageId' }), { status: 400, headers })
    }

    if (!['text', 'image', 'file', 'system'].includes(messageType)) {
      return new Response(JSON.stringify({ error: 'Invalid messageType' }), { status: 400, headers })
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey)

    let senderName = 'Someone'
    let recipientId: string | null = null
    let canonicalConversation: ConversationRow | null = null

    const { data: senderProfile } = await serviceClient
      .from('users')
      .select('full_name')
      .eq('id', senderId)
      .single()

    if (senderProfile?.full_name) {
      senderName = senderProfile.full_name
    }

    if (conversationId) {
      const { data: conversation, error: conversationError } = await serviceClient
        .from('conversations')
        .select('id, kind, task_id, participant_1_id, participant_2_id')
        .eq('id', conversationId)
        .single()

      if (conversationError || !conversation) {
        return new Response(JSON.stringify({ error: 'Conversation not found' }), { status: 404, headers })
      }

      if (conversation.participant_1_id !== senderId && conversation.participant_2_id !== senderId) {
        return new Response(
          JSON.stringify({ error: 'Not authorized to send messages in this conversation' }),
          { status: 403, headers },
        )
      }

      if (taskId && conversation.task_id !== taskId) {
        return new Response(JSON.stringify({ error: 'Conversation and task do not match' }), { status: 400, headers })
      }

      canonicalConversation = conversation as ConversationRow
      recipientId = conversation.participant_1_id === senderId
        ? conversation.participant_2_id
        : conversation.participant_1_id
    }

    if (!canonicalConversation && taskId) {
      const { data: task, error: taskError } = await serviceClient
        .from('tasks')
        .select('id, agent_id, runner_id')
        .eq('id', taskId)
        .single()

      if (taskError || !task) {
        return new Response(JSON.stringify({ error: 'Task not found' }), { status: 404, headers })
      }

      const typedTask = task as TaskRow

      if (!typedTask.runner_id) {
        return new Response(
          JSON.stringify({ error: 'Task does not have both messaging participants yet' }),
          { status: 400, headers },
        )
      }

      if (typedTask.agent_id === senderId) {
        recipientId = typedTask.runner_id
      } else if (typedTask.runner_id === senderId) {
        recipientId = typedTask.agent_id
      } else {
        return new Response(
          JSON.stringify({ error: 'Not authorized to send messages for this task' }),
          { status: 403, headers },
        )
      }

      const { data: existingConversation, error: existingConversationError } = await serviceClient
        .from('conversations')
        .select('id, kind, task_id, participant_1_id, participant_2_id')
        .eq('kind', 'task')
        .eq('task_id', taskId)
        .maybeSingle()

      if (existingConversationError) {
        console.error('[send-message] Failed to load task conversation:', existingConversationError)
        return new Response(JSON.stringify({ error: 'Failed to resolve task conversation' }), { status: 500, headers })
      }

      if (existingConversation) {
        canonicalConversation = existingConversation as ConversationRow
      } else {
        const { participant1, participant2 } = canonicalizeParticipants(typedTask.agent_id, typedTask.runner_id)
        const { data: createdConversation, error: createConversationError } = await serviceClient
          .from('conversations')
          .insert({
            participant_1_id: participant1,
            participant_2_id: participant2,
            kind: 'task',
            task_id: taskId,
            created_by: typedTask.agent_id,
          })
          .select('id, kind, task_id, participant_1_id, participant_2_id')
          .single()

        if (createConversationError?.code === '23505') {
          const { data: racedConversation, error: racedConversationError } = await serviceClient
            .from('conversations')
            .select('id, kind, task_id, participant_1_id, participant_2_id')
            .eq('kind', 'task')
            .eq('task_id', taskId)
            .single()

          if (racedConversationError || !racedConversation) {
            console.error('[send-message] Failed to reload raced task conversation:', racedConversationError)
            return new Response(JSON.stringify({ error: 'Failed to resolve task conversation' }), { status: 500, headers })
          }

          canonicalConversation = racedConversation as ConversationRow
        } else if (createConversationError || !createdConversation) {
          console.error('[send-message] Failed to create task conversation:', createConversationError)
          return new Response(JSON.stringify({ error: 'Failed to resolve task conversation' }), { status: 500, headers })
        } else {
          canonicalConversation = createdConversation as ConversationRow
        }
      }
    }

    if (!canonicalConversation) {
      return new Response(JSON.stringify({ error: 'Failed to resolve conversation' }), { status: 500, headers })
    }

    if (clientMessageId) {
      const { data: existingMessage, error: existingMessageError } = await serviceClient
        .from('messages')
        .select('*')
        .eq('conversation_id', canonicalConversation.id)
        .eq('sender_id', senderId)
        .eq('client_message_id', clientMessageId)
        .maybeSingle()

      if (existingMessageError) {
        console.error('[send-message] Failed to check idempotency:', existingMessageError)
        return new Response(JSON.stringify({ error: 'Failed to validate message idempotency' }), { status: 500, headers })
      }

      if (existingMessage) {
        return new Response(
          JSON.stringify({ message: existingMessage, notification_sent: false }),
          { status: 200, headers },
        )
      }
    }

    const insertPayload: Record<string, unknown> = {
      sender_id: senderId,
      body,
      conversation_id: canonicalConversation.id,
      task_id: canonicalConversation.task_id,
      message_type: messageType,
      metadata,
    }

    if (clientMessageId) {
      insertPayload.client_message_id = clientMessageId
    }

    let message: Record<string, unknown> | null = null
    let insertError: { message: string; code?: string } | null = null

    const insertResult = await serviceClient
      .from('messages')
      .insert(insertPayload)
      .select()
      .single()

    message = insertResult.data
    insertError = insertResult.error

    if (insertError?.code === '23505' && clientMessageId) {
      const { data: duplicateMessage, error: duplicateLookupError } = await serviceClient
        .from('messages')
        .select('*')
        .eq('conversation_id', canonicalConversation.id)
        .eq('sender_id', senderId)
        .eq('client_message_id', clientMessageId)
        .maybeSingle()

      if (duplicateLookupError) {
        console.error('[send-message] Duplicate lookup failed:', duplicateLookupError)
        return new Response(JSON.stringify({ error: duplicateLookupError.message }), { status: 500, headers })
      }

      if (duplicateMessage) {
        return new Response(
          JSON.stringify({ message: duplicateMessage, notification_sent: false }),
          { status: 200, headers },
        )
      }
    }

    if (insertError || !message) {
      console.error('[send-message] Insert error:', insertError)
      return new Response(
        JSON.stringify({ error: insertError?.message ?? 'Failed to send message' }),
        { status: 500, headers },
      )
    }

    if (recipientId) {
      const participantRows = [
        { conversation_id: canonicalConversation.id, user_id: senderId },
        { conversation_id: canonicalConversation.id, user_id: recipientId },
      ]

      const { error: participantError } = await serviceClient
        .from('conversation_participants')
        .upsert(participantRows, {
          onConflict: 'conversation_id,user_id',
          ignoreDuplicates: true,
        })

      if (participantError) {
        console.error('[send-message] Failed to upsert participants:', participantError)
      }
    }

    let notificationSent = false

    if (recipientId && recipientId !== senderId) {
      try {
        const messagePreview = body.length > 100 ? body.slice(0, 97) + '...' : body
        const notifPayload: Record<string, string> = {
          sender_name: senderName,
          message_preview: messagePreview,
          conversation_id: canonicalConversation.id,
          screen: 'messages',
        }

        if (canonicalConversation.task_id) {
          notifPayload.task_id = canonicalConversation.task_id
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

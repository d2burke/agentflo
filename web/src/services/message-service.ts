import { createClient } from '@/lib/supabase/client'
import type { Conversation, ConversationPreview, Message, MessageType } from '@/types/models'
import type { RealtimePostgresInsertPayload, SupabaseClient } from '@supabase/supabase-js'

export const MESSAGE_PAGE_SIZE = 50
export const SESSION_EXPIRED_MESSAGE = 'Session expired. Please sign in again.'
const SESSION_REFRESH_WINDOW_MS = 60_000

function unwrapSingleRecord<T>(data: T | T[] | null, errorMessage: string): T {
  if (Array.isArray(data)) {
    if (data.length === 0) throw new Error(errorMessage)
    return data[0] as T
  }

  if (!data) throw new Error(errorMessage)
  return data
}

function normalizeMessage(message: Message): Message {
  return {
    ...message,
    message_type: (message.message_type ?? 'text') as MessageType,
    metadata: message.metadata ?? {},
    delivery_status: message.delivery_status ?? 'sent',
  }
}

async function getAccessTokenForMessageSend(supabase: SupabaseClient): Promise<string> {
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser()

  if (userError || !user) {
    throw new Error(SESSION_EXPIRED_MESSAGE)
  }

  let {
    data: { session },
  } = await supabase.auth.getSession()

  const expiresSoon = session?.expires_at
    ? (session.expires_at * 1000) <= (Date.now() + SESSION_REFRESH_WINDOW_MS)
    : false

  if (!session?.access_token || expiresSoon) {
    const { data, error } = await supabase.auth.refreshSession()
    if (error || !data.session?.access_token) {
      throw new Error(SESSION_EXPIRED_MESSAGE)
    }

    session = data.session
  }

  return session.access_token
}

export const messageService = {
  async fetchConversations(userId: string, limit = 100): Promise<ConversationPreview[]> {
    const supabase = createClient()
    const { data, error } = await supabase.rpc('get_conversation_list_v2', {
      p_user_id: userId,
      p_limit: limit,
      p_cursor: null,
    })

    if (error) throw error

    return ((data as ConversationPreview[] | null) ?? []).map((conversation) => ({
      ...conversation,
      unread_count: Number(conversation.unread_count ?? 0),
    }))
  },

  async fetchMessagePage(
    conversationId: string,
    beforeMessageId: string | null = null,
    limit = MESSAGE_PAGE_SIZE,
  ): Promise<Message[]> {
    const supabase = createClient()
    const { data, error } = await supabase.rpc('get_messages_page_v2', {
      p_conversation_id: conversationId,
      p_before_message_id: beforeMessageId,
      p_limit: limit,
    })

    if (error) throw error

    return ((data as Message[] | null) ?? [])
      .map(normalizeMessage)
      .reverse()
  },

  async fetchMessages(conversationId: string): Promise<Message[]> {
    return this.fetchMessagePage(conversationId)
  },

  async fetchTaskMessages(taskId: string): Promise<Message[]> {
    const conversation = await this.getOrCreateTaskConversation(taskId)
    return this.fetchMessages(conversation.id)
  },

  async markConversationRead(conversationId: string, lastReadMessageId?: string): Promise<void> {
    const supabase = createClient()
    const { error } = await supabase.rpc('mark_conversation_read_v2', {
      p_conversation_id: conversationId,
      p_last_read_message_id: lastReadMessageId ?? null,
    })

    if (error) throw error
  },

  async sendMessage(params: {
    senderId: string
    body: string
    conversationId?: string
    taskId?: string
    clientMessageId?: string
    messageType?: MessageType
    metadata?: Record<string, unknown>
  }): Promise<Message> {
    const supabase = createClient()
    const accessToken = await getAccessTokenForMessageSend(supabase)
    const payload = {
      body: params.body,
      conversationId: params.conversationId ?? undefined,
      taskId: params.taskId ?? undefined,
      clientMessageId: params.clientMessageId ?? undefined,
      messageType: params.messageType ?? 'text',
      metadata: params.metadata ?? {},
    }

    const response = await fetch('/api/messages/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      credentials: 'same-origin',
      body: JSON.stringify(payload),
    })

    let data: { message?: Message; error?: string } | null = null

    try {
      data = await response.json() as { message?: Message; error?: string }
    } catch {
      data = null
    }

    if (!response.ok) {
      const errorMessage = data?.error ?? `Failed to send message (${response.status})`
      if (response.status === 401 || errorMessage.trim().toLowerCase() === 'unauthorized') {
        throw new Error(SESSION_EXPIRED_MESSAGE)
      }
      throw new Error(errorMessage)
    }

    if (!data?.message) {
      throw new Error('send-message returned no message payload')
    }

    return normalizeMessage(data.message)
  },

  async getOrCreateConversation(_userId: string, otherUserId: string, taskId?: string): Promise<Conversation> {
    if (taskId) {
      return this.getOrCreateTaskConversation(taskId)
    }

    return this.getOrCreateDirectConversation(otherUserId)
  },

  async getOrCreateDirectConversation(otherUserId: string): Promise<Conversation> {
    const supabase = createClient()
    const { data, error } = await supabase.rpc('get_or_create_direct_conversation_v2', {
      p_other_user_id: otherUserId,
    })

    if (error) throw error
    return unwrapSingleRecord(data as Conversation | Conversation[] | null, 'Conversation not found')
  },

  async getOrCreateTaskConversation(taskId: string): Promise<Conversation> {
    const supabase = createClient()
    const { data, error } = await supabase.rpc('get_or_create_task_conversation_v2', {
      p_task_id: taskId,
    })

    if (error) throw error
    return unwrapSingleRecord(data as Conversation | Conversation[] | null, 'Task conversation not found')
  },

  subscribeToMessages(conversationId: string, callback: (message: Message) => void) {
    const supabase = createClient()
    return supabase
      .channel(`messages:${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `conversation_id=eq.${conversationId}`,
        },
        (payload: RealtimePostgresInsertPayload<Message>) => callback(normalizeMessage(payload.new)),
      )
      .subscribe()
  },
}

import { createClient } from '@/lib/supabase/client'
import type { Message, Conversation } from '@/types/models'

export const messageService = {
  async fetchConversations(userId: string): Promise<Conversation[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('conversations')
      .select()
      .or(`participant_1_id.eq.${userId},participant_2_id.eq.${userId}`)
      .order('created_at', { ascending: false })

    if (error) throw error
    return data as Conversation[]
  },

  async fetchMessages(conversationId: string): Promise<Message[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('messages')
      .select()
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })

    if (error) throw error
    return data as Message[]
  },

  async fetchTaskMessages(taskId: string): Promise<Message[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('messages')
      .select()
      .eq('task_id', taskId)
      .order('created_at', { ascending: true })

    if (error) throw error
    return data as Message[]
  },

  async sendMessage(params: {
    senderId: string
    body: string
    conversationId?: string
    taskId?: string
  }): Promise<Message> {
    const supabase = createClient()

    // Use send-message edge function to insert message AND trigger push notification
    const { data, error } = await supabase.functions.invoke('send-message', {
      body: {
        body: params.body,
        conversationId: params.conversationId ?? undefined,
        taskId: params.taskId ?? undefined,
      },
    })

    if (error) throw error

    return data.message as Message
  },

  async getOrCreateConversation(userId: string, otherUserId: string, taskId?: string): Promise<Conversation> {
    const supabase = createClient()

    // Check existing
    const { data: existing } = await supabase
      .from('conversations')
      .select()
      .or(
        `and(participant_1_id.eq.${userId},participant_2_id.eq.${otherUserId}),and(participant_1_id.eq.${otherUserId},participant_2_id.eq.${userId})`,
      )
      .limit(1)

    if (existing && existing.length > 0) return existing[0] as Conversation

    const { data, error } = await supabase
      .from('conversations')
      .insert({
        participant_1_id: userId,
        participant_2_id: otherUserId,
        task_id: taskId ?? null,
      })
      .select()
      .single()

    if (error) throw error
    return data as Conversation
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
        (payload) => callback(payload.new as Message),
      )
      .subscribe()
  },
}

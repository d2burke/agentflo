import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { getMockClient } from '@/__tests__/setup'
import { messageService } from '@/services/message-service'

describe('messageService', () => {
  let mock: ReturnType<typeof getMockClient>
  let originalFetch: typeof global.fetch | undefined

  beforeEach(() => {
    mock = getMockClient()
    originalFetch = global.fetch
    global.fetch = vi.fn() as unknown as typeof global.fetch
  })

  afterEach(() => {
    global.fetch = originalFetch as typeof global.fetch
  })

  describe('fetchConversations', () => {
    it('uses the conversation list RPC', async () => {
      mock.__setMockResult({ data: [] })

      await messageService.fetchConversations('user-1')

      expect(mock.rpc).toHaveBeenCalledWith('get_conversation_list_v2', {
        p_user_id: 'user-1',
        p_limit: 100,
        p_cursor: null,
      })
    })
  })

  describe('fetchMessagePage', () => {
    it('uses paginated message RPC parameters', async () => {
      mock.__setMockResult({ data: [] })

      await messageService.fetchMessagePage('conv-1', 'msg-older', 25)

      expect(mock.rpc).toHaveBeenCalledWith('get_messages_page_v2', {
        p_conversation_id: 'conv-1',
        p_before_message_id: 'msg-older',
        p_limit: 25,
      })
    })
  })

  describe('markConversationRead', () => {
    it('marks a conversation read through the v2 RPC', async () => {
      mock.__setMockResult({ data: null })

      await messageService.markConversationRead('conv-1', 'msg-1')

      expect(mock.rpc).toHaveBeenCalledWith('mark_conversation_read_v2', {
        p_conversation_id: 'conv-1',
        p_last_read_message_id: 'msg-1',
      })
    })
  })

  describe('sendMessage', () => {
    it('invokes the edge function with canonical payload fields', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: vi.fn().mockResolvedValue({
          message: {
            id: 'msg-1',
            conversation_id: 'conv-1',
            task_id: 'task-1',
            sender_id: 'user-1',
            body: 'Hello!',
          },
        }),
      })

      await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello!',
        conversationId: 'conv-1',
        taskId: 'task-1',
        clientMessageId: 'client-1',
      })

      expect(global.fetch).toHaveBeenCalledWith('/api/messages/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'same-origin',
        body: JSON.stringify({
          body: 'Hello!',
          conversationId: 'conv-1',
          taskId: 'task-1',
          clientMessageId: 'client-1',
          messageType: 'text',
          metadata: {},
        }),
      })
    })

    it('maps a 401 route response to a session-expired error', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        json: vi.fn().mockResolvedValue({ error: 'Unauthorized' }),
      })

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello again!',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('Session expired. Please sign in again.')
    })

    it('maps an invalid-jwt route response to a session-expired error', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        json: vi.fn().mockResolvedValue({ error: 'Invalid JWT' }),
      })

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Retried',
        conversationId: 'conv-1',
        clientMessageId: '22222222-2222-4222-8222-222222222222',
      })).rejects.toThrow('Session expired. Please sign in again.')
    })

    it('surfaces the edge function error body message', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
        json: vi.fn().mockResolvedValue({ error: 'Conversation not found' }),
      })

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('Conversation not found')
    })

    it('fails with a session expired message when no access token is available', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        json: vi.fn().mockResolvedValue({ error: 'Unauthorized' }),
      })

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('Session expired. Please sign in again.')
    })

    it('fails with a session expired message when auth retry still fails', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        json: vi.fn().mockResolvedValue({ error: 'Invalid JWT' }),
      })

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('Session expired. Please sign in again.')
    })
  })

  describe('getOrCreateConversation', () => {
    it('resolves direct conversations via RPC', async () => {
      mock.__setMockResult({ data: { id: 'conv-1' } })

      await messageService.getOrCreateConversation('user-1', 'user-2')

      expect(mock.rpc).toHaveBeenCalledWith('get_or_create_direct_conversation_v2', {
        p_other_user_id: 'user-2',
      })
    })

    it('resolves task conversations via RPC when taskId is provided', async () => {
      mock.__setMockResult({ data: { id: 'conv-task-1' } })

      await messageService.getOrCreateConversation('user-1', 'user-2', 'task-1')

      expect(mock.rpc).toHaveBeenCalledWith('get_or_create_task_conversation_v2', {
        p_task_id: 'task-1',
      })
    })
  })

  describe('subscribeToMessages', () => {
    it('subscribes to Realtime channel for a conversation', () => {
      const callback = () => {}

      messageService.subscribeToMessages('conv-1', callback)

      expect(mock.channel).toHaveBeenCalledWith('messages:conv-1')
    })
  })
})

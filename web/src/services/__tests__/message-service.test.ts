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
    it('sends messages through the canonical server route', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } }, error: null })
      mock.auth.getSession.mockResolvedValue({
        data: { session: { access_token: 'access-token', expires_at: Math.floor(Date.now() / 1000) + 3600 } },
        error: null,
      })
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        status: 201,
        text: vi.fn().mockResolvedValue(JSON.stringify({
          message: {
            id: 'msg-1',
            conversation_id: 'conv-1',
            task_id: 'task-1',
            sender_id: 'user-1',
            body: 'Hello!',
          },
        })),
      } as unknown as Response)

      await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello!',
        conversationId: 'conv-1',
        taskId: 'task-1',
        clientMessageId: 'client-1',
      })

      expect(mock.from).not.toHaveBeenCalledWith('messages')
      expect(global.fetch).toHaveBeenCalledWith(
        '/api/messages/send',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer access-token',
          },
          body: JSON.stringify({
            body: 'Hello!',
            conversation_id: 'conv-1',
            task_id: 'task-1',
            clientMessageId: 'client-1',
            conversationId: 'conv-1',
            taskId: 'task-1',
            messageType: 'text',
            metadata: {},
          }),
        },
      )
    })

    it('surfaces message send errors', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } }, error: null })
      mock.auth.getSession.mockResolvedValue({
        data: { session: { access_token: 'access-token', expires_at: Math.floor(Date.now() / 1000) + 3600 } },
        error: null,
      })
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 403,
        text: vi.fn().mockResolvedValue(JSON.stringify({ error: 'new row violates row-level security policy' })),
      } as unknown as Response)

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('new row violates row-level security policy')
    })

    it('fails with a session expired message when no access token is available', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } }, error: null })
      mock.auth.getSession.mockResolvedValue({ data: { session: null }, error: null })
      mock.auth.refreshSession.mockResolvedValue({
        data: { session: null, user: null },
        error: new Error('refresh failed'),
      })
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        text: vi.fn().mockResolvedValue(JSON.stringify({ error: 'Unauthorized' })),
      } as unknown as Response)

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('Session expired. Please sign in again.')
    })

    it('refreshes the session before sending when the access token is near expiry', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } }, error: null })
      mock.auth.getSession.mockResolvedValue({
        data: { session: { access_token: 'stale-token', expires_at: Math.floor(Date.now() / 1000) + 10 } },
        error: null,
      })
      mock.auth.refreshSession.mockResolvedValue({
        data: {
          session: { access_token: 'fresh-token', expires_at: Math.floor(Date.now() / 1000) + 3600 },
          user: { id: 'user-1' },
        },
        error: null,
      })
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        status: 201,
        text: vi.fn().mockResolvedValue(JSON.stringify({
          message: {
            id: 'msg-2',
            conversation_id: 'conv-1',
            task_id: null,
            sender_id: 'user-1',
            body: 'Hello?',
          },
        })),
      } as unknown as Response)

      await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })

      expect(mock.auth.refreshSession).toHaveBeenCalled()
      expect(global.fetch).toHaveBeenCalledWith(
        '/api/messages/send',
        expect.objectContaining({
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer fresh-token',
          },
        }),
      )
    })

    it('fails with a session expired message when no authenticated user is present', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: null }, error: null })
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        text: vi.fn().mockResolvedValue(JSON.stringify({ error: 'Unauthorized' })),
      } as unknown as Response)

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('Session expired. Please sign in again.')
    })

    it('returns the message from the server response', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } }, error: null })
      mock.auth.getSession.mockResolvedValue({
        data: { session: { access_token: 'access-token', expires_at: Math.floor(Date.now() / 1000) + 3600 } },
        error: null,
      })
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        text: vi.fn().mockResolvedValue(JSON.stringify({
          message: {
            id: 'msg-existing',
            conversation_id: 'conv-1',
            task_id: null,
            sender_id: 'user-1',
            body: 'Hello?',
            client_message_id: '11111111-1111-4111-8111-111111111111',
          },
        })),
      } as unknown as Response)

      const message = await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })

      expect(message.id).toBe('msg-existing')
    })

    it('maps unauthorized send responses to session expiry', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } }, error: null })
      mock.auth.getSession.mockResolvedValue({
        data: { session: { access_token: 'access-token', expires_at: Math.floor(Date.now() / 1000) + 3600 } },
        error: null,
      })
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        text: vi.fn().mockResolvedValue(JSON.stringify({ error: 'Unauthorized' })),
      } as unknown as Response)

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello!',
        conversationId: 'conv-1',
        clientMessageId: '33333333-3333-4333-8333-333333333333',
      })).rejects.toThrow('Session expired. Please sign in again.')
    })

    it('retries the server route without a bearer token after an initial 401', async () => {
      mock.auth.getUser.mockResolvedValue({ data: { user: { id: 'user-1' } }, error: null })
      mock.auth.getSession.mockResolvedValue({
        data: { session: { access_token: 'access-token', expires_at: Math.floor(Date.now() / 1000) + 3600 } },
        error: null,
      })
      global.fetch = vi.fn()
        .mockResolvedValueOnce({
          ok: false,
          status: 401,
          text: vi.fn().mockResolvedValue(JSON.stringify({ error: 'Unauthorized' })),
        } as unknown as Response)
        .mockResolvedValueOnce({
          ok: true,
          status: 201,
          text: vi.fn().mockResolvedValue(JSON.stringify({
            message: {
              id: 'msg-retry',
              conversation_id: 'conv-1',
              task_id: null,
              sender_id: 'user-1',
              body: 'Hello again',
            },
          })),
        } as unknown as Response)

      const message = await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello again',
        conversationId: 'conv-1',
        clientMessageId: '44444444-4444-4444-8444-444444444444',
      })

      expect(message.id).toBe('msg-retry')
      expect(global.fetch).toHaveBeenNthCalledWith(
        1,
        '/api/messages/send',
        expect.objectContaining({
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer access-token',
          },
        }),
      )
      expect(global.fetch).toHaveBeenNthCalledWith(
        2,
        '/api/messages/send',
        expect.objectContaining({
          headers: {
            'Content-Type': 'application/json',
          },
        }),
      )
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

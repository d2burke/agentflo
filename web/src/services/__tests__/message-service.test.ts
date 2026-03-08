import { beforeEach, describe, expect, it } from 'vitest'
import { getMockClient } from '@/__tests__/setup'
import { messageService } from '@/services/message-service'

describe('messageService', () => {
  let mock: ReturnType<typeof getMockClient>

  beforeEach(() => {
    mock = getMockClient()
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
      mock.__setMockResult({
        data: {
          message: {
            id: 'msg-1',
            conversation_id: 'conv-1',
            task_id: 'task-1',
            sender_id: 'user-1',
            body: 'Hello!',
          },
        },
      })

      await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello!',
        conversationId: 'conv-1',
        taskId: 'task-1',
        clientMessageId: 'client-1',
      })

      expect(mock.functions.invoke).toHaveBeenCalledWith('send-message', {
        body: {
          body: 'Hello!',
          conversationId: 'conv-1',
          taskId: 'task-1',
          clientMessageId: 'client-1',
          messageType: 'text',
          metadata: {},
        },
      })
    })

    it('retries once after refreshing the session on a 401 function error', async () => {
      mock.functions.invoke
        .mockResolvedValueOnce({
          data: null,
          error: {
            message: 'Edge Function returned a non-2xx status code',
            context: new Response(
              JSON.stringify({ error: 'Unauthorized' }),
              { status: 401, headers: { 'Content-Type': 'application/json' } },
            ),
          },
        })
        .mockResolvedValueOnce({
          data: {
            message: {
              id: 'msg-1',
              conversation_id: 'conv-1',
              sender_id: 'user-1',
              body: 'Hello again!',
            },
          },
          error: null,
        })

      const message = await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello again!',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })

      expect(mock.auth.refreshSession).toHaveBeenCalledOnce()
      expect(mock.functions.invoke).toHaveBeenCalledTimes(2)
      expect(message.id).toBe('msg-1')
    })

    it('surfaces the edge function error body message', async () => {
      mock.functions.invoke.mockResolvedValueOnce({
        data: null,
        error: {
          message: 'Edge Function returned a non-2xx status code',
          context: new Response(
            JSON.stringify({ error: 'Conversation not found' }),
            { status: 404, headers: { 'Content-Type': 'application/json' } },
          ),
        },
      })

      await expect(messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello?',
        conversationId: 'conv-1',
        clientMessageId: '11111111-1111-4111-8111-111111111111',
      })).rejects.toThrow('Conversation not found')
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

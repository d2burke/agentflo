import { describe, it, expect, beforeEach } from 'vitest'
import { messageService } from '@/services/message-service'
import { getMockClient } from '@/__tests__/setup'

describe('messageService', () => {
  let mock: ReturnType<typeof getMockClient>

  beforeEach(() => {
    mock = getMockClient()
  })

  describe('fetchConversations', () => {
    it('queries conversations with OR filter for both participant positions', async () => {
      mock.__setMockResult({ data: [] })

      await messageService.fetchConversations('user-1')

      expect(mock.from).toHaveBeenCalledWith('conversations')
      expect(mock.or).toHaveBeenCalledWith(
        'participant_1_id.eq.user-1,participant_2_id.eq.user-1',
      )
      expect(mock.order).toHaveBeenCalledWith('created_at', { ascending: false })
    })
  })

  describe('fetchMessages', () => {
    it('queries messages by conversation_id ordered ascending', async () => {
      mock.__setMockResult({ data: [] })

      await messageService.fetchMessages('conv-1')

      expect(mock.from).toHaveBeenCalledWith('messages')
      expect(mock.eq).toHaveBeenCalledWith('conversation_id', 'conv-1')
      expect(mock.order).toHaveBeenCalledWith('created_at', { ascending: true })
    })
  })

  describe('fetchTaskMessages', () => {
    it('queries messages by task_id', async () => {
      mock.__setMockResult({ data: [] })

      await messageService.fetchTaskMessages('task-1')

      expect(mock.from).toHaveBeenCalledWith('messages')
      expect(mock.eq).toHaveBeenCalledWith('task_id', 'task-1')
    })
  })

  describe('sendMessage', () => {
    it('invokes send-message edge function with correct params', async () => {
      mock.__setMockResult({ data: { message: { id: 'msg-1', sender_id: 'user-1', body: 'Hello!' } } })

      const result = await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello!',
        conversationId: 'conv-1',
        taskId: 'task-1',
      })

      expect(mock.functions.invoke).toHaveBeenCalledWith('send-message', {
        body: {
          body: 'Hello!',
          conversationId: 'conv-1',
          taskId: 'task-1',
        },
      })
      expect(result).toEqual({ id: 'msg-1', sender_id: 'user-1', body: 'Hello!' })
    })
  })

  describe('subscribeToMessages', () => {
    it('subscribes to Realtime channel for conversation', () => {
      const callback = () => {}
      messageService.subscribeToMessages('conv-1', callback)

      expect(mock.channel).toHaveBeenCalledWith('messages:conv-1')
    })
  })
})

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
    it('inserts message with correct columns', async () => {
      mock.__setMockResult({ data: { id: 'msg-1' } })

      await messageService.sendMessage({
        senderId: 'user-1',
        body: 'Hello!',
        conversationId: 'conv-1',
        taskId: 'task-1',
      })

      expect(mock.from).toHaveBeenCalledWith('messages')
      expect(mock.insert).toHaveBeenCalledWith({
        sender_id: 'user-1',
        body: 'Hello!',
        conversation_id: 'conv-1',
        task_id: 'task-1',
      })
      expect(mock.single).toHaveBeenCalled()
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

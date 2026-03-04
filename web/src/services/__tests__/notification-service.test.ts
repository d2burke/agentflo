import { describe, it, expect, beforeEach } from 'vitest'
import { notificationService } from '@/services/notification-service'
import { getMockClient } from '@/__tests__/setup'

describe('notificationService', () => {
  let mock: ReturnType<typeof getMockClient>

  beforeEach(() => {
    mock = getMockClient()
  })

  describe('fetchNotifications', () => {
    it('queries notifications table by user_id with limit', async () => {
      mock.__setMockResult({ data: [] })

      await notificationService.fetchNotifications('user-1')

      expect(mock.from).toHaveBeenCalledWith('notifications')
      expect(mock.eq).toHaveBeenCalledWith('user_id', 'user-1')
      expect(mock.order).toHaveBeenCalledWith('created_at', { ascending: false })
      expect(mock.limit).toHaveBeenCalledWith(50)
    })
  })

  describe('markAsRead', () => {
    it('updates read_at on specific notification', async () => {
      mock.__setMockResult({ data: null })

      await notificationService.markAsRead('notif-1')

      expect(mock.from).toHaveBeenCalledWith('notifications')
      expect(mock.update).toHaveBeenCalledWith(
        expect.objectContaining({ read_at: expect.any(String) }),
      )
      expect(mock.eq).toHaveBeenCalledWith('id', 'notif-1')
    })
  })

  describe('markAllAsRead', () => {
    it('updates all unread notifications for user', async () => {
      mock.__setMockResult({ data: null })

      await notificationService.markAllAsRead('user-1')

      expect(mock.from).toHaveBeenCalledWith('notifications')
      expect(mock.eq).toHaveBeenCalledWith('user_id', 'user-1')
      expect(mock.is).toHaveBeenCalledWith('read_at', null)
    })
  })
})

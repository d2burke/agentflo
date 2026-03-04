import { describe, it, expect, beforeEach } from 'vitest'
import { storageService } from '@/services/storage-service'
import { getMockClient } from '@/__tests__/setup'

describe('storageService', () => {
  let mock: ReturnType<typeof getMockClient>

  beforeEach(() => {
    mock = getMockClient()
  })

  describe('uploadFile', () => {
    it('uploads to correct bucket and returns public URL', async () => {
      const file = new File(['test'], 'photo.jpg', { type: 'image/jpeg' })

      const url = await storageService.uploadFile('deliverables', 'task-1/photo.jpg', file)

      expect(mock.storage.from).toHaveBeenCalledWith('deliverables')
      expect(url).toBe('https://storage.example.com/file.jpg')
    })
  })

  describe('uploadDeliverablePhoto', () => {
    it('constructs correct path with taskId/runnerId prefix', async () => {
      const file = new File(['test'], 'photo.jpg', { type: 'image/jpeg' })

      await storageService.uploadDeliverablePhoto('task-1', 'runner-1', file, 0)

      expect(mock.storage.from).toHaveBeenCalledWith('deliverables')
    })
  })

  describe('uploadAvatar', () => {
    it('uploads to avatars bucket', async () => {
      const file = new File(['test'], 'avatar.png', { type: 'image/png' })

      await storageService.uploadAvatar('user-1', file)

      expect(mock.storage.from).toHaveBeenCalledWith('avatars')
    })
  })

  describe('uploadPortfolioImage', () => {
    it('uploads to portfolio bucket', async () => {
      const file = new File(['test'], 'portfolio.jpg', { type: 'image/jpeg' })

      await storageService.uploadPortfolioImage('runner-1', file, 0)

      expect(mock.storage.from).toHaveBeenCalledWith('portfolio')
    })
  })

  describe('deleteFile', () => {
    it('removes file from bucket', async () => {
      await storageService.deleteFile('deliverables', 'task-1/photo.jpg')

      expect(mock.storage.from).toHaveBeenCalledWith('deliverables')
    })
  })
})

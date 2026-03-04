import { describe, it, expect, beforeEach } from 'vitest'
import { authService } from '@/services/auth-service'
import { getMockClient } from '@/__tests__/setup'

describe('authService', () => {
  let mock: ReturnType<typeof getMockClient>

  beforeEach(() => {
    mock = getMockClient()
  })

  describe('signUp', () => {
    it('creates auth user then inserts profile into users table', async () => {
      mock.__setMockResult({ data: null })

      await authService.signUp('test@example.com', 'password123', 'Jane Doe', '5125551234', 'agent')

      expect(mock.auth.signUp).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      })

      expect(mock.from).toHaveBeenCalledWith('users')
      expect(mock.upsert).toHaveBeenCalledWith({
        id: 'test-user-id',
        email: 'test@example.com',
        full_name: 'Jane Doe',
        phone: '5125551234',
        role: 'agent',
      })
    })

    it('throws if auth.signUp fails', async () => {
      mock.auth.signUp.mockResolvedValue({ data: { user: null }, error: new Error('Email taken') })

      await expect(authService.signUp('x@x.com', 'pass', 'Test', '', 'agent')).rejects.toThrow()
    })
  })

  describe('signIn', () => {
    it('calls signInWithPassword with credentials', async () => {
      await authService.signIn('test@example.com', 'password123')

      expect(mock.auth.signInWithPassword).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      })
    })
  })

  describe('signOut', () => {
    it('calls supabase auth signOut', async () => {
      await authService.signOut()
      expect(mock.auth.signOut).toHaveBeenCalled()
    })
  })

  describe('fetchUserProfile', () => {
    it('queries users table by id', async () => {
      const user = { id: 'user-1', full_name: 'Test', role: 'agent', email: 'test@test.com' }
      mock.__setMockResult({ data: user })

      await authService.fetchUserProfile('user-1')

      expect(mock.from).toHaveBeenCalledWith('users')
      expect(mock.select).toHaveBeenCalledWith('*')
      expect(mock.eq).toHaveBeenCalledWith('id', 'user-1')
      expect(mock.single).toHaveBeenCalled()
    })
  })

  describe('updateProfile', () => {
    it('updates users table and returns updated record', async () => {
      const updated = { id: 'user-1', full_name: 'Updated Name' }
      mock.__setMockResult({ data: updated })

      await authService.updateProfile('user-1', { full_name: 'Updated Name' })

      expect(mock.from).toHaveBeenCalledWith('users')
      expect(mock.update).toHaveBeenCalledWith({ full_name: 'Updated Name' })
      expect(mock.eq).toHaveBeenCalledWith('id', 'user-1')
    })
  })

  describe('MFA', () => {
    it('enrollMFA calls mfa.enroll with TOTP', async () => {
      await authService.enrollMFA()
      expect(mock.auth.mfa.enroll).toHaveBeenCalledWith({
        factorType: 'totp',
        friendlyName: 'AgentFlo Authenticator',
      })
    })

    it('verifyMFA creates challenge then verifies', async () => {
      await authService.verifyMFA('factor-1', '123456')

      expect(mock.auth.mfa.challenge).toHaveBeenCalledWith({ factorId: 'factor-1' })
      expect(mock.auth.mfa.verify).toHaveBeenCalledWith({
        factorId: 'factor-1',
        challengeId: 'challenge-1',
        code: '123456',
      })
    })

    it('getMFAFactors lists factors', async () => {
      await authService.getMFAFactors()
      expect(mock.auth.mfa.listFactors).toHaveBeenCalled()
    })

    it('unenrollMFA removes factor', async () => {
      await authService.unenrollMFA('factor-1')
      expect(mock.auth.mfa.unenroll).toHaveBeenCalledWith({ factorId: 'factor-1' })
    })
  })
})

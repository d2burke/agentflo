import { vi, beforeEach } from 'vitest'
import '@testing-library/jest-dom'

// ── Chainable Supabase Mock Factory ──

export function createMockSupabaseClient() {
  let mockResolvedValue: any = { data: null, error: null }

  const chain: any = {}

  // Methods that continue the chain
  const chainMethods = [
    'from', 'select', 'insert', 'update', 'delete', 'upsert',
    'eq', 'neq', 'or', 'is', 'in', 'order', 'limit', 'single',
  ]

  for (const method of chainMethods) {
    chain[method] = vi.fn().mockImplementation(() => {
      // Return a thenable chain (Supabase queries are PromiseLike)
      return Object.assign(
        Object.create(chain),
        { then: (resolve: any) => resolve(mockResolvedValue) },
      )
    })
  }

  // RPC calls
  chain.rpc = vi.fn().mockImplementation(() => ({
    then: (resolve: any) => resolve(mockResolvedValue),
  }))

  // Edge functions
  chain.functions = {
    invoke: vi.fn().mockResolvedValue(mockResolvedValue),
  }

  // Auth
  chain.auth = {
    signUp: vi.fn().mockResolvedValue({ data: { user: { id: 'test-user-id' } }, error: null }),
    signInWithPassword: vi.fn().mockResolvedValue({ data: { user: { id: 'test-user-id' } }, error: null }),
    signOut: vi.fn().mockResolvedValue({ error: null }),
    getUser: vi.fn().mockResolvedValue({ data: { user: null }, error: null }),
    resetPasswordForEmail: vi.fn().mockResolvedValue({ error: null }),
    onAuthStateChange: vi.fn().mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } }),
    mfa: {
      enroll: vi.fn().mockResolvedValue({ data: { id: 'factor-1', totp: { uri: 'otpauth://...' } }, error: null }),
      challenge: vi.fn().mockResolvedValue({ data: { id: 'challenge-1' }, error: null }),
      verify: vi.fn().mockResolvedValue({ data: {}, error: null }),
      listFactors: vi.fn().mockResolvedValue({ data: { totp: [] }, error: null }),
      unenroll: vi.fn().mockResolvedValue({ data: {}, error: null }),
    },
  }

  // Storage
  chain.storage = {
    from: vi.fn().mockReturnValue({
      upload: vi.fn().mockResolvedValue({ error: null }),
      getPublicUrl: vi.fn().mockReturnValue({ data: { publicUrl: 'https://storage.example.com/file.jpg' } }),
      remove: vi.fn().mockResolvedValue({ error: null }),
    }),
  }

  // Realtime
  chain.channel = vi.fn().mockReturnValue({
    on: vi.fn().mockReturnThis(),
    subscribe: vi.fn(),
    unsubscribe: vi.fn(),
  })

  // Helper to set what queries resolve to
  chain.__setMockResult = (result: { data?: any; error?: any }) => {
    mockResolvedValue = { data: result.data ?? null, error: result.error ?? null }
  }

  return chain
}

// ── Global mock of createClient ──

let mockClient: ReturnType<typeof createMockSupabaseClient>

vi.mock('@/lib/supabase/client', () => ({
  createClient: vi.fn(() => mockClient),
}))

// Reset mock before each test
beforeEach(() => {
  mockClient = createMockSupabaseClient()
})

export function getMockClient() {
  return mockClient
}

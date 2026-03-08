import { afterEach, describe, expect, it, vi } from 'vitest'
import { createClientMessageId } from '@/lib/client-message-id'

const UUID_V4_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

const originalCrypto = globalThis.crypto

function setCrypto(value: Crypto | undefined) {
  Object.defineProperty(globalThis, 'crypto', {
    value,
    configurable: true,
    writable: true,
  })
}

afterEach(() => {
  setCrypto(originalCrypto)
  vi.restoreAllMocks()
})

describe('createClientMessageId', () => {
  it('uses crypto.randomUUID when available', () => {
    const randomUUID = vi.fn(() => '11111111-1111-4111-8111-111111111111')
    setCrypto({
      randomUUID,
      getRandomValues: vi.fn(),
    } as unknown as Crypto)

    expect(createClientMessageId()).toBe('11111111-1111-4111-8111-111111111111')
    expect(randomUUID).toHaveBeenCalledOnce()
  })

  it('falls back to crypto.getRandomValues with a valid UUID', () => {
    setCrypto({
      getRandomValues: vi.fn((values: Uint8Array) => {
        values.set([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
        return values
      }),
    } as unknown as Crypto)

    expect(createClientMessageId()).toMatch(UUID_V4_PATTERN)
  })

  it('falls back to Math.random and still returns a valid UUID', () => {
    setCrypto(undefined)
    vi.spyOn(Math, 'random').mockReturnValue(0.25)

    expect(createClientMessageId()).toMatch(UUID_V4_PATTERN)
  })
})

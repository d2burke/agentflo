import { describe, it, expect } from 'vitest'
import {
  cn,
  formatPrice,
  formatPriceFull,
  calculateFee,
  firstName,
  getInitials,
  timeAgo,
  formatDate,
  formatDateTime,
  getGreeting,
} from '@/lib/utils'

describe('cn', () => {
  it('merges class names', () => {
    expect(cn('foo', 'bar')).toBe('foo bar')
  })

  it('handles conditional classes', () => {
    expect(cn('foo', false && 'bar', 'baz')).toBe('foo baz')
  })

  it('resolves Tailwind conflicts', () => {
    expect(cn('p-4', 'p-6')).toBe('p-6')
  })
})

describe('formatPrice', () => {
  it('formats cents to dollars', () => {
    expect(formatPrice(15000)).toBe('$150')
  })

  it('includes cents when not whole', () => {
    expect(formatPrice(15050)).toBe('$150.50')
  })

  it('handles zero', () => {
    expect(formatPrice(0)).toBe('$0')
  })

  it('handles single cent', () => {
    expect(formatPrice(1)).toBe('$0.01')
  })
})

describe('formatPriceFull', () => {
  it('always shows two decimal places', () => {
    expect(formatPriceFull(15000)).toBe('$150.00')
  })

  it('shows partial cents', () => {
    expect(formatPriceFull(15050)).toBe('$150.50')
  })
})

describe('calculateFee', () => {
  it('calculates 15% fee by default', () => {
    expect(calculateFee(10000)).toBe(1500)
  })

  it('rounds to nearest cent', () => {
    expect(calculateFee(10001)).toBe(1500)
  })

  it('handles zero', () => {
    expect(calculateFee(0)).toBe(0)
  })
})

describe('firstName', () => {
  it('returns first name from full name', () => {
    expect(firstName('Jane Doe')).toBe('Jane')
  })

  it('returns the only name if single word', () => {
    expect(firstName('Jane')).toBe('Jane')
  })

  it('handles empty string', () => {
    expect(firstName('')).toBe('')
  })
})

describe('getInitials', () => {
  it('returns initials from full name', () => {
    expect(getInitials('Jane Doe')).toBe('JD')
  })

  it('returns single initial for single name', () => {
    expect(getInitials('Jane')).toBe('J')
  })

  it('handles three-part names', () => {
    expect(getInitials('Mary Jane Watson')).toBe('MJ')
  })

  it('handles empty string', () => {
    expect(getInitials('')).toBe('')
  })
})

describe('getGreeting', () => {
  it('returns a greeting string', () => {
    const greeting = getGreeting()
    expect(['Good morning', 'Good afternoon', 'Good evening']).toContain(greeting)
  })
})

describe('timeAgo', () => {
  it('returns a string for a recent date', () => {
    const now = new Date().toISOString()
    const result = timeAgo(now)
    expect(typeof result).toBe('string')
    expect(result.length).toBeGreaterThan(0)
  })

  it('handles null/undefined gracefully', () => {
    const result = timeAgo(null)
    expect(typeof result).toBe('string')
  })
})

describe('formatDate', () => {
  it('formats an ISO date string', () => {
    const result = formatDate('2024-01-15T10:30:00Z')
    expect(typeof result).toBe('string')
    expect(result.length).toBeGreaterThan(0)
  })
})

describe('formatDateTime', () => {
  it('formats an ISO date-time string', () => {
    const result = formatDateTime('2024-01-15T10:30:00Z')
    expect(typeof result).toBe('string')
    expect(result).toContain('Jan')
  })
})

// Shared input validation and sanitization for edge functions

/**
 * Strip HTML tags and limit string length.
 */
export function sanitizeString(input: unknown, maxLength = 10000): string {
  if (typeof input !== 'string') return ''
  return input
    .replace(/<[^>]*>/g, '')  // Strip HTML tags
    .replace(/[<>]/g, '')     // Strip remaining angle brackets
    .trim()
    .slice(0, maxLength)
}

/**
 * Validate UUID format.
 */
export function isValidUUID(value: unknown): value is string {
  if (typeof value !== 'string') return false
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
}

/**
 * Validate email format.
 */
export function isValidEmail(value: unknown): value is string {
  if (typeof value !== 'string') return false
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) && value.length <= 320
}

/**
 * Validate price is a positive integer in cents (max $10,000).
 */
export function isValidPrice(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value > 0 && value <= 1000000
}

/**
 * Validate task category.
 */
const VALID_CATEGORIES = ['Photography', 'Showing', 'Staging', 'Open House', 'Inspection'] as const
export type TaskCategory = typeof VALID_CATEGORIES[number]

export function isValidCategory(value: unknown): value is TaskCategory {
  return typeof value === 'string' && VALID_CATEGORIES.includes(value as TaskCategory)
}

/**
 * Validate platform for push tokens.
 */
export function isValidPlatform(value: unknown): value is 'ios' | 'android' | 'web' {
  return typeof value === 'string' && ['ios', 'android', 'web'].includes(value)
}

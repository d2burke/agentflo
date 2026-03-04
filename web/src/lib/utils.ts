import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { formatDistanceToNow, format, isToday, isYesterday } from 'date-fns'

// Tailwind class merge utility
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Format price from cents to dollars
export function formatPrice(cents: number): string {
  const dollars = cents / 100
  return dollars % 1 === 0
    ? `$${dollars.toFixed(0)}`
    : `$${dollars.toFixed(2)}`
}

// Format price with cents always shown
export function formatPriceFull(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`
}

// Relative time (e.g., "2 hours ago")
export function timeAgo(dateString: string | null | undefined): string {
  if (!dateString) return ''
  return formatDistanceToNow(new Date(dateString), { addSuffix: true })
}

// Format date for display
export function formatDate(dateString: string | null | undefined): string {
  if (!dateString) return ''
  const date = new Date(dateString)
  if (isToday(date)) return `Today at ${format(date, 'h:mm a')}`
  if (isYesterday(date)) return `Yesterday at ${format(date, 'h:mm a')}`
  return format(date, 'MMM d, yyyy')
}

// Format date with time
export function formatDateTime(dateString: string | null | undefined): string {
  if (!dateString) return ''
  return format(new Date(dateString), 'MMM d, yyyy h:mm a')
}

// Time-of-day greeting
export function getGreeting(): string {
  const hour = new Date().getHours()
  if (hour < 12) return 'Good morning'
  if (hour < 17) return 'Good afternoon'
  return 'Good evening'
}

// Get first name from full name
export function firstName(fullName: string): string {
  return fullName.split(' ')[0]
}

// Get initials from full name
export function getInitials(name: string): string {
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)
}

// Calculate platform fee from price
export function calculateFee(priceInCents: number, rate = 0.15): number {
  return Math.round(priceInCents * rate)
}

import type { TaskCategory, TaskStatus } from '@/types/models'

// Task category metadata
export const TASK_CATEGORIES: Record<TaskCategory, {
  label: string
  description: string
  suggestedPrice: string
  icon: string // Lucide icon name
  isCheckInCheckOut: boolean
}> = {
  Photography: {
    label: 'Photography',
    description: 'Professional listing photos',
    suggestedPrice: '$100-$300',
    icon: 'Camera',
    isCheckInCheckOut: false,
  },
  Showing: {
    label: 'Showing',
    description: 'Buyer or inspector showing',
    suggestedPrice: '$50-$100',
    icon: 'Eye',
    isCheckInCheckOut: true,
  },
  Staging: {
    label: 'Staging',
    description: 'Furniture staging & setup',
    suggestedPrice: '$200-$400',
    icon: 'Box',
    isCheckInCheckOut: true,
  },
  'Open House': {
    label: 'Open House',
    description: 'Host an open house event',
    suggestedPrice: '$75-$150',
    icon: 'Home',
    isCheckInCheckOut: true,
  },
  Inspection: {
    label: 'Inspection',
    description: 'Property inspection report',
    suggestedPrice: '$75-$200',
    icon: 'ClipboardCheck',
    isCheckInCheckOut: false,
  },
}

// Status semantic types
export type StatusSemantic = 'pending' | 'active' | 'working' | 'alert' | 'done'

// Status badge styling
export const STATUS_BADGES: Record<TaskStatus, {
  label: string
  semantic: StatusSemantic
}> = {
  draft: { label: 'Draft', semantic: 'done' },
  posted: { label: 'Posted', semantic: 'pending' },
  accepted: { label: 'Accepted', semantic: 'active' },
  in_progress: { label: 'In Progress', semantic: 'working' },
  deliverables_submitted: { label: 'Review', semantic: 'pending' },
  revision_requested: { label: 'Revision', semantic: 'working' },
  completed: { label: 'Completed', semantic: 'done' },
  cancelled: { label: 'Cancelled', semantic: 'alert' },
}

// Semantic status colors (CSS variable-based)
export const STATUS_SEMANTIC_STYLES: Record<StatusSemantic, {
  bgClass: string
  textClass: string
  dotClass: string
}> = {
  pending: { bgClass: 'bg-[var(--color-status-pending-bg)]', textClass: 'text-[var(--color-status-pending-text)]', dotClass: 'bg-[var(--color-status-pending-dot)]' },
  active: { bgClass: 'bg-[var(--color-status-active-bg)]', textClass: 'text-[var(--color-status-active-text)]', dotClass: 'bg-[var(--color-status-active-dot)]' },
  working: { bgClass: 'bg-[var(--color-status-working-bg)]', textClass: 'text-[var(--color-status-working-text)]', dotClass: 'bg-[var(--color-status-working-dot)]' },
  alert: { bgClass: 'bg-[var(--color-status-alert-bg)]', textClass: 'text-[var(--color-status-alert-text)]', dotClass: 'bg-[var(--color-status-alert-dot)]' },
  done: { bgClass: 'bg-[var(--color-status-done-bg)]', textClass: 'text-[var(--color-status-done-text)]', dotClass: 'bg-[var(--color-status-done-dot)]' },
}

// Category-aware status display names
export function getCategoryStatusLabel(status: TaskStatus, category?: TaskCategory): string {
  if (!category) return STATUS_BADGES[status].label
  const key = `${category}:${status}` as const
  const overrides: Record<string, string> = {
    'Photography:in_progress': 'Shooting',
    'Photography:deliverables_submitted': 'Delivered',
    'Staging:deliverables_submitted': 'Staged',
    'Staging:completed': 'Staged',
    'Open House:accepted': 'Scheduled',
    'Open House:in_progress': 'Live',
    'Inspection:accepted': 'Confirmed',
    'Inspection:in_progress': 'Inspecting',
    'Inspection:deliverables_submitted': 'Report Ready',
  }
  return overrides[key] ?? STATUS_BADGES[status].label
}

// Category-aware semantic mapping
export function getCategoryStatusSemantic(status: TaskStatus, category?: TaskCategory): StatusSemantic {
  if (!category) return STATUS_BADGES[status].semantic
  const key = `${category}:${status}` as const
  const overrides: Record<string, StatusSemantic> = {
    'Open House:accepted': 'pending',
    'Open House:in_progress': 'alert',
    'Photography:deliverables_submitted': 'active',
    'Inspection:deliverables_submitted': 'alert',
  }
  return overrides[key] ?? STATUS_BADGES[status].semantic
}

// ASHI inspection systems
export const ASHI_SYSTEMS = [
  { key: 'structure', label: 'Structure' },
  { key: 'exterior', label: 'Exterior' },
  { key: 'roofing', label: 'Roofing' },
  { key: 'plumbing', label: 'Plumbing' },
  { key: 'electrical', label: 'Electrical' },
  { key: 'heating', label: 'Heating' },
  { key: 'cooling', label: 'Cooling' },
  { key: 'interior', label: 'Interior' },
  { key: 'insulation_ventilation', label: 'Insulation & Ventilation' },
  { key: 'fireplaces', label: 'Fireplaces' },
] as const

// Buyer interest options
export const BUYER_INTEREST_OPTIONS = [
  { value: 'not_interested', label: 'Not Interested' },
  { value: 'somewhat_interested', label: 'Somewhat Interested' },
  { value: 'very_interested', label: 'Very Interested' },
  { value: 'likely_offer', label: 'Likely Offer' },
] as const

// Platform fee rate
export const PLATFORM_FEE_RATE = 0.15

// Supabase query columns — excludes property_point (binary geography type)
export const TASK_COLUMNS = `id,agent_id,runner_id,category,status,property_address,property_lat,property_lng,price,platform_fee,runner_payout,instructions,category_form_data,stripe_payment_intent_id,scheduled_at,posted_at,accepted_at,completed_at,cancelled_at,cancellation_reason,checked_in_at,checked_in_lat,checked_in_lng,checked_out_at,checked_out_lat,checked_out_lng,qr_code_token,created_at,updated_at`

export const TASK_COLUMNS_WITH_AGENT = `${TASK_COLUMNS},agent:users!agent_id(id,full_name,avatar_url)`

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

// Status badge styling — matches design-tokens.ts statusBadge
export const STATUS_BADGES: Record<TaskStatus, {
  label: string
  bgClass: string
  textClass: string
}> = {
  draft: { label: 'Draft', bgClass: 'bg-border-light', textClass: 'text-slate' },
  posted: { label: 'Posted', bgClass: 'bg-blue-light', textClass: 'text-blue' },
  accepted: { label: 'Accepted', bgClass: 'bg-green-light', textClass: 'text-green' },
  in_progress: { label: 'In Progress', bgClass: 'bg-amber-light', textClass: 'text-amber' },
  deliverables_submitted: { label: 'Review', bgClass: 'bg-blue-light', textClass: 'text-blue' },
  revision_requested: { label: 'Revision', bgClass: 'bg-amber-light', textClass: 'text-amber' },
  completed: { label: 'Completed', bgClass: 'bg-green-light', textClass: 'text-green' },
  cancelled: { label: 'Cancelled', bgClass: 'bg-error-light', textClass: 'text-error' },
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

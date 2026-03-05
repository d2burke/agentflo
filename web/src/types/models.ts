// TypeScript models — direct translation from AgentFlo/Models/Models.swift
// All field names use snake_case to match Supabase column names (no CodingKeys needed)

export type UserRole = 'agent' | 'runner'

export type VettingStatus = 'not_started' | 'pending' | 'approved' | 'rejected' | 'expired'

export interface AppUser {
  id: string
  role: UserRole
  email: string
  full_name: string
  phone?: string | null
  avatar_url?: string | null
  brokerage?: string | null
  license_number?: string | null
  license_state?: string | null
  bio?: string | null
  vetting_status: VettingStatus
  onboarding_completed_steps?: string[] | null
  stripe_customer_id?: string | null
  stripe_connect_id?: string | null
  headline?: string | null
  specialties?: string[] | null
  profile_slug?: string | null
  is_public_profile_enabled?: boolean | null
  created_at?: string | null
  updated_at?: string | null
}

// Task

export type TaskStatus =
  | 'draft'
  | 'posted'
  | 'accepted'
  | 'in_progress'
  | 'deliverables_submitted'
  | 'revision_requested'
  | 'completed'
  | 'cancelled'

export type TaskCategory = 'Photography' | 'Showing' | 'Staging' | 'Open House' | 'Inspection'

export interface AgentTask {
  id: string
  agent_id: string
  runner_id?: string | null
  category: TaskCategory
  status: TaskStatus
  property_address: string
  property_lat?: number | null
  property_lng?: number | null
  price: number // cents
  platform_fee?: number | null
  runner_payout?: number | null
  instructions?: string | null
  category_form_data?: Record<string, string> | null
  stripe_payment_intent_id?: string | null
  scheduled_at?: string | null
  posted_at?: string | null
  accepted_at?: string | null
  completed_at?: string | null
  cancelled_at?: string | null
  cancellation_reason?: string | null
  checked_in_at?: string | null
  checked_in_lat?: number | null
  checked_in_lng?: number | null
  checked_out_at?: string | null
  checked_out_lat?: number | null
  checked_out_lng?: number | null
  qr_code_token?: string | null
  created_at?: string | null
  updated_at?: string | null
  // Joined fields
  agent?: PublicProfile | null
}

// Task Application

export type ApplicationStatus = 'pending' | 'accepted' | 'declined' | 'withdrawn'

export interface TaskApplication {
  id: string
  task_id: string
  runner_id: string
  status: ApplicationStatus
  message?: string | null
  created_at?: string | null
  // Joined
  runner?: PublicProfile | null
}

// Public Profile (limited user info for display in task cards)

export interface PublicProfile {
  id: string
  full_name: string
  avatar_url?: string | null
}

// Public Profile Full (from public_profiles view)

export interface PublicProfileFull {
  id: string
  full_name: string
  avatar_url?: string | null
  role: UserRole
  brokerage?: string | null
  bio?: string | null
  headline?: string | null
  specialties?: string[] | null
  profile_slug?: string | null
  is_public_profile_enabled?: boolean | null
  is_verified: boolean
  avg_rating?: number | null
  review_count: number
  completed_tasks: number
  created_at?: string | null
}

// Deliverable

export type DeliverableType = 'photo' | 'document' | 'report' | 'checklist'

export interface Deliverable {
  id: string
  task_id: string
  runner_id: string
  type: DeliverableType
  file_url?: string | null
  thumbnail_url?: string | null
  title?: string | null
  notes?: string | null
  sort_order?: number | null
  room?: string | null
  photo_type?: 'before' | 'after' | null
  created_at?: string | null
}

// Message

export interface Message {
  id: string
  task_id?: string | null
  conversation_id?: string | null
  sender_id: string
  body: string
  read_at?: string | null
  created_at?: string | null
}

// Conversation

export interface Conversation {
  id: string
  participant_1_id: string
  participant_2_id: string
  task_id?: string | null
  created_at?: string | null
}

// Open House Visitor

export type InterestLevel = 'just_looking' | 'interested' | 'very_interested'

export interface OpenHouseVisitor {
  id: string
  task_id: string
  visitor_name: string
  email?: string | null
  phone?: string | null
  interest_level: InterestLevel
  pre_approved: boolean
  agent_represented: boolean
  representing_agent_name?: string | null
  notes?: string | null
  created_at?: string | null
}

// Showing Report

export type BuyerInterest = 'not_interested' | 'somewhat_interested' | 'very_interested' | 'likely_offer'

export interface ShowingReport {
  id: string
  task_id: string
  runner_id: string
  buyer_name: string
  buyer_interest: BuyerInterest
  questions?: Array<Record<string, string>> | null
  property_feedback?: string | null
  follow_up_notes?: string | null
  next_steps?: string | null
  created_at?: string | null
}

// Review

export interface Review {
  id: string
  task_id: string
  reviewer_id: string
  reviewee_id: string
  rating: number // 1-5
  comment?: string | null
  created_at?: string | null
}

// Notification

export interface AppNotification {
  id: string
  user_id: string
  type: string
  title: string
  body: string
  data?: Record<string, string> | null
  read_at?: string | null
  push_sent_at?: string | null
  created_at?: string | null
}

// Portfolio Image

export interface PortfolioImage {
  id: string
  runner_id: string
  image_url: string
  caption?: string | null
  sort_order: number
  created_at?: string | null
}

// Inspection

export type InspectionSystem =
  | 'structure'
  | 'exterior'
  | 'roofing'
  | 'plumbing'
  | 'electrical'
  | 'heating'
  | 'cooling'
  | 'interior'
  | 'insulation_ventilation'
  | 'fireplaces'

export type FindingStatus = 'good' | 'deficiency' | 'not_inspected' | 'na'

export type FindingSeverity = 'critical' | 'major' | 'minor' | 'monitor' | 'good'

export interface InspectionFinding {
  id: string
  task_id: string
  runner_id: string
  system_category: InspectionSystem
  sub_item: string
  status: FindingStatus
  severity?: FindingSeverity | null
  description?: string | null
  recommendation?: string | null
  not_inspected_reason?: string | null
  photo_urls?: string[] | null
  sort_order: number
  created_at?: string | null
}

// Service Area

export interface ServiceArea {
  id: string
  runner_id: string
  name: string
  center_lat: number
  center_lng: number
  radius_miles: number
  is_active: boolean
  created_at?: string | null
}

// Availability

export interface Availability {
  id: string
  runner_id: string
  day_of_week: number // 0-6
  start_time: string
  end_time: string
  is_active: boolean
}

// Notification Preferences

export interface NotificationPreferences {
  user_id: string
  task_updates: boolean
  messages: boolean
  payment_confirmations: boolean
  new_available_tasks: boolean
  weekly_earnings: boolean
  product_updates: boolean
}

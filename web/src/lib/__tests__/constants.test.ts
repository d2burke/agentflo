import { describe, it, expect } from 'vitest'
import {
  TASK_COLUMNS,
  TASK_COLUMNS_WITH_AGENT,
  TASK_CATEGORIES,
  STATUS_BADGES,
  PLATFORM_FEE_RATE,
} from '@/lib/constants'
import type { AgentTask, TaskCategory, TaskStatus } from '@/types/models'

describe('TASK_COLUMNS', () => {
  const columns = TASK_COLUMNS.split(',').map((c) => c.trim())

  it('contains every key from AgentTask except joined fields', () => {
    // All AgentTask keys that come from the DB (excluding joined/virtual fields)
    const agentTaskDbKeys: (keyof AgentTask)[] = [
      'id', 'agent_id', 'runner_id', 'category', 'status',
      'property_address', 'property_lat', 'property_lng',
      'price', 'platform_fee', 'runner_payout',
      'instructions', 'category_form_data', 'stripe_payment_intent_id',
      'scheduled_at', 'posted_at', 'accepted_at', 'completed_at',
      'cancelled_at', 'cancellation_reason',
      'checked_in_at', 'checked_in_lat', 'checked_in_lng',
      'checked_out_at', 'checked_out_lat', 'checked_out_lng',
      'qr_code_token', 'created_at', 'updated_at',
    ]

    for (const key of agentTaskDbKeys) {
      expect(columns, `Missing column: ${key}`).toContain(key)
    }
  })

  it('does NOT contain property_point (PostGIS binary)', () => {
    expect(columns).not.toContain('property_point')
  })

  it('does NOT contain joined field "agent"', () => {
    // "agent" is a join alias, not a DB column
    expect(columns).not.toContain('agent')
  })

  it('has no empty or whitespace-only entries', () => {
    for (const col of columns) {
      expect(col.length).toBeGreaterThan(0)
    }
  })
})

describe('TASK_COLUMNS_WITH_AGENT', () => {
  it('starts with TASK_COLUMNS', () => {
    expect(TASK_COLUMNS_WITH_AGENT.startsWith(TASK_COLUMNS)).toBe(true)
  })

  it('includes the agent join with correct foreign-key syntax', () => {
    expect(TASK_COLUMNS_WITH_AGENT).toContain('agent:users!agent_id(id,full_name,avatar_url)')
  })
})

describe('TASK_CATEGORIES', () => {
  const expectedCategories: TaskCategory[] = [
    'Photography', 'Showing', 'Staging', 'Open House', 'Inspection',
  ]

  it('has all expected categories', () => {
    for (const cat of expectedCategories) {
      expect(TASK_CATEGORIES).toHaveProperty(cat)
    }
  })

  it('each category has required metadata', () => {
    for (const [, meta] of Object.entries(TASK_CATEGORIES)) {
      expect(meta).toHaveProperty('label')
      expect(meta).toHaveProperty('description')
      expect(meta).toHaveProperty('suggestedPrice')
      expect(meta).toHaveProperty('icon')
      expect(meta).toHaveProperty('isCheckInCheckOut')
    }
  })
})

describe('STATUS_BADGES', () => {
  const expectedStatuses: TaskStatus[] = [
    'draft', 'posted', 'accepted', 'in_progress',
    'deliverables_submitted', 'revision_requested', 'completed', 'cancelled',
  ]

  it('has all expected statuses', () => {
    for (const status of expectedStatuses) {
      expect(STATUS_BADGES).toHaveProperty(status)
    }
  })

  it('each badge has label, bgClass, and textClass', () => {
    for (const [, badge] of Object.entries(STATUS_BADGES)) {
      expect(badge).toHaveProperty('label')
      expect(badge).toHaveProperty('bgClass')
      expect(badge).toHaveProperty('textClass')
    }
  })
})

describe('PLATFORM_FEE_RATE', () => {
  it('equals 15%', () => {
    expect(PLATFORM_FEE_RATE).toBe(0.15)
  })
})

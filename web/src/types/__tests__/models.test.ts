import { describe, it, expect } from 'vitest'
import type {
  AppUser, AgentTask, Message, Conversation,
  Deliverable, AppNotification,
} from '@/types/models'

// ── Fixture Factories ──
// These produce valid objects matching DB schema. Exported for reuse in service tests.

export function createMockUser(overrides?: Partial<AppUser>): AppUser {
  return {
    id: 'user-1',
    role: 'agent',
    email: 'test@example.com',
    full_name: 'Test User',
    phone: '5125551234',
    avatar_url: null,
    brokerage: null,
    license_number: null,
    license_state: null,
    bio: null,
    vetting_status: 'approved',
    onboarding_completed_steps: null,
    stripe_customer_id: null,
    stripe_connect_id: null,
    headline: null,
    specialties: null,
    profile_slug: null,
    is_public_profile_enabled: false,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
    ...overrides,
  }
}

export function createMockTask(overrides?: Partial<AgentTask>): AgentTask {
  return {
    id: 'task-1',
    agent_id: 'user-1',
    runner_id: null,
    category: 'Photography',
    status: 'posted',
    property_address: '123 Main St, Austin, TX 78701',
    property_lat: 30.2672,
    property_lng: -97.7431,
    price: 15000,
    platform_fee: 2250,
    runner_payout: 15000,
    instructions: 'Take exterior and interior photos',
    category_form_data: null,
    stripe_payment_intent_id: null,
    scheduled_at: '2024-02-01T10:00:00Z',
    posted_at: '2024-01-15T12:00:00Z',
    accepted_at: null,
    completed_at: null,
    cancelled_at: null,
    cancellation_reason: null,
    checked_in_at: null,
    checked_in_lat: null,
    checked_in_lng: null,
    checked_out_at: null,
    checked_out_lat: null,
    checked_out_lng: null,
    qr_code_token: null,
    created_at: '2024-01-15T12:00:00Z',
    updated_at: '2024-01-15T12:00:00Z',
    agent: null,
    ...overrides,
  }
}

export function createMockMessage(overrides?: Partial<Message>): Message {
  return {
    id: 'msg-1',
    task_id: 'task-1',
    conversation_id: 'conv-1',
    sender_id: 'user-1',
    body: 'Hello!',
    client_message_id: null,
    message_type: 'text',
    metadata: {},
    reply_to_message_id: null,
    edited_at: null,
    deleted_at: null,
    delivery_status: 'sent',
    read_at: null,
    created_at: '2024-01-15T12:00:00Z',
    ...overrides,
  }
}

export function createMockConversation(overrides?: Partial<Conversation>): Conversation {
  return {
    id: 'conv-1',
    participant_1_id: 'user-1',
    participant_2_id: 'user-2',
    kind: 'task',
    task_id: 'task-1',
    created_by: 'user-1',
    last_message_id: 'msg-1',
    last_message_at: '2024-01-15T12:00:00Z',
    last_message_preview: 'Hello!',
    created_at: '2024-01-15T12:00:00Z',
    updated_at: '2024-01-15T12:00:00Z',
    ...overrides,
  }
}

export function createMockNotification(overrides?: Partial<AppNotification>): AppNotification {
  return {
    id: 'notif-1',
    user_id: 'user-1',
    type: 'task_accepted',
    title: 'Task Accepted',
    body: 'Your task was accepted by a runner',
    data: { task_id: 'task-1' },
    read_at: null,
    push_sent_at: null,
    created_at: '2024-01-15T12:00:00Z',
    ...overrides,
  }
}

export function createMockDeliverable(overrides?: Partial<Deliverable>): Deliverable {
  return {
    id: 'del-1',
    task_id: 'task-1',
    runner_id: 'user-2',
    type: 'photo',
    file_url: 'https://storage.example.com/photo.jpg',
    thumbnail_url: null,
    title: 'Front exterior',
    notes: null,
    sort_order: 0,
    room: null,
    photo_type: null,
    created_at: '2024-01-15T12:00:00Z',
    ...overrides,
  }
}

// ── Tests ──

describe('Model fixtures', () => {
  it('createMockUser produces a valid AppUser', () => {
    const user = createMockUser()
    expect(user.id).toBe('user-1')
    expect(user.role).toBe('agent')
    expect(user.email).toBe('test@example.com')
    expect(user.full_name).toBe('Test User')
    expect(user.vetting_status).toBe('approved')
  })

  it('createMockUser accepts overrides', () => {
    const runner = createMockUser({ role: 'runner', full_name: 'Runner Bob' })
    expect(runner.role).toBe('runner')
    expect(runner.full_name).toBe('Runner Bob')
  })

  it('createMockTask produces a valid AgentTask', () => {
    const task = createMockTask()
    expect(task.id).toBe('task-1')
    expect(task.category).toBe('Photography')
    expect(task.status).toBe('posted')
    expect(task.price).toBe(15000)
    expect(typeof task.property_address).toBe('string')
  })

  it('createMockTask accepts overrides', () => {
    const task = createMockTask({ status: 'completed', price: 20000 })
    expect(task.status).toBe('completed')
    expect(task.price).toBe(20000)
  })

  it('createMockMessage produces a valid Message', () => {
    const msg = createMockMessage()
    expect(msg.sender_id).toBe('user-1')
    expect(msg.body).toBe('Hello!')
  })

  it('createMockConversation has two participants', () => {
    const conv = createMockConversation()
    expect(conv.participant_1_id).toBeTruthy()
    expect(conv.participant_2_id).toBeTruthy()
    expect(conv.participant_1_id).not.toBe(conv.participant_2_id)
  })

  it('createMockNotification produces a valid notification', () => {
    const notif = createMockNotification()
    expect(notif.type).toBe('task_accepted')
    expect(notif.data?.task_id).toBe('task-1')
  })

  it('createMockDeliverable produces a valid deliverable', () => {
    const del = createMockDeliverable()
    expect(del.type).toBe('photo')
    expect(del.file_url).toBeTruthy()
  })

  it('all AgentTask DB fields are snake_case', () => {
    const task = createMockTask()
    for (const key of Object.keys(task)) {
      if (key === 'agent') continue // joined field
      // snake_case: only lowercase, numbers, underscores
      expect(key, `Field "${key}" should be snake_case`).toMatch(/^[a-z][a-z0-9_]*$/)
    }
  })

  it('all AppUser DB fields are snake_case', () => {
    const user = createMockUser()
    for (const key of Object.keys(user)) {
      expect(key, `Field "${key}" should be snake_case`).toMatch(/^[a-z][a-z0-9_]*$/)
    }
  })
})

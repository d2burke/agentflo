import { describe, it, expect, vi, beforeEach } from 'vitest'
import { taskService } from '@/services/task-service'
import { getMockClient } from '@/__tests__/setup'
import { TASK_COLUMNS, TASK_COLUMNS_WITH_AGENT } from '@/lib/constants'
import { createMockTask } from '@/types/__tests__/models.test'

describe('taskService', () => {
  let mock: ReturnType<typeof getMockClient>

  beforeEach(() => {
    mock = getMockClient()
  })

  // ── Fetch Tasks ──

  describe('fetchAgentTasks', () => {
    it('queries tasks table with TASK_COLUMNS and agent_id filter', async () => {
      const tasks = [createMockTask()]
      mock.__setMockResult({ data: tasks })

      await taskService.fetchAgentTasks('agent-1')

      expect(mock.from).toHaveBeenCalledWith('tasks')
      expect(mock.select).toHaveBeenCalledWith(TASK_COLUMNS)
      expect(mock.eq).toHaveBeenCalledWith('agent_id', 'agent-1')
      expect(mock.order).toHaveBeenCalledWith('created_at', { ascending: false })
    })
  })

  describe('fetchRunnerTasks', () => {
    it('queries tasks table with TASK_COLUMNS_WITH_AGENT and runner_id filter', async () => {
      const tasks = [{ ...createMockTask(), agent: [{ id: 'a1', full_name: 'Agent', avatar_url: null }] }]
      mock.__setMockResult({ data: tasks })

      const result = await taskService.fetchRunnerTasks('runner-1')

      expect(mock.from).toHaveBeenCalledWith('tasks')
      expect(mock.select).toHaveBeenCalledWith(TASK_COLUMNS_WITH_AGENT)
      expect(mock.eq).toHaveBeenCalledWith('runner_id', 'runner-1')
    })

    it('normalizes agent array join to single object', async () => {
      const agentData = { id: 'a1', full_name: 'Agent', avatar_url: null }
      const tasks = [{ ...createMockTask(), agent: [agentData] }]
      mock.__setMockResult({ data: tasks })

      const result = await taskService.fetchRunnerTasks('runner-1')
      expect(result[0].agent).toEqual(agentData)
    })
  })

  describe('fetchAvailableTasks', () => {
    it('filters by status=posted and orders by posted_at', async () => {
      mock.__setMockResult({ data: [] })

      await taskService.fetchAvailableTasks()

      expect(mock.from).toHaveBeenCalledWith('tasks')
      expect(mock.select).toHaveBeenCalledWith(TASK_COLUMNS_WITH_AGENT)
      expect(mock.eq).toHaveBeenCalledWith('status', 'posted')
      expect(mock.order).toHaveBeenCalledWith('posted_at', { ascending: false })
    })
  })

  describe('fetchTask', () => {
    it('queries single task by id with agent join', async () => {
      const task = { ...createMockTask(), agent: [{ id: 'a1', full_name: 'Agent', avatar_url: null }] }
      mock.__setMockResult({ data: task })

      await taskService.fetchTask('task-1')

      expect(mock.from).toHaveBeenCalledWith('tasks')
      expect(mock.select).toHaveBeenCalledWith(TASK_COLUMNS_WITH_AGENT)
      expect(mock.eq).toHaveBeenCalledWith('id', 'task-1')
      expect(mock.single).toHaveBeenCalled()
    })
  })

  // ── Create / Update Draft ──

  describe('createDraft', () => {
    it('inserts with correct column mapping', async () => {
      const task = createMockTask()
      mock.__setMockResult({ data: task })

      await taskService.createDraft({
        agentId: 'agent-1',
        category: 'Photography',
        propertyAddress: '123 Main St',
        price: 15000,
        instructions: 'Take photos',
        scheduledAt: '2024-02-01T10:00:00Z',
      })

      expect(mock.from).toHaveBeenCalledWith('tasks')
      expect(mock.insert).toHaveBeenCalledWith({
        agent_id: 'agent-1',
        category: 'Photography',
        property_address: '123 Main St',
        price: 15000,
        status: 'draft',
        instructions: 'Take photos',
        scheduled_at: '2024-02-01T10:00:00Z',
      })
      expect(mock.select).toHaveBeenCalledWith(TASK_COLUMNS)
      expect(mock.single).toHaveBeenCalled()
    })
  })

  describe('updateDraft', () => {
    it('updates with correct column mapping', async () => {
      mock.__setMockResult({ data: null })

      await taskService.updateDraft('task-1', {
        category: 'Showing',
        propertyAddress: '456 Oak Ave',
        price: 10000,
        instructions: null,
        scheduledAt: null,
      })

      expect(mock.from).toHaveBeenCalledWith('tasks')
      expect(mock.update).toHaveBeenCalledWith({
        category: 'Showing',
        property_address: '456 Oak Ave',
        price: 10000,
        instructions: null,
        scheduled_at: null,
      })
      expect(mock.eq).toHaveBeenCalledWith('id', 'task-1')
    })
  })

  // ── Edge Functions ──

  describe('postTask', () => {
    it('invokes post-task edge function', async () => {
      mock.functions.invoke.mockResolvedValue({ data: null, error: null })

      await taskService.postTask('task-1')

      expect(mock.functions.invoke).toHaveBeenCalledWith('post-task', {
        body: { taskId: 'task-1' },
      })
    })
  })

  describe('cancelTask', () => {
    it('invokes cancel-task with optional reason', async () => {
      mock.functions.invoke.mockResolvedValue({ data: null, error: null })

      await taskService.cancelTask('task-1', 'Changed my mind')

      expect(mock.functions.invoke).toHaveBeenCalledWith('cancel-task', {
        body: { taskId: 'task-1', reason: 'Changed my mind' },
      })
    })

    it('omits reason when not provided', async () => {
      mock.functions.invoke.mockResolvedValue({ data: null, error: null })

      await taskService.cancelTask('task-1')

      expect(mock.functions.invoke).toHaveBeenCalledWith('cancel-task', {
        body: { taskId: 'task-1' },
      })
    })
  })

  describe('approveAndPay', () => {
    it('invokes approve-and-pay edge function', async () => {
      mock.functions.invoke.mockResolvedValue({ data: null, error: null })

      await taskService.approveAndPay('task-1')

      expect(mock.functions.invoke).toHaveBeenCalledWith('approve-and-pay', {
        body: { taskId: 'task-1' },
      })
    })
  })

  describe('applyForTask', () => {
    it('calls accept_task RPC with correct parameter names', async () => {
      await taskService.applyForTask('task-1', 'runner-1')

      expect(mock.rpc).toHaveBeenCalledWith('accept_task', {
        p_task_id: 'task-1',
        p_runner_id: 'runner-1',
      })
    })
  })

  // ── Deliverables ──

  describe('fetchDeliverables', () => {
    it('queries deliverables table by task_id', async () => {
      mock.__setMockResult({ data: [] })

      await taskService.fetchDeliverables('task-1')

      expect(mock.from).toHaveBeenCalledWith('deliverables')
      expect(mock.eq).toHaveBeenCalledWith('task_id', 'task-1')
      expect(mock.order).toHaveBeenCalledWith('sort_order', { ascending: true })
    })
  })

  // ── Applications ──

  describe('fetchApplications', () => {
    it('queries task_applications with runner join', async () => {
      mock.__setMockResult({ data: [] })

      await taskService.fetchApplications('task-1')

      expect(mock.from).toHaveBeenCalledWith('task_applications')
      expect(mock.select).toHaveBeenCalledWith('*, runner:users!runner_id(id, full_name, avatar_url)')
      expect(mock.eq).toHaveBeenCalledWith('task_id', 'task-1')
    })
  })

  // ── Showing Reports ──

  describe('fetchShowingReport', () => {
    it('queries showing_reports with limit 1', async () => {
      mock.__setMockResult({ data: [] })

      const result = await taskService.fetchShowingReport('task-1')

      expect(mock.from).toHaveBeenCalledWith('showing_reports')
      expect(mock.eq).toHaveBeenCalledWith('task_id', 'task-1')
      expect(mock.limit).toHaveBeenCalledWith(1)
      expect(result).toBeNull()
    })
  })

  // ── Visitors ──

  describe('fetchVisitors', () => {
    it('queries open_house_visitors', async () => {
      mock.__setMockResult({ data: [] })

      await taskService.fetchVisitors('task-1')

      expect(mock.from).toHaveBeenCalledWith('open_house_visitors')
      expect(mock.eq).toHaveBeenCalledWith('task_id', 'task-1')
    })
  })

  // ── Stripe ──

  describe('createSetupIntent', () => {
    it('invokes create-setup-intent edge function', async () => {
      const response = { setupIntent: 'si_123', ephemeralKey: 'ek_123', customer: 'cus_123', publishableKey: 'pk_test' }
      mock.functions.invoke.mockResolvedValue({ data: response, error: null })

      const result = await taskService.createSetupIntent()

      expect(mock.functions.invoke).toHaveBeenCalledWith('create-setup-intent', { body: {} })
      expect(result).toEqual(response)
    })
  })

  describe('createConnectLink', () => {
    it('invokes create-connect-link edge function', async () => {
      const response = { url: 'https://connect.stripe.com/...', account_id: 'acct_123' }
      mock.functions.invoke.mockResolvedValue({ data: response, error: null })

      const result = await taskService.createConnectLink()

      expect(mock.functions.invoke).toHaveBeenCalledWith('create-connect-link', { body: {} })
      expect(result).toEqual(response)
    })
  })
})

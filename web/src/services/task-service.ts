import { createClient } from '@/lib/supabase/client'
import { TASK_COLUMNS, TASK_COLUMNS_WITH_AGENT } from '@/lib/constants'
import type {
  AgentTask,
  TaskApplication,
  Deliverable,
  ShowingReport,
  OpenHouseVisitor,
  PublicProfileFull,
} from '@/types/models'

// Supabase foreign-key joins return nested objects as arrays — normalize to single object
function normalizeAgentJoin(rows: any[]): AgentTask[] {
  return rows.map((row) => {
    if (Array.isArray(row.agent)) row.agent = row.agent[0] ?? null
    return row as AgentTask
  })
}

export const taskService = {
  // ── Fetch Tasks ──

  async fetchAgentTasks(agentId: string): Promise<AgentTask[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('tasks')
      .select(TASK_COLUMNS)
      .eq('agent_id', agentId)
      .order('created_at', { ascending: false })

    if (error) throw error
    return data as AgentTask[]
  },

  async fetchRunnerTasks(runnerId: string): Promise<AgentTask[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('tasks')
      .select(TASK_COLUMNS_WITH_AGENT)
      .eq('runner_id', runnerId)
      .order('created_at', { ascending: false })

    if (error) throw error
    return normalizeAgentJoin(data)
  },

  async fetchAvailableTasks(): Promise<AgentTask[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('tasks')
      .select(TASK_COLUMNS_WITH_AGENT)
      .eq('status', 'posted')
      .order('posted_at', { ascending: false })

    if (error) throw error
    return normalizeAgentJoin(data)
  },

  async fetchTask(id: string): Promise<AgentTask> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('tasks')
      .select(TASK_COLUMNS_WITH_AGENT)
      .eq('id', id)
      .single()

    if (error) throw error
    const row = data as any
    if (Array.isArray(row.agent)) row.agent = row.agent[0] ?? null
    return row as AgentTask
  },

  // ── Create / Update Draft ──

  async createDraft(params: {
    agentId: string
    category: string
    propertyAddress: string
    price: number
    instructions?: string | null
    scheduledAt?: string | null
  }): Promise<AgentTask> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('tasks')
      .insert({
        agent_id: params.agentId,
        category: params.category,
        property_address: params.propertyAddress,
        price: params.price,
        status: 'draft',
        instructions: params.instructions ?? null,
        scheduled_at: params.scheduledAt ?? null,
      })
      .select(TASK_COLUMNS)
      .single()

    if (error) throw error
    return data as AgentTask
  },

  async updateDraft(
    taskId: string,
    params: {
      category: string
      propertyAddress: string
      price: number
      instructions?: string | null
      scheduledAt?: string | null
    },
  ) {
    const supabase = createClient()
    const { error } = await supabase
      .from('tasks')
      .update({
        category: params.category,
        property_address: params.propertyAddress,
        price: params.price,
        instructions: params.instructions ?? null,
        scheduled_at: params.scheduledAt ?? null,
      })
      .eq('id', taskId)

    if (error) throw error
  },

  // ── Edge Functions ──

  async postTask(taskId: string) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('post-task', {
      body: { taskId },
    })
    if (error) throw error
  },

  async cancelTask(taskId: string, reason?: string) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('cancel-task', {
      body: { taskId, ...(reason ? { reason } : {}) },
    })
    if (error) throw error
  },

  async acceptRunner(applicationId: string) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('accept-runner', {
      body: { applicationId },
    })
    if (error) throw error
  },

  async submitDeliverables(taskId: string, deliverables: Array<Record<string, string>>) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('submit-deliverables', {
      body: { taskId, deliverables },
    })
    if (error) throw error
  },

  async approveAndPay(taskId: string) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('approve-and-pay', {
      body: { taskId },
    })
    if (error) throw error
  },

  async startTask(taskId: string) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('start-task', {
      body: { taskId },
    })
    if (error) throw error
  },

  async checkIn(taskId: string, lat: number, lng: number) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('check-in', {
      body: { taskId, lat, lng },
    })
    if (error) throw error
  },

  async checkOut(taskId: string, lat: number, lng: number) {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('check-out', {
      body: { taskId, lat, lng },
    })
    if (error) throw error
  },

  async applyForTask(taskId: string, runnerId: string) {
    const supabase = createClient()
    const { error } = await supabase.rpc('accept_task', {
      p_task_id: taskId,
      p_runner_id: runnerId,
    })
    if (error) throw error
  },

  // ── Deliverables ──

  async fetchDeliverables(taskId: string): Promise<Deliverable[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('deliverables')
      .select()
      .eq('task_id', taskId)
      .order('sort_order', { ascending: true })

    if (error) throw error
    return data as Deliverable[]
  },

  // ── Applications ──

  async fetchApplications(taskId: string): Promise<TaskApplication[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('task_applications')
      .select('*, runner:users!runner_id(id, full_name, avatar_url)')
      .eq('task_id', taskId)
      .order('created_at', { ascending: false })

    if (error) throw error
    return data as TaskApplication[]
  },

  // ── Showing Reports ──

  async fetchShowingReport(taskId: string): Promise<ShowingReport | null> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('showing_reports')
      .select()
      .eq('task_id', taskId)
      .limit(1)

    if (error) throw error
    return (data as ShowingReport[])[0] ?? null
  },

  async setQRCodeToken(taskId: string, token: string) {
    const supabase = createClient()
    const { error } = await supabase
      .from('tasks')
      .update({ qr_code_token: token })
      .eq('id', taskId)

    if (error) throw error
  },

  // ── Open House Visitors ──

  async fetchVisitors(taskId: string): Promise<OpenHouseVisitor[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('open_house_visitors')
      .select()
      .eq('task_id', taskId)
      .order('created_at', { ascending: false })

    if (error) throw error
    return data as OpenHouseVisitor[]
  },

  // ── Public Profile ──

  async fetchPublicProfileFull(userId: string): Promise<PublicProfileFull> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('public_profiles')
      .select()
      .eq('id', userId)
      .single()

    if (error) throw error
    return data as PublicProfileFull
  },

  // ── Stripe ──

  async createSetupIntent(): Promise<{ setupIntent: string; ephemeralKey: string; customer: string; publishableKey: string }> {
    const supabase = createClient()
    const { data, error } = await supabase.functions.invoke('create-setup-intent', {
      body: {},
    })
    if (error) throw error
    return data
  },

  async createConnectLink(): Promise<{ url: string; account_id: string }> {
    const supabase = createClient()
    const { data, error } = await supabase.functions.invoke('create-connect-link', {
      body: {},
    })
    if (error) throw error
    return data
  },
}

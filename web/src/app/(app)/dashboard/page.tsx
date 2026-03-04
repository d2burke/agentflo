'use client'

import { useMemo } from 'react'
import { useAppStore } from '@/stores/app-store'
import { useMyTasks, useAvailableTasks } from '@/hooks/use-tasks'
import { getGreeting, firstName, formatPrice } from '@/lib/utils'
import { Plus, ClipboardCheck, Eye } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { EmptyState } from '@/components/ui/empty-state'
import { TaskCard } from '@/components/ui/task-card'
import Link from 'next/link'

export default function DashboardPage() {
  const { user } = useAppStore()

  if (!user) return null

  return user.role === 'agent' ? <AgentDashboard /> : <RunnerDashboard />
}

function AgentDashboard() {
  const { user } = useAppStore()
  const { data: tasks = [] } = useMyTasks()

  if (!user) return null

  const counts = useMemo(() => {
    const posted = tasks.filter((t) => t.status === 'posted').length
    const inProgress = tasks.filter((t) =>
      ['accepted', 'in_progress', 'deliverables_submitted', 'revision_requested'].includes(t.status),
    ).length
    const completed = tasks.filter((t) => t.status === 'completed').length
    return { posted, inProgress, completed }
  }, [tasks])

  const recentTasks = tasks.filter((t) => t.status !== 'draft').slice(0, 5)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold text-navy">
          {getGreeting()}, {firstName(user.full_name)}
        </h1>
        <p className="text-sm text-slate mt-1">Manage your tasks and track progress</p>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <StatusWidget label="Posted" count={counts.posted} color="blue" />
        <StatusWidget label="In Progress" count={counts.inProgress} color="amber" />
        <StatusWidget label="Completed" count={counts.completed} color="green" />
      </div>

      <Link href="/tasks/new">
        <PillButton icon={<Plus className="h-4 w-4" />} fullWidth size="lg">
          Create a Task
        </PillButton>
      </Link>

      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-navy">Recent Tasks</h2>
          {recentTasks.length > 0 && (
            <Link href="/tasks" className="text-sm font-semibold text-red hover:text-red-hover transition-colors">
              View All
            </Link>
          )}
        </div>
        {recentTasks.length > 0 ? (
          <div className="space-y-3">
            {recentTasks.map((task) => (
              <TaskCard key={task.id} task={task} />
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<ClipboardCheck className="h-10 w-10" />}
            title="No tasks yet"
            description="Create your first task to get started."
            action={
              <Link href="/tasks/new">
                <PillButton size="sm">Create Task</PillButton>
              </Link>
            }
          />
        )}
      </div>
    </div>
  )
}

function RunnerDashboard() {
  const { user } = useAppStore()
  const { data: myTasks = [] } = useMyTasks()
  const { data: availableTasks = [] } = useAvailableTasks()

  if (!user) return null

  const completedThisWeek = useMemo(() => {
    const weekAgo = new Date()
    weekAgo.setDate(weekAgo.getDate() - 7)
    return myTasks.filter(
      (t) => t.status === 'completed' && t.completed_at && new Date(t.completed_at) >= weekAgo,
    )
  }, [myTasks])

  const weeklyEarnings = completedThisWeek.reduce((sum, t) => sum + (t.runner_payout ?? 0), 0)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold text-navy">
          {getGreeting()}, {firstName(user.full_name)}
        </h1>
        <p className="text-sm text-slate mt-1">Find and complete tasks near you</p>
      </div>

      <div className="bg-gradient-to-br from-navy-light to-navy-mid rounded-card p-6 text-white">
        <p className="text-sm font-medium text-slate-light mb-1">This Week</p>
        <p className="text-3xl font-extrabold">{formatPrice(weeklyEarnings)}</p>
        <p className="text-xs text-slate-light mt-1">
          {completedThisWeek.length} task{completedThisWeek.length !== 1 ? 's' : ''} completed
        </p>
      </div>

      <div>
        <h2 className="text-lg font-bold text-navy mb-4">Available Tasks</h2>
        {availableTasks.length > 0 ? (
          <div className="space-y-3">
            {availableTasks.slice(0, 5).map((task) => (
              <TaskCard key={task.id} task={task} />
            ))}
            {availableTasks.length > 5 && (
              <Link href="/tasks" className="block text-center text-sm font-semibold text-red hover:text-red-hover transition-colors py-2">
                View all {availableTasks.length} tasks
              </Link>
            )}
          </div>
        ) : (
          <EmptyState
            icon={<Eye className="h-10 w-10" />}
            title="No available tasks"
            description="Check back soon for new tasks in your area."
          />
        )}
      </div>
    </div>
  )
}

function StatusWidget({ label, count, color }: { label: string; count: number; color: 'blue' | 'amber' | 'green' }) {
  const colors = {
    blue: 'bg-blue-light text-blue',
    amber: 'bg-amber-light text-amber',
    green: 'bg-green-light text-green',
  }

  return (
    <div className={`rounded-card p-4 ${colors[color]}`}>
      <p className="text-2xl font-extrabold">{count}</p>
      <p className="text-xs font-semibold mt-0.5">{label}</p>
    </div>
  )
}

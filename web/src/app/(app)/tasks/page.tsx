'use client'

import { useState, useMemo } from 'react'
import { useMyTasks, useAvailableTasks } from '@/hooks/use-tasks'
import { useAppStore } from '@/stores/app-store'
import { TaskCard } from '@/components/ui/task-card'
import { EmptyState } from '@/components/ui/empty-state'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { PillButton } from '@/components/ui/pill-button'
import { ClipboardCheck, Plus } from 'lucide-react'
import { cn } from '@/lib/utils'
import Link from 'next/link'
import type { TaskStatus } from '@/types/models'

type FilterOption = 'all' | TaskStatus

const AGENT_FILTERS: { value: FilterOption; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'posted', label: 'Posted' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'deliverables_submitted', label: 'Review' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
]

const RUNNER_FILTERS: { value: FilterOption | 'available'; label: string }[] = [
  { value: 'all', label: 'My Tasks' },
  { value: 'available' as FilterOption, label: 'Available' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'completed', label: 'Completed' },
]

export default function AllTasksPage() {
  const { user } = useAppStore()
  const { data: myTasks = [], isLoading } = useMyTasks()
  const { data: availableTasks = [] } = useAvailableTasks()
  const [filter, setFilter] = useState<string>('all')

  const isAgent = user?.role === 'agent'
  const filters = isAgent ? AGENT_FILTERS : RUNNER_FILTERS

  const filteredTasks = useMemo(() => {
    if (filter === 'available') return availableTasks

    const tasks = myTasks.filter((t) => t.status !== 'draft')

    if (filter === 'all') return tasks
    if (filter === 'in_progress') {
      return tasks.filter((t) =>
        ['accepted', 'in_progress', 'revision_requested'].includes(t.status),
      )
    }
    return tasks.filter((t) => t.status === filter)
  }, [myTasks, availableTasks, filter])

  if (!user) return null

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-extrabold text-navy">Tasks</h1>
        {isAgent && (
          <Link href="/tasks/new">
            <PillButton icon={<Plus className="h-4 w-4" />} size="sm">
              New Task
            </PillButton>
          </Link>
        )}
      </div>

      {/* Filter chips */}
      <div className="flex gap-2 overflow-x-auto pb-1 -mx-1 px-1">
        {filters.map((f) => (
          <button
            key={f.value}
            onClick={() => setFilter(f.value)}
            className={cn(
              'px-4 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-colors',
              filter === f.value
                ? 'bg-red text-white'
                : 'bg-border-light text-navy hover:bg-border',
            )}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Task list */}
      {isLoading ? (
        <LoadingSpinner message="Loading tasks..." />
      ) : filteredTasks.length > 0 ? (
        <div className="space-y-3">
          {filteredTasks.map((task) => (
            <TaskCard key={task.id} task={task} />
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<ClipboardCheck className="h-10 w-10" />}
          title={filter === 'all' ? 'No tasks yet' : `No ${filters.find((f) => f.value === filter)?.label ?? ''} tasks`}
          description={
            isAgent
              ? 'Create your first task to get started.'
              : 'Check back soon for new tasks in your area.'
          }
          action={
            isAgent ? (
              <Link href="/tasks/new">
                <PillButton size="sm">Create Task</PillButton>
              </Link>
            ) : undefined
          }
        />
      )}
    </div>
  )
}

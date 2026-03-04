'use client'

import Link from 'next/link'
import { MapPin, Calendar } from 'lucide-react'
import { cn, formatPrice, formatDate } from '@/lib/utils'
import { CategoryIcon } from './category-icon'
import { StatusBadge } from './status-badge'
import type { AgentTask } from '@/types/models'

interface TaskCardProps {
  task: AgentTask
  className?: string
}

export function TaskCard({ task, className }: TaskCardProps) {
  return (
    <Link
      href={`/tasks/${task.id}`}
      className={cn(
        'block bg-surface border border-border rounded-card p-4',
        'transition-all hover:shadow-card-hover hover:border-slate-light/50',
        className,
      )}
    >
      <div className="flex items-start gap-3">
        <CategoryIcon category={task.category} size="md" />
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between gap-2 mb-1">
            <span className="text-sm font-bold text-navy truncate">
              {task.category}
            </span>
            <StatusBadge status={task.status} />
          </div>

          <div className="flex items-center gap-1.5 text-slate text-xs mb-2">
            <MapPin className="h-3.5 w-3.5 shrink-0" />
            <span className="truncate">{task.property_address}</span>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-base font-extrabold text-navy">
              {formatPrice(task.price)}
            </span>
            {task.scheduled_at && (
              <div className="flex items-center gap-1 text-slate-light text-xs">
                <Calendar className="h-3 w-3" />
                <span>{formatDate(task.scheduled_at)}</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </Link>
  )
}

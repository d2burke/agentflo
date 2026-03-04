import { cn } from '@/lib/utils'
import { STATUS_BADGES } from '@/lib/constants'
import type { TaskStatus } from '@/types/models'

interface StatusBadgeProps {
  status: TaskStatus
  className?: string
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const badge = STATUS_BADGES[status]
  if (!badge) return null

  return (
    <span
      className={cn(
        'inline-flex items-center px-2.5 py-0.5 rounded-badge text-xs font-bold whitespace-nowrap',
        badge.bgClass,
        badge.textClass,
        className,
      )}
    >
      {badge.label}
    </span>
  )
}

import { cn } from '@/lib/utils'
import { STATUS_BADGES, STATUS_SEMANTIC_STYLES, getCategoryStatusLabel, getCategoryStatusSemantic } from '@/lib/constants'
import type { TaskStatus, TaskCategory } from '@/types/models'

interface StatusBadgeProps {
  status: TaskStatus
  category?: TaskCategory
  className?: string
}

export function StatusBadge({ status, category, className }: StatusBadgeProps) {
  const badge = STATUS_BADGES[status]
  if (!badge) return null

  const semantic = getCategoryStatusSemantic(status, category)
  const styles = STATUS_SEMANTIC_STYLES[semantic]
  const label = getCategoryStatusLabel(status, category)

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 px-2 py-0.5 rounded-badge text-[11px] font-bold whitespace-nowrap',
        styles.bgClass,
        styles.textClass,
        className,
      )}
    >
      <span className={cn('h-[5px] w-[5px] rounded-full shrink-0', styles.dotClass)} />
      {label}
    </span>
  )
}

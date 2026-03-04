import { cn } from '@/lib/utils'

interface EmptyStateProps {
  icon?: React.ReactNode
  title: string
  description?: string
  action?: React.ReactNode
  className?: string
}

export function EmptyState({ icon, title, description, action, className }: EmptyStateProps) {
  return (
    <div className={cn('flex flex-col items-center justify-center py-16 px-4 text-center', className)}>
      {icon && (
        <div className="mb-4 text-slate-light">{icon}</div>
      )}
      <h3 className="text-base font-bold text-navy mb-1">{title}</h3>
      {description && (
        <p className="text-sm text-slate max-w-sm mb-4">{description}</p>
      )}
      {action}
    </div>
  )
}

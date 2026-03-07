import { cn } from '@/lib/utils'

interface StatChipProps {
  value: string
  label: string
  accent?: boolean
  className?: string
}

export function StatChip({ value, label, accent = false, className }: StatChipProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center px-3 py-2 rounded-card-inner min-w-[60px]',
        accent
          ? 'bg-red-light'
          : 'bg-border-light',
        className,
      )}
    >
      <span
        className={cn(
          'text-[15px] font-extrabold tracking-tight leading-tight',
          accent ? 'text-red' : 'text-navy',
        )}
      >
        {value}
      </span>
      <span className="text-[9px] font-semibold text-slate uppercase tracking-wider leading-tight mt-0.5">
        {label}
      </span>
    </div>
  )
}

interface StatChipsRowProps {
  children: React.ReactNode
  className?: string
}

export function StatChipsRow({ children, className }: StatChipsRowProps) {
  return (
    <div className={cn('flex gap-[7px]', className)}>
      {children}
    </div>
  )
}

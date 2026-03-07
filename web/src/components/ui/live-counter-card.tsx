'use client'

import { cn } from '@/lib/utils'

interface LiveCounterCardProps {
  count: number
  subtitle: string
  meta?: string
  className?: string
}

export function LiveCounterCard({ count, subtitle, meta, className }: LiveCounterCardProps) {
  return (
    <div
      className={cn(
        'bg-surface border border-border rounded-card p-4 flex flex-col items-center text-center',
        className,
      )}
    >
      <div className="flex items-center gap-2 mb-2">
        <span className="relative flex h-2.5 w-2.5">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red opacity-75" />
          <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-red" />
        </span>
        <span className="text-[11px] font-bold text-red uppercase tracking-wider">
          Live Now
        </span>
      </div>
      <span className="text-[32px] font-extrabold text-navy tracking-tight leading-none">
        {count}
      </span>
      <span className="text-xs font-semibold text-slate mt-1">{subtitle}</span>
      {meta && (
        <span className="text-[10px] text-slate-light mt-0.5">{meta}</span>
      )}
    </div>
  )
}

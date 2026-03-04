import { Camera, Eye, Box, Home, ClipboardCheck } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { TaskCategory } from '@/types/models'

const ICON_MAP: Record<TaskCategory, React.ElementType> = {
  Photography: Camera,
  Showing: Eye,
  Staging: Box,
  'Open House': Home,
  Inspection: ClipboardCheck,
}

const COLOR_MAP: Record<TaskCategory, { bg: string; text: string }> = {
  Photography: { bg: 'bg-blue-light', text: 'text-blue' },
  Showing: { bg: 'bg-amber-light', text: 'text-amber' },
  Staging: { bg: 'bg-green-light', text: 'text-green' },
  'Open House': { bg: 'bg-red-light', text: 'text-red' },
  Inspection: { bg: 'bg-border-light', text: 'text-navy' },
}

interface CategoryIconProps {
  category: TaskCategory
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const SIZES = {
  sm: 'h-8 w-8',
  md: 'h-10 w-10',
  lg: 'h-12 w-12',
}

const ICON_SIZES = {
  sm: 'h-4 w-4',
  md: 'h-5 w-5',
  lg: 'h-6 w-6',
}

export function CategoryIcon({ category, size = 'md', className }: CategoryIconProps) {
  const Icon = ICON_MAP[category] ?? ClipboardCheck
  const colors = COLOR_MAP[category] ?? COLOR_MAP.Inspection

  return (
    <div
      className={cn(
        'flex items-center justify-center rounded-md shrink-0',
        SIZES[size],
        colors.bg,
        colors.text,
        className,
      )}
    >
      <Icon className={ICON_SIZES[size]} />
    </div>
  )
}

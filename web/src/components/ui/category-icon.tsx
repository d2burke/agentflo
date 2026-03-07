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

interface CategoryIconProps {
  category: TaskCategory
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const SIZES = {
  sm: 'h-6 w-6',
  md: 'h-7 w-7',
  lg: 'h-10 w-10',
}

const ICON_SIZES = {
  sm: 'h-3 w-3',
  md: 'h-3.5 w-3.5',
  lg: 'h-5 w-5',
}

export function CategoryIcon({ category, size = 'md', className }: CategoryIconProps) {
  const Icon = ICON_MAP[category] ?? ClipboardCheck

  return (
    <div
      className={cn(
        'flex items-center justify-center rounded-lg shrink-0 bg-red text-white',
        SIZES[size],
        className,
      )}
    >
      <Icon className={ICON_SIZES[size]} />
    </div>
  )
}

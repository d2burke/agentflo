'use client'

import Link from 'next/link'
import { MessageSquare } from 'lucide-react'
import { Avatar } from '@/components/ui/avatar'
import { StatusBadge } from '@/components/ui/status-badge'
import { timeAgo } from '@/lib/utils'
import type { TaskStatus, TaskCategory, PublicProfile } from '@/types/models'

interface RunnerCardProps {
  person: PublicProfile
  label: string
  timestamp?: string | null
  status: TaskStatus
  category: TaskCategory
  taskId: string
  showMessage?: boolean
}

export function RunnerCard({ person, label, timestamp, status, category, taskId, showMessage }: RunnerCardProps) {
  return (
    <div className="bg-surface border border-border rounded-card p-4">
      <div className="flex items-center gap-3">
        <Avatar
          src={person.avatar_url}
          name={person.full_name}
          size="md"
          className="rounded-xl"
        />
        <div className="flex-1 min-w-0">
          <p className="text-[13px] font-bold text-navy truncate">{person.full_name}</p>
          {timestamp && (
            <p className="text-[10.5px] text-slate-light font-medium">{label} {timeAgo(timestamp)}</p>
          )}
        </div>
        <StatusBadge status={status} category={category} />
      </div>
      {showMessage && (
        <Link
          href={`/messages?taskId=${taskId}`}
          className="flex items-center justify-center gap-2 w-full h-[37px] bg-border-light rounded-[10px] text-xs font-bold text-navy mt-3 hover:bg-border transition-colors"
        >
          <MessageSquare className="h-3.5 w-3.5" />
          Message
        </Link>
      )}
    </div>
  )
}

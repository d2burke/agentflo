'use client'

import Link from 'next/link'
import { usePendingUsers } from '@/hooks/use-admin'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { EmptyState } from '@/components/ui/empty-state'
import { Avatar } from '@/components/ui/avatar'
import { ClipboardList, ChevronRight } from 'lucide-react'
import { timeAgo, cn } from '@/lib/utils'

export default function VettingListPage() {
  const { data: users = [], isLoading } = usePendingUsers()

  return (
    <div>
      <h1 className="text-2xl font-extrabold text-navy mb-1">Pending Reviews</h1>
      <p className="text-sm text-slate mb-6">
        {users.length} user{users.length !== 1 ? 's' : ''} awaiting verification
      </p>

      {isLoading ? (
        <LoadingSpinner message="Loading..." />
      ) : users.length > 0 ? (
        <div className="space-y-2">
          {users.map((user) => (
            <Link
              key={user.id}
              href={`/admin/vetting/${user.id}`}
              className="flex items-center gap-4 rounded-card border border-border bg-white p-4 hover:shadow-md transition-shadow"
            >
              <Avatar src={user.avatar_url} name={user.full_name} size="md" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-navy">{user.full_name}</p>
                <p className="text-xs text-slate">{user.email}</p>
                <div className="flex items-center gap-3 mt-1">
                  <span className={cn(
                    'inline-flex items-center px-2 py-0.5 rounded-badge text-[10px] font-bold uppercase',
                    user.role === 'agent'
                      ? 'bg-blue-50 text-blue-700'
                      : 'bg-green-50 text-green-700',
                  )}>
                    {user.role}
                  </span>
                  {user.license_number && (
                    <span className="text-[10px] text-slate">
                      License: {user.license_number} ({user.license_state})
                    </span>
                  )}
                </div>
              </div>
              <div className="text-right shrink-0">
                <p className="text-[10px] text-slate">{timeAgo(user.created_at)}</p>
              </div>
              <ChevronRight className="h-4 w-4 text-slate shrink-0" />
            </Link>
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<ClipboardList className="h-10 w-10" />}
          title="No pending reviews"
          description="All users have been reviewed."
        />
      )}
    </div>
  )
}

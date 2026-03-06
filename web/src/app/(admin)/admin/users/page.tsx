'use client'

import { useState, Suspense } from 'react'
import Link from 'next/link'
import { useSearchParams } from 'next/navigation'
import { useAllUsers } from '@/hooks/use-admin'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { EmptyState } from '@/components/ui/empty-state'
import { Avatar } from '@/components/ui/avatar'
import { Users, Search, ChevronRight } from 'lucide-react'
import { cn, timeAgo } from '@/lib/utils'
import type { VettingStatus } from '@/types/models'

const FILTER_TABS: Array<{ label: string; value: VettingStatus | undefined }> = [
  { label: 'All', value: undefined },
  { label: 'Pending', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'Not Started', value: 'not_started' },
]

export default function AllUsersPage() {
  return (
    <Suspense fallback={<LoadingSpinner message="Loading..." />}>
      <AllUsersContent />
    </Suspense>
  )
}

function AllUsersContent() {
  const searchParams = useSearchParams()
  const initialStatus = searchParams.get('status') as VettingStatus | null
  const [filter, setFilter] = useState<VettingStatus | undefined>(initialStatus ?? undefined)
  const [search, setSearch] = useState('')
  const { data: users = [], isLoading } = useAllUsers(filter)

  const filtered = search
    ? users.filter(
        (u) =>
          u.full_name.toLowerCase().includes(search.toLowerCase()) ||
          u.email.toLowerCase().includes(search.toLowerCase()),
      )
    : users

  return (
    <div>
      <h1 className="text-2xl font-extrabold text-navy mb-6">All Users</h1>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-2 mb-4">
        {FILTER_TABS.map((tab) => (
          <button
            key={tab.label}
            onClick={() => setFilter(tab.value)}
            className={cn(
              'px-3 py-1.5 rounded-pill text-xs font-semibold transition-colors',
              filter === tab.value
                ? 'bg-navy text-white'
                : 'bg-border-light text-slate hover:bg-border',
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Search */}
      <div className="relative mb-4">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by name or email..."
          className="w-full rounded-card border border-border bg-surface pl-10 pr-4 py-2.5 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/20"
        />
      </div>

      {isLoading ? (
        <LoadingSpinner message="Loading..." />
      ) : filtered.length > 0 ? (
        <div className="rounded-card border border-border overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-surface text-left">
                <th className="px-4 py-3 text-[10px] font-bold text-slate uppercase">User</th>
                <th className="px-4 py-3 text-[10px] font-bold text-slate uppercase">Role</th>
                <th className="px-4 py-3 text-[10px] font-bold text-slate uppercase">Status</th>
                <th className="px-4 py-3 text-[10px] font-bold text-slate uppercase">Joined</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filtered.map((user) => (
                <tr key={user.id} className="bg-white hover:bg-border-light/50 transition-colors">
                  <td className="px-4 py-3">
                    <Link href={`/admin/vetting/${user.id}`} className="flex items-center gap-3">
                      <Avatar src={user.avatar_url} name={user.full_name} size="sm" />
                      <div>
                        <p className="font-semibold text-navy">{user.full_name}</p>
                        <p className="text-xs text-slate">{user.email}</p>
                      </div>
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    <span className={cn(
                      'inline-flex items-center px-2 py-0.5 rounded-badge text-[10px] font-bold uppercase',
                      user.role === 'agent' ? 'bg-blue-50 text-blue-700' : 'bg-green-50 text-green-700',
                    )}>
                      {user.role}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={cn(
                      'inline-flex items-center px-2 py-0.5 rounded-badge text-[10px] font-bold uppercase',
                      user.vetting_status === 'approved' && 'bg-green-50 text-green-700',
                      user.vetting_status === 'rejected' && 'bg-red-50 text-red-700',
                      user.vetting_status === 'pending' && 'bg-amber-50 text-amber-700',
                      user.vetting_status === 'not_started' && 'bg-border-light text-slate',
                      user.vetting_status === 'expired' && 'bg-border-light text-slate',
                    )}>
                      {user.vetting_status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-slate">{timeAgo(user.created_at)}</td>
                  <td className="px-4 py-3">
                    <Link href={`/admin/vetting/${user.id}`}>
                      <ChevronRight className="h-4 w-4 text-slate" />
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <EmptyState
          icon={<Users className="h-10 w-10" />}
          title="No users found"
          description={search ? 'Try a different search term.' : 'No users match this filter.'}
        />
      )}
    </div>
  )
}

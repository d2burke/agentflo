'use client'

import Link from 'next/link'
import { useVettingCounts } from '@/hooks/use-admin'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ClipboardList, UserCheck, UserX, Clock, Users } from 'lucide-react'
import { cn } from '@/lib/utils'

const STAT_CARDS = [
  { key: 'pending', label: 'Pending Review', icon: Clock, color: 'text-amber-600 bg-amber-50', href: '/admin/vetting' },
  { key: 'approved', label: 'Approved', icon: UserCheck, color: 'text-green-600 bg-green-50', href: '/admin/users?status=approved' },
  { key: 'rejected', label: 'Rejected', icon: UserX, color: 'text-red-600 bg-red-50', href: '/admin/users?status=rejected' },
  { key: 'not_started', label: 'Not Started', icon: Users, color: 'text-slate bg-border-light', href: '/admin/users?status=not_started' },
] as const

export default function AdminDashboard() {
  const { data: counts, isLoading } = useVettingCounts()

  return (
    <div>
      <h1 className="text-2xl font-extrabold text-navy mb-6">Admin Dashboard</h1>

      {isLoading ? (
        <LoadingSpinner message="Loading..." />
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
            {STAT_CARDS.map((card) => (
              <Link
                key={card.key}
                href={card.href}
                className="rounded-card border border-border bg-white p-5 hover:shadow-md transition-shadow"
              >
                <div className="flex items-center gap-3 mb-3">
                  <div className={cn('h-10 w-10 rounded-lg flex items-center justify-center', card.color)}>
                    <card.icon className="h-5 w-5" />
                  </div>
                  <span className="text-sm text-slate font-medium">{card.label}</span>
                </div>
                <p className="text-3xl font-extrabold text-navy">
                  {counts?.[card.key] ?? 0}
                </p>
              </Link>
            ))}
          </div>

          {(counts?.pending ?? 0) > 0 && (
            <Link
              href="/admin/vetting"
              className="inline-flex items-center gap-2 rounded-pill bg-amber-50 text-amber-700 px-4 py-2 text-sm font-semibold hover:bg-amber-100 transition-colors"
            >
              <ClipboardList className="h-4 w-4" />
              {counts!.pending} user{counts!.pending !== 1 ? 's' : ''} awaiting review
            </Link>
          )}
        </>
      )}
    </div>
  )
}

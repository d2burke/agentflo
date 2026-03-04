'use client'

import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useAppStore } from '@/stores/app-store'
import { notificationService } from '@/services/notification-service'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { EmptyState } from '@/components/ui/empty-state'
import { PillButton } from '@/components/ui/pill-button'
import {
  Bell, DollarSign, CheckCircle, MessageSquare, AlertTriangle, User, ClipboardCheck,
} from 'lucide-react'
import { timeAgo, cn } from '@/lib/utils'
import { useRouter } from 'next/navigation'

const ICON_MAP: Record<string, React.ReactNode> = {
  task_posted: <ClipboardCheck className="h-4 w-4" />,
  task_accepted: <CheckCircle className="h-4 w-4" />,
  task_completed: <CheckCircle className="h-4 w-4" />,
  payment_received: <DollarSign className="h-4 w-4" />,
  payment_sent: <DollarSign className="h-4 w-4" />,
  new_message: <MessageSquare className="h-4 w-4" />,
  task_cancelled: <AlertTriangle className="h-4 w-4" />,
  new_application: <User className="h-4 w-4" />,
}

export default function NotificationsPage() {
  const { user } = useAppStore()
  const qc = useQueryClient()
  const router = useRouter()

  const { data: notifications = [], isLoading } = useQuery({
    queryKey: ['notifications', user?.id],
    queryFn: () => notificationService.fetchNotifications(user!.id),
    enabled: !!user,
  })

  const unreadCount = notifications.filter((n) => !n.read_at).length

  async function handleMarkAllRead() {
    if (!user) return
    await notificationService.markAllAsRead(user.id)
    qc.invalidateQueries({ queryKey: ['notifications'] })
  }

  async function handleClick(notification: (typeof notifications)[0]) {
    if (!notification.read_at) {
      await notificationService.markAsRead(notification.id)
      qc.invalidateQueries({ queryKey: ['notifications'] })
    }
    // Navigate based on notification data
    if (notification.data?.task_id) {
      router.push(`/tasks/${notification.data.task_id}`)
    }
  }

  if (!user) return null

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-extrabold text-navy">Notifications</h1>
        {unreadCount > 0 && (
          <PillButton size="sm" variant="ghost" onClick={handleMarkAllRead}>
            Mark all read
          </PillButton>
        )}
      </div>

      {isLoading ? (
        <LoadingSpinner message="Loading..." />
      ) : notifications.length > 0 ? (
        <div className="space-y-1">
          {notifications.map((n) => (
            <button
              key={n.id}
              onClick={() => handleClick(n)}
              className={cn(
                'w-full text-left flex items-start gap-3 rounded-card p-4 transition-colors',
                n.read_at ? 'bg-surface hover:bg-border-light' : 'bg-blue-light/50 hover:bg-blue-light',
              )}
            >
              <div className={cn(
                'h-8 w-8 rounded-full flex items-center justify-center shrink-0',
                n.read_at ? 'bg-border-light text-slate' : 'bg-red-glow text-red',
              )}>
                {ICON_MAP[n.type] ?? <Bell className="h-4 w-4" />}
              </div>
              <div className="flex-1 min-w-0">
                <p className={cn('text-sm', n.read_at ? 'text-navy' : 'text-navy font-semibold')}>
                  {n.title}
                </p>
                <p className="text-xs text-slate mt-0.5 line-clamp-2">{n.body}</p>
                <p className="text-[10px] text-slate mt-1">{timeAgo(n.created_at)}</p>
              </div>
              {!n.read_at && <div className="h-2 w-2 rounded-full bg-red shrink-0 mt-2" />}
            </button>
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<Bell className="h-10 w-10" />}
          title="No notifications"
          description="You're all caught up!"
        />
      )}
    </div>
  )
}

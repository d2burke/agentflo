import { createClient } from '@/lib/supabase/client'
import type { AppNotification } from '@/types/models'
import type { RealtimeSubscriptionStatus } from '@/services/message-service'

export const notificationService = {
  async fetchNotifications(userId: string): Promise<AppNotification[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(50)

    if (error) throw error
    return data as AppNotification[]
  },

  async markAsRead(notificationId: string) {
    const supabase = createClient()
    const { error } = await supabase
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('id', notificationId)

    if (error) throw error
  },

  async markAllAsRead(userId: string) {
    const supabase = createClient()
    const { error } = await supabase
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('user_id', userId)
      .is('read_at', null)

    if (error) throw error
  },

  subscribeToNotifications(
    userId: string,
    callback: () => void,
    onStatusChange?: (status: RealtimeSubscriptionStatus, error?: Error) => void,
  ) {
    const supabase = createClient()
    return supabase
      .channel(`notifications:${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${userId}`,
        },
        () => callback(),
      )
      .subscribe((status, error) => {
        onStatusChange?.(status, error)
      })
  },
}

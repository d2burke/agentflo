import { createClient } from '@/lib/supabase/client'
import type { AppNotification } from '@/types/models'

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
}

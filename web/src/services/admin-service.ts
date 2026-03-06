import { createClient } from '@/lib/supabase/client'
import type { AppUser, AdminUserDetail, VettingStatus } from '@/types/models'

export const adminService = {
  async fetchPendingUsers(): Promise<AppUser[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('vetting_status', 'pending')
      .order('created_at', { ascending: true })

    if (error) throw error
    return data ?? []
  },

  async fetchAllUsers(filter?: VettingStatus): Promise<AppUser[]> {
    const supabase = createClient()
    let query = supabase.from('users').select('*').order('created_at', { ascending: false })

    if (filter) {
      query = query.eq('vetting_status', filter)
    }

    const { data, error } = await query
    if (error) throw error
    return data ?? []
  },

  async fetchUserWithVetting(userId: string): Promise<AdminUserDetail> {
    const supabase = createClient()

    // Fetch user and vetting records separately to avoid join issues with RLS
    const [{ data: user, error: userError }, { data: records, error: recordsError }] =
      await Promise.all([
        supabase.from('users').select('*').eq('id', userId).single(),
        supabase.from('vetting_records').select('*').eq('user_id', userId),
      ])

    if (userError) throw userError
    if (recordsError) throw recordsError

    return { ...user, vetting_records: records ?? [] } as AdminUserDetail
  },

  async fetchVettingCounts(): Promise<Record<VettingStatus, number>> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('users')
      .select('vetting_status')

    if (error) throw error

    const counts: Record<string, number> = {
      not_started: 0,
      pending: 0,
      approved: 0,
      rejected: 0,
      expired: 0,
    }

    for (const row of data ?? []) {
      counts[row.vetting_status] = (counts[row.vetting_status] || 0) + 1
    }

    return counts as Record<VettingStatus, number>
  },

  async approveUser(userId: string, notes: string): Promise<void> {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('admin-vet-user', {
      body: { userId, action: 'approve', reviewerNotes: notes },
    })
    if (error) throw error
  },

  async rejectUser(userId: string, notes: string): Promise<void> {
    const supabase = createClient()
    const { error } = await supabase.functions.invoke('admin-vet-user', {
      body: { userId, action: 'reject', reviewerNotes: notes },
    })
    if (error) throw error
  },
}

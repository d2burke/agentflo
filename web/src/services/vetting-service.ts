import { createClient } from '@/lib/supabase/client'
import type { VettingRecord } from '@/types/models'

export type VettingRecordType = 'license' | 'photo_id' | 'brokerage'

export interface LicenseData {
  license_number: string
  state: string
  expiry?: string
}

export interface PhotoIdData {
  file_url: string
}

export interface BrokerageData {
  brokerage_name: string
  office_phone?: string
}

export const vettingService = {
  /** Fetch all vetting records for the current user */
  async fetchMyVettingRecords(): Promise<VettingRecord[]> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('vetting_records')
      .select('*')
      .order('created_at', { ascending: true })

    if (error) throw error
    return data ?? []
  },

  /** Submit a vetting record (license, photo_id, or brokerage) */
  async submitRecord(
    type: VettingRecordType,
    submittedData: Record<string, string>,
  ): Promise<VettingRecord> {
    const supabase = createClient()
    const { data, error } = await supabase.functions.invoke('submit-vetting', {
      body: { type, submittedData },
    })
    if (error) throw error
    return data.record as VettingRecord
  },

  /** Upload a photo ID file to vetting-documents bucket */
  async uploadPhotoId(userId: string, file: File): Promise<string> {
    const supabase = createClient()
    const ext = file.name.split('.').pop() ?? 'jpg'
    const path = `${userId}/photo-id-${Date.now()}.${ext}`

    const { error } = await supabase.storage
      .from('vetting-documents')
      .upload(path, file, { upsert: true })

    if (error) throw error

    // Get signed URL (private bucket)
    const { data: urlData } = await supabase.storage
      .from('vetting-documents')
      .createSignedUrl(path, 60 * 60 * 24 * 365) // 1 year

    return urlData?.signedUrl ?? path
  },
}

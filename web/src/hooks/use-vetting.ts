'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { vettingService, type VettingRecordType } from '@/services/vetting-service'
import { toast } from 'sonner'

export const vettingKeys = {
  all: ['vetting'] as const,
  myRecords: () => [...vettingKeys.all, 'my-records'] as const,
}

export function useMyVettingRecords() {
  return useQuery({
    queryKey: vettingKeys.myRecords(),
    queryFn: () => vettingService.fetchMyVettingRecords(),
  })
}

export function useSubmitVetting() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({
      type,
      submittedData,
    }: {
      type: VettingRecordType
      submittedData: Record<string, string>
    }) => vettingService.submitRecord(type, submittedData),
    onSuccess: () => {
      toast.success('Submitted for review')
      qc.invalidateQueries({ queryKey: vettingKeys.all })
    },
    onError: (err: Error) => {
      toast.error(`Failed to submit: ${err.message}`)
    },
  })
}

export function useUploadPhotoId() {
  return useMutation({
    mutationFn: ({ userId, file }: { userId: string; file: File }) =>
      vettingService.uploadPhotoId(userId, file),
    onError: (err: Error) => {
      toast.error(`Upload failed: ${err.message}`)
    },
  })
}

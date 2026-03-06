'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminService } from '@/services/admin-service'
import { toast } from 'sonner'
import type { VettingStatus } from '@/types/models'

export const adminKeys = {
  all: ['admin'] as const,
  pendingUsers: () => [...adminKeys.all, 'pending'] as const,
  allUsers: (filter?: VettingStatus) => [...adminKeys.all, 'users', filter] as const,
  userDetail: (id: string) => [...adminKeys.all, 'user', id] as const,
  counts: () => [...adminKeys.all, 'counts'] as const,
}

export function usePendingUsers() {
  return useQuery({
    queryKey: adminKeys.pendingUsers(),
    queryFn: () => adminService.fetchPendingUsers(),
  })
}

export function useAllUsers(filter?: VettingStatus) {
  return useQuery({
    queryKey: adminKeys.allUsers(filter),
    queryFn: () => adminService.fetchAllUsers(filter),
  })
}

export function useUserDetail(userId: string) {
  return useQuery({
    queryKey: adminKeys.userDetail(userId),
    queryFn: () => adminService.fetchUserWithVetting(userId),
    enabled: !!userId,
  })
}

export function useVettingCounts() {
  return useQuery({
    queryKey: adminKeys.counts(),
    queryFn: () => adminService.fetchVettingCounts(),
  })
}

export function useApproveUser() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ userId, notes }: { userId: string; notes: string }) =>
      adminService.approveUser(userId, notes),
    onSuccess: () => {
      toast.success('User approved')
      qc.invalidateQueries({ queryKey: adminKeys.all })
    },
    onError: (err: Error) => {
      toast.error(`Failed to approve: ${err.message}`)
    },
  })
}

export function useRejectUser() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ userId, notes }: { userId: string; notes: string }) =>
      adminService.rejectUser(userId, notes),
    onSuccess: () => {
      toast.success('User rejected')
      qc.invalidateQueries({ queryKey: adminKeys.all })
    },
    onError: (err: Error) => {
      toast.error(`Failed to reject: ${err.message}`)
    },
  })
}

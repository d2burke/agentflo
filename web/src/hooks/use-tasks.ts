'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { taskService } from '@/services/task-service'
import { useAppStore } from '@/stores/app-store'
import { toast } from 'sonner'

// ── Query Keys ──

export const taskKeys = {
  all: ['tasks'] as const,
  agentTasks: (agentId: string) => [...taskKeys.all, 'agent', agentId] as const,
  runnerTasks: (runnerId: string) => [...taskKeys.all, 'runner', runnerId] as const,
  available: () => [...taskKeys.all, 'available'] as const,
  detail: (id: string) => [...taskKeys.all, 'detail', id] as const,
  deliverables: (taskId: string) => ['deliverables', taskId] as const,
  applications: (taskId: string) => ['applications', taskId] as const,
  myReview: (taskId: string, userId: string) => ['review', taskId, userId] as const,
}

// ── Hooks ──

export function useMyTasks() {
  const { user } = useAppStore()
  return useQuery({
    queryKey: user?.role === 'agent'
      ? taskKeys.agentTasks(user.id)
      : taskKeys.runnerTasks(user?.id ?? ''),
    queryFn: () =>
      user?.role === 'agent'
        ? taskService.fetchAgentTasks(user.id)
        : taskService.fetchRunnerTasks(user!.id),
    enabled: !!user,
  })
}

export function useAvailableTasks() {
  return useQuery({
    queryKey: taskKeys.available(),
    queryFn: () => taskService.fetchAvailableTasks(),
  })
}

export function useTask(id: string) {
  return useQuery({
    queryKey: taskKeys.detail(id),
    queryFn: () => taskService.fetchTask(id),
    enabled: !!id,
  })
}

export function useDeliverables(taskId: string, enabled = true) {
  return useQuery({
    queryKey: taskKeys.deliverables(taskId),
    queryFn: () => taskService.fetchDeliverables(taskId),
    enabled: !!taskId && enabled,
  })
}

export function useApplications(taskId: string, enabled = true) {
  return useQuery({
    queryKey: taskKeys.applications(taskId),
    queryFn: () => taskService.fetchApplications(taskId),
    enabled: !!taskId && enabled,
  })
}

export function useVisitors(taskId: string, enabled = true) {
  return useQuery({
    queryKey: ['visitors', taskId] as const,
    queryFn: () => taskService.fetchVisitors(taskId),
    enabled: !!taskId && enabled,
  })
}

// ── Mutations ──

export function usePostTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (taskId: string) => taskService.postTask(taskId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: taskKeys.all })
      toast.success('Task posted successfully')
    },
    onError: (err: Error) => toast.error(err.message),
  })
}

export function useCancelTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ taskId, reason }: { taskId: string; reason?: string }) =>
      taskService.cancelTask(taskId, reason),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: taskKeys.all })
      toast.success('Task cancelled')
    },
    onError: (err: Error) => toast.error(err.message),
  })
}

export function useAcceptRunner() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (applicationId: string) => taskService.acceptRunner(applicationId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: taskKeys.all })
      toast.success('Runner accepted')
    },
    onError: (err: Error) => toast.error(err.message),
  })
}

export function useApproveAndPay() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (taskId: string) => taskService.approveAndPay(taskId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: taskKeys.all })
      toast.success('Payment released!')
    },
    onError: (err: Error) => toast.error(err.message),
  })
}

export function useApplyForTask() {
  const qc = useQueryClient()
  const { user } = useAppStore()
  return useMutation({
    mutationFn: (taskId: string) => taskService.applyForTask(taskId, user!.id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: taskKeys.all })
      toast.success('Task accepted!')
    },
    onError: (err: Error) => toast.error(err.message),
  })
}

export function useStartTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (taskId: string) => taskService.startTask(taskId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: taskKeys.all })
    },
    onError: (err: Error) => toast.error(err.message),
  })
}

export function useMyReview(taskId: string, userId: string | undefined, enabled = true) {
  return useQuery({
    queryKey: taskKeys.myReview(taskId, userId ?? ''),
    queryFn: () => taskService.fetchUserReview(taskId, userId!),
    enabled: !!taskId && !!userId && enabled,
  })
}

export function useSubmitReview() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (params: {
      taskId: string
      reviewerId: string
      revieweeId: string
      rating: number
      comment?: string | null
    }) => taskService.submitReview(params),
    onSuccess: (_data, variables) => {
      qc.invalidateQueries({ queryKey: taskKeys.myReview(variables.taskId, variables.reviewerId) })
      toast.success('Review submitted!')
    },
    onError: (err: Error) => toast.error(err.message),
  })
}

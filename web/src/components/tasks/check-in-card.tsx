'use client'

import { useState } from 'react'
import { LogIn, LogOut, MapPin, Loader2 } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { taskService } from '@/services/task-service'
import { useQueryClient } from '@tanstack/react-query'
import { taskKeys } from '@/hooks/use-tasks'
import { toast } from 'sonner'
import type { AgentTask } from '@/types/models'

export function CheckInCard({ task }: { task: AgentTask }) {
  const qc = useQueryClient()
  const [loading, setLoading] = useState(false)

  const isCheckedIn = !!task.checked_in_at
  const isCheckedOut = !!task.checked_out_at

  async function getLocation(): Promise<{ lat: number; lng: number }> {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Geolocation not supported'))
        return
      }
      navigator.geolocation.getCurrentPosition(
        (pos) => resolve({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
        (err) => reject(new Error(err.message)),
        { enableHighAccuracy: true, timeout: 10000 },
      )
    })
  }

  async function handleCheckIn() {
    setLoading(true)
    try {
      const { lat, lng } = await getLocation()
      await taskService.checkIn(task.id, lat, lng)
      qc.invalidateQueries({ queryKey: taskKeys.detail(task.id) })
      toast.success('Checked in successfully')
    } catch (err: any) {
      toast.error(err.message || 'Failed to check in')
    } finally {
      setLoading(false)
    }
  }

  async function handleCheckOut() {
    setLoading(true)
    try {
      const { lat, lng } = await getLocation()
      await taskService.checkOut(task.id, lat, lng)
      qc.invalidateQueries({ queryKey: taskKeys.detail(task.id) })
      toast.success('Checked out successfully')
    } catch (err: any) {
      toast.error(err.message || 'Failed to check out')
    } finally {
      setLoading(false)
    }
  }

  if (isCheckedOut) return null

  return (
    <div className="bg-surface border border-border rounded-card p-5">
      <div className="flex items-center gap-2 mb-3">
        <MapPin className="h-4 w-4 text-navy" />
        <h3 className="text-sm font-semibold text-navy">Location Check</h3>
      </div>

      {!isCheckedIn ? (
        <PillButton
          fullWidth
          icon={loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <LogIn className="h-4 w-4" />}
          onClick={handleCheckIn}
          loading={loading}
        >
          Check In
        </PillButton>
      ) : (
        <PillButton
          fullWidth
          variant="secondary"
          icon={loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <LogOut className="h-4 w-4" />}
          onClick={handleCheckOut}
          loading={loading}
        >
          Check Out
        </PillButton>
      )}
    </div>
  )
}

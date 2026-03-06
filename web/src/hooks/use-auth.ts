'use client'

import { useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useAppStore } from '@/stores/app-store'
import { authService } from '@/services/auth-service'
import { requestPushPermissionAndRegister, getPushPermissionState } from '@/lib/firebase'

export function useAuth() {
  const { user, isLoading, setUser, setLoading } = useAppStore()

  useEffect(() => {
    let subscription: { unsubscribe: () => void } | null = null

    async function init() {
      try {
        const supabase = createClient()

        const { data: { user: authUser } } = await supabase.auth.getUser()

        if (authUser) {
          try {
            const profile = await authService.fetchUserProfile(authUser.id)
            setUser(profile)
          } catch {
            // Profile fetch failed — continue without user data
          }
        }

        const { data: { subscription: sub } } = supabase.auth.onAuthStateChange(
          async (event, session) => {
            if (event === 'SIGNED_IN' && session?.user) {
              try {
                const profile = await authService.fetchUserProfile(session.user.id)
                setUser(profile)
              } catch {
                // ignore
              }
              // Re-register push token for the newly signed-in user
              // (if browser already has push permission granted)
              if (getPushPermissionState() === 'granted') {
                requestPushPermissionAndRegister().catch(() => {})
              }
            } else if (event === 'SIGNED_OUT') {
              setUser(null)
            }
          },
        )
        subscription = sub
      } catch {
        // Supabase client creation or auth check failed
      } finally {
        setLoading(false)
      }
    }

    init()

    return () => subscription?.unsubscribe()
  }, [setUser, setLoading])

  return { user, isLoading }
}

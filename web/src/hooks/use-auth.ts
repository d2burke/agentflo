'use client'

import { useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useAppStore } from '@/stores/app-store'
import { authService } from '@/services/auth-service'

export function useAuth() {
  const { user, isLoading, setUser, setLoading } = useAppStore()

  useEffect(() => {
    const supabase = createClient()

    // Get initial session
    supabase.auth.getUser().then(async ({ data: { user: authUser } }) => {
      if (authUser) {
        const profile = await authService.fetchUserProfile(authUser.id)
        setUser(profile)
      }
      setLoading(false)
    })

    // Listen for auth state changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session?.user) {
        const profile = await authService.fetchUserProfile(session.user.id)
        setUser(profile)
      } else if (event === 'SIGNED_OUT') {
        setUser(null)
      }
    })

    return () => subscription.unsubscribe()
  }, [setUser, setLoading])

  return { user, isLoading }
}

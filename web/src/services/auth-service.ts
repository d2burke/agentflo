import { createClient } from '@/lib/supabase/client'
import type { AppUser, UserRole } from '@/types/models'

export const authService = {
  async signUp(
    email: string,
    password: string,
    fullName: string,
    phone: string,
    role: UserRole,
  ) {
    const supabase = createClient()

    // Create auth user
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
    })

    if (authError) throw authError
    if (!authData.user) throw new Error('Sign up failed')

    // Create public.users profile row
    const { error: profileError } = await supabase.from('users').upsert({
      id: authData.user.id,
      email,
      full_name: fullName,
      phone,
      role,
    })

    if (profileError) throw profileError

    return authData
  },

  async signIn(email: string, password: string) {
    const supabase = createClient()
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    if (error) throw error
    return data
  },

  async signOut() {
    const supabase = createClient()
    const { error } = await supabase.auth.signOut()
    if (error) throw error
  },

  async resetPassword(email: string) {
    const supabase = createClient()
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (error) throw error
  },

  async fetchUserProfile(userId: string): Promise<AppUser | null> {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .single()

    if (error) return null
    return data as AppUser
  },

  async updateProfile(userId: string, updates: Partial<AppUser>) {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('users')
      .update(updates)
      .eq('id', userId)
      .select()
      .single()

    if (error) throw error
    return data as AppUser
  },

  // MFA methods
  async enrollMFA() {
    const supabase = createClient()
    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      friendlyName: 'AgentFlo Authenticator',
    })
    if (error) throw error
    return data
  },

  async verifyMFA(factorId: string, code: string) {
    const supabase = createClient()
    const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({
      factorId,
    })
    if (challengeError) throw challengeError

    const { data, error } = await supabase.auth.mfa.verify({
      factorId,
      challengeId: challenge.id,
      code,
    })
    if (error) throw error
    return data
  },

  async getMFAFactors() {
    const supabase = createClient()
    const { data, error } = await supabase.auth.mfa.listFactors()
    if (error) throw error
    return data
  },

  async unenrollMFA(factorId: string) {
    const supabase = createClient()
    const { data, error } = await supabase.auth.mfa.unenroll({ factorId })
    if (error) throw error
    return data
  },
}

import { create } from 'zustand'
import type { AppUser } from '@/types/models'

interface AppStore {
  // Auth
  user: AppUser | null
  isLoading: boolean
  mfaVerified: boolean

  // UI
  sidebarCollapsed: boolean

  // Actions
  setUser: (user: AppUser | null) => void
  setLoading: (loading: boolean) => void
  setMfaVerified: (verified: boolean) => void
  toggleSidebar: () => void
  reset: () => void
}

export const useAppStore = create<AppStore>((set) => ({
  // Initial state
  user: null,
  isLoading: true,
  mfaVerified: false,
  sidebarCollapsed: false,

  // Actions
  setUser: (user) => set({ user }),
  setLoading: (isLoading) => set({ isLoading }),
  setMfaVerified: (mfaVerified) => set({ mfaVerified }),
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
  reset: () => set({ user: null, isLoading: false, mfaVerified: false }),
}))

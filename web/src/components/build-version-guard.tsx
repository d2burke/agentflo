'use client'

import { useEffect } from 'react'

const BUILD_VERSION_STORAGE_KEY = 'agentflo-build-version'

export function BuildVersionGuard({ buildVersion }: { buildVersion: string }) {
  useEffect(() => {
    if (!buildVersion || typeof window === 'undefined') {
      return
    }

    const previousVersion = window.sessionStorage.getItem(BUILD_VERSION_STORAGE_KEY)

    if (previousVersion && previousVersion !== buildVersion) {
      window.sessionStorage.setItem(BUILD_VERSION_STORAGE_KEY, buildVersion)
      window.location.reload()
      return
    }

    window.sessionStorage.setItem(BUILD_VERSION_STORAGE_KEY, buildVersion)
  }, [buildVersion])

  return null
}

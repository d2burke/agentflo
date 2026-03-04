import Link from 'next/link'
import { PillButton } from '@/components/ui/pill-button'
import { FileQuestion } from 'lucide-react'

export default function AppNotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] text-center px-6">
      <div className="h-16 w-16 rounded-full bg-border-light text-slate flex items-center justify-center mb-4">
        <FileQuestion className="h-8 w-8" />
      </div>
      <h2 className="text-xl font-extrabold text-navy mb-2">Page Not Found</h2>
      <p className="text-sm text-slate mb-6">The page you&apos;re looking for doesn&apos;t exist.</p>
      <Link href="/dashboard">
        <PillButton>Go to Dashboard</PillButton>
      </Link>
    </div>
  )
}

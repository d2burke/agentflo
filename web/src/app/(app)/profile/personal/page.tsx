'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft } from 'lucide-react'
import { InputField } from '@/components/ui/input-field'
import { PillButton } from '@/components/ui/pill-button'
import { useAppStore } from '@/stores/app-store'
import { authService } from '@/services/auth-service'
import { toast } from 'sonner'

export default function PersonalInfoPage() {
  const { user, setUser } = useAppStore()
  const router = useRouter()

  const [fullName, setFullName] = useState(user?.full_name ?? '')
  const [phone, setPhone] = useState(user?.phone ?? '')
  const [brokerage, setBrokerage] = useState(user?.brokerage ?? '')
  const [licenseNumber, setLicenseNumber] = useState(user?.license_number ?? '')
  const [licenseState, setLicenseState] = useState(user?.license_state ?? '')
  const [bio, setBio] = useState(user?.bio ?? '')
  const [saving, setSaving] = useState(false)

  if (!user) return null

  async function handleSave() {
    setSaving(true)
    try {
      const updated = await authService.updateProfile(user!.id, {
        full_name: fullName,
        phone: phone || null,
        brokerage: brokerage || null,
        license_number: licenseNumber || null,
        license_state: licenseState || null,
        bio: bio || null,
      })
      setUser(updated)
      toast.success('Profile updated')
    } catch (err: any) {
      toast.error(err.message || 'Failed to update profile')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="max-w-2xl">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-1 text-sm font-medium text-slate hover:text-navy transition-colors mb-6"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <h1 className="text-2xl font-extrabold text-navy mb-6">Personal Info</h1>

      <div className="space-y-4">
        <InputField label="Full Name" value={fullName} onChange={(e) => setFullName(e.target.value)} required />
        <InputField label="Email" value={user.email} disabled />
        <InputField label="Phone" type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
        <InputField label="Brokerage" value={brokerage} onChange={(e) => setBrokerage(e.target.value)} />
        <div className="grid grid-cols-2 gap-4">
          <InputField label="License Number" value={licenseNumber} onChange={(e) => setLicenseNumber(e.target.value)} />
          <InputField label="License State" value={licenseState} onChange={(e) => setLicenseState(e.target.value)} />
        </div>
        <div>
          <label className="block text-sm font-semibold text-navy mb-1.5">Bio</label>
          <textarea
            className="w-full rounded-input border border-border bg-surface px-4 py-3 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/30 focus:border-red transition-colors min-h-[100px] resize-y"
            placeholder="Tell us about yourself..."
            value={bio}
            onChange={(e) => setBio(e.target.value)}
          />
        </div>

        <PillButton fullWidth loading={saving} onClick={handleSave}>
          Save Changes
        </PillButton>
      </div>
    </div>
  )
}

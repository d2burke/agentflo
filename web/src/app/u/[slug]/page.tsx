import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import type { PublicProfileFull } from '@/types/models'
import { PublicProfileView } from './public-profile-view'

interface Props {
  params: Promise<{ slug: string }>
}

export default async function PublicProfilePage({ params }: Props) {
  const { slug } = await params
  const supabase = await createClient()

  const { data, error } = await supabase
    .from('public_profiles')
    .select()
    .eq('profile_slug', slug)
    .eq('is_public_profile_enabled', true)
    .single()

  if (error || !data) notFound()

  return <PublicProfileView profile={data as PublicProfileFull} />
}

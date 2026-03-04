import { createClient } from '@/lib/supabase/client'

export const storageService = {
  async uploadFile(
    bucket: string,
    path: string,
    file: File,
  ): Promise<string> {
    const supabase = createClient()
    const { error } = await supabase.storage
      .from(bucket)
      .upload(path, file, { upsert: true })

    if (error) throw error

    const { data } = supabase.storage.from(bucket).getPublicUrl(path)
    return data.publicUrl
  },

  async uploadDeliverablePhoto(
    taskId: string,
    runnerId: string,
    file: File,
    index: number,
  ): Promise<string> {
    const ext = file.name.split('.').pop() || 'jpg'
    const path = `${taskId}/${runnerId}/${Date.now()}_${index}.${ext}`
    return this.uploadFile('deliverables', path, file)
  },

  async uploadAvatar(userId: string, file: File): Promise<string> {
    const ext = file.name.split('.').pop() || 'jpg'
    const path = `${userId}/avatar.${ext}`
    return this.uploadFile('avatars', path, file)
  },

  async uploadPortfolioImage(runnerId: string, file: File, index: number): Promise<string> {
    const ext = file.name.split('.').pop() || 'jpg'
    const path = `${runnerId}/${Date.now()}_${index}.${ext}`
    return this.uploadFile('portfolio', path, file)
  },

  async deleteFile(bucket: string, path: string) {
    const supabase = createClient()
    const { error } = await supabase.storage.from(bucket).remove([path])
    if (error) throw error
  },
}

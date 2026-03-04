'use client'

import { useState, useRef } from 'react'
import { Camera, X, Upload, Loader2 } from 'lucide-react'
import { PillButton } from '@/components/ui/pill-button'
import { storageService } from '@/services/storage-service'
import { toast } from 'sonner'

interface PhotoUploadProps {
  taskId: string
  runnerId: string
  onUploadComplete?: (urls: string[]) => void
}

export function PhotoUpload({ taskId, runnerId, onUploadComplete }: PhotoUploadProps) {
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [files, setFiles] = useState<File[]>([])
  const [previews, setPreviews] = useState<string[]>([])
  const [uploading, setUploading] = useState(false)

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const newFiles = Array.from(e.target.files || [])
    if (newFiles.length === 0) return

    setFiles((prev) => [...prev, ...newFiles])

    // Generate previews
    newFiles.forEach((file) => {
      const reader = new FileReader()
      reader.onloadend = () => {
        setPreviews((prev) => [...prev, reader.result as string])
      }
      reader.readAsDataURL(file)
    })
  }

  function removeFile(index: number) {
    setFiles((prev) => prev.filter((_, i) => i !== index))
    setPreviews((prev) => prev.filter((_, i) => i !== index))
  }

  async function handleUpload() {
    if (files.length === 0) return

    setUploading(true)
    try {
      const urls = await Promise.all(
        files.map((file, i) =>
          storageService.uploadDeliverablePhoto(taskId, runnerId, file, i),
        ),
      )
      toast.success(`${urls.length} photo${urls.length > 1 ? 's' : ''} uploaded`)
      onUploadComplete?.(urls)
      setFiles([])
      setPreviews([])
    } catch (err: any) {
      toast.error(err.message || 'Upload failed')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="space-y-4">
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        multiple
        className="hidden"
        onChange={handleFileSelect}
      />

      {/* Drop zone / select button */}
      <button
        onClick={() => fileInputRef.current?.click()}
        className="w-full border-2 border-dashed border-border rounded-card p-8 text-center hover:border-red hover:bg-red-glow/30 transition-colors"
      >
        <Camera className="h-8 w-8 text-slate mx-auto mb-2" />
        <p className="text-sm font-semibold text-navy">Click to select photos</p>
        <p className="text-xs text-slate mt-1">JPG, PNG up to 10MB each</p>
      </button>

      {/* Previews */}
      {previews.length > 0 && (
        <div className="grid grid-cols-3 gap-2">
          {previews.map((preview, i) => (
            <div key={i} className="relative aspect-square rounded-md overflow-hidden group">
              <img src={preview} alt={`Preview ${i + 1}`} className="w-full h-full object-cover" />
              <button
                onClick={() => removeFile(i)}
                className="absolute top-1 right-1 h-6 w-6 rounded-full bg-navy/70 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
              >
                <X className="h-3 w-3" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Upload button */}
      {files.length > 0 && (
        <PillButton
          fullWidth
          loading={uploading}
          onClick={handleUpload}
          icon={<Upload className="h-4 w-4" />}
        >
          Upload {files.length} Photo{files.length > 1 ? 's' : ''}
        </PillButton>
      )}
    </div>
  )
}

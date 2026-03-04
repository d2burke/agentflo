'use client'

import { Suspense, useState, useEffect, useRef } from 'react'
import { useSearchParams } from 'next/navigation'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useAppStore } from '@/stores/app-store'
import { messageService } from '@/services/message-service'
import { createClient } from '@/lib/supabase/client'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { EmptyState } from '@/components/ui/empty-state'
import { Avatar } from '@/components/ui/avatar'
import { MessageSquare, Send } from 'lucide-react'
import { timeAgo, cn } from '@/lib/utils'
import type { Message, Conversation, PublicProfile } from '@/types/models'

export default function MessagesPage() {
  return (
    <Suspense>
      <MessagesContent />
    </Suspense>
  )
}

function MessagesContent() {
  const { user } = useAppStore()
  const searchParams = useSearchParams()
  const taskId = searchParams.get('taskId')

  const [activeConversationId, setActiveConversationId] = useState<string | null>(null)

  const { data: conversations = [], isLoading } = useQuery({
    queryKey: ['conversations', user?.id],
    queryFn: () => messageService.fetchConversations(user!.id),
    enabled: !!user,
  })

  if (!user) return null

  return (
    <div className="h-[calc(100vh-theme(spacing.24))]">
      <h1 className="text-2xl font-extrabold text-navy mb-6">Messages</h1>

      {isLoading ? (
        <LoadingSpinner message="Loading..." />
      ) : conversations.length > 0 || taskId ? (
        <div className="flex border border-border rounded-card overflow-hidden h-[calc(100%-4rem)]">
          {/* Conversation list */}
          <div className={cn(
            'w-80 border-r border-border bg-surface overflow-y-auto shrink-0',
            activeConversationId ? 'hidden lg:block' : 'w-full lg:w-80',
          )}>
            {conversations.map((conv) => (
              <ConversationItem
                key={conv.id}
                conversation={conv}
                userId={user.id}
                isActive={activeConversationId === conv.id}
                onClick={() => setActiveConversationId(conv.id)}
              />
            ))}
            {conversations.length === 0 && (
              <div className="p-6">
                <p className="text-sm text-slate">No conversations yet</p>
              </div>
            )}
          </div>

          {/* Message thread */}
          <div className={cn(
            'flex-1 flex flex-col',
            !activeConversationId && 'hidden lg:flex',
          )}>
            {activeConversationId ? (
              <MessageThread
                conversationId={activeConversationId}
                userId={user.id}
                onBack={() => setActiveConversationId(null)}
              />
            ) : (
              <div className="flex-1 flex items-center justify-center">
                <EmptyState
                  icon={<MessageSquare className="h-10 w-10" />}
                  title="Select a conversation"
                  description="Choose a conversation from the left to start messaging."
                />
              </div>
            )}
          </div>
        </div>
      ) : (
        <EmptyState
          icon={<MessageSquare className="h-10 w-10" />}
          title="No messages yet"
          description="When you start a conversation about a task, it will appear here."
        />
      )}
    </div>
  )
}

function ConversationItem({
  conversation,
  userId,
  isActive,
  onClick,
}: {
  conversation: Conversation
  userId: string
  isActive: boolean
  onClick: () => void
}) {
  const otherId = conversation.participant_1_id === userId
    ? conversation.participant_2_id
    : conversation.participant_1_id

  const { data: profile } = useQuery({
    queryKey: ['profile', otherId],
    queryFn: async () => {
      const supabase = createClient()
      const { data } = await supabase
        .from('users')
        .select('id, full_name, avatar_url')
        .eq('id', otherId)
        .single()
      return data as PublicProfile | null
    },
  })

  return (
    <button
      onClick={onClick}
      className={cn(
        'w-full text-left flex items-center gap-3 p-4 transition-colors border-b border-border',
        isActive ? 'bg-red-glow' : 'hover:bg-border-light',
      )}
    >
      <Avatar src={profile?.avatar_url} name={profile?.full_name ?? 'User'} size="sm" />
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold text-navy truncate">{profile?.full_name ?? 'Loading...'}</p>
        <p className="text-[10px] text-slate">{timeAgo(conversation.created_at)}</p>
      </div>
    </button>
  )
}

function MessageThread({
  conversationId,
  userId,
  onBack,
}: {
  conversationId: string
  userId: string
  onBack: () => void
}) {
  const qc = useQueryClient()
  const scrollRef = useRef<HTMLDivElement>(null)
  const [input, setInput] = useState('')
  const [sending, setSending] = useState(false)

  const { data: messages = [], isLoading } = useQuery({
    queryKey: ['messages', conversationId],
    queryFn: () => messageService.fetchMessages(conversationId),
  })

  // Subscribe to realtime messages
  useEffect(() => {
    const channel = messageService.subscribeToMessages(conversationId, () => {
      qc.invalidateQueries({ queryKey: ['messages', conversationId] })
    })
    return () => { channel.unsubscribe() }
  }, [conversationId, qc])

  // Auto-scroll on new messages
  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight })
  }, [messages.length])

  async function handleSend(e: React.FormEvent) {
    e.preventDefault()
    if (!input.trim() || sending) return

    setSending(true)
    try {
      await messageService.sendMessage({
        senderId: userId,
        body: input.trim(),
        conversationId,
      })
      setInput('')
      qc.invalidateQueries({ queryKey: ['messages', conversationId] })
    } finally {
      setSending(false)
    }
  }

  return (
    <>
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 border-b border-border lg:hidden">
        <button onClick={onBack} className="text-sm font-medium text-slate hover:text-navy">
          &larr; Back
        </button>
      </div>

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto p-4 space-y-3">
        {isLoading ? (
          <LoadingSpinner />
        ) : (
          messages.map((msg) => (
            <div
              key={msg.id}
              className={cn('flex', msg.sender_id === userId ? 'justify-end' : 'justify-start')}
            >
              <div
                className={cn(
                  'max-w-[75%] rounded-2xl px-4 py-2.5',
                  msg.sender_id === userId
                    ? 'bg-red text-white rounded-br-md'
                    : 'bg-border-light text-navy rounded-bl-md',
                )}
              >
                <p className="text-sm">{msg.body}</p>
                <p className={cn(
                  'text-[10px] mt-1',
                  msg.sender_id === userId ? 'text-white/70' : 'text-slate',
                )}>
                  {timeAgo(msg.created_at)}
                </p>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Input */}
      <form onSubmit={handleSend} className="flex items-center gap-2 p-4 border-t border-border">
        <input
          type="text"
          className="flex-1 rounded-full border border-border bg-surface px-4 py-2.5 text-sm text-navy placeholder:text-slate focus:outline-none focus:ring-2 focus:ring-red/30 focus:border-red transition-colors"
          placeholder="Type a message..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <button
          type="submit"
          disabled={!input.trim() || sending}
          className="h-10 w-10 rounded-full bg-red text-white flex items-center justify-center hover:bg-red-hover transition-colors disabled:opacity-50"
        >
          <Send className="h-4 w-4" />
        </button>
      </form>
    </>
  )
}

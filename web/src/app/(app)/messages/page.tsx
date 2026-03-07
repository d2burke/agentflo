'use client'

import { Suspense, useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import {
  type InfiniteData,
  useInfiniteQuery,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query'
import { MessageSquare, Send } from 'lucide-react'
import { toast } from 'sonner'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { EmptyState } from '@/components/ui/empty-state'
import { Avatar } from '@/components/ui/avatar'
import { messageService, MESSAGE_PAGE_SIZE } from '@/services/message-service'
import { useAppStore } from '@/stores/app-store'
import { cn, timeAgo } from '@/lib/utils'
import type { ConversationPreview, Message } from '@/types/models'

const NO_ACTIVE_CONVERSATION = '__none__'

type MessagePages = InfiniteData<Message[], string | null>

function compareMessages(left: Message, right: Message) {
  const leftCreatedAt = left.created_at ?? ''
  const rightCreatedAt = right.created_at ?? ''

  if (leftCreatedAt !== rightCreatedAt) {
    return leftCreatedAt.localeCompare(rightCreatedAt)
  }

  return left.id.localeCompare(right.id)
}

function sortMessagesAscending(messages: Message[]) {
  return [...messages].sort(compareMessages)
}

function mergeMessages(messages: Message[]) {
  const grouped = new Map<string, Message>()

  for (const message of messages) {
    const key = message.client_message_id ? `client:${message.client_message_id}` : `id:${message.id}`
    const existing = grouped.get(key)

    grouped.set(key, {
      ...(existing ?? {}),
      ...message,
      metadata: message.metadata ?? existing?.metadata ?? {},
      message_type: message.message_type ?? existing?.message_type ?? 'text',
      delivery_status:
        message.delivery_status
        ?? (existing?.delivery_status === 'sent' ? 'sent' : existing?.delivery_status)
        ?? 'sent',
      read_at: message.read_at ?? existing?.read_at ?? null,
    } as Message)
  }

  return sortMessagesAscending(Array.from(grouped.values()))
}

function appendMessageToPages(existing: MessagePages | undefined, message: Message): MessagePages {
  if (!existing) {
    return {
      pages: [[message]],
      pageParams: [null],
    }
  }

  const nextPages = [...existing.pages]
  const newestPage = nextPages[0] ?? []
  nextPages[0] = mergeMessages([...newestPage, message])

  return {
    ...existing,
    pages: nextPages,
  }
}

function sortConversations(previews: ConversationPreview[]) {
  return [...previews].sort((left, right) => {
    const leftPinned = left.is_pinned ? 1 : 0
    const rightPinned = right.is_pinned ? 1 : 0

    if (leftPinned !== rightPinned) {
      return rightPinned - leftPinned
    }

    const leftSort = left.sort_at ?? left.last_message_at ?? ''
    const rightSort = right.sort_at ?? right.last_message_at ?? ''

    if (leftSort !== rightSort) {
      return rightSort.localeCompare(leftSort)
    }

    return left.conversation_id.localeCompare(right.conversation_id)
  })
}

function patchConversationList(
  previews: ConversationPreview[] | undefined,
  conversationId: string,
  patch: Partial<ConversationPreview>,
) {
  if (!previews) return previews

  return sortConversations(
    previews.map((preview) => (
      preview.conversation_id === conversationId
        ? { ...preview, ...patch }
        : preview
    )),
  )
}

function createClientMessageId() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }

  return `client-${Date.now()}`
}

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
  const conversationIdParam = searchParams.get('conversationId')
  const taskId = searchParams.get('taskId')
  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null)

  const conversationsQuery = useQuery({
    queryKey: ['conversations', user?.id],
    queryFn: () => messageService.fetchConversations(user!.id),
    enabled: !!user,
  })

  const taskConversationQuery = useQuery({
    queryKey: ['task-conversation', taskId],
    queryFn: () => messageService.getOrCreateTaskConversation(taskId!),
    enabled: !!user && !!taskId,
    retry: false,
  })

  const conversations = useMemo(
    () => conversationsQuery.data ?? [],
    [conversationsQuery.data],
  )
  const resolvedTaskConversationId = taskConversationQuery.data?.id ?? null

  const activeConversationId = useMemo(() => {
    const candidateIds = [
      selectedConversationId,
      conversationIdParam,
      resolvedTaskConversationId,
      conversations[0]?.conversation_id,
    ].filter((value): value is string => Boolean(value))

    return candidateIds[0] ?? NO_ACTIVE_CONVERSATION
  }, [conversationIdParam, conversations, resolvedTaskConversationId, selectedConversationId])

  const activeConversation = useMemo(
    () => conversations.find((conversation) => conversation.conversation_id === activeConversationId) ?? null,
    [activeConversationId, conversations],
  )

  const hasAnyConversationContext = conversations.length > 0 || !!conversationIdParam || !!taskId

  if (!user) {
    return null
  }

  if (conversationsQuery.isLoading || taskConversationQuery.isLoading) {
    return <LoadingSpinner message="Loading messages..." />
  }

  if (taskConversationQuery.error) {
    return (
      <EmptyState
        icon={<MessageSquare className="h-10 w-10" />}
        title="Conversation unavailable"
        description="This task conversation could not be opened."
      />
    )
  }

  return (
    <div className="h-[calc(100vh-theme(spacing.24))]">
      <h1 className="mb-6 text-2xl font-extrabold text-navy">Messages</h1>

      {hasAnyConversationContext ? (
        <div className="flex h-[calc(100%-4rem)] overflow-hidden rounded-card border border-border">
          <div
            className={cn(
              'w-80 shrink-0 overflow-y-auto border-r border-border bg-surface',
              activeConversationId !== NO_ACTIVE_CONVERSATION ? 'hidden lg:block' : 'w-full lg:w-80',
            )}
          >
            {conversations.length > 0 ? (
              conversations.map((conversation) => (
                <ConversationItem
                  key={conversation.conversation_id}
                  conversation={conversation}
                  isActive={conversation.conversation_id === activeConversationId}
                  onClick={() => setSelectedConversationId(conversation.conversation_id)}
                />
              ))
            ) : (
              <div className="p-6">
                <p className="text-sm text-slate">No conversations yet</p>
              </div>
            )}
          </div>

          <div className={cn('flex flex-1 flex-col', activeConversationId === NO_ACTIVE_CONVERSATION && 'hidden lg:flex')}>
            {activeConversationId !== NO_ACTIVE_CONVERSATION ? (
              <MessageThread
                key={activeConversationId}
                conversation={activeConversation}
                conversationId={activeConversationId}
                userId={user.id}
                onBack={() => setSelectedConversationId(null)}
              />
            ) : (
              <div className="flex flex-1 items-center justify-center">
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
  isActive,
  onClick,
}: {
  conversation: ConversationPreview
  isActive: boolean
  onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'flex w-full items-center gap-3 border-b border-border p-4 text-left transition-colors',
        isActive ? 'bg-red-glow' : 'hover:bg-border-light',
      )}
    >
      <Avatar src={conversation.other_user_avatar} name={conversation.other_user_name} size="sm" />
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <p className="truncate text-sm font-semibold text-navy">{conversation.other_user_name}</p>
          {conversation.conversation_kind === 'task' ? (
            <span className="rounded-full bg-red-light px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-red">
              Task
            </span>
          ) : null}
        </div>
        <p className="truncate text-xs text-slate">
          {conversation.last_message_body ?? conversation.draft_body ?? 'No messages yet'}
        </p>
      </div>
      <div className="flex shrink-0 flex-col items-end gap-1">
        <p className="text-[10px] text-slate">
          {conversation.last_message_at ? timeAgo(conversation.last_message_at) : ''}
        </p>
        {conversation.unread_count > 0 ? (
          <span className="rounded-full bg-red px-2 py-0.5 text-[10px] font-semibold text-white">
            {conversation.unread_count}
          </span>
        ) : null}
      </div>
    </button>
  )
}

function MessageThread({
  conversationId,
  conversation,
  userId,
  onBack,
}: {
  conversationId: string
  conversation: ConversationPreview | null
  userId: string
  onBack: () => void
}) {
  const queryClient = useQueryClient()
  const scrollRef = useRef<HTMLDivElement>(null)
  const [input, setInput] = useState('')
  const [optimisticMessages, setOptimisticMessages] = useState<Message[]>([])

  const messagesQuery = useInfiniteQuery({
    queryKey: ['messages', conversationId],
    queryFn: ({ pageParam }) => messageService.fetchMessagePage(conversationId, pageParam),
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => (
      lastPage.length === MESSAGE_PAGE_SIZE
        ? (lastPage[0]?.id ?? null)
        : null
    ),
  })

  const serverMessages = useMemo(
    () => (messagesQuery.data?.pages ?? []).slice().reverse().flatMap((page) => page),
    [messagesQuery.data],
  )

  const messages = useMemo(
    () => mergeMessages([...serverMessages, ...optimisticMessages]),
    [optimisticMessages, serverMessages],
  )

  const lastMessageId = messages[messages.length - 1]?.id

  useEffect(() => {
    const channel = messageService.subscribeToMessages(conversationId, (message) => {
      queryClient.setQueryData<MessagePages>(['messages', conversationId], (existing) => appendMessageToPages(existing, message))
      setOptimisticMessages((current) => current.filter((candidate) => {
        if (candidate.id === message.id) return false
        if (candidate.client_message_id && candidate.client_message_id === message.client_message_id) return false
        return true
      }))
      queryClient.setQueryData<ConversationPreview[]>(['conversations', userId], (current) => patchConversationList(current, conversationId, {
        last_message_id: message.id,
        last_message_body: message.body,
        last_message_type: message.message_type ?? 'text',
        last_message_at: message.created_at ?? new Date().toISOString(),
        last_message_sender_id: message.sender_id,
        unread_count: 0,
        sort_at: message.created_at ?? new Date().toISOString(),
      }))
    })

    return () => {
      void channel.unsubscribe()
    }
  }, [conversationId, queryClient, userId])

  useEffect(() => {
    if (!lastMessageId) return

    scrollRef.current?.scrollTo({
      top: scrollRef.current.scrollHeight,
      behavior: 'smooth',
    })
  }, [lastMessageId])

  useEffect(() => {
    if (!lastMessageId) return

    void messageService.markConversationRead(conversationId, lastMessageId)
      .then(() => {
        queryClient.setQueryData<ConversationPreview[]>(['conversations', userId], (current) => patchConversationList(current, conversationId, {
          unread_count: 0,
        }))
      })
      .catch(() => {
        // Read state drift is non-fatal for the thread UI.
      })
  }, [conversationId, lastMessageId, queryClient, userId])

  async function deliverMessage(message: Message) {
    setOptimisticMessages((current) => mergeMessages([
      ...current.filter((candidate) => candidate.id !== message.id && candidate.client_message_id !== message.client_message_id),
      { ...message, delivery_status: 'sending' },
    ]))

    try {
      const sentMessage = await messageService.sendMessage({
        senderId: userId,
        body: message.body,
        conversationId,
        clientMessageId: message.client_message_id ?? undefined,
        messageType: message.message_type ?? 'text',
        metadata: message.metadata ?? {},
      })

      setOptimisticMessages((current) => current.filter((candidate) => {
        if (candidate.id === message.id) return false
        if (candidate.client_message_id && candidate.client_message_id === sentMessage.client_message_id) return false
        return true
      }))

      queryClient.setQueryData<MessagePages>(['messages', conversationId], (existing) => appendMessageToPages(existing, sentMessage))
      queryClient.setQueryData<ConversationPreview[]>(['conversations', userId], (current) => patchConversationList(current, conversationId, {
        last_message_id: sentMessage.id,
        last_message_body: sentMessage.body,
        last_message_type: sentMessage.message_type ?? 'text',
        last_message_at: sentMessage.created_at ?? new Date().toISOString(),
        last_message_sender_id: sentMessage.sender_id,
        unread_count: 0,
        sort_at: sentMessage.created_at ?? new Date().toISOString(),
      }))
    } catch (error) {
      setOptimisticMessages((current) => mergeMessages(current.map((candidate) => {
        if (candidate.id === message.id) {
          return { ...candidate, delivery_status: 'failed' }
        }

        return candidate
      })))
      throw error
    }
  }

  async function handleSend(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()

    const trimmed = input.trim()
    if (!trimmed) return

    const clientMessageId = createClientMessageId()
    const draft: Message = {
      id: `temp-${clientMessageId}`,
      conversation_id: conversationId,
      task_id: conversation?.task_id ?? null,
      sender_id: userId,
      body: trimmed,
      client_message_id: clientMessageId,
      message_type: 'text',
      metadata: {},
      read_at: null,
      created_at: new Date().toISOString(),
      delivery_status: 'sending',
    }

    setInput('')

    try {
      await deliverMessage(draft)
    } catch {
      toast.error('Failed to send message')
      setInput(trimmed)
    }
  }

  async function retryMessage(message: Message) {
    try {
      await deliverMessage({ ...message, delivery_status: 'sending' })
    } catch {
      toast.error('Failed to resend message')
    }
  }

  return (
    <>
      <div className="border-b border-border px-4 py-3">
        <div className="flex items-center gap-3 lg:hidden">
          <button onClick={onBack} className="text-sm font-medium text-slate hover:text-navy">
            &larr; Back
          </button>
        </div>
        <div className="mt-2 flex items-center gap-3">
          <Avatar
            src={conversation?.other_user_avatar}
            name={conversation?.other_user_name ?? 'Conversation'}
            size="sm"
          />
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold text-navy">
              {conversation?.other_user_name ?? 'Conversation'}
            </p>
            <p className="text-xs text-slate">
              {conversation?.conversation_kind === 'task' ? 'Task conversation' : 'Direct conversation'}
            </p>
          </div>
        </div>
      </div>

      <div ref={scrollRef} className="flex-1 overflow-y-auto p-4">
        {messagesQuery.isLoading ? (
          <LoadingSpinner message="Loading messages..." />
        ) : messages.length === 0 ? (
          <EmptyState
            icon={<MessageSquare className="h-10 w-10" />}
            title="No messages yet"
            description="Send a message to start the conversation."
          />
        ) : (
          <div className="space-y-3">
            {messagesQuery.hasNextPage ? (
              <div className="flex justify-center">
                <button
                  type="button"
                  onClick={() => void messagesQuery.fetchNextPage()}
                  disabled={messagesQuery.isFetchingNextPage}
                  className="rounded-full border border-border px-4 py-2 text-xs font-semibold text-slate transition-colors hover:border-red hover:text-red disabled:opacity-60"
                >
                  {messagesQuery.isFetchingNextPage ? 'Loading older messages...' : 'Load older messages'}
                </button>
              </div>
            ) : null}

            {messages.map((message) => {
              const isOutgoing = message.sender_id === userId

              return (
                <div key={message.id} className={cn('flex', isOutgoing ? 'justify-end' : 'justify-start')}>
                  <div
                    className={cn(
                      'max-w-[78%] rounded-2xl px-4 py-2.5',
                      isOutgoing ? 'bg-red text-white rounded-br-md' : 'bg-border-light text-navy rounded-bl-md',
                    )}
                  >
                    <p className="text-sm">{message.body}</p>
                    <div className="mt-1 flex items-center gap-2">
                      <p className={cn('text-[10px]', isOutgoing ? 'text-white/70' : 'text-slate')}>
                        {message.created_at ? timeAgo(message.created_at) : 'Just now'}
                      </p>
                      {isOutgoing && message.delivery_status === 'sending' ? (
                        <span className="text-[10px] text-white/70">Sending...</span>
                      ) : null}
                      {isOutgoing && message.delivery_status === 'failed' ? (
                        <button
                          type="button"
                          onClick={() => void retryMessage(message)}
                          className="text-[10px] font-semibold text-white underline underline-offset-2"
                        >
                          Retry
                        </button>
                      ) : null}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      <form onSubmit={handleSend} className="flex items-center gap-2 border-t border-border p-4">
        <input
          type="text"
          className="flex-1 rounded-full border border-border bg-surface px-4 py-2.5 text-sm text-navy placeholder:text-slate transition-colors focus:border-red focus:outline-none focus:ring-2 focus:ring-red/30"
          placeholder="Type a message..."
          value={input}
          onChange={(event) => setInput(event.target.value)}
        />
        <button
          type="submit"
          disabled={!input.trim()}
          className="flex h-10 w-10 items-center justify-center rounded-full bg-red text-white transition-colors hover:bg-red-hover disabled:opacity-50"
        >
          <Send className="h-4 w-4" />
        </button>
      </form>
    </>
  )
}

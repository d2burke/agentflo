import SwiftUI

enum MessageContext {
    case task(UUID)
    case conversation(UUID)

    var cacheKey: String {
        switch self {
        case .task(let id):
            return "task-\(id.uuidString)"
        case .conversation(let id):
            return "conversation-\(id.uuidString)"
        }
    }
}

struct MessagingView: View {
    let context: MessageContext
    let otherUserName: String

    @Environment(AppState.self) private var appState
    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var isLoadingOlder = false
    @State private var isSending = false
    @State private var hasMoreMessages = true
    @State private var oldestLoadedMessageId: UUID?
    @State private var resolvedConversationId: UUID?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var errorMessage: String?

    init(taskId: UUID, otherUserName: String) {
        self.context = .task(taskId)
        self.otherUserName = otherUserName
    }

    init(conversationId: UUID, otherUserName: String) {
        self.context = .conversation(conversationId)
        self.otherUserName = otherUserName
    }

    private var currentUserId: UUID? {
        appState.authService.currentUser?.id
    }

    private var title: String {
        otherUserName.isEmpty ? "Messages" : otherUserName
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        if hasMoreMessages && !messages.isEmpty {
                            Button {
                                Task { await loadOlderMessages() }
                            } label: {
                                Text(isLoadingOlder ? "Loading older messages..." : "Load older messages")
                                    .font(.captionSM)
                                    .foregroundStyle(.agentSlate)
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.sm)
                                    .background(Color.agentSurface)
                                    .clipShape(Capsule())
                            }
                            .disabled(isLoadingOlder)
                            .padding(.top, Spacing.sm)
                        }

                        if isLoading {
                            LoadingView()
                                .frame(height: 100)
                        } else if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                VStack(spacing: 0) {
                                    if shouldShowDateHeader(at: index) {
                                        dateHeader(for: message.createdAt ?? Date())
                                    }

                                    MessageBubble(
                                        message: message,
                                        isOutgoing: message.senderId == currentUserId
                                    )
                                }
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.vertical, Spacing.md)
                }
                .scrollIndicators(.hidden)
                .onAppear { scrollProxy = proxy }
            }

            Divider()
            inputBar
        }
        .background(.agentBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toast(errorMessage ?? "", style: .error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ))
        .task(id: context.cacheKey) {
            await configureThread()
        }
        .onDisappear {
            appState.messageService.unsubscribe()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "message")
                .font(.system(size: 40))
                .foregroundStyle(.agentSlateLight)
            Text("No messages yet")
                .font(.bodyEmphasis)
                .foregroundStyle(.agentSlate)
            Text("Send a message to start the conversation.")
                .font(.bodySM)
                .foregroundStyle(.agentSlateLight)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func shouldShowDateHeader(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index].createdAt ?? Date()
        let previous = messages[index - 1].createdAt ?? Date()
        return !Calendar.current.isDate(current, inSameDayAs: previous)
    }

    private func dateHeader(for date: Date) -> some View {
        Text(date.formatted(date: .abbreviated, time: .omitted))
            .font(.caption)
            .foregroundStyle(.agentSlateLight)
            .padding(.vertical, Spacing.md)
    }

    private var inputBar: some View {
        HStack(spacing: Spacing.md) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .font(.bodySM)
                .lineLimit(1...4)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.agentSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .agentSlateLight : .agentRed)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || resolvedConversationId == nil)
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.vertical, Spacing.md)
        .background(.agentBackground)
    }

    private func configureThread() async {
        isLoading = true
        hasMoreMessages = true
        oldestLoadedMessageId = nil
        resolvedConversationId = nil
        messages = []
        appState.messageService.unsubscribe()

        do {
            let conversationId = try await resolveConversationId()
            resolvedConversationId = conversationId

            let initialPage = try await appState.messageService.fetchMessagePage(
                conversationId: conversationId,
                beforeMessageId: nil,
                limit: 50
            )

            messages = mergeMessages(existing: [], incoming: initialPage)
            oldestLoadedMessageId = messages.first?.id
            hasMoreMessages = initialPage.count == 50

            if let lastMessageId = messages.last?.id {
                try? await appState.messageService.markConversationRead(
                    conversationId: conversationId,
                    lastReadMessageId: lastMessageId
                )
            }

            subscribeToRealtime(conversationId: conversationId)
            isLoading = false
            scrollToBottom(animated: false)
        } catch {
            errorMessage = "Failed to load messages"
            isLoading = false
        }
    }

    private func resolveConversationId() async throws -> UUID {
        switch context {
        case .conversation(let conversationId):
            return conversationId
        case .task(let taskId):
            let conversation = try await appState.messageService.getOrCreateTaskConversation(taskId: taskId)
            return conversation.id
        }
    }

    private func loadOlderMessages() async {
        guard let conversationId = resolvedConversationId,
              let oldestLoadedMessageId,
              !isLoadingOlder else { return }

        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let olderPage = try await appState.messageService.fetchMessagePage(
                conversationId: conversationId,
                beforeMessageId: oldestLoadedMessageId,
                limit: 50
            )

            messages = mergeMessages(existing: messages, incoming: olderPage)
            oldestLoadedMessageId = messages.first?.id
            hasMoreMessages = olderPage.count == 50
        } catch {
            errorMessage = "Failed to load older messages"
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let senderId = currentUserId,
              let conversationId = resolvedConversationId else { return }

        messageText = ""
        isSending = true

        defer { isSending = false }

        do {
            let message = try await appState.messageService.sendMessage(
                conversationId: conversationId,
                senderId: senderId,
                body: text
            )
            messages = mergeMessages(existing: messages, incoming: [message])
            scrollToBottom(animated: true)
        } catch {
            errorMessage = "Failed to send message"
            messageText = text
        }
    }

    private func subscribeToRealtime(conversationId: UUID) {
        appState.messageService.subscribeToMessages(conversationId: conversationId) { newMessage in
            handleNewRealtimeMessage(newMessage, conversationId: conversationId)
        }
    }

    private func handleNewRealtimeMessage(_ newMessage: Message, conversationId: UUID) {
        let previousCount = messages.count
        messages = mergeMessages(existing: messages, incoming: [newMessage])

        if messages.count != previousCount || messages.last?.id == newMessage.id {
            scrollToBottom(animated: true)
        }

        if newMessage.senderId != currentUserId {
            Task {
                try? await appState.messageService.markConversationRead(
                    conversationId: conversationId,
                    lastReadMessageId: newMessage.id
                )
            }
        }
    }

    private func mergeMessages(existing: [Message], incoming: [Message]) -> [Message] {
        let merged = Dictionary(grouping: existing + incoming, by: \.id)
            .compactMap { $0.value.sorted(by: compareMessages).last }
            .sorted(by: compareMessages)
        return merged
    }

    private func compareMessages(_ left: Message, _ right: Message) -> Bool {
        let leftDate = left.createdAt ?? .distantPast
        let rightDate = right.createdAt ?? .distantPast
        if leftDate == rightDate {
            return left.id.uuidString < right.id.uuidString
        }
        return leftDate < rightDate
    }

    private func scrollToBottom(animated: Bool) {
        guard let lastId = messages.last?.id else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProxy?.scrollTo(lastId, anchor: .bottom)
                }
            } else {
                scrollProxy?.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MessagingView(taskId: UUID(), otherUserName: "Jane Smith")
    }
    .environment(AppState.preview)
}
#endif

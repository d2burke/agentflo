import SwiftUI

enum MessageContext {
    case task(UUID)
    case conversation(UUID)
}

struct MessagingView: View {
    let context: MessageContext
    let otherUserName: String

    @Environment(AppState.self) private var appState
    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var errorMessage: String?

    // Convenience initializers for backward compatibility
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

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        if isLoading {
                            LoadingView()
                                .frame(height: 100)
                        } else if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                VStack(spacing: 0) {
                                    // Date header when day changes
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

            // Message input
            inputBar
        }
        .background(.agentBackground)
        .navigationTitle(otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toast(errorMessage ?? "", style: .error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ))
        .task {
            await loadMessages()
            subscribeToRealtime()
        }
        .onDisappear {
            appState.messageService.unsubscribe()
        }
    }

    // MARK: - Empty State

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

    // MARK: - Date Header

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

    // MARK: - Input Bar

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
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.vertical, Spacing.md)
        .background(.agentBackground)
    }

    // MARK: - Data

    private func loadMessages() async {
        do {
            switch context {
            case .task(let taskId):
                messages = try await appState.messageService.fetchMessages(taskId: taskId)
                if let userId = currentUserId {
                    try? await appState.messageService.markAllAsRead(taskId: taskId, currentUserId: userId)
                }
            case .conversation(let conversationId):
                messages = try await appState.messageService.fetchMessages(conversationId: conversationId)
                if let userId = currentUserId {
                    try? await appState.messageService.markAllAsRead(conversationId: conversationId, currentUserId: userId)
                }
            }
            isLoading = false
            scrollToBottom()
        } catch {
            errorMessage = "Failed to load messages"
            isLoading = false
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let senderId = currentUserId else { return }

        messageText = ""
        isSending = true

        do {
            let message: Message
            switch context {
            case .task(let taskId):
                message = try await appState.messageService.sendMessage(
                    taskId: taskId, senderId: senderId, body: text
                )
            case .conversation(let conversationId):
                message = try await appState.messageService.sendMessage(
                    conversationId: conversationId, senderId: senderId, body: text
                )
            }
            // Add locally if not already added by realtime
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
            scrollToBottom()
        } catch {
            errorMessage = "Failed to send message"
            messageText = text // Restore text on failure
        }

        isSending = false
    }

    private func subscribeToRealtime() {
        switch context {
        case .task(let taskId):
            appState.messageService.subscribeToMessages(taskId: taskId) { newMessage in
                handleNewRealtimeMessage(newMessage)
            }
        case .conversation(let conversationId):
            appState.messageService.subscribeToMessages(conversationId: conversationId) { newMessage in
                handleNewRealtimeMessage(newMessage)
            }
        }
    }

    private func handleNewRealtimeMessage(_ newMessage: Message) {
        if !messages.contains(where: { $0.id == newMessage.id }) {
            messages.append(newMessage)
            scrollToBottom()

            // Mark as read if from other user
            if newMessage.senderId != currentUserId {
                Task {
                    try? await appState.messageService.markAsRead(messageId: newMessage.id)
                }
            }
        }
    }

    private func scrollToBottom() {
        guard let lastId = messages.last?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
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

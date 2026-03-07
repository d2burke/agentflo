import SwiftUI

struct ConversationsListView: View {
    @Environment(AppState.self) private var appState

    @State private var conversations: [ConversationPreview] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false

    private var currentUserId: UUID? {
        appState.authService.currentUser?.id
    }

    var body: some View {
        Group {
            if isLoading && !hasLoadedOnce {
                LoadingView(message: "Loading messages...")
            } else if conversations.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "message",
                    description: Text("Your conversations will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(conversations) { conversation in
                            Button {
                                appState.messagesPath.append(
                                    MessagesDestination.conversation(
                                        conversationId: conversation.conversationId,
                                        otherUserName: conversation.otherUserName
                                    )
                                )
                            } label: {
                                ConversationRow(
                                    conversation: conversation,
                                    currentUserId: currentUserId
                                )
                            }
                            .buttonStyle(.plain)

                            if conversation.id != conversations.last?.id {
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(.agentBackground)
        .navigationTitle("Messages")
        .refreshable { await loadConversations() }
        .task { await loadConversations() }
        .onAppear {
            if hasLoadedOnce {
                Task { await loadConversations() }
            }
        }
    }

    private func loadConversations() async {
        guard let userId = currentUserId else { return }
        do {
            conversations = try await appState.messageService.fetchConversationList(userId: userId)
        } catch {
            print("[ConversationsListView] Failed to load: \(error)")
        }
        isLoading = false
        hasLoadedOnce = true
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationPreview
    let currentUserId: UUID?

    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Avatar
            CachedAvatarView(
                avatarPath: conversation.otherUserAvatar,
                name: conversation.otherUserName,
                size: 48
            )

            // Name + last message
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(conversation.unreadCount > 0 ? .bodyEmphasis : .bodySM)
                        .foregroundStyle(.agentNavy)
                        .lineLimit(1)

                    Spacer()

                    if let lastAt = conversation.lastMessageAt {
                        Text(timeLabel(for: lastAt))
                            .font(.captionSM)
                            .foregroundStyle(.agentSlateLight)
                    }
                }

                HStack {
                    if let body = conversation.lastMessageBody {
                        let prefix = conversation.lastMessageSenderId == currentUserId ? "You: " : ""
                        Text("\(prefix)\(body)")
                            .font(.bodySM)
                            .foregroundStyle(conversation.unreadCount > 0 ? .agentNavy : .agentSlate)
                            .lineLimit(2)
                    } else {
                        Text("No messages yet")
                            .font(.bodySM)
                            .foregroundStyle(.agentSlateLight)
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.captionSM)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.agentRed)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.vertical, Spacing.lg)
        .background(.agentSurface)
    }

    private func timeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day, daysAgo < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

#Preview {
    NavigationStack {
        ConversationsListView()
    }
    .environment(AppState.preview)
}

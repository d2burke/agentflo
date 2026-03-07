import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                Text(message.body)
                    .font(.bodySM)
                    .foregroundStyle(isOutgoing ? .white : .agentNavy)

                HStack(spacing: 4) {
                    Text(timeString)
                        .font(.system(size: 11))
                        .foregroundStyle(isOutgoing ? .white.opacity(0.7) : .agentSlateLight)

                    if isOutgoing {
                        Image(systemName: message.readAt != nil ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(isOutgoing ? .white.opacity(0.7) : .agentSlateLight)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isOutgoing ? Color.agentNavySolid : Color.agentSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isOutgoing ? .clear : Shadows.card, radius: 2, y: 1)

            if !isOutgoing { Spacer(minLength: 60) }
        }
    }

    private var timeString: String {
        guard let createdAt = message.createdAt else { return "" }
        return createdAt.formatted(date: .omitted, time: .shortened)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        MessageBubble(
            message: Message(
                id: UUID(),
                taskId: UUID(),
                conversationId: UUID(),
                senderId: UUID(),
                body: "Hi, I have a question about the property.",
                clientMessageId: nil,
                messageType: "text",
                metadata: [:],
                replyToMessageId: nil,
                editedAt: nil,
                deletedAt: nil,
                readAt: nil,
                createdAt: .now
            ),
            isOutgoing: false
        )
        MessageBubble(
            message: Message(
                id: UUID(),
                taskId: UUID(),
                conversationId: UUID(),
                senderId: UUID(),
                body: "Sure, what would you like to know?",
                clientMessageId: nil,
                messageType: "text",
                metadata: [:],
                replyToMessageId: nil,
                editedAt: nil,
                deletedAt: nil,
                readAt: .now,
                createdAt: .now
            ),
            isOutgoing: true
        )
    }
    .padding()
    .background(Color.agentBackground)
}
#endif

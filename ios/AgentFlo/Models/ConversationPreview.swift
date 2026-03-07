import Foundation

struct ConversationPreview: Codable, Identifiable {
    let conversationId: UUID
    let otherUserId: UUID
    let otherUserName: String
    let otherUserAvatar: String?
    let lastMessageBody: String?
    let lastMessageAt: Date?
    let lastMessageSenderId: UUID?
    let unreadCount: Int

    var id: UUID { conversationId }

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case otherUserId = "other_user_id"
        case otherUserName = "other_user_name"
        case otherUserAvatar = "other_user_avatar"
        case lastMessageBody = "last_message_body"
        case lastMessageAt = "last_message_at"
        case lastMessageSenderId = "last_message_sender_id"
        case unreadCount = "unread_count"
    }
}

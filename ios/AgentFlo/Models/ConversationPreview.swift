import Foundation

struct ConversationPreview: Codable, Identifiable {
    let conversationId: UUID
    let conversationKind: String
    let taskId: UUID?
    let otherUserId: UUID
    let otherUserName: String
    let otherUserAvatar: String?
    let lastMessageId: UUID?
    let lastMessageBody: String?
    let lastMessageType: String?
    let lastMessageAt: Date?
    let lastMessageSenderId: UUID?
    let unreadCount: Int
    let isPinned: Bool?
    let archivedAt: Date?
    let draftBody: String?
    let sortAt: Date?

    var id: UUID { conversationId }

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case conversationKind = "conversation_kind"
        case taskId = "task_id"
        case otherUserId = "other_user_id"
        case otherUserName = "other_user_name"
        case otherUserAvatar = "other_user_avatar"
        case lastMessageId = "last_message_id"
        case lastMessageBody = "last_message_body"
        case lastMessageType = "last_message_type"
        case lastMessageAt = "last_message_at"
        case lastMessageSenderId = "last_message_sender_id"
        case unreadCount = "unread_count"
        case isPinned = "is_pinned"
        case archivedAt = "archived_at"
        case draftBody = "draft_body"
        case sortAt = "sort_at"
    }
}

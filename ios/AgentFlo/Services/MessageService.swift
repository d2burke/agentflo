import Foundation
import Supabase

@Observable
final class MessageService {

    enum ServiceError: LocalizedError {
        case emptyRPCResult(String)

        var errorDescription: String? {
            switch self {
            case .emptyRPCResult(let message):
                return message
            }
        }
    }

    var messages: [Message] = []
    private var realtimeChannel: RealtimeChannelV2?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return decoder
    }()

    // MARK: - Decoding Helpers

    private func decodeValue<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    private func decodeSingleRecord<T: Decodable>(_ type: T.Type, from data: Data, emptyMessage: String) throws -> T {
        if let record = try? decoder.decode(type, from: data) {
            return record
        }

        let records = try decoder.decode([T].self, from: data)
        guard let record = records.first else {
            throw ServiceError.emptyRPCResult(emptyMessage)
        }
        return record
    }

    // MARK: - Fetch Messages

    func fetchMessages(taskId: UUID) async throws -> [Message] {
        let conversation = try await getOrCreateTaskConversation(taskId: taskId)
        return try await fetchMessages(conversationId: conversation.id)
    }

    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        try await fetchMessagePage(conversationId: conversationId)
    }

    func fetchMessagePage(
        conversationId: UUID,
        beforeMessageId: UUID? = nil,
        limit: Int = 50
    ) async throws -> [Message] {
        let response = try await supabase
            .rpc(
                "get_messages_page_v2",
                params: MessagePageParams(
                    conversationId: conversationId,
                    beforeMessageId: beforeMessageId,
                    limit: limit
                )
            )
            .execute()

        let page = try decodeValue([Message].self, from: response.data)
        return page.reversed()
    }

    // MARK: - Send Message

    @discardableResult
    func sendMessage(taskId: UUID, senderId: UUID, body: String) async throws -> Message {
        _ = senderId
        let conversation = try await getOrCreateTaskConversation(taskId: taskId)
        return try await sendMessage(conversationId: conversation.id, senderId: senderId, body: body)
    }

    @discardableResult
    func sendMessage(conversationId: UUID, senderId: UUID, body: String) async throws -> Message {
        _ = senderId
        let payload = SendMessagePayload(
            body: body,
            taskId: nil,
            conversationId: conversationId.uuidString,
            clientMessageId: UUID().uuidString,
            messageType: "text",
            metadata: [:]
        )
        let bodyData = try JSONEncoder().encode(payload)

        let response: SendMessageResponse = try await supabase.functions.invoke(
            "send-message",
            options: .init(body: bodyData)
        )

        return response.message
    }

    // MARK: - Read State

    func markConversationRead(conversationId: UUID, lastReadMessageId: UUID? = nil) async throws {
        try await supabase
            .rpc(
                "mark_conversation_read_v2",
                params: MarkConversationReadParams(
                    conversationId: conversationId,
                    lastReadMessageId: lastReadMessageId
                )
            )
            .execute()
    }

    func markAllAsRead(taskId: UUID, currentUserId: UUID) async throws {
        _ = currentUserId
        let conversation = try await getOrCreateTaskConversation(taskId: taskId)
        let latestPage = try await fetchMessagePage(conversationId: conversation.id, limit: 1)
        try await markConversationRead(conversationId: conversation.id, lastReadMessageId: latestPage.last?.id)
    }

    func markAllAsRead(conversationId: UUID, currentUserId: UUID) async throws {
        _ = currentUserId
        let latestPage = try await fetchMessagePage(conversationId: conversationId, limit: 1)
        try await markConversationRead(conversationId: conversationId, lastReadMessageId: latestPage.last?.id)
    }

    // MARK: - Unread Count

    func fetchUnreadCount(taskId: UUID, currentUserId: UUID) async throws -> Int {
        let conversation = try await getOrCreateTaskConversation(taskId: taskId)
        let conversations = try await fetchConversationList(userId: currentUserId)
        return conversations.first(where: { $0.conversationId == conversation.id })?.unreadCount ?? 0
    }

    // MARK: - Conversation List

    func fetchConversationList(userId: UUID) async throws -> [ConversationPreview] {
        let response = try await supabase
            .rpc(
                "get_conversation_list_v2",
                params: ConversationListParams(userId: userId, limit: 100)
            )
            .execute()

        return try decodeValue([ConversationPreview].self, from: response.data)
    }

    // MARK: - Conversations

    func findOrCreateConversation(userId1: UUID, userId2: UUID) async throws -> Conversation {
        _ = userId1
        let response = try await supabase
            .rpc(
                "get_or_create_direct_conversation_v2",
                params: DirectConversationParams(otherUserId: userId2)
            )
            .execute()

        return try decodeSingleRecord(Conversation.self, from: response.data, emptyMessage: "Conversation not found")
    }

    func getOrCreateTaskConversation(taskId: UUID) async throws -> Conversation {
        let response = try await supabase
            .rpc(
                "get_or_create_task_conversation_v2",
                params: TaskConversationParams(taskId: taskId)
            )
            .execute()

        return try decodeSingleRecord(Conversation.self, from: response.data, emptyMessage: "Task conversation not found")
    }

    // MARK: - Realtime Subscription

    func subscribeToMessages(taskId: UUID, onNew: @escaping (Message) -> Void) {
        Task {
            do {
                let conversation = try await getOrCreateTaskConversation(taskId: taskId)
                subscribeToMessages(conversationId: conversation.id, onNew: onNew)
            } catch {
                print("[MessageService] Failed to subscribe to task conversation: \(error)")
            }
        }
    }

    func subscribeToMessages(conversationId: UUID, onNew: @escaping (Message) -> Void) {
        Task {
            if let channel = realtimeChannel {
                await supabase.realtimeV2.removeChannel(channel)
                realtimeChannel = nil
            }

            let channel = supabase.realtimeV2.channel("messages:\(conversationId.uuidString)")
            realtimeChannel = channel

            let insertions = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages",
                filter: "conversation_id=eq.\(conversationId.uuidString)"
            )

            await channel.subscribe()

            for await insertion in insertions {
                do {
                    let message = try insertion.decodeRecord(as: Message.self, decoder: decoder)
                    await MainActor.run {
                        onNew(message)
                    }
                } catch {
                    print("[MessageService] Failed to decode realtime message: \(error)")
                }
            }
        }
    }

    func unsubscribe() {
        Task {
            if let channel = realtimeChannel {
                await supabase.realtimeV2.removeChannel(channel)
            }
            realtimeChannel = nil
        }
    }
}

// MARK: - Request / Response Bodies

private struct SendMessagePayload: Encodable {
    let body: String
    let taskId: String?
    let conversationId: String?
    let clientMessageId: String
    let messageType: String
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case body
        case taskId = "taskId"
        case conversationId = "conversationId"
        case clientMessageId = "clientMessageId"
        case messageType = "messageType"
        case metadata
    }
}

private struct SendMessageResponse: Decodable {
    let message: Message
    let notificationSent: Bool

    enum CodingKeys: String, CodingKey {
        case message
        case notificationSent = "notification_sent"
    }
}

private struct MessagePageParams: Encodable {
    let conversationId: UUID
    let beforeMessageId: UUID?
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case conversationId = "p_conversation_id"
        case beforeMessageId = "p_before_message_id"
        case limit = "p_limit"
    }
}

private struct MarkConversationReadParams: Encodable {
    let conversationId: UUID
    let lastReadMessageId: UUID?

    enum CodingKeys: String, CodingKey {
        case conversationId = "p_conversation_id"
        case lastReadMessageId = "p_last_read_message_id"
    }
}

private struct ConversationListParams: Encodable {
    let userId: UUID
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case userId = "p_user_id"
        case limit = "p_limit"
    }
}

private struct DirectConversationParams: Encodable {
    let otherUserId: UUID

    enum CodingKeys: String, CodingKey {
        case otherUserId = "p_other_user_id"
    }
}

private struct TaskConversationParams: Encodable {
    let taskId: UUID

    enum CodingKeys: String, CodingKey {
        case taskId = "p_task_id"
    }
}

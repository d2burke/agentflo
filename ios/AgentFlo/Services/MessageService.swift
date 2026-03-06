import Foundation
import Supabase

@Observable
final class MessageService {

    var messages: [Message] = []
    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Fetch Messages (task-based)

    func fetchMessages(taskId: UUID) async throws -> [Message] {
        try await supabase
            .from("messages")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    // MARK: - Fetch Messages (conversation-based)

    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        try await supabase
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    // MARK: - Send Message (task-based)
    // Routes through send-message edge function for push notification delivery

    @discardableResult
    func sendMessage(taskId: UUID, senderId: UUID, body: String) async throws -> Message {
        let payload = SendMessagePayload(body: body, taskId: taskId.uuidString, conversationId: nil)
        let bodyData = try JSONEncoder().encode(payload)

        let response: SendMessageResponse = try await supabase.functions.invoke(
            "send-message",
            options: .init(body: bodyData)
        )

        return response.message
    }

    // MARK: - Send Message (conversation-based)
    // Routes through send-message edge function for push notification delivery

    @discardableResult
    func sendMessage(conversationId: UUID, senderId: UUID, body: String) async throws -> Message {
        let payload = SendMessagePayload(body: body, taskId: nil, conversationId: conversationId.uuidString)
        let bodyData = try JSONEncoder().encode(payload)

        let response: SendMessageResponse = try await supabase.functions.invoke(
            "send-message",
            options: .init(body: bodyData)
        )

        return response.message
    }

    // MARK: - Mark as Read

    func markAsRead(messageId: UUID) async throws {
        try await supabase
            .from("messages")
            .update(["read_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: messageId.uuidString)
            .execute()
    }

    func markAllAsRead(taskId: UUID, currentUserId: UUID) async throws {
        try await supabase
            .from("messages")
            .update(["read_at": ISO8601DateFormatter().string(from: Date())])
            .eq("task_id", value: taskId.uuidString)
            .neq("sender_id", value: currentUserId.uuidString)
            .is("read_at", value: nil)
            .execute()
    }

    func markAllAsRead(conversationId: UUID, currentUserId: UUID) async throws {
        try await supabase
            .from("messages")
            .update(["read_at": ISO8601DateFormatter().string(from: Date())])
            .eq("conversation_id", value: conversationId.uuidString)
            .neq("sender_id", value: currentUserId.uuidString)
            .is("read_at", value: nil)
            .execute()
    }

    // MARK: - Unread Count

    func fetchUnreadCount(taskId: UUID, currentUserId: UUID) async throws -> Int {
        let messages: [Message] = try await supabase
            .from("messages")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .neq("sender_id", value: currentUserId.uuidString)
            .is("read_at", value: nil)
            .execute()
            .value
        return messages.count
    }

    // MARK: - Conversations

    func findOrCreateConversation(userId1: UUID, userId2: UUID) async throws -> Conversation {
        // Canonical ordering: smaller UUID is participant_1
        let p1 = min(userId1, userId2)
        let p2 = max(userId1, userId2)

        // Try to find existing conversation
        let existing: [Conversation] = try await supabase
            .from("conversations")
            .select()
            .eq("participant_1_id", value: p1.uuidString)
            .eq("participant_2_id", value: p2.uuidString)
            .execute()
            .value

        if let conversation = existing.first {
            return conversation
        }

        // Create new conversation
        return try await supabase
            .from("conversations")
            .insert(NewConversationBody(participant1Id: p1, participant2Id: p2))
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Realtime Subscription (task-based)

    func subscribeToMessages(taskId: UUID, onNew: @escaping (Message) -> Void) {
        let channel = supabase.realtimeV2.channel("messages:\(taskId.uuidString)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "task_id=eq.\(taskId.uuidString)"
        )

        Task {
            await channel.subscribe()
            for await insertion in insertions {
                do {
                    let message = try insertion.decodeRecord(as: Message.self, decoder: JSONDecoder())
                    await MainActor.run {
                        onNew(message)
                    }
                } catch {
                    print("[MessageService] Failed to decode realtime message: \(error)")
                }
            }
        }

        realtimeChannel = channel
    }

    // MARK: - Realtime Subscription (conversation-based)

    func subscribeToMessages(conversationId: UUID, onNew: @escaping (Message) -> Void) {
        let channel = supabase.realtimeV2.channel("conv-messages:\(conversationId.uuidString)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId.uuidString)"
        )

        Task {
            await channel.subscribe()
            for await insertion in insertions {
                do {
                    let message = try insertion.decodeRecord(as: Message.self, decoder: JSONDecoder())
                    await MainActor.run {
                        onNew(message)
                    }
                } catch {
                    print("[MessageService] Failed to decode realtime message: \(error)")
                }
            }
        }

        realtimeChannel = channel
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
}

private struct SendMessageResponse: Decodable {
    let message: Message
    let notificationSent: Bool

    enum CodingKeys: String, CodingKey {
        case message
        case notificationSent = "notification_sent"
    }
}

private struct NewConversationBody: Encodable {
    let participant1Id: UUID
    let participant2Id: UUID

    enum CodingKeys: String, CodingKey {
        case participant1Id = "participant_1_id"
        case participant2Id = "participant_2_id"
    }
}

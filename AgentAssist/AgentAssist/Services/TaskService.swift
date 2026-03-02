import Foundation
import Supabase

@Observable
final class TaskService {

    // MARK: - Fetch Tasks

    // Explicit column list — excludes property_point (PostGIS geography) which can't be decoded
    private static let taskColumns = "id,agent_id,runner_id,category,status,property_address,property_lat,property_lng,price,platform_fee,runner_payout,instructions,category_form_data,stripe_payment_intent_id,scheduled_at,posted_at,accepted_at,completed_at,cancelled_at,cancellation_reason,created_at,updated_at"

    func fetchTasks(forAgent agentId: UUID) async throws -> [AgentTask] {
        try await supabase
            .from("tasks")
            .select(Self.taskColumns)
            .eq("agent_id", value: agentId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchTasks(forRunner runnerId: UUID) async throws -> [AgentTask] {
        try await supabase
            .from("tasks")
            .select(Self.taskColumns)
            .eq("runner_id", value: runnerId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchAvailableTasks() async throws -> [AgentTask] {
        try await supabase
            .from("tasks")
            .select(Self.taskColumns)
            .eq("status", value: "posted")
            .order("posted_at", ascending: false)
            .execute()
            .value
    }

    func fetchTask(id: UUID) async throws -> AgentTask {
        try await supabase
            .from("tasks")
            .select(Self.taskColumns)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    // MARK: - Create Task

    func createDraft(
        agentId: UUID,
        category: String,
        address: String,
        price: Int,
        instructions: String?,
        scheduledAt: Date?
    ) async throws -> AgentTask {
        let body = CreateDraftBody(
            agentId: agentId,
            category: category,
            propertyAddress: address,
            price: price,
            status: "draft",
            instructions: instructions,
            scheduledAt: scheduledAt
        )

        return try await supabase
            .from("tasks")
            .insert(body)
            .select(Self.taskColumns)
            .single()
            .execute()
            .value
    }

    // MARK: - Edge Function Calls

    /// Refresh the session and return auth headers to ensure edge functions get a valid token.
    private func authHeaders() async throws -> [String: String] {
        let session = try await supabase.auth.refreshSession()
        return ["Authorization": "Bearer \(session.accessToken)"]
    }

    @discardableResult
    func postTask(taskId: UUID) async throws -> [String: AnyDecodable] {
        let headers = try await authHeaders()
        return try await supabase.functions
            .invoke(
                "post-task",
                options: .init(headers: headers, body: ["taskId": taskId.uuidString])
            )
    }

    func acceptRunner(applicationId: UUID) async throws {
        let headers = try await authHeaders()
        let _: [String: AnyDecodable] = try await supabase.functions
            .invoke(
                "accept-runner",
                options: .init(headers: headers, body: ["applicationId": applicationId.uuidString])
            )
    }

    func cancelTask(taskId: UUID, reason: String?) async throws {
        let headers = try await authHeaders()
        var body: [String: String] = ["taskId": taskId.uuidString]
        if let reason { body["reason"] = reason }

        let _: [String: AnyDecodable] = try await supabase.functions
            .invoke("cancel-task", options: .init(headers: headers, body: body))
    }

    func submitDeliverables(taskId: UUID, deliverables: [[String: String]]) async throws {
        let headers = try await authHeaders()
        let _: [String: AnyDecodable] = try await supabase.functions
            .invoke(
                "submit-deliverables",
                options: .init(headers: headers, body: SubmitDeliverablesBody(
                    taskId: taskId.uuidString,
                    deliverables: deliverables
                ))
            )
    }

    func approveAndPay(taskId: UUID) async throws {
        let headers = try await authHeaders()
        let _: [String: AnyDecodable] = try await supabase.functions
            .invoke(
                "approve-and-pay",
                options: .init(headers: headers, body: ["taskId": taskId.uuidString])
            )
    }

    func createSetupIntent() async throws -> SetupIntentResponse {
        let headers = try await authHeaders()
        return try await supabase.functions
            .invoke(
                "create-setup-intent",
                options: .init(headers: headers, body: [:] as [String: String])
            )
    }

    func createConnectLink() async throws -> ConnectLinkResponse {
        let headers = try await authHeaders()
        return try await supabase.functions
            .invoke(
                "create-connect-link",
                options: .init(headers: headers, body: [:] as [String: String])
            )
    }

    func updateTaskStatus(taskId: UUID, status: String) async throws {
        try await supabase
            .from("tasks")
            .update(["status": status])
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    // MARK: - User Profiles

    func fetchUserPublicProfile(userId: UUID) async throws -> PublicProfile {
        try await supabase
            .from("users")
            .select("id, full_name, avatar_url")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    // MARK: - Applications

    func fetchApplications(forTask taskId: UUID) async throws -> [TaskApplication] {
        try await supabase
            .from("task_applications")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func applyForTask(taskId: UUID, runnerId: UUID, message: String?) async throws {
        try await supabase.rpc(
            "accept_task",
            params: [
                "p_task_id": taskId.uuidString,
                "p_runner_id": runnerId.uuidString,
            ]
        ).execute()
    }
}

// Body for creating a task draft — uses proper types so JSON encodes correctly
private struct CreateDraftBody: Encodable {
    let agentId: UUID
    let category: String
    let propertyAddress: String
    let price: Int
    let status: String
    let instructions: String?
    let scheduledAt: Date?

    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case category
        case propertyAddress = "property_address"
        case price
        case status
        case instructions
        case scheduledAt = "scheduled_at"
    }
}

// Response from create-setup-intent edge function
struct SetupIntentResponse: Decodable {
    let setupIntent: String
    let ephemeralKey: String
    let customer: String
    let publishableKey: String
}

// Response from create-connect-link edge function
struct ConnectLinkResponse: Decodable {
    let url: String
    let accountId: String

    enum CodingKeys: String, CodingKey {
        case url
        case accountId = "account_id"
    }
}

// Body for submit-deliverables edge function
private struct SubmitDeliverablesBody: Encodable {
    let taskId: String
    let deliverables: [[String: String]]
}

// Helper for decoding arbitrary JSON from edge function responses
struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let double = try? container.decode(Double.self) { value = double }
        else { value = "" }
    }
}

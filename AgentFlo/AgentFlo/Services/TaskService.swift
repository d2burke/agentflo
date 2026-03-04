import Foundation
import Supabase

@Observable
final class TaskService {

    // MARK: - Fetch Tasks

    // Explicit column list — excludes property_point (PostGIS geography) which can't be decoded
    private static let taskColumns = "id,agent_id,runner_id,category,status,property_address,property_lat,property_lng,price,platform_fee,runner_payout,instructions,category_form_data,stripe_payment_intent_id,scheduled_at,posted_at,accepted_at,completed_at,cancelled_at,cancellation_reason,checked_in_at,checked_in_lat,checked_in_lng,checked_out_at,checked_out_lat,checked_out_lng,qr_code_token,created_at,updated_at"

    // Same columns + nested agent profile (for runner views)
    private static let taskColumnsWithAgent = "id,agent_id,runner_id,category,status,property_address,property_lat,property_lng,price,platform_fee,runner_payout,instructions,category_form_data,stripe_payment_intent_id,scheduled_at,posted_at,accepted_at,completed_at,cancelled_at,cancellation_reason,checked_in_at,checked_in_lat,checked_in_lng,checked_out_at,checked_out_lat,checked_out_lng,qr_code_token,created_at,updated_at,agent:users!agent_id(id,full_name,avatar_url)"

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
            .select(Self.taskColumnsWithAgent)
            .eq("runner_id", value: runnerId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchAvailableTasks() async throws -> [AgentTask] {
        try await supabase
            .from("tasks")
            .select(Self.taskColumnsWithAgent)
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

    func updateDraft(
        taskId: UUID,
        category: String,
        address: String,
        price: Int,
        instructions: String?,
        scheduledAt: Date?
    ) async throws {
        try await supabase
            .from("tasks")
            .update(UpdateDraftBody(
                category: category,
                propertyAddress: address,
                price: price,
                instructions: instructions,
                scheduledAt: scheduledAt
            ))
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    // MARK: - Edge Function Calls

    /// Refresh the session and return auth headers to ensure edge functions get a valid token.
    private func authHeaders() async throws -> [String: String] {
        let session = try await supabase.auth.refreshSession()
        return ["Authorization": "Bearer \(session.accessToken)"]
    }

    func postTask(taskId: UUID) async throws {
        let headers = try await authHeaders()
        try await supabase.functions
            .invoke(
                "post-task",
                options: .init(headers: headers, body: ["taskId": taskId.uuidString])
            )
    }

    func acceptRunner(applicationId: UUID) async throws {
        let headers = try await authHeaders()
        try await supabase.functions
            .invoke(
                "accept-runner",
                options: .init(headers: headers, body: ["applicationId": applicationId.uuidString])
            )
    }

    func cancelTask(taskId: UUID, reason: String?) async throws {
        let headers = try await authHeaders()
        var body: [String: String] = ["taskId": taskId.uuidString]
        if let reason { body["reason"] = reason }

        try await supabase.functions
            .invoke("cancel-task", options: .init(headers: headers, body: body))
    }

    func submitDeliverables(taskId: UUID, deliverables: [[String: String]]) async throws {
        let headers = try await authHeaders()
        try await supabase.functions
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
        try await supabase.functions
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

    func checkIn(taskId: UUID, lat: Double, lng: Double) async throws {
        let headers = try await authHeaders()
        try await supabase.functions
            .invoke(
                "check-in",
                options: .init(headers: headers, body: CheckInOutBody(
                    taskId: taskId.uuidString, lat: lat, lng: lng
                ))
            )
    }

    func checkOut(taskId: UUID, lat: Double, lng: Double) async throws {
        let headers = try await authHeaders()
        try await supabase.functions
            .invoke(
                "check-out",
                options: .init(headers: headers, body: CheckInOutBody(
                    taskId: taskId.uuidString, lat: lat, lng: lng
                ))
            )
    }

    func startTask(taskId: UUID) async throws {
        let headers = try await authHeaders()
        try await supabase.functions
            .invoke(
                "start-task",
                options: .init(headers: headers, body: ["taskId": taskId.uuidString])
            )
    }

    // MARK: - Deliverables

    func fetchDeliverables(taskId: UUID) async throws -> [Deliverable] {
        try await supabase
            .from("deliverables")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func updateTaskStatus(taskId: UUID, status: String) async throws {
        try await supabase
            .from("tasks")
            .update(["status": status])
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    // MARK: - Open House Visitors

    func setQRCodeToken(taskId: UUID, token: String) async throws {
        try await supabase
            .from("tasks")
            .update(["qr_code_token": token])
            .eq("id", value: taskId.uuidString)
            .execute()
    }

    func fetchVisitors(taskId: UUID) async throws -> [OpenHouseVisitor] {
        try await supabase
            .from("open_house_visitors")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Showing Reports

    func submitShowingReport(
        taskId: UUID, runnerId: UUID, buyerName: String, buyerInterest: BuyerInterest,
        questions: [[String: String]]?, propertyFeedback: String?, followUpNotes: String?, nextSteps: String?
    ) async throws {
        try await supabase
            .from("showing_reports")
            .insert(NewShowingReportBody(
                taskId: taskId, runnerId: runnerId, buyerName: buyerName,
                buyerInterest: buyerInterest.rawValue, questions: questions,
                propertyFeedback: propertyFeedback, followUpNotes: followUpNotes, nextSteps: nextSteps
            ))
            .execute()
    }

    func fetchShowingReport(taskId: UUID) async throws -> ShowingReport? {
        let results: [ShowingReport] = try await supabase
            .from("showing_reports")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .limit(1)
            .execute()
            .value
        return results.first
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

    func fetchPublicProfileFull(userId: UUID) async throws -> PublicProfileFull {
        try await supabase
            .from("public_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    // MARK: - Onboarding Checks

    func hasServiceAreas(runnerId: UUID) async throws -> Bool {
        struct IdRow: Decodable { let id: UUID }
        let results: [IdRow] = try await supabase
            .from("service_areas")
            .select("id")
            .eq("runner_id", value: runnerId.uuidString)
            .limit(1)
            .execute()
            .value
        return !results.isEmpty
    }

    func hasAvailability(runnerId: UUID) async throws -> Bool {
        struct IdRow: Decodable { let id: UUID }
        let results: [IdRow] = try await supabase
            .from("availability_schedules")
            .select("id")
            .eq("runner_id", value: runnerId.uuidString)
            .limit(1)
            .execute()
            .value
        return !results.isEmpty
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

    // MARK: - Portfolio

    func fetchPortfolioImages(runnerId: UUID) async throws -> [PortfolioImage] {
        try await supabase
            .from("portfolio_images")
            .select()
            .eq("runner_id", value: runnerId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func insertPortfolioImage(runnerId: UUID, imageUrl: String, caption: String?, sortOrder: Int) async throws -> PortfolioImage {
        try await supabase
            .from("portfolio_images")
            .insert(InsertPortfolioBody(runnerId: runnerId, imageUrl: imageUrl, caption: caption, sortOrder: sortOrder))
            .select()
            .single()
            .execute()
            .value
    }

    func deletePortfolioImage(id: UUID) async throws {
        try await supabase
            .from("portfolio_images")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updatePublicProfileSettings(userId: UUID, headline: String?, specialties: [String], profileSlug: String?, isEnabled: Bool) async throws {
        try await supabase
            .from("users")
            .update(PublicProfileUpdate(
                headline: headline,
                specialties: specialties,
                profileSlug: profileSlug,
                isPublicProfileEnabled: isEnabled
            ))
            .eq("id", value: userId.uuidString)
            .execute()
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

// Body for updating a draft task
private struct UpdateDraftBody: Encodable {
    let category: String
    let propertyAddress: String
    let price: Int
    let instructions: String?
    let scheduledAt: Date?

    enum CodingKeys: String, CodingKey {
        case category, price, instructions
        case propertyAddress = "property_address"
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

// Body for check-in / check-out edge functions — lat/lng must encode as numbers
struct CheckInOutBody: Encodable {
    let taskId: String
    let lat: Double
    let lng: Double
}

// Body for inserting a portfolio image
private struct InsertPortfolioBody: Encodable {
    let runnerId: UUID
    let imageUrl: String
    let caption: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case caption
        case runnerId = "runner_id"
        case imageUrl = "image_url"
        case sortOrder = "sort_order"
    }
}

// Body for updating public profile settings
private struct PublicProfileUpdate: Encodable {
    let headline: String?
    let specialties: [String]
    let profileSlug: String?
    let isPublicProfileEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case headline, specialties
        case profileSlug = "profile_slug"
        case isPublicProfileEnabled = "is_public_profile_enabled"
    }
}

// Body for submitting a showing report
private struct NewShowingReportBody: Encodable {
    let taskId: UUID
    let runnerId: UUID
    let buyerName: String
    let buyerInterest: String
    let questions: [[String: String]]?
    let propertyFeedback: String?
    let followUpNotes: String?
    let nextSteps: String?

    enum CodingKeys: String, CodingKey {
        case questions
        case taskId = "task_id"
        case runnerId = "runner_id"
        case buyerName = "buyer_name"
        case buyerInterest = "buyer_interest"
        case propertyFeedback = "property_feedback"
        case followUpNotes = "follow_up_notes"
        case nextSteps = "next_steps"
    }
}


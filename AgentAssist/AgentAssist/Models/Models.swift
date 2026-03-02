import Foundation

// MARK: - User

enum UserRole: String, Codable {
    case agent
    case runner
}

enum VettingStatus: String, Codable {
    case notStarted = "not_started"
    case pending
    case approved
    case rejected
    case expired
}

struct AppUser: Codable, Identifiable {
    let id: UUID
    let role: UserRole
    let email: String
    let fullName: String
    var phone: String?
    var avatarUrl: String?
    var brokerage: String?
    var licenseNumber: String?
    var licenseState: String?
    var bio: String?
    var vettingStatus: VettingStatus
    var onboardingCompletedSteps: [String]?
    var stripeCustomerId: String?
    var stripeConnectId: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role, email, phone, brokerage, bio
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case licenseNumber = "license_number"
        case licenseState = "license_state"
        case vettingStatus = "vetting_status"
        case onboardingCompletedSteps = "onboarding_completed_steps"
        case stripeCustomerId = "stripe_customer_id"
        case stripeConnectId = "stripe_connect_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Task

enum TaskStatus: String, Codable {
    case draft
    case posted
    case accepted
    case inProgress = "in_progress"
    case deliverablesSubmitted = "deliverables_submitted"
    case revisionRequested = "revision_requested"
    case completed
    case cancelled
}

struct AgentTask: Codable, Identifiable {
    let id: UUID
    let agentId: UUID
    var runnerId: UUID?
    let category: String
    var status: TaskStatus
    let propertyAddress: String
    var propertyLat: Double?
    var propertyLng: Double?
    let price: Int // cents
    var platformFee: Int?
    var runnerPayout: Int?
    var instructions: String?
    var categoryFormData: [String: String]?
    var stripePaymentIntentId: String?
    var scheduledAt: Date?
    var postedAt: Date?
    var acceptedAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
    var cancellationReason: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, category, status, price, instructions
        case agentId = "agent_id"
        case runnerId = "runner_id"
        case propertyAddress = "property_address"
        case propertyLat = "property_lat"
        case propertyLng = "property_lng"
        case platformFee = "platform_fee"
        case runnerPayout = "runner_payout"
        case categoryFormData = "category_form_data"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case scheduledAt = "scheduled_at"
        case postedAt = "posted_at"
        case acceptedAt = "accepted_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
        case cancellationReason = "cancellation_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        agentId = try c.decode(UUID.self, forKey: .agentId)
        runnerId = try c.decodeIfPresent(UUID.self, forKey: .runnerId)
        category = try c.decode(String.self, forKey: .category)
        status = try c.decode(TaskStatus.self, forKey: .status)
        propertyAddress = try c.decode(String.self, forKey: .propertyAddress)
        propertyLat = try c.decodeIfPresent(Double.self, forKey: .propertyLat)
        propertyLng = try c.decodeIfPresent(Double.self, forKey: .propertyLng)
        price = try c.decode(Int.self, forKey: .price)
        platformFee = try c.decodeIfPresent(Int.self, forKey: .platformFee)
        runnerPayout = try c.decodeIfPresent(Int.self, forKey: .runnerPayout)
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
        // categoryFormData may be {} or null — gracefully decode
        categoryFormData = try? c.decodeIfPresent([String: String].self, forKey: .categoryFormData)
        stripePaymentIntentId = try c.decodeIfPresent(String.self, forKey: .stripePaymentIntentId)
        scheduledAt = try c.decodeIfPresent(Date.self, forKey: .scheduledAt)
        postedAt = try c.decodeIfPresent(Date.self, forKey: .postedAt)
        acceptedAt = try c.decodeIfPresent(Date.self, forKey: .acceptedAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        cancelledAt = try c.decodeIfPresent(Date.self, forKey: .cancelledAt)
        cancellationReason = try c.decodeIfPresent(String.self, forKey: .cancellationReason)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var formattedPrice: String {
        let dollars = Double(price) / 100.0
        return "$\(String(format: "%.0f", dollars))"
    }

    var formattedPayout: String {
        guard let payout = runnerPayout else { return formattedPrice }
        let dollars = Double(payout) / 100.0
        return "$\(String(format: "%.0f", dollars))"
    }
}

// MARK: - Task Application

enum ApplicationStatus: String, Codable {
    case pending
    case accepted
    case declined
    case withdrawn
}

struct TaskApplication: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let runnerId: UUID
    var status: ApplicationStatus
    var message: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, message
        case taskId = "task_id"
        case runnerId = "runner_id"
        case createdAt = "created_at"
    }
}

// MARK: - Public Profile (limited user info for display)

struct PublicProfile: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Deliverable

enum DeliverableType: String, Codable {
    case photo
    case document
    case report
    case checklist
}

struct Deliverable: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let runnerId: UUID
    let type: DeliverableType
    let fileUrl: String
    var thumbnailUrl: String?
    var title: String?
    var notes: String?
    var sortOrder: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, notes
        case taskId = "task_id"
        case runnerId = "runner_id"
        case fileUrl = "file_url"
        case thumbnailUrl = "thumbnail_url"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

// MARK: - Message

struct Message: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let senderId: UUID
    let body: String
    var readAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case taskId = "task_id"
        case senderId = "sender_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

// MARK: - Review

struct Review: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let reviewerId: UUID
    let revieweeId: UUID
    let rating: Int
    var comment: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, rating, comment
        case taskId = "task_id"
        case reviewerId = "reviewer_id"
        case revieweeId = "reviewee_id"
        case createdAt = "created_at"
    }
}

// MARK: - Notification

struct AppNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: String
    let title: String
    let body: String
    var data: [String: String]?
    var readAt: Date?
    var pushSentAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, data
        case userId = "user_id"
        case readAt = "read_at"
        case pushSentAt = "push_sent_at"
        case createdAt = "created_at"
    }

    var isRead: Bool { readAt != nil }
}

// MARK: - Preview Helpers

#if DEBUG
import SwiftUI

extension AgentTask {
    init(
        id: UUID = UUID(),
        agentId: UUID = UUID(),
        runnerId: UUID? = nil,
        category: String = "Photography",
        status: TaskStatus = .posted,
        propertyAddress: String = "123 Main St, Austin, TX 78701",
        propertyLat: Double? = nil,
        propertyLng: Double? = nil,
        price: Int = 15000,
        platformFee: Int? = nil,
        runnerPayout: Int? = nil,
        instructions: String? = nil,
        categoryFormData: [String: String]? = nil,
        stripePaymentIntentId: String? = nil,
        scheduledAt: Date? = nil,
        postedAt: Date? = nil,
        acceptedAt: Date? = nil,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil,
        cancellationReason: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.agentId = agentId
        self.runnerId = runnerId
        self.category = category
        self.status = status
        self.propertyAddress = propertyAddress
        self.propertyLat = propertyLat
        self.propertyLng = propertyLng
        self.price = price
        self.platformFee = platformFee
        self.runnerPayout = runnerPayout
        self.instructions = instructions
        self.categoryFormData = categoryFormData
        self.stripePaymentIntentId = stripePaymentIntentId
        self.scheduledAt = scheduledAt
        self.postedAt = postedAt
        self.acceptedAt = acceptedAt
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
        self.cancellationReason = cancellationReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let preview = AgentTask(
        category: "Photography",
        status: .posted,
        propertyAddress: "1234 Elm Street, Austin, TX 78701",
        price: 15000,
        instructions: "Please take wide-angle shots of all rooms.",
        scheduledAt: Calendar.current.date(byAdding: .day, value: 2, to: .now)
    )

    static let previewList: [AgentTask] = [
        AgentTask(category: "Photography", status: .posted, propertyAddress: "1234 Elm St, Austin, TX 78701", price: 15000, scheduledAt: Calendar.current.date(byAdding: .day, value: 2, to: .now)),
        AgentTask(category: "Showing", status: .inProgress, propertyAddress: "567 Oak Ave, Dallas, TX 75201", price: 7500, runnerPayout: 6375, scheduledAt: Calendar.current.date(byAdding: .day, value: 1, to: .now)),
        AgentTask(category: "Staging", status: .completed, propertyAddress: "890 Pine Rd, Houston, TX 77001", price: 25000, platformFee: 5000, runnerPayout: 20000, completedAt: .now),
        AgentTask(category: "Open House", status: .accepted, propertyAddress: "321 Maple Dr, San Antonio, TX 78201", price: 10000, scheduledAt: Calendar.current.date(byAdding: .day, value: 5, to: .now)),
    ]
}

extension AppUser {
    static let previewAgent = AppUser(
        id: UUID(),
        role: .agent,
        email: "jane@example.com",
        fullName: "Jane Smith",
        phone: "(512) 555-1234",
        avatarUrl: nil,
        brokerage: "Compass",
        licenseNumber: "12345678",
        licenseState: "TX",
        bio: "Top producing agent in Austin",
        vettingStatus: .approved,
        onboardingCompletedSteps: nil,
        stripeCustomerId: "cus_test123",
        stripeConnectId: nil,
        createdAt: Calendar.current.date(byAdding: .month, value: -3, to: .now),
        updatedAt: .now
    )

    static let previewRunner = AppUser(
        id: UUID(),
        role: .runner,
        email: "john@example.com",
        fullName: "John Doe",
        phone: "(214) 555-9876",
        avatarUrl: nil,
        brokerage: nil,
        licenseNumber: nil,
        licenseState: nil,
        bio: "Professional photographer and showing assistant",
        vettingStatus: .approved,
        onboardingCompletedSteps: nil,
        stripeCustomerId: nil,
        stripeConnectId: "acct_test456",
        createdAt: Calendar.current.date(byAdding: .month, value: -1, to: .now),
        updatedAt: .now
    )
}

extension AppNotification {
    static let previewList: [AppNotification] = [
        AppNotification(id: UUID(), userId: UUID(), type: "task_update", title: "Task Accepted", body: "A runner has accepted your photography task.", data: nil, readAt: nil, pushSentAt: nil, createdAt: .now),
        AppNotification(id: UUID(), userId: UUID(), type: "payment", title: "Payment Received", body: "You received $150.00 for staging task.", data: nil, readAt: .now, pushSentAt: nil, createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: .now)),
        AppNotification(id: UUID(), userId: UUID(), type: "message", title: "New Message", body: "Jane sent you a message about the showing.", data: nil, readAt: nil, pushSentAt: nil, createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: .now)),
    ]
}

extension AppState {
    static var preview: AppState {
        let state = AppState()
        state.authService.currentUser = .previewAgent
        state.authService.isLoading = false
        return state
    }

    static var previewRunner: AppState {
        let state = AppState()
        state.authService.currentUser = .previewRunner
        state.authService.isLoading = false
        return state
    }
}
#endif

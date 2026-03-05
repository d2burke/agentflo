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
    var headline: String?
    var specialties: [String]?
    var profileSlug: String?
    var isPublicProfileEnabled: Bool?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role, email, phone, brokerage, bio, headline, specialties
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case licenseNumber = "license_number"
        case licenseState = "license_state"
        case vettingStatus = "vetting_status"
        case onboardingCompletedSteps = "onboarding_completed_steps"
        case stripeCustomerId = "stripe_customer_id"
        case stripeConnectId = "stripe_connect_id"
        case profileSlug = "profile_slug"
        case isPublicProfileEnabled = "is_public_profile_enabled"
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
    var checkedInAt: Date?
    var checkedInLat: Double?
    var checkedInLng: Double?
    var checkedOutAt: Date?
    var checkedOutLat: Double?
    var checkedOutLng: Double?
    var qrCodeToken: String?
    let createdAt: Date?
    var updatedAt: Date?
    var agentProfile: PublicProfile?

    enum CodingKeys: String, CodingKey {
        case id, category, status, price, instructions
        case agentId = "agent_id"
        case agentProfile = "agent"
        case qrCodeToken = "qr_code_token"
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
        case checkedInAt = "checked_in_at"
        case checkedInLat = "checked_in_lat"
        case checkedInLng = "checked_in_lng"
        case checkedOutAt = "checked_out_at"
        case checkedOutLat = "checked_out_lat"
        case checkedOutLng = "checked_out_lng"
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
        checkedInAt = try c.decodeIfPresent(Date.self, forKey: .checkedInAt)
        checkedInLat = try c.decodeIfPresent(Double.self, forKey: .checkedInLat)
        checkedInLng = try c.decodeIfPresent(Double.self, forKey: .checkedInLng)
        checkedOutAt = try c.decodeIfPresent(Date.self, forKey: .checkedOutAt)
        checkedOutLat = try c.decodeIfPresent(Double.self, forKey: .checkedOutLat)
        checkedOutLng = try c.decodeIfPresent(Double.self, forKey: .checkedOutLng)
        qrCodeToken = try c.decodeIfPresent(String.self, forKey: .qrCodeToken)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        agentProfile = try? c.decodeIfPresent(PublicProfile.self, forKey: .agentProfile)
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

    var taskCategory: TaskCategory? {
        TaskCategory(rawValue: category.lowercased().replacingOccurrences(of: " ", with: "_"))
    }

    var isCheckInCheckOut: Bool {
        taskCategory?.isCheckInCheckOut ?? false
    }
}

// MARK: - Task Category

enum TaskCategory: String, CaseIterable {
    case photography
    case showing
    case staging
    case openHouse = "open_house"
    case inspection

    var displayName: String {
        switch self {
        case .photography: "Photography"
        case .showing: "Showing"
        case .staging: "Staging"
        case .openHouse: "Open House"
        case .inspection: "Inspection"
        }
    }

    var isCheckInCheckOut: Bool {
        switch self {
        case .showing, .staging, .openHouse: true
        default: false
        }
    }

    var categoryDescription: String {
        switch self {
        case .photography: "Professional listing photos"
        case .showing: "Buyer or inspector showing"
        case .staging: "Furniture staging & setup"
        case .openHouse: "Host an open house event"
        case .inspection: "Property inspection report"
        }
    }

    var suggestedPriceRange: String {
        switch self {
        case .photography: "$100–$300"
        case .showing: "$50–$100"
        case .staging: "$200–$400"
        case .openHouse: "$75–$150"
        case .inspection: "$75–$200"
        }
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

// MARK: - Public Profile Full (from public_profiles view)

struct PublicProfileFull: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let avatarUrl: String?
    let role: UserRole
    let brokerage: String?
    let bio: String?
    let headline: String?
    let specialties: [String]?
    let profileSlug: String?
    let isPublicProfileEnabled: Bool?
    let isVerified: Bool
    let avgRating: Double?
    let reviewCount: Int
    let completedTasks: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role, brokerage, bio, headline, specialties
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case profileSlug = "profile_slug"
        case isPublicProfileEnabled = "is_public_profile_enabled"
        case isVerified = "is_verified"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case completedTasks = "completed_tasks"
        case createdAt = "created_at"
    }
}

// MARK: - Conversation (for direct messaging)

struct Conversation: Codable, Identifiable {
    let id: UUID
    let participant1Id: UUID
    let participant2Id: UUID
    var taskId: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case participant1Id = "participant_1_id"
        case participant2Id = "participant_2_id"
        case taskId = "task_id"
        case createdAt = "created_at"
    }
}

// MARK: - Portfolio Image

struct PortfolioImage: Codable, Identifiable {
    let id: UUID
    let runnerId: UUID
    let imageUrl: String
    var caption: String?
    var sortOrder: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, caption
        case runnerId = "runner_id"
        case imageUrl = "image_url"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
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
    let fileUrl: String?
    var thumbnailUrl: String?
    var title: String?
    var notes: String?
    var sortOrder: Int?
    var room: String?
    var photoType: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, notes, room
        case taskId = "task_id"
        case runnerId = "runner_id"
        case fileUrl = "file_url"
        case thumbnailUrl = "thumbnail_url"
        case sortOrder = "sort_order"
        case photoType = "photo_type"
        case createdAt = "created_at"
    }
}

// MARK: - Message

struct Message: Codable, Identifiable {
    let id: UUID
    let taskId: UUID?
    let conversationId: UUID?
    let senderId: UUID
    let body: String
    var readAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case taskId = "task_id"
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

// MARK: - Open House Visitor

struct OpenHouseVisitor: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let visitorName: String
    var email: String?
    var phone: String?
    let interestLevel: String
    var preApproved: Bool
    var agentRepresented: Bool
    var representingAgentName: String?
    var notes: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, phone, notes
        case taskId = "task_id"
        case visitorName = "visitor_name"
        case interestLevel = "interest_level"
        case preApproved = "pre_approved"
        case agentRepresented = "agent_represented"
        case representingAgentName = "representing_agent_name"
        case createdAt = "created_at"
    }

    var interestDisplayName: String {
        switch interestLevel {
        case "just_looking": "Just Looking"
        case "interested": "Interested"
        case "very_interested": "Very Interested"
        default: interestLevel.capitalized
        }
    }
}

// MARK: - Showing Report

enum BuyerInterest: String, Codable, CaseIterable {
    case notInterested = "not_interested"
    case somewhatInterested = "somewhat_interested"
    case veryInterested = "very_interested"
    case likelyOffer = "likely_offer"

    var displayName: String {
        switch self {
        case .notInterested: "Not Interested"
        case .somewhatInterested: "Somewhat Interested"
        case .veryInterested: "Very Interested"
        case .likelyOffer: "Likely Offer"
        }
    }
}

struct ShowingReport: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let runnerId: UUID
    let buyerName: String
    let buyerInterest: BuyerInterest
    var questions: [[String: String]]?
    var propertyFeedback: String?
    var followUpNotes: String?
    var nextSteps: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, questions
        case taskId = "task_id"
        case runnerId = "runner_id"
        case buyerName = "buyer_name"
        case buyerInterest = "buyer_interest"
        case propertyFeedback = "property_feedback"
        case followUpNotes = "follow_up_notes"
        case nextSteps = "next_steps"
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
        checkedInAt: Date? = nil,
        checkedInLat: Double? = nil,
        checkedInLng: Double? = nil,
        checkedOutAt: Date? = nil,
        checkedOutLat: Double? = nil,
        checkedOutLng: Double? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        agentProfile: PublicProfile? = nil,
        qrCodeToken: String? = nil
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
        self.checkedInAt = checkedInAt
        self.checkedInLat = checkedInLat
        self.checkedInLng = checkedInLng
        self.checkedOutAt = checkedOutAt
        self.checkedOutLat = checkedOutLat
        self.checkedOutLng = checkedOutLng
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.agentProfile = agentProfile
        self.qrCodeToken = qrCodeToken
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
        headline: nil,
        specialties: nil,
        profileSlug: nil,
        isPublicProfileEnabled: nil,
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
        headline: "Real estate photography specialist",
        specialties: ["photography", "inspection"],
        profileSlug: "john-doe",
        isPublicProfileEnabled: true,
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

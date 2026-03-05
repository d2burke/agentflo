import XCTest
@testable import AgentFlo

final class ModelsTests: XCTestCase {

    // MARK: - JSON Decoder Setup

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Supabase returns ISO8601 with fractional seconds
            let formatters: [ISO8601DateFormatter] = {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                return [f1, f2]
            }()
            for fmt in formatters {
                if let date = fmt.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return d
    }

    // MARK: - AgentTask Decoding

    func testDecodeMinimalTask() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "agent_id": "22222222-2222-2222-2222-222222222222",
            "category": "Photography",
            "status": "draft",
            "property_address": "123 Main St, Austin TX",
            "price": 15000,
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let task = try decoder.decode(AgentTask.self, from: json)

        XCTAssertEqual(task.id.uuidString.lowercased(), "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(task.category, "Photography")
        XCTAssertEqual(task.status, .draft)
        XCTAssertEqual(task.propertyAddress, "123 Main St, Austin TX")
        XCTAssertEqual(task.price, 15000)
        XCTAssertNil(task.runnerId)
        XCTAssertNil(task.instructions)
        XCTAssertNil(task.scheduledAt)
        XCTAssertNil(task.checkedInAt)
        XCTAssertNil(task.checkedOutAt)
    }

    func testDecodeFullTask() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "agent_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "category": "Showing",
            "status": "in_progress",
            "property_address": "456 Oak Ave, Dallas TX",
            "property_lat": 32.7767,
            "property_lng": -96.7970,
            "price": 7500,
            "platform_fee": 1125,
            "runner_payout": 7500,
            "instructions": "Meet at front door",
            "category_form_data": {"key": "value"},
            "stripe_payment_intent_id": "pi_test123",
            "scheduled_at": "2024-02-01T14:00:00Z",
            "posted_at": "2024-01-15T10:00:00Z",
            "accepted_at": "2024-01-16T08:00:00Z",
            "completed_at": null,
            "cancelled_at": null,
            "cancellation_reason": null,
            "checked_in_at": "2024-02-01T14:05:00Z",
            "checked_in_lat": 32.7767,
            "checked_in_lng": -96.7970,
            "checked_out_at": null,
            "checked_out_lat": null,
            "checked_out_lng": null,
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-16T08:00:00Z"
        }
        """.data(using: .utf8)!

        let task = try decoder.decode(AgentTask.self, from: json)

        XCTAssertEqual(task.runnerId?.uuidString.lowercased(), "33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(task.status, .inProgress)
        XCTAssertEqual(task.platformFee, 1125)
        XCTAssertEqual(task.runnerPayout, 7500)
        XCTAssertEqual(task.instructions, "Meet at front door")
        XCTAssertNotNil(task.checkedInAt)
        XCTAssertEqual(task.checkedInLat ?? 0, 32.7767, accuracy: 0.0001)
        XCTAssertNil(task.checkedOutAt)
    }

    func testDecodeAllStatuses() throws {
        let statuses = [
            ("draft", TaskStatus.draft),
            ("posted", TaskStatus.posted),
            ("accepted", TaskStatus.accepted),
            ("in_progress", TaskStatus.inProgress),
            ("deliverables_submitted", TaskStatus.deliverablesSubmitted),
            ("revision_requested", TaskStatus.revisionRequested),
            ("completed", TaskStatus.completed),
            ("cancelled", TaskStatus.cancelled),
        ]

        for (raw, expected) in statuses {
            let json = """
            {
                "id": "11111111-1111-1111-1111-111111111111",
                "agent_id": "22222222-2222-2222-2222-222222222222",
                "category": "Photography",
                "status": "\(raw)",
                "property_address": "123 Main St",
                "price": 10000,
                "created_at": "2024-01-15T10:00:00Z",
                "updated_at": "2024-01-15T10:00:00Z"
            }
            """.data(using: .utf8)!

            let task = try decoder.decode(AgentTask.self, from: json)
            XCTAssertEqual(task.status, expected, "Failed for status '\(raw)'")
        }
    }

    // MARK: - Formatted Price

    func testFormattedPrice() {
        let task = AgentTask(price: 15000)
        XCTAssertEqual(task.formattedPrice, "$150")
    }

    func testFormattedPriceSmallAmount() {
        let task = AgentTask(price: 99)
        XCTAssertEqual(task.formattedPrice, "$1")
    }

    func testFormattedPayoutFallsBackToPrice() {
        let task = AgentTask(price: 10000, runnerPayout: nil)
        XCTAssertEqual(task.formattedPayout, "$100")
    }

    func testFormattedPayoutUsesRunnerPayout() {
        let task = AgentTask(price: 10000, runnerPayout: 8500)
        XCTAssertEqual(task.formattedPayout, "$85")
    }

    // MARK: - Deliverable Decoding

    func testDecodeDeliverableWithFileUrl() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "type": "photo",
            "file_url": "task123/photo_0.jpg",
            "title": "Living Room",
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let d = try decoder.decode(Deliverable.self, from: json)
        XCTAssertEqual(d.type, .photo)
        XCTAssertEqual(d.fileUrl, "task123/photo_0.jpg")
        XCTAssertEqual(d.title, "Living Room")
    }

    func testDecodeDeliverableWithoutFileUrl() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "type": "checklist",
            "file_url": null,
            "notes": "Check-in: 2024-01-15T14:05:00Z",
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let d = try decoder.decode(Deliverable.self, from: json)
        XCTAssertEqual(d.type, .checklist)
        XCTAssertNil(d.fileUrl)
        XCTAssertNotNil(d.notes)
    }

    // MARK: - AppNotification

    func testDecodeNotification() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "type": "task_update",
            "title": "Task Accepted",
            "body": "A runner accepted your task.",
            "data": {"task_id": "33333333-3333-3333-3333-333333333333"},
            "read_at": null,
            "push_sent_at": null,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let n = try decoder.decode(AppNotification.self, from: json)
        XCTAssertEqual(n.type, "task_update")
        XCTAssertFalse(n.isRead)
        XCTAssertEqual(n.data?["task_id"], "33333333-3333-3333-3333-333333333333")
    }

    func testNotificationIsRead() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "type": "payment",
            "title": "Payment",
            "body": "Received",
            "data": null,
            "read_at": "2024-01-15T12:00:00Z",
            "push_sent_at": null,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let n = try decoder.decode(AppNotification.self, from: json)
        XCTAssertTrue(n.isRead)
    }

    // MARK: - Task with Agent Profile (PostgREST nested select)

    func testDecodeTaskWithAgentProfile() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "agent_id": "22222222-2222-2222-2222-222222222222",
            "category": "Photography",
            "status": "posted",
            "property_address": "123 Main St",
            "price": 15000,
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z",
            "agent": {
                "id": "22222222-2222-2222-2222-222222222222",
                "full_name": "Jane Smith",
                "avatar_url": "avatars/jane.jpg"
            }
        }
        """.data(using: .utf8)!

        let task = try decoder.decode(AgentTask.self, from: json)
        XCTAssertNotNil(task.agentProfile)
        XCTAssertEqual(task.agentProfile?.fullName, "Jane Smith")
        XCTAssertEqual(task.agentProfile?.avatarUrl, "avatars/jane.jpg")
    }

    func testDecodeTaskWithoutAgentProfile() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "agent_id": "22222222-2222-2222-2222-222222222222",
            "category": "Photography",
            "status": "draft",
            "property_address": "123 Main St",
            "price": 15000,
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let task = try decoder.decode(AgentTask.self, from: json)
        XCTAssertNil(task.agentProfile, "Agent profile should be nil when not included in response")
    }

    // MARK: - Message Decoding

    func testDecodeMessage() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "sender_id": "33333333-3333-3333-3333-333333333333",
            "body": "Hello, I have a question about the property.",
            "read_at": null,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let m = try decoder.decode(Message.self, from: json)
        XCTAssertEqual(m.body, "Hello, I have a question about the property.")
        XCTAssertNil(m.readAt)
        XCTAssertNotNil(m.createdAt)
    }

    func testDecodeMessageWithReadAt() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "sender_id": "33333333-3333-3333-3333-333333333333",
            "body": "Got it, thanks!",
            "read_at": "2024-01-15T12:00:00Z",
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let m = try decoder.decode(Message.self, from: json)
        XCTAssertNotNil(m.readAt, "read_at should be decoded when present")
    }

    // MARK: - Platform Fee Calculation

    func testPlatformFeeCalculation() {
        // Simulates the 15% agent-pays fee from accept_task RPC
        // Agent pays: price + fee. Runner gets: price (full amount).
        let price = 15000 // cents
        let feeRate = 0.15
        let fee = Int((Double(price) * feeRate).rounded())
        let payout = price // runner gets full price

        XCTAssertEqual(fee, 2250)
        XCTAssertEqual(payout, 15000)
        XCTAssertEqual(price + fee, 17250, "Agent total = price + fee")
    }

    func testFormattedPayoutWithFees() {
        // Agent-pays model: runner_payout = price
        let task = AgentTask(price: 15000, platformFee: 2250, runnerPayout: 15000)
        XCTAssertEqual(task.formattedPayout, "$150") // runner gets full $150
        XCTAssertEqual(task.formattedPrice, "$150")
    }

    // MARK: - AppUser Stripe Fields

    func testAppUserStripeConnectIdDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "role": "runner",
            "email": "runner@example.com",
            "full_name": "Test Runner",
            "vetting_status": "approved",
            "stripe_connect_id": "acct_abc123",
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try decoder.decode(AppUser.self, from: json)
        XCTAssertEqual(user.stripeConnectId, "acct_abc123")
        XCTAssertEqual(user.role, .runner)
        XCTAssertNil(user.stripeCustomerId)
    }

    func testAppUserWithoutStripeConnect() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "role": "runner",
            "email": "runner@example.com",
            "full_name": "Test Runner",
            "vetting_status": "not_started",
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try decoder.decode(AppUser.self, from: json)
        XCTAssertNil(user.stripeConnectId,
            "Runner without Stripe Connect should have nil stripeConnectId")
    }

    func testAppUserAgentStripeCustomer() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "role": "agent",
            "email": "agent@example.com",
            "full_name": "Test Agent",
            "vetting_status": "approved",
            "stripe_customer_id": "cus_xyz789",
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try decoder.decode(AppUser.self, from: json)
        XCTAssertEqual(user.stripeCustomerId, "cus_xyz789")
        XCTAssertEqual(user.role, .agent)
        XCTAssertNil(user.stripeConnectId)
    }

    // MARK: - ConnectLinkResponse

    func testConnectLinkResponseDecoding() throws {
        let json = """
        {
            "url": "https://connect.stripe.com/setup/e/acct_123/abc",
            "account_id": "acct_123"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ConnectLinkResponse.self, from: json)
        XCTAssertEqual(response.url, "https://connect.stripe.com/setup/e/acct_123/abc")
        XCTAssertEqual(response.accountId, "acct_123")
    }

    // MARK: - Preview Helpers

    func testPreviewTaskInitializer() {
        let task = AgentTask.preview
        XCTAssertEqual(task.category, "Photography")
        XCTAssertEqual(task.status, .posted)
        XCTAssertEqual(task.price, 15000)
        XCTAssertNil(task.checkedInAt)
    }

    func testPreviewListHasMultipleCategories() {
        let categories = Set(AgentTask.previewList.map(\.category))
        XCTAssertTrue(categories.count >= 3, "Preview list should have multiple categories")
    }

    // MARK: - PublicProfileFull Decoding

    func testPublicProfileFullDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "full_name": "Jane Smith",
            "avatar_url": "avatars/jane.jpg",
            "role": "runner",
            "brokerage": "Compass",
            "headline": "Expert photographer",
            "specialties": ["photography", "inspection"],
            "profile_slug": "jane-smith",
            "is_public_profile_enabled": true,
            "is_verified": true,
            "avg_rating": 4.8,
            "review_count": 15,
            "completed_tasks": 42
        }
        """.data(using: .utf8)!

        let p = try decoder.decode(PublicProfileFull.self, from: json)
        XCTAssertEqual(p.fullName, "Jane Smith")
        XCTAssertEqual(p.role, .runner)
        XCTAssertEqual(p.headline, "Expert photographer")
        XCTAssertEqual(p.specialties, ["photography", "inspection"])
        XCTAssertEqual(p.profileSlug, "jane-smith")
        XCTAssertTrue(p.isVerified)
        XCTAssertEqual(p.avgRating ?? 0, 4.8, accuracy: 0.01)
        XCTAssertEqual(p.reviewCount, 15)
        XCTAssertEqual(p.completedTasks, 42)
    }

    func testPublicProfileFullMinimalDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "full_name": "John Doe",
            "avatar_url": null,
            "role": "agent",
            "brokerage": null,
            "headline": null,
            "specialties": null,
            "profile_slug": null,
            "is_public_profile_enabled": false,
            "is_verified": false,
            "avg_rating": null,
            "review_count": 0,
            "completed_tasks": 0
        }
        """.data(using: .utf8)!

        let p = try decoder.decode(PublicProfileFull.self, from: json)
        XCTAssertEqual(p.fullName, "John Doe")
        XCTAssertNil(p.avatarUrl)
        XCTAssertNil(p.headline)
        XCTAssertNil(p.avgRating)
        XCTAssertFalse(p.isVerified)
        XCTAssertEqual(p.completedTasks, 0)
    }

    // MARK: - Conversation Decoding

    func testConversationDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "participant_1_id": "22222222-2222-2222-2222-222222222222",
            "participant_2_id": "33333333-3333-3333-3333-333333333333",
            "task_id": null,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let c = try decoder.decode(Conversation.self, from: json)
        XCTAssertEqual(c.participant1Id.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(c.participant2Id.uuidString.lowercased(), "33333333-3333-3333-3333-333333333333")
        XCTAssertNil(c.taskId)
    }

    func testConversationWithTaskDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "participant_1_id": "22222222-2222-2222-2222-222222222222",
            "participant_2_id": "33333333-3333-3333-3333-333333333333",
            "task_id": "44444444-4444-4444-4444-444444444444",
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let c = try decoder.decode(Conversation.self, from: json)
        XCTAssertNotNil(c.taskId)
        XCTAssertEqual(c.taskId?.uuidString.lowercased(), "44444444-4444-4444-4444-444444444444")
    }

    // MARK: - Message with Conversation ID

    func testDecodeMessageWithConversationId() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": null,
            "conversation_id": "22222222-2222-2222-2222-222222222222",
            "sender_id": "33333333-3333-3333-3333-333333333333",
            "body": "Direct message",
            "read_at": null,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let m = try decoder.decode(Message.self, from: json)
        XCTAssertNil(m.taskId)
        XCTAssertNotNil(m.conversationId)
        XCTAssertEqual(m.body, "Direct message")
    }

    // MARK: - BuyerInterest Enum

    func testBuyerInterestAllCases() {
        let cases = BuyerInterest.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertEqual(BuyerInterest.notInterested.rawValue, "not_interested")
        XCTAssertEqual(BuyerInterest.somewhatInterested.rawValue, "somewhat_interested")
        XCTAssertEqual(BuyerInterest.veryInterested.rawValue, "very_interested")
        XCTAssertEqual(BuyerInterest.likelyOffer.rawValue, "likely_offer")
    }

    // MARK: - ShowingReport Decoding

    func testShowingReportDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "buyer_name": "John Buyer",
            "buyer_interest": "very_interested",
            "questions": [{"question": "How old is the roof?"}],
            "property_feedback": "Nice layout",
            "follow_up_notes": "Wants a second showing",
            "next_steps": "Schedule follow-up",
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let r = try decoder.decode(ShowingReport.self, from: json)
        XCTAssertEqual(r.buyerName, "John Buyer")
        XCTAssertEqual(r.buyerInterest, .veryInterested)
        XCTAssertEqual(r.propertyFeedback, "Nice layout")
        XCTAssertNotNil(r.questions)
    }

    func testShowingReportMinimalDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "buyer_name": "Jane Buyer",
            "buyer_interest": "not_interested",
            "questions": null,
            "property_feedback": null,
            "follow_up_notes": null,
            "next_steps": null,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let r = try decoder.decode(ShowingReport.self, from: json)
        XCTAssertEqual(r.buyerInterest, .notInterested)
        XCTAssertNil(r.propertyFeedback)
    }

    // MARK: - Deliverable with Staging Fields

    func testDeliverableWithStagingFields() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "type": "photo",
            "file_url": "task123/staging_0.jpg",
            "room": "Living Room",
            "photo_type": "before",
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let d = try decoder.decode(Deliverable.self, from: json)
        XCTAssertEqual(d.room, "Living Room")
        XCTAssertEqual(d.photoType, "before")
    }

    func testDeliverableWithoutStagingFields() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "type": "photo",
            "file_url": "task123/photo_0.jpg",
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let d = try decoder.decode(Deliverable.self, from: json)
        XCTAssertNil(d.room)
        XCTAssertNil(d.photoType)
    }

    // MARK: - Open House Visitor Decoding

    func testOpenHouseVisitorDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "visitor_name": "Jane Doe",
            "email": "jane@example.com",
            "phone": "555-0123",
            "interest_level": "very_interested",
            "pre_approved": true,
            "agent_represented": true,
            "representing_agent_name": "Bob Smith",
            "notes": "Loved the kitchen",
            "created_at": "2024-01-15T14:30:00Z"
        }
        """.data(using: .utf8)!

        let v = try decoder.decode(OpenHouseVisitor.self, from: json)
        XCTAssertEqual(v.visitorName, "Jane Doe")
        XCTAssertEqual(v.email, "jane@example.com")
        XCTAssertEqual(v.phone, "555-0123")
        XCTAssertEqual(v.interestLevel, "very_interested")
        XCTAssertTrue(v.preApproved)
        XCTAssertTrue(v.agentRepresented)
        XCTAssertEqual(v.representingAgentName, "Bob Smith")
        XCTAssertEqual(v.interestDisplayName, "Very Interested")
    }

    func testOpenHouseVisitorMinimalDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "visitor_name": "John Q",
            "interest_level": "just_looking",
            "pre_approved": false,
            "agent_represented": false
        }
        """.data(using: .utf8)!

        let v = try decoder.decode(OpenHouseVisitor.self, from: json)
        XCTAssertEqual(v.visitorName, "John Q")
        XCTAssertNil(v.email)
        XCTAssertNil(v.phone)
        XCTAssertEqual(v.interestLevel, "just_looking")
        XCTAssertFalse(v.preApproved)
        XCTAssertFalse(v.agentRepresented)
        XCTAssertNil(v.representingAgentName)
        XCTAssertEqual(v.interestDisplayName, "Just Looking")
    }

    // MARK: - AgentTask QR Code Token

    func testAgentTaskQRCodeToken() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "agent_id": "22222222-2222-2222-2222-222222222222",
            "category": "Open House",
            "status": "in_progress",
            "property_address": "123 Main St",
            "price": 10000,
            "qr_code_token": "abc-123-token"
        }
        """.data(using: .utf8)!

        let task = try decoder.decode(AgentTask.self, from: json)
        XCTAssertEqual(task.qrCodeToken, "abc-123-token")
        XCTAssertEqual(task.taskCategory, .openHouse)
    }
}

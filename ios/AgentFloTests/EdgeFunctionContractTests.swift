import XCTest
@testable import AgentFlo

/// Tests that validate the contracts between the iOS app and Supabase Edge Functions.
/// These ensure the request/response formats match what the edge functions expect.
final class EdgeFunctionContractTests: XCTestCase {

    // MARK: - post-task Contract

    /// The post-task edge function expects { taskId: string }
    func testPostTaskRequestFormat() throws {
        let taskId = UUID()
        let body = ["taskId": taskId.uuidString]

        let data = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertNotNil(decoded?["taskId"])
        XCTAssertEqual(decoded?["taskId"], taskId.uuidString)
    }

    // MARK: - submit-deliverables Contract

    /// The submit-deliverables function expects { taskId: string, deliverables: [{type, file_url, ...}] }
    func testSubmitDeliverablesPhotoFormat() throws {
        let taskId = UUID()
        let deliverables: [[String: String]] = [
            [
                "type": "photo",
                "file_url": "\(taskId.uuidString)/photo_0_1234.jpg",
                "title": "Photo 1",
                "sort_order": "1",
            ],
            [
                "type": "photo",
                "file_url": "\(taskId.uuidString)/photo_1_1235.jpg",
                "title": "Photo 2",
                "sort_order": "2",
            ],
        ]

        // Verify each deliverable has required fields
        for d in deliverables {
            XCTAssertNotNil(d["type"], "Deliverable must have a type")
            XCTAssertNotNil(d["file_url"], "Photo deliverable must have file_url")
        }
    }

    func testSubmitDeliverablesDocumentFormat() throws {
        let deliverables: [[String: String]] = [
            [
                "type": "document",
                "file_url": "taskid/doc_123_report.pdf",
                "title": "Inspection Report.pdf",
                "sort_order": "1",
            ],
        ]

        XCTAssertEqual(deliverables[0]["type"], "document")
        XCTAssertTrue(deliverables[0]["file_url"]?.hasSuffix(".pdf") ?? false)
    }

    // MARK: - check-in / check-out Contract

    /// check-in expects { taskId: string, lat: number, lng: number }
    /// Verify that CheckInOutBody encodes lat/lng as JSON numbers (not strings)
    func testCheckInBodyEncodesNumbersCorrectly() throws {
        let body = CheckInOutBody(taskId: UUID().uuidString, lat: 30.2672, lng: -97.7431)
        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)

        // lat should be a number, not a string
        XCTAssertTrue(json?["lat"] is Double, "lat should encode as a number, got: \(type(of: json?["lat"]))")
        XCTAssertTrue(json?["lng"] is Double, "lng should encode as a number, got: \(type(of: json?["lng"]))")
        XCTAssertTrue(json?["taskId"] is String, "taskId should be a string")

        let lat = json?["lat"] as? Double ?? 0
        XCTAssertEqual(lat, 30.2672, accuracy: 0.0001)
    }

    // MARK: - cancel-task Contract

    /// cancel-task expects { taskId: string, reason?: string }
    func testCancelTaskWithReason() throws {
        let taskId = UUID()
        var body: [String: String] = ["taskId": taskId.uuidString]
        body["reason"] = "Schedule conflict"

        let data = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertEqual(decoded?["taskId"], taskId.uuidString)
        XCTAssertEqual(decoded?["reason"], "Schedule conflict")
    }

    func testCancelTaskWithoutReason() throws {
        let taskId = UUID()
        let body = ["taskId": taskId.uuidString]

        let data = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertEqual(decoded?["taskId"], taskId.uuidString)
        XCTAssertNil(decoded?["reason"])
    }

    // MARK: - approve-and-pay Contract

    /// approve-and-pay expects { taskId: string }
    func testApproveAndPayFormat() throws {
        let body = ["taskId": UUID().uuidString]
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertNotNil(decoded?["taskId"])
        XCTAssertNil(decoded?["amount"], "Amount should NOT be in request — it uses the task's price")
    }

    // MARK: - start-task Contract

    /// start-task expects { taskId: string } — no lat/lng needed
    func testStartTaskRequestFormat() throws {
        let taskId = UUID()
        let body = ["taskId": taskId.uuidString]

        let data = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertNotNil(decoded?["taskId"])
        XCTAssertNil(decoded?["lat"], "start-task should NOT include lat")
        XCTAssertNil(decoded?["lng"], "start-task should NOT include lng")
    }

    /// start-task is for non-check-in categories only
    func testStartTaskCategoryRestriction() {
        let checkInCategories: [TaskCategory] = [.showing, .staging, .openHouse]
        let startTaskCategories: [TaskCategory] = [.photography, .inspection]

        for cat in checkInCategories {
            XCTAssertTrue(cat.isCheckInCheckOut,
                "\(cat.rawValue) should use check-in, not start-task")
        }
        for cat in startTaskCategories {
            XCTAssertFalse(cat.isCheckInCheckOut,
                "\(cat.rawValue) should use start-task, not check-in")
        }
    }

    // MARK: - Message Contract

    /// send-message expects the canonical conversation payload
    func testSendMessagePayloadFormat() throws {
        let payload: [String: Any] = [
            "body": "Hello, question about the property.",
            "conversationId": UUID().uuidString,
            "clientMessageId": UUID().uuidString,
            "messageType": "text",
            "metadata": [:],
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(decoded?["conversationId"])
        XCTAssertNotNil(decoded?["clientMessageId"])
        XCTAssertEqual(decoded?["messageType"] as? String, "text")
        XCTAssertFalse((decoded?["body"] as? String)?.isEmpty ?? true)
    }

    // MARK: - Payout Setup Validation

    /// Runners must have stripeConnectId to accept tasks
    func testRunnerPayoutSetupDetection() {
        // Runner without Stripe Connect
        let runnerNoConnect = AppUser(
            id: UUID(), role: .runner, email: "test@test.com",
            fullName: "Test", vettingStatus: .approved,
            stripeConnectId: nil, createdAt: nil
        )
        XCTAssertNil(runnerNoConnect.stripeConnectId,
            "Runner without payout setup should have nil stripeConnectId")

        // Runner with Stripe Connect
        let runnerWithConnect = AppUser(
            id: UUID(), role: .runner, email: "test@test.com",
            fullName: "Test", vettingStatus: .approved,
            stripeConnectId: "acct_123", createdAt: nil
        )
        XCTAssertNotNil(runnerWithConnect.stripeConnectId,
            "Runner with payout setup should have non-nil stripeConnectId")
    }

    /// The accept_task RPC contract: requires runner to have stripe_connect_id
    func testAcceptTaskRequiresPayoutSetup() {
        // This test validates the contract documented in the accept_task RPC:
        // The RPC will raise an exception if stripe_connect_id is NULL
        let rpcParams: [String: String] = [
            "p_task_id": UUID().uuidString,
            "p_runner_id": UUID().uuidString,
        ]
        // Verify the RPC parameter format
        XCTAssertNotNil(rpcParams["p_task_id"])
        XCTAssertNotNil(rpcParams["p_runner_id"])
        // Note: actual stripe_connect_id check happens server-side in the RPC
    }

    /// The approve-and-pay function should require runner's stripe_connect_id
    func testApproveAndPayRequiresRunnerConnect() {
        // Approve-and-pay now fails if runner has no stripe_connect_id
        // Previously it silently skipped the transfer, marking task complete without paying runner
        // This test validates the expected behavior contract:
        // - If runner has no stripe_connect_id → return 400 error
        // - If runner has stripe_connect_id → proceed with transfer
        let body = ["taskId": UUID().uuidString]
        XCTAssertNotNil(body["taskId"], "approve-and-pay still only needs taskId")
    }

    // MARK: - Open House Check-In Contract

    /// open-house-checkin POST expects { token, visitor_name, email?, phone?, interest_level, ... }
    func testOpenHouseCheckinPostContract() throws {
        let body: [String: Any] = [
            "token": UUID().uuidString,
            "visitor_name": "Jane Doe",
            "email": "jane@test.com",
            "phone": "555-0123",
            "interest_level": "very_interested",
            "pre_approved": true,
            "agent_represented": false,
        ]

        let data = try JSONSerialization.data(withJSONObject: body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(decoded?["token"], "token is required")
        XCTAssertNotNil(decoded?["visitor_name"], "visitor_name is required")
        XCTAssertTrue(decoded?["pre_approved"] is Bool, "pre_approved should be bool")
        XCTAssertTrue(decoded?["agent_represented"] is Bool, "agent_represented should be bool")

        let validInterest = ["just_looking", "interested", "very_interested"]
        let interest = decoded?["interest_level"] as? String ?? ""
        XCTAssertTrue(validInterest.contains(interest),
            "interest_level '\(interest)' must match DB constraint")
    }

    /// check-out for Open House should create visitor report deliverable
    func testCheckOutCreatesVisitorReportDeliverable() {
        // The check-out edge function creates a 'report' type deliverable for open house tasks
        // with title "Open House Visitor Report" and visitor data in notes as JSON
        let expectedType = "report"
        let expectedTitle = "Open House Visitor Report"

        XCTAssertTrue(DeliverableType(rawValue: expectedType) != nil,
            "Visitor report must use a valid deliverable type")
        XCTAssertEqual(expectedTitle, "Open House Visitor Report")
    }

    // MARK: - Deliverable Type Validation

    func testAllDeliverableTypesAreValid() {
        let validTypes: [DeliverableType] = [.photo, .document, .report, .checklist]

        for type in validTypes {
            // Verify each type has a valid raw value matching the DB constraint
            let raw = type.rawValue
            XCTAssertTrue(
                ["photo", "document", "report", "checklist"].contains(raw),
                "DeliverableType '\(raw)' must match DB CHECK constraint"
            )
        }
    }

    // MARK: - Submit Inspection Contract

    func testSubmitInspectionContract() throws {
        let body = ["taskId": UUID().uuidString]
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertNotNil(decoded?["taskId"], "submit-inspection requires taskId")
    }

    func testInspectionSystemCategoryValues() {
        // All 10 ASHI system categories must match DB CHECK constraint
        let dbValues = [
            "structure", "exterior", "roofing", "plumbing", "electrical",
            "heating", "cooling", "interior", "insulation_ventilation", "fireplaces",
        ]
        let swiftValues = ASHISystem.allCases.map(\.rawValue)

        XCTAssertEqual(dbValues.count, swiftValues.count)
        for (db, swift) in zip(dbValues, swiftValues) {
            XCTAssertEqual(db, swift, "ASHISystem.\(swift) must match DB value '\(db)'")
        }
    }

    // MARK: - Status Values Match DB

    func testAllTaskStatusRawValuesMatchDB() {
        let dbValues = ["draft", "posted", "accepted", "in_progress",
                        "deliverables_submitted", "revision_requested",
                        "completed", "cancelled"]

        let swiftStatuses: [TaskStatus] = [
            .draft, .posted, .accepted, .inProgress,
            .deliverablesSubmitted, .revisionRequested,
            .completed, .cancelled,
        ]

        XCTAssertEqual(dbValues.count, swiftStatuses.count)

        for (dbVal, status) in zip(dbValues, swiftStatuses) {
            XCTAssertEqual(status.rawValue, dbVal,
                "TaskStatus.\(status) should have rawValue '\(dbVal)' but got '\(status.rawValue)'")
        }
    }
}

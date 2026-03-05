import XCTest
@testable import AgentFlo

final class OpenHouseTests: XCTestCase {

    // MARK: - QR Code URL Generation

    func testQRCodeURLGeneration() {
        let token = "abc-123-test-token"
        let baseURL = "https://giloreldlxdpqsvmqiqh.supabase.co/functions/v1/open-house-checkin"
        let url = "\(baseURL)?token=\(token)"

        XCTAssertTrue(url.contains("token=abc-123-test-token"))
        XCTAssertTrue(url.hasPrefix("https://"))
        XCTAssertTrue(url.contains("/functions/v1/open-house-checkin"))
    }

    func testQRCodeURLWithUUIDToken() {
        let token = UUID().uuidString
        let url = "https://giloreldlxdpqsvmqiqh.supabase.co/functions/v1/open-house-checkin?token=\(token)"

        // UUID format: 8-4-4-4-12 hex chars
        XCTAssertTrue(token.count == 36, "UUID token should be 36 chars")
        XCTAssertTrue(url.contains(token))
    }

    // MARK: - Visitor Interest Level Values

    func testVisitorInterestLevelValues() {
        // These must match the DB CHECK constraint in open_house_visitors
        let validLevels = ["just_looking", "interested", "very_interested"]

        // Verify OpenHouseVisitor display names work for all valid levels
        for level in validLevels {
            let json = """
            {
                "id": "\(UUID().uuidString)",
                "task_id": "\(UUID().uuidString)",
                "visitor_name": "Test",
                "interest_level": "\(level)",
                "pre_approved": false,
                "agent_represented": false
            }
            """.data(using: .utf8)!

            let visitor = try? JSONDecoder().decode(OpenHouseVisitor.self, from: json)
            XCTAssertNotNil(visitor, "Should decode visitor with interest_level '\(level)'")
            XCTAssertFalse(visitor?.interestDisplayName.isEmpty ?? true,
                "interestDisplayName should not be empty for '\(level)'")
        }
    }

    func testVisitorInterestDisplayNames() {
        let expectations: [(String, String)] = [
            ("just_looking", "Just Looking"),
            ("interested", "Interested"),
            ("very_interested", "Very Interested"),
        ]

        for (level, expectedDisplay) in expectations {
            let json = """
            {
                "id": "\(UUID().uuidString)",
                "task_id": "\(UUID().uuidString)",
                "visitor_name": "Test",
                "interest_level": "\(level)",
                "pre_approved": false,
                "agent_represented": false
            }
            """.data(using: .utf8)!

            let visitor = try! JSONDecoder().decode(OpenHouseVisitor.self, from: json)
            XCTAssertEqual(visitor.interestDisplayName, expectedDisplay)
        }
    }

    // MARK: - Visitor Count Aggregation

    func testVisitorCountAggregation() {
        let visitors = makeTestVisitors()

        let totalCount = visitors.count
        let preApprovedCount = visitors.filter(\.preApproved).count
        let veryInterestedCount = visitors.filter { $0.interestLevel == "very_interested" }.count

        XCTAssertEqual(totalCount, 5)
        XCTAssertEqual(preApprovedCount, 2)
        XCTAssertEqual(veryInterestedCount, 1)
    }

    func testEmptyVisitorCounts() {
        let visitors: [OpenHouseVisitor] = []
        XCTAssertEqual(visitors.count, 0)
        XCTAssertEqual(visitors.filter(\.preApproved).count, 0)
        XCTAssertEqual(visitors.filter { $0.interestLevel == "very_interested" }.count, 0)
    }

    // MARK: - TaskCategory Open House

    func testOpenHouseIsCheckInCheckOut() {
        XCTAssertTrue(TaskCategory.openHouse.isCheckInCheckOut,
            "Open House should be a check-in/check-out category")
    }

    func testOpenHouseDisplayName() {
        XCTAssertEqual(TaskCategory.openHouse.displayName, "Open House")
    }

    func testOpenHouseRawValue() {
        XCTAssertEqual(TaskCategory.openHouse.rawValue, "open_house")
    }

    // MARK: - Helpers

    private func makeTestVisitors() -> [OpenHouseVisitor] {
        let taskId = UUID()
        return [
            makeVisitor(taskId: taskId, name: "Alice", interest: "interested", preApproved: true),
            makeVisitor(taskId: taskId, name: "Bob", interest: "just_looking", preApproved: false),
            makeVisitor(taskId: taskId, name: "Carol", interest: "very_interested", preApproved: true),
            makeVisitor(taskId: taskId, name: "Dave", interest: "interested", preApproved: false),
            makeVisitor(taskId: taskId, name: "Eve", interest: "interested", preApproved: false),
        ]
    }

    private func makeVisitor(taskId: UUID, name: String, interest: String, preApproved: Bool) -> OpenHouseVisitor {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "task_id": "\(taskId.uuidString)",
            "visitor_name": "\(name)",
            "interest_level": "\(interest)",
            "pre_approved": \(preApproved),
            "agent_represented": false
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(OpenHouseVisitor.self, from: json)
    }
}

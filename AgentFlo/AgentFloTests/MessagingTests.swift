import XCTest
@testable import AgentFlo

final class MessagingTests: XCTestCase {

    // MARK: - Conversation Canonical Ordering

    func testCanonicalOrderingSmallFirst() {
        let id1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let id2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let p1 = min(id1, id2)
        let p2 = max(id1, id2)

        XCTAssertEqual(p1, id1, "Smaller UUID should be participant_1")
        XCTAssertEqual(p2, id2, "Larger UUID should be participant_2")
    }

    func testCanonicalOrderingReversed() {
        let id1 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let id2 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        let p1 = min(id1, id2)
        let p2 = max(id1, id2)

        XCTAssertEqual(p1, id2, "Smaller UUID should be participant_1 regardless of input order")
        XCTAssertEqual(p2, id1, "Larger UUID should be participant_2 regardless of input order")
    }

    func testCanonicalOrderingSameUser() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        let p1 = min(id, id)
        let p2 = max(id, id)

        XCTAssertEqual(p1, p2, "Same user should produce equal participant IDs")
    }

    // MARK: - MessageContext

    func testMessageContextTaskCase() {
        let taskId = UUID()
        let context = MessageContext.task(taskId)

        if case .task(let id) = context {
            XCTAssertEqual(id, taskId)
        } else {
            XCTFail("Expected task context")
        }
    }

    func testMessageContextConversationCase() {
        let convId = UUID()
        let context = MessageContext.conversation(convId)

        if case .conversation(let id) = context {
            XCTAssertEqual(id, convId)
        } else {
            XCTFail("Expected conversation context")
        }
    }

    // MARK: - DashboardDestination

    func testDirectMessagingDestination() {
        let convId = UUID()
        let dest = DashboardDestination.directMessaging(conversationId: convId, otherUserName: "Jane")

        if case .directMessaging(let id, let name) = dest {
            XCTAssertEqual(id, convId)
            XCTAssertEqual(name, "Jane")
        } else {
            XCTFail("Expected directMessaging destination")
        }
    }

    func testPublicProfileDestination() {
        let userId = UUID()
        let dest = DashboardDestination.publicProfile(userId)

        if case .publicProfile(let id) = dest {
            XCTAssertEqual(id, userId)
        } else {
            XCTFail("Expected publicProfile destination")
        }
    }
}

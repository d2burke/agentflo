import XCTest
@testable import AgentFlo

final class TaskCategoryTests: XCTestCase {

    // MARK: - Category Parsing

    func testPhotographyCategory() {
        let task = AgentTask(category: "Photography")
        XCTAssertEqual(task.taskCategory, .photography)
        XCTAssertFalse(task.isCheckInCheckOut)
    }

    func testShowingCategory() {
        let task = AgentTask(category: "Showing")
        XCTAssertEqual(task.taskCategory, .showing)
        XCTAssertTrue(task.isCheckInCheckOut)
    }

    func testStagingCategory() {
        let task = AgentTask(category: "Staging")
        XCTAssertEqual(task.taskCategory, .staging)
        XCTAssertTrue(task.isCheckInCheckOut)
    }

    func testOpenHouseCategory() {
        let task = AgentTask(category: "Open House")
        XCTAssertEqual(task.taskCategory, .openHouse)
        XCTAssertTrue(task.isCheckInCheckOut)
    }

    func testInspectionCategory() {
        let task = AgentTask(category: "Inspection")
        XCTAssertEqual(task.taskCategory, .inspection)
        XCTAssertFalse(task.isCheckInCheckOut)
    }

    func testUnknownCategoryReturnsNil() {
        let task = AgentTask(category: "SomethingNew")
        XCTAssertNil(task.taskCategory)
        XCTAssertFalse(task.isCheckInCheckOut)
    }

    // MARK: - Check-In/Check-Out Flag

    func testIsCheckInCheckOutValues() {
        let checkInCategories: [TaskCategory] = [.showing, .staging, .openHouse]
        let nonCheckInCategories: [TaskCategory] = [.photography, .inspection]

        for cat in checkInCategories {
            XCTAssertTrue(cat.isCheckInCheckOut, "\(cat.rawValue) should be check-in/check-out")
        }

        for cat in nonCheckInCategories {
            XCTAssertFalse(cat.isCheckInCheckOut, "\(cat.rawValue) should NOT be check-in/check-out")
        }
    }

    // MARK: - Category from DB String

    func testCategoryRawValues() {
        XCTAssertEqual(TaskCategory(rawValue: "photography"), .photography)
        XCTAssertEqual(TaskCategory(rawValue: "showing"), .showing)
        XCTAssertEqual(TaskCategory(rawValue: "staging"), .staging)
        XCTAssertEqual(TaskCategory(rawValue: "open_house"), .openHouse)
        XCTAssertEqual(TaskCategory(rawValue: "inspection"), .inspection)
    }
}

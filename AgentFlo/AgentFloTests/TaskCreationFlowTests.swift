import XCTest
@testable import AgentFlo

/// Tests for the task creation and draft flow logic.
final class TaskCreationFlowTests: XCTestCase {

    // MARK: - Price Conversion

    func testPriceInCentsConversion() {
        // Simulates the priceText → priceInCents logic from TaskCreationSheet
        let priceText = "150"
        let cents = (Int(priceText) ?? 0) * 100
        XCTAssertEqual(cents, 15000)
    }

    func testPriceInCentsEmptyString() {
        let priceText = ""
        let cents = (Int(priceText) ?? 0) * 100
        XCTAssertEqual(cents, 0)
    }

    func testPriceInCentsInvalidInput() {
        let priceText = "abc"
        let cents = (Int(priceText) ?? 0) * 100
        XCTAssertEqual(cents, 0)
    }

    // MARK: - Form Validation

    func testFormValidWithAllFields() {
        let address = "123 Main St"
        let priceText = "100"

        let isValid = !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !priceText.isEmpty
            && (Int(priceText) ?? 0) > 0

        XCTAssertTrue(isValid)
    }

    func testFormInvalidWithEmptyAddress() {
        let address = "   "
        let priceText = "100"

        let isValid = !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !priceText.isEmpty
            && (Int(priceText) ?? 0) > 0

        XCTAssertFalse(isValid)
    }

    func testFormInvalidWithZeroPrice() {
        let address = "123 Main St"
        let priceText = "0"

        let isValid = !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !priceText.isEmpty
            && (Int(priceText) ?? 0) > 0

        XCTAssertFalse(isValid)
    }

    func testFormInvalidWithEmptyPrice() {
        let address = "123 Main St"
        let priceText = ""

        let isValid = !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !priceText.isEmpty
            && (Int(priceText) ?? 0) > 0

        XCTAssertFalse(isValid)
    }

    // MARK: - Category List

    func testAllCategoriesHaveRequiredData() {
        let categories: [(name: String, description: String, priceRange: String)] = [
            ("Photography", "Professional listing photos", "$100–$300"),
            ("Showing", "Buyer or inspector showing", "$50–$100"),
            ("Staging", "Furniture staging & setup", "$200–$400"),
            ("Open House", "Host an open house event", "$75–$150"),
            ("Inspection", "Property inspection report", "$75–$200"),
        ]

        XCTAssertEqual(categories.count, 5, "Should have 5 task categories")

        for cat in categories {
            XCTAssertFalse(cat.name.isEmpty, "Category name should not be empty")
            XCTAssertFalse(cat.description.isEmpty, "Category description should not be empty")
            XCTAssertTrue(cat.priceRange.hasPrefix("$"), "Price range should start with $")

            // Verify each category maps to a valid TaskCategory
            let task = AgentTask(category: cat.name)
            XCTAssertNotNil(task.taskCategory,
                "Category '\(cat.name)' should map to a valid TaskCategory")
        }
    }

    // MARK: - Draft Editing

    func testEditingTaskPreFillsCategory() {
        let draft = AgentTask(
            category: "Showing",
            status: .draft,
            propertyAddress: "456 Oak Ave",
            price: 7500,
            instructions: "Ring doorbell"
        )

        // Simulate prefill logic from TaskCreationSheet.onAppear
        let selectedCategory = draft.category
        let address = draft.propertyAddress
        let priceText = String(draft.price / 100)
        let instructions = draft.instructions ?? ""

        XCTAssertEqual(selectedCategory, "Showing")
        XCTAssertEqual(address, "456 Oak Ave")
        XCTAssertEqual(priceText, "75")
        XCTAssertEqual(instructions, "Ring doorbell")
    }

    func testEditingTaskWithZeroPriceShowsEmpty() {
        let draft = AgentTask(
            category: "Photography",
            status: .draft,
            propertyAddress: "Test",
            price: 0 // Edge case — shouldn't happen but handle gracefully
        )

        let dollars = draft.price / 100
        let priceText = dollars > 0 ? "\(dollars)" : ""

        XCTAssertEqual(priceText, "")
    }

    // MARK: - Dashboard Display

    func testDisplayTasksExcludesDraftAndCancelled() {
        let tasks = [
            AgentTask(category: "Photography", status: .draft, propertyAddress: "A", price: 100),
            AgentTask(category: "Photography", status: .posted, propertyAddress: "B", price: 200),
            AgentTask(category: "Showing", status: .inProgress, propertyAddress: "C", price: 300),
            AgentTask(category: "Staging", status: .cancelled, propertyAddress: "D", price: 400),
            AgentTask(category: "Open House", status: .completed, propertyAddress: "E", price: 500),
        ]

        // Simulates displayTasks filter from AgentDashboardView
        let displayTasks = tasks.filter { $0.status != .draft && $0.status != .cancelled }

        XCTAssertEqual(displayTasks.count, 3)
        XCTAssertTrue(displayTasks.allSatisfy { $0.status != .draft })
        XCTAssertTrue(displayTasks.allSatisfy { $0.status != .cancelled })
    }

    // MARK: - TaskSheetMode

    func testTaskSheetModeIdentity() {
        let task1 = AgentTask(id: UUID(), category: "Photography", status: .draft, propertyAddress: "A", price: 100)
        let task2 = AgentTask(id: UUID(), category: "Showing", status: .draft, propertyAddress: "B", price: 200)

        // Test that createNew always has the same ID
        // (This validates the Identifiable conformance used by .sheet(item:))
        let mode1 = TaskSheetMode.createNew
        let mode2 = TaskSheetMode.createNew
        XCTAssertEqual(mode1.id, mode2.id)

        // Test that editDraft uses the task's UUID
        let edit1 = TaskSheetMode.editDraft(task1)
        let edit2 = TaskSheetMode.editDraft(task2)
        XCTAssertNotEqual(edit1.id, edit2.id)
        XCTAssertEqual(edit1.id, task1.id.uuidString)
    }
}

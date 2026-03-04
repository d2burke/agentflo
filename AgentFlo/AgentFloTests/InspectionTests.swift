import XCTest
@testable import AgentFlo

final class InspectionTests: XCTestCase {

    // MARK: - ASHI System

    func testASHISystemAllCases() {
        let systems = ASHISystem.allCases
        XCTAssertEqual(systems.count, 10, "ASHI standard requires exactly 10 system categories")
    }

    func testASHISystemRawValues() {
        let expectedRawValues = [
            "structure", "exterior", "roofing", "plumbing", "electrical",
            "heating", "cooling", "interior", "insulation_ventilation", "fireplaces",
        ]
        let actualRawValues = ASHISystem.allCases.map(\.rawValue)
        XCTAssertEqual(actualRawValues, expectedRawValues)
    }

    func testASHISystemSubItems() {
        for system in ASHISystem.allCases {
            XCTAssertFalse(system.subItems.isEmpty,
                "\(system.displayName) must have at least 1 sub-item")
        }
    }

    func testASHISystemDisplayNames() {
        for system in ASHISystem.allCases {
            XCTAssertFalse(system.displayName.isEmpty)
        }
        XCTAssertEqual(ASHISystem.insulationVentilation.displayName, "Insulation & Ventilation")
    }

    func testASHISystemIcons() {
        for system in ASHISystem.allCases {
            XCTAssertFalse(system.iconName.isEmpty, "\(system.displayName) must have an icon")
        }
    }

    // MARK: - Finding Status

    func testFindingStatusEnum() {
        let statuses = FindingStatus.allCases
        XCTAssertEqual(statuses.count, 4)
        XCTAssertEqual(FindingStatus.good.rawValue, "good")
        XCTAssertEqual(FindingStatus.deficiency.rawValue, "deficiency")
        XCTAssertEqual(FindingStatus.notInspected.rawValue, "not_inspected")
        XCTAssertEqual(FindingStatus.na.rawValue, "na")
    }

    // MARK: - Finding Severity

    func testFindingSeverityEnum() {
        let severities = FindingSeverity.allCases
        XCTAssertEqual(severities.count, 5)
        XCTAssertEqual(FindingSeverity.critical.rawValue, "critical")
        XCTAssertEqual(FindingSeverity.major.rawValue, "major")
        XCTAssertEqual(FindingSeverity.minor.rawValue, "minor")
        XCTAssertEqual(FindingSeverity.monitor.rawValue, "monitor")
        XCTAssertEqual(FindingSeverity.good.rawValue, "good")
    }

    func testFindingSeverityColors() {
        // Each severity must have a distinct color
        for severity in FindingSeverity.allCases {
            // Just verify color property is accessible (no crash)
            _ = severity.color
        }
    }

    // MARK: - Inspection Finding Decoding

    func testInspectionFindingDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "system_category": "plumbing",
            "sub_item": "Water Heater",
            "status": "deficiency",
            "severity": "major",
            "description": "Water heater is 15 years old, showing corrosion at base",
            "recommendation": "Replace water heater within 1-2 years",
            "photo_urls": ["photo1.jpg", "photo2.jpg"],
            "sort_order": 3
        }
        """.data(using: .utf8)!

        let finding = try JSONDecoder().decode(InspectionFinding.self, from: json)
        XCTAssertEqual(finding.systemCategory, .plumbing)
        XCTAssertEqual(finding.subItem, "Water Heater")
        XCTAssertEqual(finding.status, .deficiency)
        XCTAssertEqual(finding.severity, .major)
        XCTAssertEqual(finding.description, "Water heater is 15 years old, showing corrosion at base")
        XCTAssertEqual(finding.recommendation, "Replace water heater within 1-2 years")
        XCTAssertEqual(finding.photoUrls.count, 2)
        XCTAssertEqual(finding.sortOrder, 3)
    }

    func testInspectionFindingMinimal() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "task_id": "22222222-2222-2222-2222-222222222222",
            "runner_id": "33333333-3333-3333-3333-333333333333",
            "system_category": "roofing",
            "sub_item": "Roof Coverings",
            "status": "good",
            "photo_urls": [],
            "sort_order": 0
        }
        """.data(using: .utf8)!

        let finding = try JSONDecoder().decode(InspectionFinding.self, from: json)
        XCTAssertEqual(finding.systemCategory, .roofing)
        XCTAssertEqual(finding.status, .good)
        XCTAssertNil(finding.severity)
        XCTAssertNil(finding.description)
        XCTAssertNil(finding.recommendation)
        XCTAssertTrue(finding.photoUrls.isEmpty)
    }

    // MARK: - Inspection Completeness

    func testInspectionCompletenessAllSystems() {
        let findings = makeCompleteFindingSet()
        let summary = InspectionSummary(findings: findings)
        XCTAssertTrue(summary.isComplete, "Should be complete when all 10 systems have findings")
        XCTAssertTrue(summary.completedSystems.count == 10)
    }

    func testInspectionCompletenessIncomplete() {
        // Only 3 systems
        let findings = [
            makeFinding(system: .structure, subItem: "Foundation"),
            makeFinding(system: .roofing, subItem: "Roof Coverings"),
            makeFinding(system: .plumbing, subItem: "Water Supply"),
        ]
        let summary = InspectionSummary(findings: findings)
        XCTAssertFalse(summary.isComplete)
        XCTAssertEqual(summary.completedSystems.count, 3)
        XCTAssertEqual(summary.missingSystems.count, 7)
    }

    func testInspectionMinimumPhotos() {
        var findings = makeCompleteFindingSet()

        // Each finding has 3 photos = 10 * 3 = 30 >= 25
        let summary30 = InspectionSummary(findings: findings)
        XCTAssertTrue(summary30.meetsMinimumPhotos)
        XCTAssertEqual(summary30.totalPhotos, 30)

        // Replace with 2 photos each = 10 * 2 = 20 < 25
        findings = ASHISystem.allCases.map { system in
            makeFinding(system: system, subItem: system.subItems[0], photoCount: 2)
        }
        let summary20 = InspectionSummary(findings: findings)
        XCTAssertFalse(summary20.meetsMinimumPhotos)
        XCTAssertEqual(summary20.totalPhotos, 20)
    }

    func testInspectionSeverityCounts() {
        let findings = [
            makeFinding(system: .structure, subItem: "Foundation", status: .deficiency, severity: .critical),
            makeFinding(system: .structure, subItem: "Walls", status: .deficiency, severity: .critical),
            makeFinding(system: .plumbing, subItem: "Water Supply", status: .deficiency, severity: .major),
            makeFinding(system: .electrical, subItem: "Main Panel", status: .deficiency, severity: .minor),
            makeFinding(system: .roofing, subItem: "Roof Coverings", status: .good, severity: .good),
        ]
        let summary = InspectionSummary(findings: findings)
        XCTAssertEqual(summary.criticalCount, 2)
        XCTAssertEqual(summary.majorCount, 1)
        XCTAssertEqual(summary.minorCount, 1)
        XCTAssertEqual(summary.deficiencyCount, 4)
    }

    // MARK: - Helpers

    private func makeCompleteFindingSet() -> [InspectionFinding] {
        ASHISystem.allCases.map { system in
            makeFinding(system: system, subItem: system.subItems[0], photoCount: 3)
        }
    }

    private func makeFinding(
        system: ASHISystem,
        subItem: String,
        status: FindingStatus = .good,
        severity: FindingSeverity? = nil,
        photoCount: Int = 3
    ) -> InspectionFinding {
        InspectionFinding(
            id: UUID(),
            taskId: UUID(),
            runnerId: UUID(),
            systemCategory: system,
            subItem: subItem,
            status: status,
            severity: severity,
            photoUrls: (0..<photoCount).map { "photo_\($0).jpg" },
            sortOrder: 0
        )
    }
}

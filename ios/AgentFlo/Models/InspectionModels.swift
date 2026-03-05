import SwiftUI

// MARK: - ASHI System Categories

enum ASHISystem: String, CaseIterable, Codable {
    case structure
    case exterior
    case roofing
    case plumbing
    case electrical
    case heating
    case cooling
    case interior
    case insulationVentilation = "insulation_ventilation"
    case fireplaces

    var displayName: String {
        switch self {
        case .structure: "Structure"
        case .exterior: "Exterior"
        case .roofing: "Roofing"
        case .plumbing: "Plumbing"
        case .electrical: "Electrical"
        case .heating: "Heating"
        case .cooling: "Cooling"
        case .interior: "Interior"
        case .insulationVentilation: "Insulation & Ventilation"
        case .fireplaces: "Fireplaces"
        }
    }

    var iconName: String {
        switch self {
        case .structure: "building.2"
        case .exterior: "house"
        case .roofing: "house.lodge"
        case .plumbing: "drop"
        case .electrical: "bolt"
        case .heating: "flame"
        case .cooling: "snowflake"
        case .interior: "door.left.hand.open"
        case .insulationVentilation: "wind"
        case .fireplaces: "fireplace"
        }
    }

    var subItems: [String] {
        switch self {
        case .structure:
            ["Foundation", "Floor Structure", "Wall Structure", "Ceiling Structure", "Roof Structure"]
        case .exterior:
            ["Wall Cladding", "Trim & Soffits", "Doors", "Windows", "Decks & Porches", "Driveways & Walkways", "Grading & Drainage"]
        case .roofing:
            ["Roof Coverings", "Flashings", "Skylights", "Gutters & Downspouts", "Roof Ventilation"]
        case .plumbing:
            ["Water Supply", "Drain & Waste", "Water Heater", "Fixtures & Faucets", "Sump Pump"]
        case .electrical:
            ["Service Entry", "Main Panel", "Branch Circuits", "Outlets & Switches", "GFCI/AFCI", "Smoke & CO Detectors"]
        case .heating:
            ["Heating Equipment", "Distribution", "Thermostat", "Fuel Storage"]
        case .cooling:
            ["Cooling Equipment", "Distribution", "Thermostat"]
        case .interior:
            ["Walls & Ceilings", "Floors", "Stairs & Railings", "Doors & Windows", "Countertops & Cabinets"]
        case .insulationVentilation:
            ["Attic Insulation", "Wall Insulation", "Vapor Barriers", "Bathroom Exhaust", "Kitchen Exhaust", "Attic Ventilation"]
        case .fireplaces:
            ["Fireplace", "Chimney", "Damper", "Hearth"]
        }
    }
}

// MARK: - Finding Status

enum FindingStatus: String, CaseIterable, Codable {
    case good
    case deficiency
    case notInspected = "not_inspected"
    case na

    var displayName: String {
        switch self {
        case .good: "Good"
        case .deficiency: "Deficiency"
        case .notInspected: "Not Inspected"
        case .na: "N/A"
        }
    }
}

// MARK: - Finding Severity

enum FindingSeverity: String, CaseIterable, Codable {
    case critical
    case major
    case minor
    case monitor
    case good

    var displayName: String {
        switch self {
        case .critical: "Critical"
        case .major: "Major"
        case .minor: "Minor"
        case .monitor: "Monitor"
        case .good: "Good"
        }
    }

    var color: Color {
        switch self {
        case .critical: .red
        case .major: .orange
        case .minor: .yellow
        case .monitor: .blue
        case .good: .green
        }
    }
}

// MARK: - Inspection Finding

struct InspectionFinding: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let runnerId: UUID
    let systemCategory: ASHISystem
    let subItem: String
    var status: FindingStatus
    var severity: FindingSeverity?
    var description: String?
    var recommendation: String?
    var notInspectedReason: String?
    var photoUrls: [String]
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case runnerId = "runner_id"
        case systemCategory = "system_category"
        case subItem = "sub_item"
        case status, severity, description, recommendation
        case notInspectedReason = "not_inspected_reason"
        case photoUrls = "photo_urls"
        case sortOrder = "sort_order"
    }
}

// MARK: - Inspection Summary

struct InspectionSummary {
    let findings: [InspectionFinding]

    var totalFindings: Int { findings.count }
    var criticalCount: Int { findings.filter { $0.severity == .critical }.count }
    var majorCount: Int { findings.filter { $0.severity == .major }.count }
    var minorCount: Int { findings.filter { $0.severity == .minor }.count }
    var deficiencyCount: Int { findings.filter { $0.status == .deficiency }.count }

    var completedSystems: Set<ASHISystem> {
        Set(findings.map(\.systemCategory))
    }

    var isComplete: Bool {
        completedSystems.count == ASHISystem.allCases.count
    }

    var totalPhotos: Int {
        findings.reduce(0) { $0 + $1.photoUrls.count }
    }

    var meetsMinimumPhotos: Bool {
        totalPhotos >= 25
    }

    var missingSystems: [ASHISystem] {
        ASHISystem.allCases.filter { !completedSystems.contains($0) }
    }
}

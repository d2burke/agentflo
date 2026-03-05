import Foundation
import Supabase

@Observable
final class InspectionService {

    // MARK: - Local Draft Persistence

    private static let draftPrefix = "inspection_draft_"

    /// Check if a local draft exists for a given task
    func hasLocalDraft(taskId: UUID) -> Bool {
        UserDefaults.standard.data(forKey: Self.draftPrefix + taskId.uuidString) != nil
    }

    /// Load findings from local draft (UserDefaults)
    func loadLocalDraft(taskId: UUID) -> [InspectionFinding] {
        guard let data = UserDefaults.standard.data(forKey: Self.draftPrefix + taskId.uuidString) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([InspectionFinding].self, from: data)) ?? []
    }

    /// Save findings to local draft (UserDefaults) — called automatically after each edit
    func saveLocalDraft(taskId: UUID, findings: [InspectionFinding]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(findings) {
            UserDefaults.standard.set(data, forKey: Self.draftPrefix + taskId.uuidString)
        }
    }

    /// Remove local draft after successful cloud save or submission
    func clearLocalDraft(taskId: UUID) {
        UserDefaults.standard.removeObject(forKey: Self.draftPrefix + taskId.uuidString)
    }

    // MARK: - Auth

    private func authHeaders() async throws -> [String: String] {
        let session = try await supabase.auth.refreshSession()
        return ["Authorization": "Bearer \(session.accessToken)"]
    }

    // MARK: - Cloud Operations

    func fetchFindings(taskId: UUID) async throws -> [InspectionFinding] {
        try await supabase
            .from("inspection_findings")
            .select()
            .eq("task_id", value: taskId.uuidString)
            .order("system_category")
            .order("sort_order")
            .execute()
            .value
    }

    func saveFinding(_ finding: InspectionFinding) async throws {
        try await supabase
            .from("inspection_findings")
            .upsert(finding)
            .execute()
    }

    /// Save all local findings to the cloud in a single batch
    func saveDraftToCloud(taskId: UUID, findings: [InspectionFinding]) async throws {
        guard !findings.isEmpty else { return }
        try await supabase
            .from("inspection_findings")
            .upsert(findings)
            .execute()
    }

    func deleteFinding(id: UUID) async throws {
        try await supabase
            .from("inspection_findings")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func submitInspection(taskId: UUID) async throws {
        let headers = try await authHeaders()
        try await supabase.functions.invoke(
            "submit-inspection",
            options: .init(headers: headers, body: ["taskId": taskId.uuidString])
        )
    }

    func checkCompleteness(findings: [InspectionFinding]) -> InspectionSummary {
        InspectionSummary(findings: findings)
    }
}

import Foundation
import Supabase

struct VettingRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: String
    var status: String
    var submittedData: [String: String]?
    var reviewerNotes: String?
    var reviewedBy: UUID?
    var reviewedAt: Date?
    var expiresAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case status
        case submittedData = "submitted_data"
        case reviewerNotes = "reviewer_notes"
        case reviewedBy = "reviewed_by"
        case reviewedAt = "reviewed_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

@Observable
final class VettingService {
    var records: [VettingRecord] = []
    var isLoading = false
    var isSubmitting = false
    var error: String?

    func fetchMyRecords() async {
        isLoading = true
        error = nil

        do {
            let data: [VettingRecord] = try await supabase
                .from("vetting_records")
                .select()
                .order("created_at")
                .execute()
                .value

            await MainActor.run {
                self.records = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.records = []
                self.isLoading = false
                self.error = error.localizedDescription
            }
        }
    }

    func submitRecord(type: String, submittedData: [String: String]) async throws {
        isSubmitting = true
        defer { Task { @MainActor in isSubmitting = false } }

        struct SubmitPayload: Encodable {
            let type: String
            let submittedData: [String: String]
        }

        let payload = SubmitPayload(type: type, submittedData: submittedData)
        let bodyData = try JSONEncoder().encode(payload)

        try await supabase.functions.invoke(
            "submit-vetting",
            options: .init(body: bodyData)
        )

        // Refresh records after submission
        await fetchMyRecords()
    }

    func uploadPhotoId(userId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId.uuidString.lowercased())/photo-id-\(Int(Date().timeIntervalSince1970)).jpg"

        try await supabase.storage
            .from("vetting-documents")
            .upload(path, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))

        // Get signed URL
        let url = try await supabase.storage
            .from("vetting-documents")
            .createSignedURL(path: path, expiresIn: 60 * 60 * 24 * 365) // 1 year

        return url.absoluteString
    }

    func record(ofType type: String) -> VettingRecord? {
        records.first { $0.type == type }
    }
}


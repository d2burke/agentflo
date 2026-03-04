import Foundation
import UIKit

@Observable
final class StorageService {
    private let bucket = "deliverables"

    func uploadPhoto(taskId: UUID, image: UIImage, index: Int) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.compressionFailed
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "\(taskId.uuidString)/photo_\(index)_\(timestamp).jpg"

        try await supabase.storage
            .from(bucket)
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))

        return path
    }

    func uploadDocument(taskId: UUID, data: Data, filename: String) async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let safeName = filename.replacingOccurrences(of: " ", with: "_")
        let path = "\(taskId.uuidString)/doc_\(timestamp)_\(safeName)"

        try await supabase.storage
            .from(bucket)
            .upload(path, data: data, options: .init(contentType: "application/pdf"))

        return path
    }

    func getSignedUrl(path: String) async throws -> URL {
        try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
    }

    // MARK: - Portfolio

    func uploadPortfolioImage(runnerId: UUID, image: UIImage, index: Int) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw StorageError.compressionFailed
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "\(runnerId.uuidString)/portfolio_\(index)_\(timestamp).jpg"

        try await supabase.storage
            .from("portfolio")
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))

        return path
    }

    func deletePortfolioImage(path: String) async throws {
        try await supabase.storage
            .from("portfolio")
            .remove(paths: [path])
    }
}

enum StorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            "Failed to compress image for upload."
        }
    }
}

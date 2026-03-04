import SwiftUI
import QuickLook

struct DocumentListView: View {
    let deliverables: [Deliverable]

    @State private var previewURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("\(deliverables.count) Document\(deliverables.count == 1 ? "" : "s")")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            ForEach(deliverables) { deliverable in
                Button {
                    Task { await loadDocument(deliverable) }
                } label: {
                    HStack(spacing: Spacing.lg) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.agentRed)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(deliverable.title ?? "Document")
                                .font(.bodyEmphasis)
                                .foregroundStyle(.agentNavy)
                            if let createdAt = deliverable.createdAt {
                                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.captionSM)
                                    .foregroundStyle(.agentSlate)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.agentSlate)
                    }
                    .padding(Spacing.cardPadding)
                    .background(.agentSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    .shadow(color: Shadows.card, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .quickLookPreview($previewURL)
    }

    private func loadDocument(_ deliverable: Deliverable) async {
        guard let path = deliverable.fileUrl else { return }
        do {
            let signedURL = try await supabase.storage
                .from("deliverables")
                .createSignedURL(path: path, expiresIn: 3600)

            // Download to temp file for QuickLook
            let (data, _) = try await URLSession.shared.data(from: signedURL)
            let filename = deliverable.title ?? "document.pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            previewURL = tempURL
        } catch {
            print("[DocumentList] Failed to load document: \(error)")
        }
    }
}

import SwiftUI

struct StagingComparisonView: View {
    let deliverables: [Deliverable]

    @Environment(AppState.self) private var appState

    private var groupedByRoom: [(room: String, before: [Deliverable], after: [Deliverable])] {
        let withRoom = deliverables.filter { $0.room != nil && $0.photoType != nil }
        let grouped = Dictionary(grouping: withRoom, by: { $0.room ?? "Unknown" })
        return grouped.keys.sorted().map { room in
            let items = grouped[room] ?? []
            return (
                room: room,
                before: items.filter { $0.photoType == "before" },
                after: items.filter { $0.photoType == "after" }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("Staging Photos")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            if groupedByRoom.isEmpty {
                Text("No staging photos submitted.")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlateLight)
            } else {
                ForEach(groupedByRoom, id: \.room) { group in
                    roomComparison(group)
                }
            }
        }
    }

    private func roomComparison(_ group: (room: String, before: [Deliverable], after: [Deliverable])) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(group.room)
                .font(.bodyEmphasis)
                .foregroundStyle(.agentNavy)

            HStack(spacing: Spacing.md) {
                photoColumn(label: "Before", deliverables: group.before)
                photoColumn(label: "After", deliverables: group.after)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private func photoColumn(label: String, deliverables: [Deliverable]) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(label)
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            if let first = deliverables.first, let url = first.fileUrl {
                StorageImageView(path: url, bucket: "deliverables")
                    .frame(minHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .fill(Color.agentBackground)
                    .frame(minHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        Text("No photo")
                            .font(.caption)
                            .foregroundStyle(.agentSlateLight)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Loads and displays an image from Supabase Storage
private struct StorageImageView: View {
    let path: String
    var bucket: String = "deliverables"

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.agentBackground)
                    .overlay { ProgressView() }
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        do {
            let url = try await supabase.storage.from(bucket).createSignedURL(path: path, expiresIn: 3600)
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            }
        } catch {
            print("[StorageImage] Failed to load \(path): \(error)")
        }
    }
}

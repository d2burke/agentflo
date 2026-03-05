import SwiftUI

struct PhotoGalleryView: View {
    let deliverables: [Deliverable]

    @State private var loadedImages: [UUID: Image] = [:]
    @State private var selectedPhoto: Deliverable?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("\(deliverables.count) Photo\(deliverables.count == 1 ? "" : "s")")
                .font(.captionSM)
                .foregroundStyle(.agentSlate)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
            ], spacing: 4) {
                ForEach(deliverables) { deliverable in
                    Button {
                        selectedPhoto = deliverable
                    } label: {
                        Group {
                            if let image = loadedImages[deliverable.id] {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle()
                                    .fill(Color.agentBackground)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                        .frame(minHeight: 110)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
        .task { await loadThumbnails() }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoFullScreenView(deliverable: photo, image: loadedImages[photo.id])
        }
    }

    private func loadThumbnails() async {
        for deliverable in deliverables {
            guard let path = deliverable.fileUrl else { continue }
            do {
                let url = try await supabase.storage
                    .from("deliverables")
                    .createSignedURL(path: path, expiresIn: 3600)
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    loadedImages[deliverable.id] = Image(uiImage: uiImage)
                }
            } catch {
                print("[PhotoGallery] Failed to load \(path): \(error)")
            }
        }
    }
}

struct PhotoFullScreenView: View {
    let deliverable: Deliverable
    let image: Image?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

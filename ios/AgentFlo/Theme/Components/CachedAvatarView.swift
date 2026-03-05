import SwiftUI

/// Avatar view with automatic image caching.
/// Checks memory/disk cache first, then downloads from Supabase Storage on miss.
struct CachedAvatarView: View {
    let avatarPath: String?
    let name: String
    var size: CGFloat = 44
    var bucket: String = "avatars"

    @State private var image: Image?

    var body: some View {
        AvatarView(image: image, name: name, size: size)
            .task(id: avatarPath) { await loadImage() }
    }

    private func loadImage() async {
        guard let path = avatarPath, !path.isEmpty else {
            image = nil
            return
        }

        // Check cache first
        if let cached = await ImageCache.shared.image(for: path) {
            image = Image(uiImage: cached)
            return
        }

        // Download from Supabase Storage
        do {
            let data = try await supabase.storage.from(bucket).download(path: path)
            if let uiImage = UIImage(data: data) {
                await ImageCache.shared.store(uiImage, for: path)
                image = Image(uiImage: uiImage)
            }
        } catch {
            print("[CachedAvatar] Failed to load \(path): \(error)")
        }
    }
}

import SwiftUI

/// Reusable avatar view that shows an image or falls back to initials
struct AvatarView: View {
    let image: Image?
    let name: String
    var size: CGFloat = 44

    var body: some View {
        if let image {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.agentRedLight)
                .frame(width: size, height: size)
                .overlay(
                    Text(name.prefix(1).uppercased())
                        .font(size >= 72 ? .display : (size >= 44 ? .bodyEmphasis : .captionSM))
                        .foregroundStyle(.agentRed)
                )
        }
    }
}

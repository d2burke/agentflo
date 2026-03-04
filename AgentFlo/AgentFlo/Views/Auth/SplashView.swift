import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: Spacing.xxl) {
            // App icon
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.agentRed)
                .frame(width: 72, height: 72)
                .overlay(
                    Text("A")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundStyle(.white)
                )

            // Wordmark
            HStack(spacing: 0) {
                Text("Agent")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.agentNavy)
                Text("Flo")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.agentRed)
            }

            ProgressView()
                .tint(.agentRed)
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.agentSurface)
    }
}

#Preview {
    SplashView()
}

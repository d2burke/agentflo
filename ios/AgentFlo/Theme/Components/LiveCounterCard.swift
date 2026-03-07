import SwiftUI

struct LiveCounterCard: View {
    let count: Int
    var subtitle: String = "Currently Checked In"
    var meta: String?

    var body: some View {
        VStack(spacing: 0) {
            // LIVE NOW indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.agentRed)
                    .frame(width: 7, height: 7)
                    .modifier(PulseAnimation())
                Text("LIVE NOW")
                    .font(.custom("DMSans-ExtraBold", size: 10))
                    .tracking(1.2)
                    .foregroundStyle(.agentRed)
            }
            .padding(.bottom, 8)

            // Large count
            Text("\(count)")
                .font(.liveCount)
                .tracking(-1.5)
                .foregroundStyle(.agentNavy)

            // Subtitle
            Text(subtitle)
                .font(.custom("DMSans-SemiBold", size: 12.5))
                .foregroundStyle(.agentNavy)
                .padding(.top, 3)

            // Meta
            if let meta {
                Text(meta)
                    .font(.runnerTime)
                    .foregroundStyle(.agentSlate)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }
}

private struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 0.8 : 1.0)
            .opacity(isPulsing ? 0.55 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

#Preview {
    LiveCounterCard(count: 12, meta: "3 arrivals in last 10 min")
        .padding()
}

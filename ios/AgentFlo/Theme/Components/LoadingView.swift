import SwiftUI

struct LoadingView: View {
    var message: String? = nil

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            ProgressView()
                .controlSize(.large)
                .tint(.agentRed)
            if let message {
                Text(message)
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.agentBackground)
    }
}

#Preview {
    LoadingView(message: "Loading tasks...")
}

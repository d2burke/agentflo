import SwiftUI

struct LockScreenView: View {
    @Environment(AppState.self) private var appState

    @State private var showError = false

    var body: some View {
        ZStack {
            Color.agentBackground
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // App icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.agentRed)

                Text("AgentFlo is Locked")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.agentNavy)

                Text("Authenticate to continue")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)

                Spacer()

                // Unlock button
                Button {
                    Task { await unlock() }
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: appState.biometricService.biometricIconName)
                        Text("Use \(appState.biometricService.biometricType)")
                    }
                    .font(.bodyEmphasis)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(Color.agentRed)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .task {
            await unlock()
        }
        .alert("Authentication Failed", isPresented: $showError) {
            Button("Try Again") {
                Task { await unlock() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Could not verify your identity. Please try again.")
        }
    }

    private func unlock() async {
        let success = await appState.biometricService.authenticate()
        if !success {
            showError = true
        }
    }
}

#Preview {
    LockScreenView()
        .environment(AppState.preview)
}

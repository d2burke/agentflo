import SwiftUI

struct LandingView: View {
    @State private var showCreateAccount = false
    @State private var showLogin = false
    @State private var selectedRole: UserRole?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo + wordmark
                VStack(spacing: Spacing.xxl) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.agentRed)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text("A")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundStyle(.white)
                        )

                    HStack(spacing: 0) {
                        Text("Agent")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(.agentNavy)
                        Text("Assist")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(.agentRed)
                    }

                    Text("Delegate tasks. Close deals.")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                }

                Spacer()

                // Role selection buttons
                VStack(spacing: Spacing.lg) {
                    PillButton("I'm a Real Estate Agent", variant: .primary) {
                        selectedRole = .agent
                        showCreateAccount = true
                    }

                    PillButton("I'm a Task Runner", variant: .secondary) {
                        selectedRole = .runner
                        showCreateAccount = true
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)

                // Login link
                Button {
                    showLogin = true
                } label: {
                    HStack(spacing: 0) {
                        Text("Already have an account? ")
                            .foregroundStyle(.agentSlate)
                        Text("Log In")
                            .foregroundStyle(.agentRed)
                            .bold()
                    }
                }
                .font(.bodySM)
                .padding(.top, Spacing.xxxxl)
                .padding(.bottom, Spacing.xxxxl + 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .navigationDestination(isPresented: $showCreateAccount) {
                CreateAccountView(role: selectedRole ?? .agent)
            }
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
        }
    }
}

#Preview {
    LandingView()
}

import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxxxl) {
                    Text("Welcome back")
                        .font(.titleLG)
                        .foregroundStyle(.agentNavy)

                    VStack(spacing: Spacing.xxl) {
                        InputField(label: "Email", text: $email, placeholder: "you@example.com", keyboardType: .emailAddress, textContentType: .emailAddress, autocapitalization: .never, submitLabel: .next)
                        InputField(label: "Password", text: $password, placeholder: "Enter your password", textContentType: .password, isSecure: true, submitLabel: .go) {
                            if isValid { Task { await login() } }
                        }
                    }

                    Button("Forgot your password?") {
                        // TODO: Password reset flow
                    }
                    .font(.bodySM)
                    .foregroundStyle(.agentRed)
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.sectionGap)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Spacing.xxl) {
                PillButton("Log In", isLoading: isLoading, isDisabled: !isValid) {
                    Task { await login() }
                }

                Button {
                    dismiss()
                } label: {
                    Text(
                        {
                            var result = AttributedString("Don't have an account? ")
                            result.foregroundColor = .agentSlate
                            var signUp = AttributedString("Sign Up")
                            signUp.foregroundColor = .agentRed
                            signUp.inlinePresentationIntent = .stronglyEmphasized
                            result.append(signUp)
                            return String(result.characters)
                        }()
                    )
                }
                .font(.bodySM)
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.white)
        .toast(errorMessage ?? "", style: .error, isPresented: $showError)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.agentNavy)
                }
            }
        }
    }

    private var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
        && email.contains("@")
        && !password.isEmpty
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        showError = false
        do {
            try await appState.authService.signIn(email: email, password: password)
        } catch {
            errorMessage = "Invalid email or password. Please try again."
            withAnimation(.spring(duration: 0.3)) {
                showError = true
            }
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environment(AppState())
    }
}

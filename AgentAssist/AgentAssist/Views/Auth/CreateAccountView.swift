import SwiftUI

struct CreateAccountView: View {
    let role: UserRole

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    /// Total steps: 2 when email confirmation is off, 3 when on
    private var totalSteps: Int {
        appState.authService.isAuthenticated ? 2 : 3
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressBar(current: step, total: totalSteps)
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.md)

            ScrollView {
                VStack(spacing: Spacing.xxxxl) {
                    switch step {
                    case 1: stepOneContent
                    case 2: stepTwoContent
                    case 3: stepThreeContent
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.sectionGap)
            }
            .scrollIndicators(.hidden)

            // Bottom button
            if step < 3 {
                PillButton(step == 1 ? "Continue" : "Create Account", isLoading: isLoading, isDisabled: !isStepValid) {
                    if step == 1 {
                        step = 2
                    } else {
                        Task { await createAccount() }
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, Spacing.xxxxl)
            }
        }
        .background(.agentBackground)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { handleBack() } label: {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.agentNavy)
                }
            }
        }
        .toast(errorMessage ?? "", style: .error, isPresented: $showError)
    }

    // MARK: - Step 1: Personal Info

    private var stepOneContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("Create your account")
                .font(.titleLG)
                .foregroundStyle(.agentNavy)

            InputField(label: "Full Name", text: $fullName, placeholder: "Your full name", textContentType: .name, autocapitalization: .words, submitLabel: .next)
            InputField(label: "Email", text: $email, placeholder: "you@example.com", keyboardType: .emailAddress, textContentType: .emailAddress, autocapitalization: .never, submitLabel: .next)
            InputField(label: "Phone", text: $phone, placeholder: "(512) 555-1234", keyboardType: .phonePad, textContentType: .telephoneNumber, submitLabel: .continue) {
                if isStepValid { step = 2 }
            }
        }
    }

    // MARK: - Step 2: Password

    private var stepTwoContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("Set your password")
                .font(.titleLG)
                .foregroundStyle(.agentNavy)

            InputField(label: "Password", text: $password, placeholder: "Create a password", textContentType: .newPassword, isSecure: true, submitLabel: .next)
            InputField(label: "Confirm Password", text: $confirmPassword, placeholder: "Re-enter password", textContentType: .newPassword, isSecure: true, submitLabel: .go) {
                if isStepValid { Task { await createAccount() } }
            }

            // Password requirements
            VStack(alignment: .leading, spacing: Spacing.md) {
                PasswordRequirement(text: "At least 8 characters", isMet: password.count >= 8)
                PasswordRequirement(text: "One uppercase letter", isMet: password.contains(where: { $0.isUppercase }))
                PasswordRequirement(text: "One number or symbol", isMet: password.contains(where: { $0.isNumber || $0.isPunctuation || $0.isSymbol }))
                PasswordRequirement(text: "Passwords match", isMet: !confirmPassword.isEmpty && password == confirmPassword)
            }
        }
    }

    // MARK: - Step 3: Email Verification (when confirmation is enabled)

    private var stepThreeContent: some View {
        VStack(spacing: Spacing.xxxxl) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 48))
                .foregroundStyle(.agentRed)

            VStack(spacing: Spacing.md) {
                Text("Check your email")
                    .font(.titleLG)
                    .foregroundStyle(.agentNavy)

                Text("We sent a confirmation link to **\(email)**")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)
                    .multilineTextAlignment(.center)
            }

            PillButton("I've confirmed my email") {
                Task {
                    do {
                        try await appState.authService.signIn(email: email, password: password)
                        appState.onboardingRole = role
                        appState.needsOnboarding = true
                    } catch {
                        errorMessage = "Please confirm your email first, then try again."
                        showError = true
                    }
                }
            }

            Button("Resend confirmation email") {
                // Supabase auto-sends on signup; user can sign up again to resend
            }
            .font(.bodySM)
            .foregroundStyle(.agentRed)
        }
        .padding(.top, Spacing.xxxxl)
    }

    // MARK: - Helpers

    private var isStepValid: Bool {
        switch step {
        case 1:
            return !fullName.trimmingCharacters(in: .whitespaces).isEmpty
                && !email.trimmingCharacters(in: .whitespaces).isEmpty
                && email.contains("@")
        case 2:
            return password.count >= 8
                && password.contains(where: { $0.isUppercase })
                && password.contains(where: { $0.isNumber || $0.isPunctuation || $0.isSymbol })
                && password == confirmPassword
        default:
            return true
        }
    }

    private func handleBack() {
        if step > 1 {
            step -= 1
        } else {
            dismiss()
        }
    }

    private func createAccount() async {
        isLoading = true
        errorMessage = nil
        showError = false
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await appState.authService.signUp(
                email: trimmedEmail,
                password: password,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                role: role
            )
            if appState.authService.isAuthenticated {
                // Email confirmation disabled — go straight to onboarding
                appState.onboardingRole = role
                appState.needsOnboarding = true
            } else {
                // Email confirmation required — show step 3
                step = 3
            }
        } catch {
            errorMessage = friendlyError(from: error)
            showError = true
        }
        isLoading = false
    }

    private func friendlyError(from error: Error) -> String {
        let raw = error.localizedDescription
        print("[CreateAccount] Signup error: \(raw)")
        let message = raw.lowercased()
        if message.contains("rate limit") {
            return "Too many attempts. Please wait a moment and try again."
        } else if message.contains("already registered") || message.contains("duplicate key") || message.contains("unique") {
            return "An account with this email already exists. Try logging in instead."
        } else if message.contains("row-level security") || message.contains("policy") {
            return "Account setup failed. Please try again or contact support."
        } else if message.contains("invalid email") || message.contains("email is invalid") || message.contains("email address is not valid") || (message.contains("email") && message.contains("invalid")) {
            return "Please enter a valid email address."
        }
        return "Something went wrong: \(raw)"
    }
}

// MARK: - Supporting Views

struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...total, id: \.self) { index in
                RoundedRectangle(cornerRadius: Radius.progress)
                    .fill(index <= current ? Color.agentRed : Color.agentBorder)
                    .frame(height: 4)
            }
        }
    }
}

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(isMet ? .agentGreen : .agentSlateLight)
            Text(text)
                .font(.caption)
                .foregroundStyle(isMet ? .agentNavy : .agentSlateLight)
        }
    }
}

#Preview {
    NavigationStack {
        CreateAccountView(role: .agent)
            .environment(AppState.preview)
    }
}

import SwiftUI

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var passwordValid: Bool {
        newPassword.count >= 8
        && newPassword.contains(where: { $0.isUppercase })
        && newPassword.contains(where: { $0.isNumber || $0.isPunctuation || $0.isSymbol })
        && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    Text("Create a new password for your account.")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)

                    InputField(label: "New Password", text: $newPassword, placeholder: "Create a password", textContentType: .newPassword, isSecure: true, submitLabel: .next)
                    InputField(label: "Confirm Password", text: $confirmPassword, placeholder: "Re-enter password", textContentType: .newPassword, isSecure: true, submitLabel: .go) {
                        if passwordValid { Task { await changePassword() } }
                    }

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        PasswordRequirement(text: "At least 8 characters", isMet: newPassword.count >= 8)
                        PasswordRequirement(text: "One uppercase letter", isMet: newPassword.contains(where: { $0.isUppercase }))
                        PasswordRequirement(text: "One number or symbol", isMet: newPassword.contains(where: { $0.isNumber || $0.isPunctuation || $0.isSymbol }))
                        PasswordRequirement(text: "Passwords match", isMet: !confirmPassword.isEmpty && newPassword == confirmPassword)
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.xxl)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Spacing.lg) {
                PillButton("Update Password", isLoading: isLoading, isDisabled: !passwordValid) {
                    Task { await changePassword() }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, Spacing.xxxxl)

            .background(.agentBackground)
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.agentSlate)
                }
            }
            .toast(errorMessage ?? "", style: .error, isPresented: $showError)
        }
    }

    private func changePassword() async {
        isLoading = true
        showError = false
        do {
            try await supabase.auth.update(user: .init(password: newPassword))
            dismiss()
        } catch {
            errorMessage = "Failed to update password: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }
}

#Preview {
    ChangePasswordSheet()
}

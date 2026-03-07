import SwiftUI

struct AccountSecurityView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var showDeleteConfirm = false

    @State private var isAuthenticating = false
    @State private var showAuthSuccess = false

    private var user: AppUser? { appState.authService.currentUser }

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { appState.biometricService.isBiometricEnabled },
            set: { newValue in
                if newValue {
                    // Authenticate before enabling
                    isAuthenticating = true
                    Task {
                        let success = await appState.biometricService.authenticate()
                        await MainActor.run {
                            if success {
                                appState.biometricService.isBiometricEnabled = true
                            }
                            isAuthenticating = false
                        }
                    }
                } else {
                    appState.biometricService.isBiometricEnabled = false
                    appState.biometricService.isLocked = false
                }
            }
        )
    }

    var body: some View {
        List {
            Section("Account") {
                HStack {
                    Text("Email")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                    Spacer()
                    Text(user?.email ?? "")
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                }
                HStack {
                    Text("Role")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                    Spacer()
                    Text(user?.role == .agent ? "Agent" : "Runner")
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                }
                HStack {
                    Text("Member since")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlate)
                    Spacer()
                    Text(user?.createdAt?.formatted(.dateTime.month(.wide).year()) ?? "")
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                }
            }

            Section("Security") {
                Button {
                    showChangePassword = true
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.agentSlate)
                        Text("Change Password")
                            .font(.bodySM)
                            .foregroundStyle(.agentNavy)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.agentSlateLight)
                    }
                }

                if appState.biometricService.isBiometricAvailable {
                    Toggle(isOn: biometricBinding) {
                        HStack {
                            Image(systemName: appState.biometricService.biometricIconName)
                                .foregroundStyle(.agentSlate)
                            Text("Require \(appState.biometricService.biometricType)")
                                .font(.bodySM)
                                .foregroundStyle(.agentNavy)
                        }
                    }
                    .tint(.agentRed)

                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete Account")
                    }
                    .font(.bodyEmphasis)
                }
            } footer: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                    .font(.caption)
            }
        }
        .navigationTitle("Account & Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if appState.biometricService.isBiometricAvailable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let success = await appState.biometricService.authenticate()
                            if success { showAuthSuccess = true }
                        }
                    } label: {
                        Image(systemName: appState.biometricService.biometricIconName)
                            .font(.title3)
                            .foregroundStyle(.agentRed)
                    }
                }
            }
        }
        .onAppear {
            appState.biometricService.checkBiometricAvailability()
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet()
                .presentationDragIndicator(.visible)
        }
        .alert("\(appState.biometricService.biometricType) Verified", isPresented: $showAuthSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Authentication successful.")
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // TODO: Account deletion flow
            }
        } message: {
            Text("This will permanently delete your account. This cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        AccountSecurityView()
    }
    .environment(AppState.preview)
}

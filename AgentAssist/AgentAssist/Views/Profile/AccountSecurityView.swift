import SwiftUI

struct AccountSecurityView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var showDeleteConfirm = false

    private var user: AppUser? { appState.authService.currentUser }

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
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet()
                .presentationDragIndicator(.visible)
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

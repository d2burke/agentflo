import SwiftUI

struct EarningsView: View {
    @Environment(AppState.self) private var appState

    @State private var completedTasks: [AgentTask] = []
    @State private var isLoading = true

    private var user: AppUser? { appState.authService.currentUser }

    private var totalEarnings: Int {
        completedTasks
            .filter { $0.status == .completed }
            .compactMap(\.runnerPayout)
            .reduce(0, +)
    }

    private var tasksCompleted: Int {
        completedTasks.filter { $0.status == .completed }.count
    }

    private var formattedTotal: String {
        let dollars = Double(totalEarnings) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                // Earnings card
                VStack(spacing: Spacing.lg) {
                    Text("Total Earnings")
                        .font(.bodySM)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(formattedTotal)
                        .font(.priceLG)
                        .foregroundStyle(.white)
                    HStack(spacing: Spacing.xxxxl) {
                        statItem(value: "\(tasksCompleted)", label: "Tasks")
                        statItem(value: averagePerTask, label: "Avg / Task")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxxl)
                .background(LinearGradient.navyGradient)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))

                // Recent payouts
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    Text("Recent Completed Tasks")
                        .font(.titleMD)
                        .foregroundStyle(.agentNavy)

                    if isLoading {
                        LoadingView(message: "Loading earnings...")
                            .frame(height: 200)
                    } else if completedTasks.isEmpty {
                        EmptyStateView(
                            icon: "dollarsign.circle",
                            title: "No earnings yet",
                            message: "Complete tasks to start earning. Your payouts will appear here."
                        )
                    } else {
                        ForEach(completedTasks.filter { $0.status == .completed }.prefix(10)) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.category.capitalized)
                                        .font(.bodyEmphasis)
                                        .foregroundStyle(.agentNavy)
                                    Text(task.propertyAddress)
                                        .font(.caption)
                                        .foregroundStyle(.agentSlate)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(task.formattedPayout)
                                    .font(.priceSM)
                                    .foregroundStyle(.agentGreen)
                            }
                            .padding(.vertical, Spacing.sm)
                            if task.id != completedTasks.filter({ $0.status == .completed }).prefix(10).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(.agentBackground)
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTasks() }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.titleMD)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var averagePerTask: String {
        guard tasksCompleted > 0 else { return "$0" }
        let avg = Double(totalEarnings) / Double(tasksCompleted) / 100.0
        return String(format: "$%.0f", avg)
    }

    private func loadTasks() async {
        guard let user else { return }
        do {
            completedTasks = try await appState.taskService.fetchTasks(forRunner: user.id)
        } catch {
            print("[Earnings] Failed to load: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        EarningsView()
    }
    .environment(AppState.previewRunner)
}

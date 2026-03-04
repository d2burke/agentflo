import SwiftUI
import Supabase

struct OpenHouseVisitorDashboard: View {
    let taskId: UUID
    var isLive: Bool = true

    @Environment(AppState.self) private var appState
    @State private var visitors: [OpenHouseVisitor] = []
    @State private var isLoading = true
    @State private var showShareSheet = false

    private var totalCount: Int { visitors.count }
    private var preApprovedCount: Int { visitors.filter(\.preApproved).count }
    private var veryInterestedCount: Int { visitors.filter { $0.interestLevel == "very_interested" }.count }

    var body: some View {
        if isLive {
            // Sheet presentation with NavigationStack
            NavigationStack {
                content
                    .navigationTitle("Visitors")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showShareSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [formatVisitorList()])
            }
        } else {
            // Inline embedded — no NavigationStack
            content
        }
    }

    private var content: some View {
        VStack(spacing: Spacing.sectionGap) {
            summaryCard
            visitorList
        }
        .task {
            await loadVisitors()
            if isLive { subscribeToVisitors() }
        }
        .onDisappear {
            if isLive { appState.messageService.unsubscribe() }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(value: "\(totalCount)", label: "Visitors")
            Divider().frame(height: 32)
            summaryItem(value: "\(preApprovedCount)", label: "Pre-Approved")
            Divider().frame(height: 32)
            summaryItem(value: "\(veryInterestedCount)", label: "Very Interested")
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.titleMD)
                .foregroundStyle(.agentNavy)
            Text(label)
                .font(.caption)
                .foregroundStyle(.agentSlate)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Visitor List

    private var visitorList: some View {
        VStack(spacing: Spacing.md) {
            if isLoading {
                LoadingView()
            } else if visitors.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "person.3")
                        .font(.system(size: 32))
                        .foregroundStyle(.agentSlateLight)
                    Text("No visitors yet")
                        .font(.bodySM)
                        .foregroundStyle(.agentSlateLight)
                    if isLive {
                        Text("Visitors will appear here as they check in.")
                            .font(.caption)
                            .foregroundStyle(.agentSlateLight)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxxl)
            } else {
                ForEach(visitors) { visitor in
                    visitorCard(visitor)
                }
            }
        }
    }

    private func visitorCard(_ visitor: OpenHouseVisitor) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                // Initials avatar
                Text(initials(for: visitor.visitorName))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.agentNavySolid)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(visitor.visitorName)
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)

                    if let time = visitor.createdAt {
                        Text(time.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.agentSlateLight)
                    }
                }

                Spacer()

                interestBadge(visitor.interestLevel)
            }

            HStack(spacing: Spacing.xxl) {
                if let email = visitor.email {
                    Label(email, systemImage: "envelope")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }
                if let phone = visitor.phone {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundStyle(.agentSlate)
                }
            }

            HStack(spacing: Spacing.md) {
                if visitor.preApproved {
                    miniTag("Pre-Approved", color: .agentGreen)
                }
                if visitor.agentRepresented {
                    miniTag("Has Agent", color: .agentAmber)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func interestBadge(_ level: String) -> some View {
        let (text, color): (String, Color) = {
            switch level {
            case "very_interested": ("Very Interested", .agentGreen)
            case "interested": ("Interested", .agentBlue)
            default: ("Looking", .agentSlate)
            }
        }()
        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func miniTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Data

    private func loadVisitors() async {
        do {
            visitors = try await appState.taskService.fetchVisitors(taskId: taskId)
        } catch {
            print("[Visitors] Failed to load: \(error)")
        }
        isLoading = false
    }

    private func subscribeToVisitors() {
        let channel = supabase.realtimeV2.channel("visitors:\(taskId.uuidString)")
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "open_house_visitors",
            filter: "task_id=eq.\(taskId.uuidString)"
        )

        Task {
            await channel.subscribe()
            for await insertion in insertions {
                do {
                    let visitor = try insertion.decodeRecord(as: OpenHouseVisitor.self, decoder: JSONDecoder())
                    await MainActor.run {
                        if !visitors.contains(where: { $0.id == visitor.id }) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                visitors.insert(visitor, at: 0)
                            }
                        }
                    }
                } catch {
                    print("[Visitors] Failed to decode realtime visitor: \(error)")
                }
            }
        }
    }

    private func formatVisitorList() -> String {
        var lines = ["Open House Visitor Report", "Total: \(totalCount) visitors\n"]
        for visitor in visitors {
            var line = "\(visitor.visitorName) — \(visitor.interestDisplayName)"
            if let email = visitor.email { line += " | \(email)" }
            if let phone = visitor.phone { line += " | \(phone)" }
            if visitor.preApproved { line += " | Pre-Approved" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}

import SwiftUI

struct InspectionReportView: View {
    let taskId: UUID

    @Environment(AppState.self) private var appState
    @State private var findings: [InspectionFinding] = []
    @State private var isLoading = true
    @State private var selectedTab = 0

    private var summary: InspectionSummary {
        InspectionSummary(findings: findings)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                LoadingView(message: "Loading report...")
            } else {
                tabPicker
                TabView(selection: $selectedTab) {
                    overviewTab.tag(0)
                    findingsTab.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(.agentBackground)
        .navigationTitle("Inspection Report")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFindings() }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton("Overview", index: 0)
            tabButton("Findings", index: 1)
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.top, Spacing.md)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation { selectedTab = index }
        } label: {
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(selectedTab == index ? .agentNavy : .agentSlate)
                Rectangle()
                    .fill(selectedTab == index ? Color.agentRed : .clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                severitySummaryCard
                systemOverview
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.vertical, Spacing.lg)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private var severitySummaryCard: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Findings Summary")
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Spacer()
                Text("\(summary.totalFindings) total")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)
            }

            HStack(spacing: Spacing.lg) {
                summaryStatItem("\(summary.criticalCount)", label: "Critical", color: .red)
                summaryStatItem("\(summary.majorCount)", label: "Major", color: .orange)
                summaryStatItem("\(summary.minorCount)", label: "Minor", color: .yellow)
                summaryStatItem("\(summary.totalPhotos)", label: "Photos", color: .blue)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func summaryStatItem(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.titleMD)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.agentSlate)
        }
        .frame(maxWidth: .infinity)
    }

    private var systemOverview: some View {
        VStack(spacing: Spacing.md) {
            ForEach(ASHISystem.allCases, id: \.self) { system in
                let systemFindings = findings.filter { $0.systemCategory == system }
                let defCount = systemFindings.filter { $0.status == .deficiency }.count
                let hasCritical = systemFindings.contains { $0.severity == .critical }

                HStack {
                    Image(systemName: system.iconName)
                        .foregroundStyle(hasCritical ? .red : (defCount > 0 ? .orange : .agentGreen))
                        .frame(width: 24)

                    Text(system.displayName)
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)

                    Spacer()

                    if defCount > 0 {
                        Text("\(defCount) issue\(defCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(hasCritical ? .red : .orange)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.agentGreen)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    // MARK: - Findings Tab

    private var findingsTab: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                let deficiencies = findings.filter { $0.status == .deficiency }
                    .sorted { ($0.severity?.rawValue ?? "") < ($1.severity?.rawValue ?? "") }

                if deficiencies.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.agentGreen)
                        Text("No deficiencies found")
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxxxl)
                } else {
                    ForEach(deficiencies) { finding in
                        findingCard(finding)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.vertical, Spacing.lg)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private func findingCard(_ finding: InspectionFinding) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(finding.subItem)
                    .font(.bodyEmphasis)
                    .foregroundStyle(.agentNavy)
                Spacer()
                if let severity = finding.severity {
                    Text(severity.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(severity.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(severity.color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(finding.systemCategory.displayName)
                .font(.caption)
                .foregroundStyle(.agentSlate)

            if let desc = finding.description, !desc.isEmpty {
                Text(desc)
                    .font(.bodySM)
                    .foregroundStyle(.agentNavy)
            }

            if let rec = finding.recommendation, !rec.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommendation")
                        .font(.captionSM)
                        .foregroundStyle(.agentSlate)
                    Text(rec)
                        .font(.bodySM)
                        .foregroundStyle(.agentNavy)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    // MARK: - Data

    private func loadFindings() async {
        do {
            findings = try await appState.inspectionService.fetchFindings(taskId: taskId)
        } catch {
            print("[InspectionReport] Failed to load: \(error)")
        }
        isLoading = false
    }
}

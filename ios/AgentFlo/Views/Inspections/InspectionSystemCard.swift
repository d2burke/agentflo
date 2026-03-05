import SwiftUI

struct InspectionSystemCard: View {
    let system: ASHISystem
    let findings: [InspectionFinding]
    let onTap: () -> Void

    private var completedItems: Int {
        findings.count
    }

    private var totalItems: Int {
        system.subItems.count
    }

    private var deficiencyCount: Int {
        findings.filter { $0.status == .deficiency }.count
    }

    private var isComplete: Bool {
        completedItems >= totalItems
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: system.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(isComplete ? .agentGreen : .agentSlate)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(system.displayName)
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)

                    HStack(spacing: Spacing.md) {
                        Text("\(completedItems)/\(totalItems) items")
                            .font(.caption)
                            .foregroundStyle(.agentSlate)

                        if deficiencyCount > 0 {
                            Text("\(deficiencyCount) deficienc\(deficiencyCount == 1 ? "y" : "ies")")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.agentGreen)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.agentSlateLight)
                }
            }
            .padding(Spacing.cardPadding)
            .background(.agentSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .shadow(color: Shadows.card, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

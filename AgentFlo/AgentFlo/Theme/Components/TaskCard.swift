import SwiftUI

struct TaskCard: View {
    let task: AgentTask
    var onAgentTap: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Row 1: Category icon + title inline with status badge
            HStack(alignment: .center) {
                HStack(spacing: Spacing.md) {
                    CategoryIcon(category: task.category)
                    Text(task.category)
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)
                }
                Spacer()
                StatusBadge(status: task.status)
            }

            // Row 2: Agent name (runner view only)
            if let agent = task.agentProfile {
                Button {
                    onAgentTap?(agent.id)
                } label: {
                    Label {
                        Text("Posted by \(agent.fullName)")
                    } icon: {
                        Image(systemName: "person.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
                }
                .buttonStyle(.plain)
                .disabled(onAgentTap == nil)
            }

            // Row 3: Address on its own line
            Text(task.propertyAddress)
                .font(.bodySM)
                .foregroundStyle(.agentSlate)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Row 4: Date/time left + Price right (lower baseline)
            HStack(alignment: .lastTextBaseline) {
                if let scheduledAt = task.scheduledAt {
                    Label {
                        Text(scheduledAt.formatted(date: .abbreviated, time: .shortened))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(.agentSlate)
                } else {
                    Text("No date set")
                        .font(.caption)
                        .foregroundStyle(.agentSlateLight)
                }

                Spacer()

                Text(task.formattedPrice)
                    .font(.priceSM)
                    .foregroundStyle(.agentNavy)
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }
}

struct CategoryIcon: View {
    let category: String

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 20))
            .foregroundStyle(.agentRed)
            .frame(width: 40, height: 40)
            .background(Color.agentRedLight)
            .clipShape(Circle())
    }

    private var iconName: String {
        switch category.lowercased() {
        case "photography": "camera.fill"
        case "showing": "eye.fill"
        case "staging": "paintbrush.fill"
        case "open house": "house.fill"
        case "inspection": "doc.text.magnifyingglass"
        default: "briefcase.fill"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TaskCard(task: .preview)
        TaskCard(task: AgentTask(category: "Showing", status: .inProgress, propertyAddress: "567 Oak Ave, Dallas, TX 75201", price: 7500, scheduledAt: .now))
    }
    .padding()
    .background(Color.agentBackground)
}

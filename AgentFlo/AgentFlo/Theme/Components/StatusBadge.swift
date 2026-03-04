import SwiftUI

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.displayName)
            .font(.captionSM)
            .foregroundStyle(status.textColor)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(status.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

extension TaskStatus {
    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .posted: "Posted"
        case .accepted: "Accepted"
        case .inProgress: "In Progress"
        case .deliverablesSubmitted: "Review"
        case .revisionRequested: "Revision"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }

    var textColor: Color {
        switch self {
        case .draft: .agentSlate
        case .posted, .deliverablesSubmitted: .agentBlue
        case .accepted, .completed: .agentGreen
        case .inProgress, .revisionRequested: .agentAmber
        case .cancelled: .agentError
        }
    }

    var backgroundColor: Color {
        switch self {
        case .draft: .agentBorderLight
        case .posted, .deliverablesSubmitted: .agentBlueLight
        case .accepted, .completed: .agentGreenLight
        case .inProgress, .revisionRequested: .agentAmberLight
        case .cancelled: .agentErrorLight
        }
    }

    var iconName: String {
        switch self {
        case .draft: "doc"
        case .posted: "paperplane"
        case .accepted: "checkmark.circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .deliverablesSubmitted: "doc.text.magnifyingglass"
        case .revisionRequested: "arrow.uturn.backward"
        case .completed: "checkmark.seal.fill"
        case .cancelled: "xmark.circle"
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        StatusBadge(status: .posted)
        StatusBadge(status: .inProgress)
        StatusBadge(status: .completed)
        StatusBadge(status: .cancelled)
    }
}

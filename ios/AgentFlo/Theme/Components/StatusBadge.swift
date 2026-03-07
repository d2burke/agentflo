import SwiftUI

struct StatusBadge: View {
    let status: TaskStatus
    var category: TaskCategory? = nil

    private var semantic: StatusBadgeSemantic {
        if let category {
            // Build a temporary task-like mapping
            return semanticFor(status: status, category: category)
        }
        // Fallback without category
        switch status {
        case .draft: return .done
        case .posted, .deliverablesSubmitted: return .pending
        case .accepted, .completed: return .active
        case .inProgress, .revisionRequested: return .working
        case .cancelled: return .alert
        }
    }

    private var label: String {
        if let category {
            return displayStatusFor(status: status, category: category)
        }
        return status.displayName
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(semantic.dotColor)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.custom("DMSans-Bold", size: 11))
                .foregroundStyle(semantic.textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(semantic.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func displayStatusFor(status: TaskStatus, category: TaskCategory) -> String {
        switch (category, status) {
        case (.photography, .inProgress): return "Shooting"
        case (.photography, .deliverablesSubmitted): return "Delivered"
        case (.staging, .deliverablesSubmitted), (.staging, .completed): return "Staged"
        case (.openHouse, .accepted): return "Scheduled"
        case (.openHouse, .inProgress): return "Live"
        case (.inspection, .accepted): return "Confirmed"
        case (.inspection, .inProgress): return "Inspecting"
        case (.inspection, .deliverablesSubmitted): return "Report Ready"
        case (_, .posted): return "Pending"
        default: return status.displayName
        }
    }

    private func semanticFor(status: TaskStatus, category: TaskCategory) -> StatusBadgeSemantic {
        switch (category, status) {
        case (_, .posted): return .pending
        case (_, .cancelled): return .alert
        case (.openHouse, .accepted): return .pending
        case (_, .accepted): return .active
        case (.openHouse, .inProgress): return .alert
        case (_, .inProgress): return .working
        case (.photography, .deliverablesSubmitted): return .active
        case (.inspection, .deliverablesSubmitted): return .alert
        case (_, .deliverablesSubmitted): return .pending
        case (.staging, .completed): return .done
        case (_, .completed): return .done
        default: return .done
        }
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
    VStack(spacing: 8) {
        StatusBadge(status: .posted)
        StatusBadge(status: .inProgress, category: .photography)
        StatusBadge(status: .inProgress, category: .openHouse)
        StatusBadge(status: .deliverablesSubmitted, category: .inspection)
        StatusBadge(status: .completed)
    }
}

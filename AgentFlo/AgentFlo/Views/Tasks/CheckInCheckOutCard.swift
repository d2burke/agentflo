import SwiftUI

struct CheckInCheckOutCard: View {
    let task: AgentTask
    let deliverables: [Deliverable]

    private var durationMinutes: Int? {
        guard let checkIn = task.checkedInAt, let checkOut = task.checkedOutAt else { return nil }
        return Int(checkOut.timeIntervalSince(checkIn) / 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Check-in row
            if let checkedIn = task.checkedInAt {
                HStack(spacing: Spacing.lg) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.agentGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Checked In")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlate)
                        Text(checkedIn.formatted(date: .abbreviated, time: .shortened))
                            .font(.bodySM)
                            .foregroundStyle(.agentNavy)
                    }
                    Spacer()
                    if let lat = task.checkedInLat, let lng = task.checkedInLng {
                        Text("\(lat, specifier: "%.4f"), \(lng, specifier: "%.4f")")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlateLight)
                    }
                }
            }

            // Check-out row
            if let checkedOut = task.checkedOutAt {
                HStack(spacing: Spacing.lg) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.agentRed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Checked Out")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlate)
                        Text(checkedOut.formatted(date: .abbreviated, time: .shortened))
                            .font(.bodySM)
                            .foregroundStyle(.agentNavy)
                    }
                    Spacer()
                    if let lat = task.checkedOutLat, let lng = task.checkedOutLng {
                        Text("\(lat, specifier: "%.4f"), \(lng, specifier: "%.4f")")
                            .font(.captionSM)
                            .foregroundStyle(.agentSlateLight)
                    }
                }
            }

            // Duration
            if let minutes = durationMinutes {
                Divider()
                HStack(spacing: Spacing.lg) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.agentSlate)
                    Text("Duration")
                        .font(.captionSM)
                        .foregroundStyle(.agentSlate)
                    Spacer()
                    Text(formatDuration(minutes))
                        .font(.bodyEmphasis)
                        .foregroundStyle(.agentNavy)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .background(.agentSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Shadows.card, radius: 4, y: 2)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
    }
}

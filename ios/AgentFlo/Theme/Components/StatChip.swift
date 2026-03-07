import SwiftUI

struct StatChip: View {
    let value: String
    let label: String
    var isAccent: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.chipValue)
                .tracking(-0.4)
                .foregroundStyle(isAccent ? Color.agentRed : .agentNavy)
            Text(label)
                .font(.chipLabel)
                .foregroundStyle(isAccent ? Color.agentRed.opacity(0.7) : .agentSlate)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isAccent ? Color.agentRedLight : Color(red: 0.961, green: 0.961, blue: 0.969))
        .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner))
    }
}

struct StatChipsRow: View {
    let chips: [(value: String, label: String, accent: Bool)]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                StatChip(value: chip.value, label: chip.label, isAccent: chip.accent)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatChipsRow(chips: [
            (value: "14", label: "Shot", accent: false),
            (value: "14", label: "Remaining", accent: false),
            (value: "3", label: "Rooms", accent: false),
        ])
        StatChipsRow(chips: [
            (value: "18", label: "Visitors", accent: true),
            (value: "7", label: "Leads", accent: false),
            (value: "3 hrs", label: "Duration", accent: false),
        ])
    }
    .padding()
}

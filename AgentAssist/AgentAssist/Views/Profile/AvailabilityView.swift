import SwiftUI

struct AvailabilityView: View {
    @State private var availability: [DayAvailability] = DayAvailability.defaultWeek

    struct DayAvailability: Identifiable {
        let id = UUID()
        let day: String
        var isAvailable: Bool
        var startTime: Date
        var endTime: Date

        static var defaultWeek: [DayAvailability] {
            let calendar = Calendar.current
            let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
            let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: .now)!
            return [
                DayAvailability(day: "Monday", isAvailable: true, startTime: start, endTime: end),
                DayAvailability(day: "Tuesday", isAvailable: true, startTime: start, endTime: end),
                DayAvailability(day: "Wednesday", isAvailable: true, startTime: start, endTime: end),
                DayAvailability(day: "Thursday", isAvailable: true, startTime: start, endTime: end),
                DayAvailability(day: "Friday", isAvailable: true, startTime: start, endTime: end),
                DayAvailability(day: "Saturday", isAvailable: false, startTime: start, endTime: end),
                DayAvailability(day: "Sunday", isAvailable: false, startTime: start, endTime: end),
            ]
        }
    }

    var body: some View {
        List {
            Section {
                Text("Set your weekly availability so agents know when you can accept tasks.")
                    .font(.bodySM)
                    .foregroundStyle(.agentSlate)
                    .listRowBackground(Color.clear)
            }

            ForEach($availability) { $day in
                Section {
                    Toggle(isOn: $day.isAvailable) {
                        Text(day.day)
                            .font(.bodyEmphasis)
                            .foregroundStyle(.agentNavy)
                    }
                    .tint(.agentRed)

                    if day.isAvailable {
                        DatePicker("Start", selection: $day.startTime, displayedComponents: .hourAndMinute)
                            .font(.bodySM)
                        DatePicker("End", selection: $day.endTime, displayedComponents: .hourAndMinute)
                            .font(.bodySM)
                    }
                }
            }

            Section {
                PillButton("Save Availability") {
                    // TODO: Save to Supabase
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AvailabilityView()
    }
}

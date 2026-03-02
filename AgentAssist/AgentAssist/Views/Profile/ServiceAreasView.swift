import SwiftUI

struct ServiceAreasView: View {
    @State private var areas: [String] = []
    @State private var newArea = ""
    @State private var showAddField = false

    var body: some View {
        VStack(spacing: 0) {
            if areas.isEmpty && !showAddField {
                emptyState
            } else {
                List {
                    Section("Your Service Areas") {
                        ForEach(areas, id: \.self) { area in
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.agentRed)
                                Text(area)
                                    .font(.bodySM)
                                    .foregroundStyle(.agentNavy)
                            }
                        }
                        .onDelete { indexSet in
                            areas.remove(atOffsets: indexSet)
                        }
                    }

                    if showAddField {
                        Section("Add Area") {
                            HStack {
                                TextField("e.g. Austin, TX 78701", text: $newArea)
                                    .font(.bodySM)
                                    .textContentType(.fullStreetAddress)
                                Button("Add") {
                                    let trimmed = newArea.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        areas.append(trimmed)
                                        newArea = ""
                                        showAddField = false
                                    }
                                }
                                .foregroundStyle(.agentRed)
                                .font(.bodyEmphasis)
                            }
                        }
                    }
                }
            }
        }
        .background(.agentBackground)
        .navigationTitle("Service Areas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddField = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.agentRed)
                }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "map.fill",
            title: "No Service Areas",
            message: "Add the zip codes or neighborhoods where you're available to work.",
            buttonTitle: "Add Service Area",
            buttonAction: { showAddField = true }
        )
    }
}

#Preview {
    NavigationStack {
        ServiceAreasView()
    }
}

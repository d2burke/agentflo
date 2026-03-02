import Foundation

@Observable
final class BrokerageCompleter {
    var suggestions: [String] = []
    private var debounceTask: Task<Void, Never>?

    private static let brokerages: [String] = [
        // National
        "Keller Williams Realty",
        "RE/MAX",
        "Coldwell Banker",
        "Century 21",
        "Berkshire Hathaway HomeServices",
        "eXp Realty",
        "Compass",
        "Sotheby's International Realty",
        "HomeSmart",
        "Redfin",
        "EXIT Realty",
        "Better Homes and Gardens Real Estate",
        "United Real Estate",
        "Weichert Realtors",
        "Howard Hanna",
        "Long & Foster",
        "Anywhere Real Estate",
        "Douglas Elliman",
        "Engel & Völkers",
        "The Agency",
        "Side Real Estate",
        "Real Brokerage",
        "PLACE",
        "Fathom Realty",
        "NextHome",
        // Texas
        "Keller Williams Austin",
        "Keller Williams Heritage",
        "Keller Williams San Antonio",
        "Compass Texas",
        "eXp Realty Texas",
        "RE/MAX Austin",
        "RE/MAX San Antonio",
        "Coldwell Banker D'Ann Harper",
        "JBGoodwin Realtors",
        "Kuper Sotheby's International Realty",
        "Moreland Properties",
        "Realty Austin",
        "All City Real Estate",
        "Phyllis Browning Company",
        "Independence Title",
        "Dave Perry-Miller Real Estate",
        "Ebby Halliday Realtors",
        "Allie Beth Allman & Associates",
        "Greenwood King Properties",
        "Martha Turner Sotheby's",
        // New York
        "The Corcoran Group",
        "Brown Harris Stevens",
        "Halstead Real Estate",
        "Nest Seekers International",
        "Compass NYC",
        "Douglas Elliman New York",
        "CORE Real Estate",
        "Stribling & Associates",
        "Warburg Realty",
        "Town Residential",
        "Elliman",
        "Fox Residential Group",
        "Bond New York",
        "Level Group",
        "Bohemia Realty Group",
    ]

    func search(query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let lowercased = trimmed.lowercased()
            let filtered = Self.brokerages.filter {
                $0.lowercased().contains(lowercased)
            }
            await MainActor.run {
                suggestions = Array(filtered.prefix(5))
            }
        }
    }
}

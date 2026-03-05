import SwiftUI

// All color definitions come from Asset Catalog color sets (Assets.xcassets/*.colorset).
// Xcode auto-generates Color extensions AND ShapeStyle extensions via GeneratedAssetSymbols.
// Usage: Color.agentRed, .foregroundStyle(.agentNavy), .background(.agentSurface), etc.

// Navy gradient for cards — always dark, not adaptive
// (white text overlays these, so they must stay dark in both modes)
extension LinearGradient {
    static let navyGradient = LinearGradient(
        colors: [Color(red: 0.071, green: 0.125, blue: 0.227),
                 Color(red: 0.102, green: 0.176, blue: 0.302)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

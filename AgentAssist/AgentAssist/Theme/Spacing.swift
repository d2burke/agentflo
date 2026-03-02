import SwiftUI

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let base: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 14
    static let xxl: CGFloat = 16
    static let xxxl: CGFloat = 20
    static let xxxxl: CGFloat = 24

    // Layout-specific
    static let screenPadding: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let tabBarInset: CGFloat = 16
    static let tabBarHeight: CGFloat = 52
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let card: CGFloat = 12
    static let input: CGFloat = 12
    static let pill: CGFloat = 999
    static let progress: CGFloat = 3
}

enum Shadows {
    static let card = Color.agentNavy.opacity(0.06)
    static let sheet = Color.agentNavy.opacity(0.12)
}

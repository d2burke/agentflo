import SwiftUI

extension Color {
    // Primary
    static let agentRed = Color(red: 0.784, green: 0.063, blue: 0.180) // #C8102E
    static let agentRedHover = Color(red: 0.627, green: 0.051, blue: 0.141) // #A00D24
    static let agentRedLight = Color(red: 0.992, green: 0.910, blue: 0.925) // #FDE8EC
    static let agentRedGlow = Color(red: 0.784, green: 0.063, blue: 0.180).opacity(0.15)

    // Navy
    static let agentNavy = Color(red: 0.040, green: 0.086, blue: 0.157) // #0A1628
    static let agentNavyLight = Color(red: 0.071, green: 0.125, blue: 0.227) // #12203A
    static let agentNavyMid = Color(red: 0.102, green: 0.176, blue: 0.302) // #1A2D4D

    // Slate
    static let agentSlate = Color(red: 0.392, green: 0.455, blue: 0.545) // #64748B
    static let agentSlateLight = Color(red: 0.580, green: 0.639, blue: 0.722) // #94A3B8

    // Borders & Backgrounds
    static let agentBorder = Color(red: 0.886, green: 0.910, blue: 0.941) // #E2E8F0
    static let agentBorderLight = Color(red: 0.945, green: 0.961, blue: 0.976) // #F1F5F9
    static let agentBackground = Color(red: 0.973, green: 0.980, blue: 0.988) // #F8FAFC

    // Semantic
    static let agentGreen = Color(red: 0.086, green: 0.639, blue: 0.290) // #16A34A
    static let agentAmber = Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706
    static let agentBlue = Color(red: 0.145, green: 0.388, blue: 0.922) // #2563EB
    static let agentError = Color(red: 0.863, green: 0.149, blue: 0.157) // #DC2626

    // Semantic Light Backgrounds
    static let agentGreenLight = Color(red: 0.863, green: 0.988, blue: 0.910)
    static let agentAmberLight = Color(red: 1.0, green: 0.957, blue: 0.835)
    static let agentBlueLight = Color(red: 0.878, green: 0.918, blue: 1.0)
    static let agentErrorLight = Color(red: 1.0, green: 0.910, blue: 0.910)
}

// ShapeStyle extensions for use in .foregroundStyle(), .background(), etc.
extension ShapeStyle where Self == Color {
    static var agentRed: Color { Color.agentRed }
    static var agentRedHover: Color { Color.agentRedHover }
    static var agentRedLight: Color { Color.agentRedLight }
    static var agentNavy: Color { Color.agentNavy }
    static var agentNavyLight: Color { Color.agentNavyLight }
    static var agentNavyMid: Color { Color.agentNavyMid }
    static var agentSlate: Color { Color.agentSlate }
    static var agentSlateLight: Color { Color.agentSlateLight }
    static var agentBorder: Color { Color.agentBorder }
    static var agentBorderLight: Color { Color.agentBorderLight }
    static var agentBackground: Color { Color.agentBackground }
    static var agentGreen: Color { Color.agentGreen }
    static var agentAmber: Color { Color.agentAmber }
    static var agentBlue: Color { Color.agentBlue }
    static var agentError: Color { Color.agentError }
    static var agentGreenLight: Color { Color.agentGreenLight }
    static var agentAmberLight: Color { Color.agentAmberLight }
    static var agentBlueLight: Color { Color.agentBlueLight }
    static var agentErrorLight: Color { Color.agentErrorLight }
}

// Navy gradient for cards
extension LinearGradient {
    static let navyGradient = LinearGradient(
        colors: [.agentNavyLight, .agentNavyMid],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

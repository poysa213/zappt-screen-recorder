import SwiftUI
import AppKit

/// Central design tokens for Zappt. Light-mode only, minimal and modern.
enum Theme {
    // AppKit color for drawing in NSView contexts.
    static let accentNSColor = NSColor(srgbRed: 0x5B / 255.0, green: 0x5B / 255.0, blue: 0xD6 / 255.0, alpha: 1)

    // Colors
    static let accent = Color(hex: 0x5B5BD6)          // indigo
    static let accentSoft = Color(hex: 0x5B5BD6, alpha: 0.12)
    static let recordRed = Color(hex: 0xE5484D)
    static let background = Color(hex: 0xF7F7F8)        // soft gray
    static let card = Color.white
    static let separator = Color(hex: 0xE6E6E9)
    static let textPrimary = Color(hex: 0x1A1A1E)
    static let textSecondary = Color(hex: 0x6B6B76)
    static let textTertiary = Color(hex: 0x9A9AA5)

    // Metrics
    static let corner: CGFloat = 12
    static let cornerSmall: CGFloat = 8
    static let cardShadow = Color.black.opacity(0.06)

    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// A reusable white card container with soft shadow and rounded corners.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(Theme.separator, lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 4)
    }
}

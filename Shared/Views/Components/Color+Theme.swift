import SwiftUI

extension Color {
    // MARK: - StoryJuicer Theme — "Warm Library at Dusk"

    /// Rich warm parchment background
    static let sjBackground = Color(red: 0.96, green: 0.93, blue: 0.87)

    /// Card surface — warm white with clear distinction from background
    static let sjCard = Color(red: 1.0, green: 0.98, blue: 0.96)

    /// Warm terracotta accent — primary action color
    static let sjCoral = Color(red: 0.84, green: 0.36, blue: 0.28)

    /// Soft peach for highlights and selected states
    static let sjPeach = Color(red: 0.92, green: 0.70, blue: 0.58)

    /// Warm lavender for variety
    static let sjLavender = Color(red: 0.62, green: 0.55, blue: 0.78)

    /// Rich amber gold for decorative elements
    static let sjGold = Color(red: 0.82, green: 0.64, blue: 0.22)

    /// Muted teal-green for success
    static let sjMint = Color(red: 0.32, green: 0.68, blue: 0.56)

    /// Muted sky for info states
    static let sjSky = Color(red: 0.40, green: 0.62, blue: 0.82)

    /// Deep ink for primary text — high contrast on parchment
    static let sjText = Color(red: 0.15, green: 0.12, blue: 0.10)

    /// Warm brown for secondary text — tuned for stronger readability on glass
    static let sjSecondaryText = Color(red: 0.24, green: 0.20, blue: 0.17)

    /// Muted border/divider color — visible but not harsh
    static let sjBorder = Color(red: 0.78, green: 0.73, blue: 0.66)

    /// Inactive/muted element color — softened but still readable
    static let sjMuted = Color(red: 0.41, green: 0.36, blue: 0.32)

    /// Top tone for editorial paper-like backgrounds
    static let sjPaperTop = Color(red: 0.99, green: 0.97, blue: 0.92)

    /// Bottom tone for editorial paper-like backgrounds
    static let sjPaperBottom = Color(red: 0.91, green: 0.86, blue: 0.79)

    /// High-contrast text color intended for tinted glass surfaces
    static let sjGlassInk = Color(red: 0.08, green: 0.07, blue: 0.06)

    /// Soft elevated glass tint for passive surfaces
    static let sjGlassSoft = Color(red: 0.98, green: 0.95, blue: 0.90)

    /// Very subtle neutral glass tint for secondary surfaces
    static let sjGlassWeak = Color(red: 0.99, green: 0.98, blue: 0.95)

    /// More opaque warm surface tint for text-heavy glass cards
    static let sjReadableCard = Color(red: 0.98, green: 0.96, blue: 0.92)

    /// Highlight tone for accent glows and separators
    static let sjHighlight = Color(red: 0.98, green: 0.82, blue: 0.60)
}

extension ShapeStyle where Self == Color {
    static var sjBackground: Color { .sjBackground }
    static var sjCoral: Color { .sjCoral }
    static var sjCard: Color { .sjCard }
    static var sjText: Color { .sjText }
    static var sjSecondaryText: Color { .sjSecondaryText }
    static var sjGlassInk: Color { .sjGlassInk }
    static var sjReadableCard: Color { .sjReadableCard }
}

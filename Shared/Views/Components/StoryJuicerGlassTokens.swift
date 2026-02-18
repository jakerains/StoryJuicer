import SwiftUI

enum StoryJuicerGlassTokens {
    enum Radius {
        static let card: CGFloat = 18
        static let chip: CGFloat = 12
        static let input: CGFloat = 16
        static let hero: CGFloat = 20
        static let thumbnail: CGFloat = 12
    }

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Tint {
        static let subtle: Double = 0.04
        static let standard: Double = 0.09
        static let emphasis: Double = 0.14
    }

    enum Shadow {
        static let color = Color.black.opacity(0.14)
        static let radius: CGFloat = 16
        static let y: CGFloat = 8
    }
}

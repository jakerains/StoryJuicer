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

    enum Cover3D {
        static let spineWidthRatio: CGFloat = 0.065
        static let spineMinWidth: CGFloat = 16
        static let spineMaxWidth: CGFloat = 36

        static let pageEdgeWidthRatio: CGFloat = 0.03
        static let pageEdgeMinWidth: CGFloat = 6
        static let pageEdgeMaxWidth: CGFloat = 16

        static let idleYaw: Double = -5
        static let hoverYaw: Double = -7
        static let idlePitch: Double = 0.8
        static let hoverPitch: Double = 1.6
        static let hoverScale: CGFloat = 1.01
        static let perspective: CGFloat = 0.45

        static let topBevelOpacity: Double = 0.2
        static let bottomShadowOpacity: Double = 0.42
        static let glossOpacity: Double = 0.09
    }
}

import SwiftUI

enum StoryJuicerMotion {
    static let fast = Animation.easeInOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.24)
    static let emphasis = Animation.easeInOut(duration: 0.33)

    /// Spring animation for the 3D page turn effect.
    static let pageTurn = Animation.easeInOut(duration: 0.9)
    /// Faster variant for keyboard-driven page turns.
    static let pageTurnFast = Animation.easeInOut(duration: 0.65)
}

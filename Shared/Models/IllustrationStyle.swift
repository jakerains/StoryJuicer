import Foundation
import ImagePlayground

enum IllustrationStyle: String, CaseIterable, Identifiable, Sendable {
    case illustration
    case animation
    case sketch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .illustration: "Illustration"
        case .animation:    "Animation"
        case .sketch:       "Sketch"
        }
    }

    var description: String {
        switch self {
        case .illustration: "Classic children's book illustration style"
        case .animation:    "Pixar-inspired cartoon style"
        case .sketch:       "Hand-drawn pencil sketch style"
        }
    }

    var iconName: String {
        switch self {
        case .illustration: "paintbrush.fill"
        case .animation:    "film"
        case .sketch:       "pencil.and.outline"
        }
    }

    var playgroundStyle: ImagePlaygroundStyle {
        switch self {
        case .illustration: .illustration
        case .animation:    .animation
        case .sketch:       .sketch
        }
    }
}

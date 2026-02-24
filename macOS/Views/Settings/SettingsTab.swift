import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case onDevice
    case cloud
    case premium
    case about
    case debug

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .onDevice: "On-Device"
        case .cloud: "Cloud"
        case .premium: "Premium"
        case .about: "About"
        case .debug: "Debug"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "sparkles.rectangle.stack"
        case .onDevice: "desktopcomputer"
        case .cloud: "cloud"
        case .premium: "crown.fill"
        case .about: "info.circle"
        case .debug: "ladybug"
        }
    }

    /// All tabs shown by default (excludes premium and debug, which are hidden in public builds).
    static var defaultTabs: [SettingsTab] {
        allCases.filter { $0 != .debug && $0 != .premium }
    }
}

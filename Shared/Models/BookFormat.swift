import Foundation

enum BookFormat: String, CaseIterable, Identifiable, Sendable {
    case standard
    case landscape
    case small
    case portrait

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:  "Standard Square"
        case .landscape: "Landscape"
        case .small:     "Small Square"
        case .portrait:  "Portrait"
        }
    }

    var description: String {
        switch self {
        case .standard:  "Classic 8.5\" × 8.5\" square picture book format"
        case .landscape: "Wide 11\" × 8.5\" landscape for panoramic illustrations"
        case .small:     "Compact 6\" × 6\" mini board book format"
        case .portrait:  "Tall 8.5\" × 11\" portrait format"
        }
    }

    /// Dimensions in points at 72 DPI (for screen display)
    var dimensions: CGSize {
        switch self {
        case .standard:  CGSize(width: 612, height: 612)    // 8.5 × 8.5 inches
        case .landscape: CGSize(width: 792, height: 612)    // 11 × 8.5 inches
        case .small:     CGSize(width: 432, height: 432)    // 6 × 6 inches
        case .portrait:  CGSize(width: 612, height: 792)    // 8.5 × 11 inches
        }
    }

    /// Dimensions in pixels at 300 DPI (for print-ready PDF)
    var printDimensions: CGSize {
        switch self {
        case .standard:  CGSize(width: 2550, height: 2550)
        case .landscape: CGSize(width: 3300, height: 2550)
        case .small:     CGSize(width: 1800, height: 1800)
        case .portrait:  CGSize(width: 2550, height: 3300)
        }
    }

    /// Aspect ratio (width / height)
    var aspectRatio: CGFloat {
        dimensions.width / dimensions.height
    }

    /// Icon name using SF Symbols
    var iconName: String {
        switch self {
        case .standard:  "square"
        case .landscape: "rectangle"
        case .small:     "square.dashed"
        case .portrait:  "rectangle.portrait"
        }
    }
}

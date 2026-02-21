import CoreGraphics
import Foundation

protocol StoryImageGenerating: Sendable {
    var provider: StoryImageProvider { get }

    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings,
        referenceImage: CGImage?,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> CGImage
}

extension StoryImageGenerating {
    /// Convenience overload without reference image for generators that don't support it.
    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> CGImage {
        try await generateImage(
            prompt: prompt,
            style: style,
            format: format,
            settings: settings,
            referenceImage: nil,
            onStatus: onStatus
        )
    }
}

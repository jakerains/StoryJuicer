import CoreGraphics
import Foundation
import ImagePlayground
import os

struct ImageGenerationOutcome {
    let image: CGImage
    let providerUsed: StoryImageProvider
    let didFallback: Bool
}

struct ImageGenerationRouter: Sendable {
    private static let logger = Logger(subsystem: "com.storyfox.app", category: "ImageRouter")

    private let settingsProvider: @Sendable () -> ModelSelectionSettings
    private let imagePlaygroundGenerator: ImagePlaygroundImageGenerator

    init(
        settingsProvider: @escaping @Sendable () -> ModelSelectionSettings = {
            ModelSelectionStore.load()
        },
        imagePlaygroundGenerator: ImagePlaygroundImageGenerator = ImagePlaygroundImageGenerator()
    ) {
        self.settingsProvider = settingsProvider
        self.imagePlaygroundGenerator = imagePlaygroundGenerator
    }

    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        referenceImage: CGImage? = nil,
        rankedConcepts: [RankedImageConcept]? = nil,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> ImageGenerationOutcome {
        let settings = settingsProvider()

        // Cloud image providers (don't support reference images or ranked concepts)
        if settings.imageProvider.isCloud,
           let cloudProvider = settings.imageProvider.cloudProvider {
            do {
                let generator = CloudImageGenerator(cloudProvider: cloudProvider)
                let image = try await generator.generateImage(
                    prompt: prompt,
                    style: style,
                    format: format,
                    settings: settings,
                    onStatus: onStatus
                )
                return ImageGenerationOutcome(
                    image: image,
                    providerUsed: settings.imageProvider,
                    didFallback: false
                )
            } catch {
                Self.logger.warning("Cloud image generation failed (\(cloudProvider.rawValue, privacy: .public)): \(String(describing: error), privacy: .public)")

                // Fall back to Image Playground if enabled (forward concepts)
                if settings.enableImageFallback {
                    onStatus("Cloud image generation failed, falling back to Image Playground...")
                    let image = try await imagePlaygroundGenerator.generateImage(
                        prompt: prompt,
                        style: style,
                        format: format,
                        settings: settings,
                        referenceImage: referenceImage,
                        rankedConcepts: rankedConcepts,
                        onStatus: onStatus
                    )
                    return ImageGenerationOutcome(
                        image: image,
                        providerUsed: .imagePlayground,
                        didFallback: true
                    )
                }
                throw error
            }
        }

        // Default: Image Playground (pass reference image + ranked concepts)
        do {
            let image = try await imagePlaygroundGenerator.generateImage(
                prompt: prompt,
                style: style,
                format: format,
                settings: settings,
                referenceImage: referenceImage,
                rankedConcepts: rankedConcepts,
                onStatus: onStatus
            )
            return ImageGenerationOutcome(
                image: image,
                providerUsed: .imagePlayground,
                didFallback: false
            )
        } catch {
            Self.logger.warning("Image generation failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}

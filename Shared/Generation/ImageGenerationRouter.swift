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

    /// Character photos for reference-based generation (OpenAI Premium).
    var characterPhotos: [CharacterPhotoReference] = []

    /// The premium tier, propagated to cloud image generators.
    var premiumTier: PremiumTier = .off

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
        var settings = settingsProvider()

        // Premium override: route images through the OpenAI proxy
        if premiumTier.isActive {
            settings.imageProvider = .openAI
        }

        // Cloud image providers
        if settings.imageProvider.isCloud,
           let cloudProvider = settings.imageProvider.cloudProvider {
            do {
                var generator = CloudImageGenerator(cloudProvider: cloudProvider)
                generator.characterPhotos = characterPhotos
                generator.premiumTier = premiumTier
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
                    onStatus("Switching to a different paintbrush...")
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
        let ipClock = ContinuousClock()
        let ipStart = ipClock.now
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

            // Log ImagePlayground success
            let elapsed = ipStart.duration(to: ipClock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logImageGeneration(
                sessionID: verboseSession,
                label: "Image (ImagePlayground)",
                provider: "Image Playground", model: "on-device",
                originalPrompt: prompt, styledPrompt: prompt,
                result: .success(width: image.width, height: image.height),
                duration: seconds
            )

            return ImageGenerationOutcome(
                image: image,
                providerUsed: .imagePlayground,
                didFallback: false
            )
        } catch {
            // Log ImagePlayground failure
            let elapsed = ipStart.duration(to: ipClock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logImageGeneration(
                sessionID: verboseSession,
                label: "Image (ImagePlayground)",
                provider: "Image Playground", model: "on-device",
                originalPrompt: prompt, styledPrompt: prompt,
                result: .failure(String(describing: error)),
                duration: seconds
            )

            Self.logger.warning("Image generation failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}

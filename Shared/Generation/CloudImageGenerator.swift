import CoreGraphics
import Foundation
import HuggingFace
import ImageIO
import os

/// Cloud-based image generator that implements `StoryImageGenerating`.
/// Parameterized by `CloudProvider` to work with any supported provider.
struct CloudImageGenerator: StoryImageGenerating {
    private static let logger = Logger(subsystem: "com.storyfox.app", category: "CloudImage")

    let cloudProvider: CloudProvider
    private let client: OpenAICompatibleClient
    private let settingsProvider: @Sendable () -> ModelSelectionSettings

    var provider: StoryImageProvider {
        switch cloudProvider {
        case .openRouter:  return .openRouter
        case .togetherAI:  return .togetherAI
        case .huggingFace: return .huggingFace
        case .openAI:      return .openAI
        }
    }

    init(
        cloudProvider: CloudProvider,
        client: OpenAICompatibleClient = OpenAICompatibleClient(),
        settingsProvider: @escaping @Sendable () -> ModelSelectionSettings = { ModelSelectionStore.load() }
    ) {
        self.cloudProvider = cloudProvider
        self.client = client
        self.settingsProvider = settingsProvider
    }

    /// Character photos to use as reference images (OpenAI edit endpoint only).
    var characterPhotos: [CharacterPhotoReference] = []

    /// The premium tier, used to select model/quality and gate the edit endpoint.
    var premiumTier: PremiumTier = .off

    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings,
        referenceImage: CGImage? = nil,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> CGImage {
        let apiKey: String
        if cloudProvider.usesProxy {
            apiKey = ""
        } else {
            guard let key = CloudCredentialStore.bearerToken(for: cloudProvider) else {
                throw CloudProviderError.noAPIKey(cloudProvider)
            }
            apiKey = key
        }

        let modelID = imageModelID(from: settings)
        let styledPrompt = applyStyleSuffix(to: prompt, style: style)
        let (width, height) = imageDimensions(for: format)

        onStatus("Bringing your story to life...")

        Self.logger.info("Cloud image generation: provider=\(cloudProvider.rawValue, privacy: .public) model=\(modelID, privacy: .public)")

        let imageClock = ContinuousClock()
        let imageStart = imageClock.now
        let image: CGImage

        do {
            if cloudProvider == .openAI && !characterPhotos.isEmpty && premiumTier == .premiumPlus {
                // Premium Plus: Use the edit endpoint with reference photos for character likeness
                let size = openAISize(for: format)
                let referenceData = characterPhotos.map(\.photoData)
                let characterContext = characterPhotos.map { photo in
                    "The character \(photo.name) in this scene should resemble the person/pet in the reference photo provided."
                }.joined(separator: " ")
                let editPrompt = "Create a children's book illustration. \(characterContext) Scene: \(styledPrompt)"

                let editClient = OpenAIImageEditClient()
                image = try await editClient.generateWithReferences(
                    prompt: editPrompt,
                    referenceImages: referenceData,
                    apiKey: apiKey,
                    url: cloudProvider.imageGenerationURL,
                    model: modelID,
                    size: size,
                    quality: "high",
                    inputFidelity: "high"
                )
            } else if cloudProvider == .huggingFace {
                image = try await generateWithHFInference(
                    apiKey: apiKey,
                    model: modelID,
                    prompt: styledPrompt,
                    width: width,
                    height: height
                )
            } else if cloudProvider == .openAI {
                let size = openAISize(for: format)
                let tierParam = premiumTier == .premiumPlus ? "plus" : "standard"
                image = try await client.imageGeneration(
                    url: cloudProvider.imageGenerationURL,
                    apiKey: apiKey,
                    model: modelID,
                    prompt: styledPrompt,
                    size: size,
                    extraHeaders: cloudProvider.extraHeaders,
                    skipAuth: cloudProvider.usesProxy,
                    tier: tierParam
                )
            } else {
                let size = "\(width)x\(height)"
                image = try await client.imageGeneration(
                    url: cloudProvider.imageGenerationURL,
                    apiKey: apiKey,
                    model: modelID,
                    prompt: styledPrompt,
                    size: size,
                    extraHeaders: cloudProvider.extraHeaders
                )
            }
        } catch {
            let elapsed = imageStart.duration(to: imageClock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logImageGeneration(
                sessionID: verboseSession,
                label: "Image",
                provider: cloudProvider.displayName, model: modelID,
                originalPrompt: prompt, styledPrompt: styledPrompt,
                result: .failure(String(describing: error)),
                duration: seconds
            )
            throw error
        }

        let elapsed = imageStart.duration(to: imageClock.now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
        await VerboseGenerationLogger.shared.logImageGeneration(
            sessionID: verboseSession,
            label: "Image",
            provider: cloudProvider.displayName, model: modelID,
            originalPrompt: prompt, styledPrompt: styledPrompt,
            result: .success(width: image.width, height: image.height),
            duration: seconds
        )

        Self.logger.info("Cloud image generation complete")
        return image
    }

    // MARK: - Character Sheet Generation

    /// Generate a character reference sheet in the book's art style.
    ///
    /// - Path A (photo provided): Uses the edit endpoint with the photo as reference,
    ///   style-transferring it into the book's illustration style.
    /// - Path B (no photo): Uses standard text-to-image generation from the character
    ///   description alone.
    ///
    /// Both paths go through the premium proxy (`storyfox.app/api/premium/images`).
    func generateCharacterSheet(
        prompt: String,
        referencePhoto: Data?,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings
    ) async throws -> CGImage {
        let apiKey: String
        if cloudProvider.usesProxy {
            apiKey = ""
        } else {
            guard let key = CloudCredentialStore.bearerToken(for: cloudProvider) else {
                throw CloudProviderError.noAPIKey(cloudProvider)
            }
            apiKey = key
        }

        let modelID = imageModelID(from: settings)
        let styledPrompt = applyStyleSuffix(to: prompt, style: style)
        let size = openAISize(for: format)

        Self.logger.info("Character sheet generation: provider=\(cloudProvider.rawValue, privacy: .public) hasPhoto=\(referencePhoto != nil)")

        let sheetClock = ContinuousClock()
        let sheetStart = sheetClock.now
        let result: CGImage

        do {
            if let photoData = referencePhoto {
                // Path A: Edit endpoint — style-transfer the uploaded photo
                let editClient = OpenAIImageEditClient()
                result = try await editClient.generateWithReferences(
                    prompt: styledPrompt,
                    referenceImages: [photoData],
                    apiKey: apiKey,
                    url: cloudProvider.imageGenerationURL,
                    model: modelID,
                    size: size,
                    quality: "high",
                    inputFidelity: "high"
                )
            } else {
                // Path B: Standard generation — character description to illustration
                result = try await client.imageGeneration(
                    url: cloudProvider.imageGenerationURL,
                    apiKey: apiKey,
                    model: modelID,
                    prompt: styledPrompt,
                    size: size,
                    extraHeaders: cloudProvider.extraHeaders,
                    skipAuth: cloudProvider.usesProxy
                )
            }
        } catch {
            let elapsed = sheetStart.duration(to: sheetClock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logCharacterSheet(
                sessionID: verboseSession,
                prompt: styledPrompt,
                hasReferencePhoto: referencePhoto != nil,
                result: .failure(String(describing: error)),
                duration: seconds
            )
            throw error
        }

        let elapsed = sheetStart.duration(to: sheetClock.now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
        await VerboseGenerationLogger.shared.logCharacterSheet(
            sessionID: verboseSession,
            prompt: styledPrompt,
            hasReferencePhoto: referencePhoto != nil,
            result: .success(width: result.width, height: result.height),
            duration: seconds
        )

        return result
    }

    // MARK: - HuggingFace Native Inference Path

    /// Calls the HF Inference API via the router. The router resolves the correct
    /// inference provider (hf-inference, fal-ai, replicate, etc.) for each model.
    /// Body: `{"inputs": "...", "parameters": {...}}`
    /// Response: raw image bytes (JPEG).
    private func generateWithHFInference(
        apiKey: String,
        model: String,
        prompt: String,
        width: Int,
        height: Int
    ) async throws -> CGImage {
        let url = await HFInferenceRouter.shared.inferenceURL(for: model, apiKey: apiKey)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = TimeInterval(GenerationConfig.cloudImageGenerationTimeoutSeconds)

        let body: [String: Any] = [
            "inputs": prompt,
            "parameters": [
                "width": width,
                "height": height
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        Self.logger.info("HF Inference image → \(model, privacy: .public)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudProviderError.unparsableResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudProviderError.httpError(
                statusCode: httpResponse.statusCode,
                message: String(detail.prefix(500))
            )
        }

        // Response is raw image bytes (JPEG)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CloudProviderError.imageDecodingFailed
        }

        return cgImage
    }

    // MARK: - Helpers

    private func imageModelID(from settings: ModelSelectionSettings) -> String {
        let modelID: String
        switch cloudProvider {
        case .openRouter:  modelID = settings.openRouterImageModelID
        case .togetherAI:  modelID = settings.togetherImageModelID
        case .huggingFace: modelID = settings.huggingFaceImageModelID
        case .openAI:      modelID = cloudProvider.defaultImageModelID  // Server-controlled
        }
        return modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? cloudProvider.defaultImageModelID
            : modelID
    }

    /// Maps `BookFormat` to image generation dimensions.
    private func imageDimensions(for format: BookFormat) -> (width: Int, height: Int) {
        switch format {
        case .standard, .small:
            return (1024, 1024)
        case .landscape:
            return (1792, 1024)
        case .portrait:
            return (1024, 1792)
        }
    }

    /// Maps `BookFormat` to OpenAI's supported image size strings.
    /// OpenAI supports: 1024x1024, 1536x1024 (landscape), 1024x1536 (portrait).
    private func openAISize(for format: BookFormat) -> String {
        switch format {
        case .standard, .small:
            return "1024x1024"
        case .landscape:
            return "1536x1024"
        case .portrait:
            return "1024x1536"
        }
    }

    /// Appends a style-descriptive suffix to the prompt for the diffusion model.
    /// Premium prompts already include style direction from the LLM (via `premiumStyleDirective`),
    /// so we skip the suffix to avoid redundancy and prompt bloat.
    private func applyStyleSuffix(to prompt: String, style: IllustrationStyle) -> String {
        if premiumTier.isActive {
            // Premium prompts already embed style direction from the Pass 2 LLM template.
            // Adding a suffix would duplicate it and waste prompt space.
            return prompt + ". No text, words, or letters in the image."
        }

        // Standard tier: append lightweight style reinforcement
        let suffix: String
        switch style {
        case .illustration:
            suffix = ", children's book illustration style, warm watercolor textures"
        case .animation:
            suffix = ", 3D animated cartoon style, Pixar-inspired, soft lighting"
        case .sketch:
            suffix = ", pencil sketch style, hand-drawn, delicate linework"
        }
        return prompt + suffix + ". Absolutely no text, words, letters, or numbers in the image."
    }
}

import CoreGraphics
import Foundation
import HuggingFace
import ImageIO
import os

/// Cloud-based image generator that implements `StoryImageGenerating`.
/// Parameterized by `CloudProvider` to work with any supported provider.
struct CloudImageGenerator: StoryImageGenerating {
    private static let logger = Logger(subsystem: "com.storyjuicer.app", category: "CloudImage")

    let cloudProvider: CloudProvider
    private let client: OpenAICompatibleClient
    private let settingsProvider: @Sendable () -> ModelSelectionSettings

    var provider: StoryImageProvider {
        switch cloudProvider {
        case .openRouter:  return .openRouter
        case .togetherAI:  return .togetherAI
        case .huggingFace: return .huggingFace
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

    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> CGImage {
        guard let apiKey = CloudCredentialStore.bearerToken(for: cloudProvider) else {
            throw CloudProviderError.noAPIKey(cloudProvider)
        }

        let modelID = imageModelID(from: settings)
        let styledPrompt = applyStyleSuffix(to: prompt, style: style)
        let (width, height) = imageDimensions(for: format)

        onStatus("Generating image with \(cloudProvider.displayName)...")

        Self.logger.info("Cloud image generation: provider=\(cloudProvider.rawValue, privacy: .public) model=\(modelID, privacy: .public)")

        let image: CGImage

        if cloudProvider == .huggingFace {
            image = try await generateWithHFInference(
                apiKey: apiKey,
                model: modelID,
                prompt: styledPrompt,
                width: width,
                height: height
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

        Self.logger.info("Cloud image generation complete")
        return image
    }

    // MARK: - HuggingFace Native Inference Path

    /// Calls the HF Inference API directly. The SDK's `/v1/images/generations`
    /// endpoint is broken (404), so we hit the native path instead:
    ///   POST https://router.huggingface.co/hf-inference/models/{model}
    /// Body: `{"inputs": "...", "parameters": {...}}`
    /// Response: raw image bytes (JPEG).
    private func generateWithHFInference(
        apiKey: String,
        model: String,
        prompt: String,
        width: Int,
        height: Int
    ) async throws -> CGImage {
        let url = URL(string: "https://router.huggingface.co/hf-inference/models/\(model)")!

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

    /// Appends a style-descriptive suffix to the prompt for the diffusion model.
    private func applyStyleSuffix(to prompt: String, style: IllustrationStyle) -> String {
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

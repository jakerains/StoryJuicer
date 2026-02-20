import Foundation
import os

/// Fetches and caches model lists from cloud provider APIs.
/// Uses in-memory cache (10min TTL) + UserDefaults persistence.
@Observable
@MainActor
final class CloudModelListCache {
    private static let logger = Logger(subsystem: "com.storyfox.app", category: "ModelListCache")
    private static let cacheTTL: TimeInterval = 600 // 10 minutes
    private static let defaultsKeyPrefix = "storyfox.cloudModels."

    private(set) var textModels: [CloudProvider: [CloudModelInfo]] = [:]
    private(set) var imageModels: [CloudProvider: [CloudModelInfo]] = [:]
    private(set) var isLoading: [CloudProvider: Bool] = [:]
    private(set) var lastError: [CloudProvider: String] = [:]

    private var lastFetchTime: [CloudProvider: Date] = [:]
    private let client = OpenAICompatibleClient()

    init() {
        loadFromDefaults()
    }

    /// Refresh models for a specific provider (if stale or forced).
    func refreshModels(for provider: CloudProvider, force: Bool = false) async {
        guard !force else {
            await fetchModels(for: provider)
            return
        }

        if let lastFetch = lastFetchTime[provider],
           Date().timeIntervalSince(lastFetch) < Self.cacheTTL {
            return // Cache is fresh
        }

        await fetchModels(for: provider)
    }

    /// Refresh models for all providers that have credentials.
    func refreshAllAuthenticated() async {
        for provider in CloudProvider.allCases where CloudCredentialStore.isAuthenticated(for: provider) {
            await fetchModels(for: provider)
        }
    }

    private func fetchModels(for provider: CloudProvider) async {
        guard let apiKey = CloudCredentialStore.bearerToken(for: provider) else {
            lastError[provider] = "Not authenticated"
            return
        }

        isLoading[provider] = true
        lastError[provider] = nil

        do {
            let (text, image) = try await fetchAndParse(provider: provider, apiKey: apiKey)
            textModels[provider] = text
            imageModels[provider] = image
            lastFetchTime[provider] = Date()
            saveToDefaults(provider: provider, text: text, image: image)
            Self.logger.info("Fetched \(text.count) text + \(image.count) image models for \(provider.rawValue, privacy: .public)")
        } catch {
            lastError[provider] = error.localizedDescription
            Self.logger.warning("Model fetch failed for \(provider.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
        }

        isLoading[provider] = false
    }

    private func fetchAndParse(
        provider: CloudProvider,
        apiKey: String
    ) async throws -> (text: [CloudModelInfo], image: [CloudModelInfo]) {
        switch provider {
        case .openRouter:
            return try await fetchOpenRouterModels(apiKey: apiKey)
        case .togetherAI:
            return try await fetchTogetherModels(apiKey: apiKey)
        case .huggingFace:
            return try await fetchHuggingFaceModels(apiKey: apiKey)
        }
    }

    // MARK: - OpenRouter

    private func fetchOpenRouterModels(apiKey: String) async throws -> ([CloudModelInfo], [CloudModelInfo]) {
        let data = try await client.fetchModels(
            url: CloudProvider.openRouter.modelListURL,
            apiKey: apiKey,
            extraHeaders: CloudProvider.openRouter.extraHeaders
        )

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            // Return curated models even if the API fetch fails
            return (Self.curatedOpenRouterTextModels, Self.curatedOpenRouterImageModels)
        }

        // Collect curated model IDs to avoid duplicates
        let curatedTextIDs = Set(Self.curatedOpenRouterTextModels.map(\.id))
        let curatedImageIDs = Set(Self.curatedOpenRouterImageModels.map(\.id))

        var text: [CloudModelInfo] = []
        var image: [CloudModelInfo] = []

        for model in models {
            guard let id = model["id"] as? String else { continue }
            let name = (model["name"] as? String) ?? id

            // Determine modality from architecture or id patterns
            let arch = model["architecture"] as? [String: Any]
            let modality = arch?["modality"] as? String ?? ""

            if modality.contains("image") || id.contains("flux") || id.contains("dall-e") || id.contains("stable-diffusion") || id.contains("image") {
                if !curatedImageIDs.contains(id) {
                    image.append(CloudModelInfo(id: id, displayName: name, provider: .openRouter, modality: .image))
                }
            } else {
                if !curatedTextIDs.contains(id) {
                    text.append(CloudModelInfo(id: id, displayName: name, provider: .openRouter, modality: .text))
                }
            }
        }

        // Curated models always appear at the top
        return (Self.curatedOpenRouterTextModels + text, Self.curatedOpenRouterImageModels + image)
    }

    // MARK: - Together AI

    private func fetchTogetherModels(apiKey: String) async throws -> ([CloudModelInfo], [CloudModelInfo]) {
        let data = try await client.fetchModels(
            url: CloudProvider.togetherAI.modelListURL,
            apiKey: apiKey,
            extraHeaders: CloudProvider.togetherAI.extraHeaders
        )

        guard let models = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Together may return { data: [...] }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                return parseTogetherModels(dataArray)
            }
            return ([], [])
        }

        return parseTogetherModels(models)
    }

    private func parseTogetherModels(_ models: [[String: Any]]) -> ([CloudModelInfo], [CloudModelInfo]) {
        var text: [CloudModelInfo] = []
        var image: [CloudModelInfo] = []

        for model in models {
            guard let id = model["id"] as? String else { continue }
            let name = (model["display_name"] as? String) ?? id
            let type = (model["type"] as? String) ?? ""

            if type == "image" || id.contains("flux") || id.contains("stable-diffusion") {
                image.append(CloudModelInfo(id: id, displayName: name, provider: .togetherAI, modality: .image))
            } else if type == "chat" || type == "language" {
                text.append(CloudModelInfo(id: id, displayName: name, provider: .togetherAI, modality: .text))
            }
        }

        return (text, image)
    }

    // MARK: - HuggingFace

    private func fetchHuggingFaceModels(apiKey: String) async throws -> ([CloudModelInfo], [CloudModelInfo]) {
        // Fetch text models
        var textURL = URLComponents(url: CloudProvider.huggingFace.modelListURL, resolvingAgainstBaseURL: false)!
        textURL.queryItems = [
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "inference", value: "warm")
        ]

        // Fetch image models
        var imageURL = URLComponents(url: CloudProvider.huggingFace.modelListURL, resolvingAgainstBaseURL: false)!
        imageURL.queryItems = [
            URLQueryItem(name: "pipeline_tag", value: "text-to-image"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "inference", value: "warm")
        ]

        async let textData = client.fetchModels(
            url: textURL.url!,
            apiKey: apiKey,
            extraHeaders: CloudProvider.huggingFace.extraHeaders
        )
        async let imageData = client.fetchModels(
            url: imageURL.url!,
            apiKey: apiKey,
            extraHeaders: CloudProvider.huggingFace.extraHeaders
        )

        let text = parseHuggingFaceModels(try await textData, provider: .huggingFace, modality: .text)
        let image = parseHuggingFaceModels(try await imageData, provider: .huggingFace, modality: .image)

        return (text, image)
    }

    /// Curated text models for HuggingFace — always shown at the top of the picker.
    static let curatedHFTextModels: [CloudModelInfo] = [
        CloudModelInfo(id: "openai/gpt-oss-120b", displayName: "GPT-OSS 120B", provider: .huggingFace, modality: .text),
        CloudModelInfo(id: "openai/gpt-oss-20b", displayName: "GPT-OSS 20B", provider: .huggingFace, modality: .text),
        CloudModelInfo(id: "Qwen/Qwen3-32B", displayName: "Qwen3 32B", provider: .huggingFace, modality: .text),
        CloudModelInfo(id: "deepseek-ai/DeepSeek-V3", displayName: "DeepSeek V3", provider: .huggingFace, modality: .text),
        CloudModelInfo(id: "meta-llama/Llama-3.1-8B-Instruct", displayName: "Llama 3.1 8B Instruct", provider: .huggingFace, modality: .text),
        CloudModelInfo(id: "mistralai/Mistral-7B-Instruct-v0.2", displayName: "Mistral 7B Instruct", provider: .huggingFace, modality: .text),
    ]

    /// Curated image models known to work well with HF Inference.
    static let curatedHFImageModels: [CloudModelInfo] = [
        CloudModelInfo(id: "black-forest-labs/FLUX.1-schnell", displayName: "FLUX.1 schnell", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-dev", displayName: "FLUX.1 dev", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "Tongyi-MAI/Z-Image-Turbo", displayName: "Z-Image Turbo", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "tencent/HunyuanImage-3.0", displayName: "HunyuanImage 3.0", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "stabilityai/stable-diffusion-3.5-medium", displayName: "Stable Diffusion 3.5 Medium", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "HiDream-ai/HiDream-I1-Fast", displayName: "HiDream I1 Fast", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-Canny-dev", displayName: "FLUX.1 Canny dev", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-Depth-dev", displayName: "FLUX.1 Depth dev", provider: .huggingFace, modality: .image),
    ]

    /// Curated text models for OpenRouter — always shown at the top of the picker.
    static let curatedOpenRouterTextModels: [CloudModelInfo] = [
        CloudModelInfo(id: "google/gemini-3-flash-preview", displayName: "Gemini 3 Flash Preview", provider: .openRouter, modality: .text),
        CloudModelInfo(id: "openai/gpt-5-mini", displayName: "GPT-5 Mini", provider: .openRouter, modality: .text),
        CloudModelInfo(id: "anthropic/claude-sonnet-4.6", displayName: "Claude Sonnet 4.6", provider: .openRouter, modality: .text),
        CloudModelInfo(id: "openai/gpt-5.2", displayName: "GPT-5.2", provider: .openRouter, modality: .text),
        CloudModelInfo(id: "google/gemini-3.1-pro-preview", displayName: "Gemini 3.1 Pro Preview", provider: .openRouter, modality: .text),
    ]

    /// Curated image models for OpenRouter — always shown at the top of the picker.
    static let curatedOpenRouterImageModels: [CloudModelInfo] = [
        CloudModelInfo(id: "google/gemini-3-pro-image-preview", displayName: "Nano Banana Pro", provider: .openRouter, modality: .image),
        CloudModelInfo(id: "google/gemini-2.5-flash-image", displayName: "Nano Banana", provider: .openRouter, modality: .image),
        CloudModelInfo(id: "openai/gpt-5-image", displayName: "GPT-5 Image", provider: .openRouter, modality: .image),
        CloudModelInfo(id: "openai/gpt-5-image-mini", displayName: "GPT-5 Image Mini", provider: .openRouter, modality: .image),
    ]

    private func parseHuggingFaceModels(_ data: Data, provider: CloudProvider, modality: CloudModelModality) -> [CloudModelInfo] {
        // For image models, use curated Black Forest Labs list instead of dynamic API results
        if modality == .image {
            return Self.curatedHFImageModels
        }

        let curatedIDs = Set(Self.curatedHFTextModels.map(\.id))

        guard let models = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return Self.curatedHFTextModels
        }

        let dynamic = models.compactMap { model -> CloudModelInfo? in
            guard let id = model["id"] as? String, !curatedIDs.contains(id) else { return nil }
            let name = (model["modelId"] as? String) ?? id
            return CloudModelInfo(id: id, displayName: name, provider: provider, modality: modality)
        }

        return Self.curatedHFTextModels + dynamic
    }

    // MARK: - UserDefaults Persistence

    private func saveToDefaults(provider: CloudProvider, text: [CloudModelInfo], image: [CloudModelInfo]) {
        let key = Self.defaultsKeyPrefix + provider.rawValue
        let dto = CachedModelList(
            textModelIDs: text.map(\.id),
            textModelNames: text.map(\.displayName),
            imageModelIDs: image.map(\.id),
            imageModelNames: image.map(\.displayName)
        )
        if let data = try? JSONEncoder().encode(dto) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadFromDefaults() {
        // Always seed HF models with curated lists
        textModels[.huggingFace] = Self.curatedHFTextModels
        imageModels[.huggingFace] = Self.curatedHFImageModels

        // Always seed OpenRouter with curated models
        textModels[.openRouter] = Self.curatedOpenRouterTextModels
        imageModels[.openRouter] = Self.curatedOpenRouterImageModels

        for provider in CloudProvider.allCases {
            let key = Self.defaultsKeyPrefix + provider.rawValue
            guard let data = UserDefaults.standard.data(forKey: key),
                  let dto = try? JSONDecoder().decode(CachedModelList.self, from: data) else {
                continue
            }

            // For OpenRouter, merge cached models after curated ones (avoid overwriting)
            if provider == .openRouter {
                let curatedTextIDs = Set(Self.curatedOpenRouterTextModels.map(\.id))
                let curatedImageIDs = Set(Self.curatedOpenRouterImageModels.map(\.id))

                let extraText = zip(dto.textModelIDs, dto.textModelNames).compactMap { id, name -> CloudModelInfo? in
                    curatedTextIDs.contains(id) ? nil : CloudModelInfo(id: id, displayName: name, provider: provider, modality: .text)
                }
                let extraImage = zip(dto.imageModelIDs, dto.imageModelNames).compactMap { id, name -> CloudModelInfo? in
                    curatedImageIDs.contains(id) ? nil : CloudModelInfo(id: id, displayName: name, provider: provider, modality: .image)
                }

                textModels[provider] = Self.curatedOpenRouterTextModels + extraText
                imageModels[provider] = Self.curatedOpenRouterImageModels + extraImage
            } else if provider == .huggingFace {
                // Merge cached text models after curated ones (avoid overwriting)
                let curatedTextIDs = Set(Self.curatedHFTextModels.map(\.id))
                let extraText = zip(dto.textModelIDs, dto.textModelNames).compactMap { id, name -> CloudModelInfo? in
                    curatedTextIDs.contains(id) ? nil : CloudModelInfo(id: id, displayName: name, provider: provider, modality: .text)
                }
                textModels[provider] = Self.curatedHFTextModels + extraText
                // Image models always use curated list (already set above)
            } else {
                textModels[provider] = zip(dto.textModelIDs, dto.textModelNames).map {
                    CloudModelInfo(id: $0.0, displayName: $0.1, provider: provider, modality: .text)
                }
                imageModels[provider] = zip(dto.imageModelIDs, dto.imageModelNames).map {
                    CloudModelInfo(id: $0.0, displayName: $0.1, provider: provider, modality: .image)
                }
            }
        }
    }
}

private struct CachedModelList: Codable {
    let textModelIDs: [String]
    let textModelNames: [String]
    let imageModelIDs: [String]
    let imageModelNames: [String]
}

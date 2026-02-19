import Foundation
import os

/// Fetches and caches model lists from cloud provider APIs.
/// Uses in-memory cache (10min TTL) + UserDefaults persistence.
@Observable
@MainActor
final class CloudModelListCache {
    private static let logger = Logger(subsystem: "com.storyjuicer.app", category: "ModelListCache")
    private static let cacheTTL: TimeInterval = 600 // 10 minutes
    private static let defaultsKeyPrefix = "storyjuicer.cloudModels."

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
            return ([], [])
        }

        var text: [CloudModelInfo] = []
        var image: [CloudModelInfo] = []

        for model in models {
            guard let id = model["id"] as? String else { continue }
            let name = (model["name"] as? String) ?? id

            // Determine modality from architecture or id patterns
            let arch = model["architecture"] as? [String: Any]
            let modality = arch?["modality"] as? String ?? ""

            if modality.contains("image") || id.contains("flux") || id.contains("dall-e") || id.contains("stable-diffusion") {
                image.append(CloudModelInfo(id: id, displayName: name, provider: .openRouter, modality: .image))
            } else {
                text.append(CloudModelInfo(id: id, displayName: name, provider: .openRouter, modality: .text))
            }
        }

        return (text, image)
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

    /// Curated Black Forest Labs image models known to work well with HF Inference.
    static let curatedHFImageModels: [CloudModelInfo] = [
        CloudModelInfo(id: "black-forest-labs/FLUX.1-schnell", displayName: "FLUX.1 schnell", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-dev", displayName: "FLUX.1 dev", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-Canny-dev", displayName: "FLUX.1 Canny dev", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-Depth-dev", displayName: "FLUX.1 Depth dev", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-Redux-dev", displayName: "FLUX.1 Redux dev", provider: .huggingFace, modality: .image),
        CloudModelInfo(id: "black-forest-labs/FLUX.1-Fill-dev", displayName: "FLUX.1 Fill dev", provider: .huggingFace, modality: .image),
    ]

    private func parseHuggingFaceModels(_ data: Data, provider: CloudProvider, modality: CloudModelModality) -> [CloudModelInfo] {
        // For image models, use curated Black Forest Labs list instead of dynamic API results
        if modality == .image {
            return Self.curatedHFImageModels
        }

        guard let models = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return models.compactMap { model -> CloudModelInfo? in
            guard let id = model["id"] as? String else { return nil }
            let name = (model["modelId"] as? String) ?? id
            return CloudModelInfo(id: id, displayName: name, provider: provider, modality: modality)
        }
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
        // Always seed HF image models with curated Black Forest Labs list
        imageModels[.huggingFace] = Self.curatedHFImageModels

        for provider in CloudProvider.allCases {
            let key = Self.defaultsKeyPrefix + provider.rawValue
            guard let data = UserDefaults.standard.data(forKey: key),
                  let dto = try? JSONDecoder().decode(CachedModelList.self, from: data) else {
                continue
            }

            textModels[provider] = zip(dto.textModelIDs, dto.textModelNames).map {
                CloudModelInfo(id: $0.0, displayName: $0.1, provider: provider, modality: .text)
            }
            // For HF image models, always use curated list (already set above)
            if provider != .huggingFace || dto.imageModelIDs.isEmpty {
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

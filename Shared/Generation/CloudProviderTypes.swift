import Foundation

enum CloudProvider: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case openRouter
    case togetherAI
    case huggingFace
    case openAI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRouter:  return "OpenRouter"
        case .togetherAI:  return "Together AI"
        case .huggingFace: return "Hugging Face"
        case .openAI:      return "StoryFox Premium"
        }
    }

    var baseURL: URL {
        switch self {
        case .openRouter:  return URL(string: "https://openrouter.ai/api/v1")!
        case .togetherAI:  return URL(string: "https://api.together.xyz/v1")!
        case .huggingFace: return URL(string: "https://router.huggingface.co/v1")!
        case .openAI:      return URL(string: "https://storyfox.app/api/premium")!
        }
    }

    var chatCompletionURL: URL {
        switch self {
        case .openAI:
            return URL(string: "https://storyfox.app/api/premium/text")!
        default:
            return baseURL.appendingPathComponent("chat/completions")
        }
    }

    var imageGenerationURL: URL {
        switch self {
        case .openRouter:
            return baseURL.appendingPathComponent("images/generations")
        case .togetherAI:
            return URL(string: "https://api.together.xyz/v1/images/generations")!
        case .huggingFace:
            return URL(string: "https://router.huggingface.co/v1/images/generations")!
        case .openAI:
            return URL(string: "https://storyfox.app/api/premium/images")!
        }
    }

    var modelListURL: URL {
        switch self {
        case .openRouter:
            return baseURL.appendingPathComponent("models")
        case .togetherAI:
            return baseURL.appendingPathComponent("models")
        case .huggingFace:
            // HuggingFace uses inference API model list
            return URL(string: "https://huggingface.co/api/models")!
        case .openAI:
            return URL(string: "https://storyfox.app/api/premium/config")!
        }
    }

    /// Extra HTTP headers required by this provider (e.g. OpenRouter's referer).
    /// For `.openAI`, includes the dev bypass secret if configured.
    var extraHeaders: [String: String] {
        switch self {
        case .openRouter:
            return [
                "HTTP-Referer": "https://storyfox.app",
                "X-Title": "StoryFox"
            ]
        case .openAI:
            let secret = UserDefaults.standard.string(forKey: "devBypassSecret") ?? ""
            if secret.isEmpty { return [:] }
            return ["X-Dev-Bypass": secret]
        case .togetherAI, .huggingFace:
            return [:]
        }
    }

    /// Whether this provider routes through the Vercel proxy (no client-side API key needed).
    var usesProxy: Bool {
        switch self {
        case .openAI: return true
        case .openRouter, .togetherAI, .huggingFace: return false
        }
    }

    /// Whether this provider supports OAuth login (in addition to API key).
    var supportsOAuth: Bool {
        switch self {
        case .huggingFace: return true
        case .openRouter, .togetherAI, .openAI: return false
        }
    }

    /// URL where users can create/manage API tokens for this provider.
    var tokenSettingsURL: URL? {
        switch self {
        case .openRouter:  return URL(string: "https://openrouter.ai/keys")
        case .togetherAI:  return URL(string: "https://api.together.ai/settings/api-keys")
        case .huggingFace: return URL(string: "https://huggingface.co/settings/tokens")
        case .openAI:      return URL(string: "https://platform.openai.com/api-keys")
        }
    }

    /// Keychain service identifier for this provider.
    var keychainService: String {
        "com.jakerains.StoryFox.cloud.\(rawValue)"
    }

    var defaultTextModelID: String {
        switch self {
        case .openRouter:  return "google/gemini-3-flash-preview"
        case .togetherAI:  return "meta-llama/Llama-4-Maverick-17B-128E-Instruct-Turbo"
        case .huggingFace: return "openai/gpt-oss-120b"
        case .openAI:      return "gpt-5-mini"
        }
    }

    var defaultImageModelID: String {
        switch self {
        case .openRouter:  return "google/gemini-3-pro-image-preview"
        case .togetherAI:  return "black-forest-labs/FLUX.1.1-pro"
        case .huggingFace: return "black-forest-labs/FLUX.1-schnell"
        case .openAI:      return "gpt-image-1-mini"
        }
    }
}

/// Lightweight model descriptor returned by provider APIs.
struct CloudModelInfo: Identifiable, Sendable, Hashable {
    let id: String
    let displayName: String
    let provider: CloudProvider
    let modality: CloudModelModality
    var isRecommended: Bool = false
}

enum CloudModelModality: String, Sendable, Hashable {
    case text
    case image
}

/// Resolves the correct HuggingFace Inference API URL for a given model.
///
/// HuggingFace routes models through different inference providers (hf-inference, fal-ai,
/// replicate, etc.). Not all models are available on all providers. This actor queries the
/// HF API for the model's provider mapping and picks the best available one.
actor HFInferenceRouter {
    static let shared = HFInferenceRouter()

    private var cache: [String: URL] = [:]
    private let preferredProviders = ["hf-inference", "fal-ai", "replicate", "together", "wavespeed", "nscale"]

    /// Returns the inference URL for the given HuggingFace model ID.
    /// Queries the HF API on first call per model, then caches the result.
    func inferenceURL(for modelID: String, apiKey: String) async -> URL {
        if let cached = cache[modelID] { return cached }

        let url = await resolveProvider(for: modelID, apiKey: apiKey)
        cache[modelID] = url
        return url
    }

    /// Clear cached provider mappings (e.g. when switching accounts).
    func clearCache() {
        cache.removeAll()
    }

    private func resolveProvider(for modelID: String, apiKey: String) async -> URL {
        let fallback = URL(string: "https://router.huggingface.co/hf-inference/models/\(modelID)")!

        guard let apiURL = URL(string: "https://huggingface.co/api/models/\(modelID)?expand[]=inferenceProviderMapping") else {
            return fallback
        }

        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mapping = json["inferenceProviderMapping"] as? [String: Any] else {
            return fallback
        }

        for provider in preferredProviders {
            if let info = mapping[provider] as? [String: Any],
               let status = info["status"] as? String,
               status == "live" {
                return URL(string: "https://router.huggingface.co/\(provider)/models/\(modelID)")!
            }
        }

        return fallback
    }
}

/// Errors specific to cloud provider operations.
enum CloudProviderError: LocalizedError {
    case noAPIKey(CloudProvider)
    case httpError(statusCode: Int, message: String)
    case rateLimited(retryAfterSeconds: Int?)
    case unparsableResponse
    case custom(String)
    case imageDecodingFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "\(provider.displayName) API key is not configured."
        case .httpError(let statusCode, let message):
            return "Cloud request failed (\(statusCode)): \(message)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(seconds) seconds."
            }
            return "Rate limited. Please wait and try again."
        case .unparsableResponse:
            return "Cloud model response could not be parsed."
        case .custom(let message):
            return message
        case .imageDecodingFailed:
            return "Could not decode image from cloud response."
        case .timeout:
            return "Cloud request timed out."
        }
    }
}

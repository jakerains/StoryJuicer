import Foundation

enum CloudProvider: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case openRouter
    case togetherAI
    case huggingFace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRouter:  return "OpenRouter"
        case .togetherAI:  return "Together AI"
        case .huggingFace: return "Hugging Face"
        }
    }

    var baseURL: URL {
        switch self {
        case .openRouter:  return URL(string: "https://openrouter.ai/api/v1")!
        case .togetherAI:  return URL(string: "https://api.together.xyz/v1")!
        case .huggingFace: return URL(string: "https://router.huggingface.co/v1")!
        }
    }

    var chatCompletionURL: URL {
        baseURL.appendingPathComponent("chat/completions")
    }

    var imageGenerationURL: URL {
        switch self {
        case .openRouter:
            return baseURL.appendingPathComponent("images/generations")
        case .togetherAI:
            return URL(string: "https://api.together.xyz/v1/images/generations")!
        case .huggingFace:
            return URL(string: "https://router.huggingface.co/v1/images/generations")!
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
        }
    }

    /// Extra HTTP headers required by this provider (e.g. OpenRouter's referer).
    var extraHeaders: [String: String] {
        switch self {
        case .openRouter:
            return [
                "HTTP-Referer": "https://storyfox.app",
                "X-Title": "StoryFox"
            ]
        case .togetherAI, .huggingFace:
            return [:]
        }
    }

    /// Whether this provider supports OAuth login (in addition to API key).
    var supportsOAuth: Bool {
        switch self {
        case .huggingFace: return true
        case .openRouter, .togetherAI: return false
        }
    }

    /// URL where users can create/manage API tokens for this provider.
    var tokenSettingsURL: URL? {
        switch self {
        case .openRouter:  return URL(string: "https://openrouter.ai/keys")
        case .togetherAI:  return URL(string: "https://api.together.ai/settings/api-keys")
        case .huggingFace: return URL(string: "https://huggingface.co/settings/tokens")
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
        }
    }

    var defaultImageModelID: String {
        switch self {
        case .openRouter:  return "google/gemini-3-pro-image-preview"
        case .togetherAI:  return "black-forest-labs/FLUX.1.1-pro"
        case .huggingFace: return "black-forest-labs/FLUX.1-schnell"
        }
    }
}

/// Lightweight model descriptor returned by provider APIs.
struct CloudModelInfo: Identifiable, Sendable, Hashable {
    let id: String
    let displayName: String
    let provider: CloudProvider
    let modality: CloudModelModality
}

enum CloudModelModality: String, Sendable, Hashable {
    case text
    case image
}

/// Errors specific to cloud provider operations.
enum CloudProviderError: LocalizedError {
    case noAPIKey(CloudProvider)
    case httpError(statusCode: Int, message: String)
    case rateLimited(retryAfterSeconds: Int?)
    case unparsableResponse
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
        case .imageDecodingFailed:
            return "Could not decode image from cloud response."
        case .timeout:
            return "Cloud request timed out."
        }
    }
}

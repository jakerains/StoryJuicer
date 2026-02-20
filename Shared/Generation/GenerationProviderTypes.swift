import Foundation

enum StoryTextProvider: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case appleFoundation
    case mlxSwift
    case openRouter
    case togetherAI
    case huggingFace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleFoundation: return "Apple Foundation"
        case .mlxSwift:        return "MLX Swift"
        case .openRouter:      return "OpenRouter"
        case .togetherAI:      return "Together AI"
        case .huggingFace:     return "Hugging Face"
        }
    }

    var description: String {
        switch self {
        case .appleFoundation: return "Apple on-device Foundation Models."
        case .mlxSwift:        return "Open-weight local models via MLX Swift."
        case .openRouter:      return "Cloud models via OpenRouter API."
        case .togetherAI:      return "Cloud models via Together AI API."
        case .huggingFace:     return "Cloud models via Hugging Face Inference."
        }
    }

    /// Whether this provider uses a cloud API (vs. on-device).
    var isCloud: Bool {
        switch self {
        case .openRouter, .togetherAI, .huggingFace: return true
        case .appleFoundation, .mlxSwift: return false
        }
    }

    /// The associated `CloudProvider` for cloud-based providers.
    var cloudProvider: CloudProvider? {
        switch self {
        case .openRouter:  return .openRouter
        case .togetherAI:  return .togetherAI
        case .huggingFace: return .huggingFace
        case .appleFoundation, .mlxSwift: return nil
        }
    }
}

enum StoryImageProvider: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case imagePlayground
    case diffusers
    case openRouter
    case togetherAI
    case huggingFace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .imagePlayground: return "Image Playground"
        case .diffusers:       return "Diffusers (FLUX.2 Local)"
        case .openRouter:      return "OpenRouter"
        case .togetherAI:      return "Together AI"
        case .huggingFace:     return "Hugging Face"
        }
    }

    var isCloud: Bool {
        switch self {
        case .openRouter, .togetherAI, .huggingFace: return true
        case .imagePlayground, .diffusers: return false
        }
    }

    var cloudProvider: CloudProvider? {
        switch self {
        case .openRouter:  return .openRouter
        case .togetherAI:  return .togetherAI
        case .huggingFace: return .huggingFace
        case .imagePlayground, .diffusers: return nil
        }
    }
}

struct CuratedMLXModel: Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let details: String
}

struct CuratedDiffusersImageModel: Sendable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let details: String
}

struct ModelSelectionSettings: Codable, Sendable, Equatable {
    var textProvider: StoryTextProvider
    var imageProvider: StoryImageProvider
    var mlxModelID: String
    var diffusersModelID: String
    var hfTokenKeychainRef: String?
    var diffusersRuntimeAlias: String
    var enableFoundationFallback: Bool
    var enableImageFallback: Bool
    var audienceMode: AudienceMode

    // Cloud provider model IDs
    var openRouterTextModelID: String
    var openRouterImageModelID: String
    var togetherTextModelID: String
    var togetherImageModelID: String
    var huggingFaceTextModelID: String
    var huggingFaceImageModelID: String

    static let defaultMLXModelID = "lmstudio-community/LFM2.5-1.2B-Instruct-MLX-4bit"
    static let defaultDiffusersModelID = "black-forest-labs/FLUX.2-klein-4B"

    static let curatedMLXModels: [CuratedMLXModel] = [
        CuratedMLXModel(
            id: "lmstudio-community/LFM2.5-1.2B-Instruct-MLX-4bit",
            displayName: "LFM2.5 1.2B Instruct (4-bit)",
            details: "Small, fast local model for story drafting."
        ),
        CuratedMLXModel(
            id: "mlx-community/Qwen3-4B-4bit",
            displayName: "Qwen3 4B (4-bit)",
            details: "Higher quality at higher memory cost."
        ),
        CuratedMLXModel(
            id: "mlx-community/Qwen3-1.7B-4bit",
            displayName: "Qwen3 1.7B (4-bit)",
            details: "Balanced quality and memory footprint."
        )
    ]

    static let curatedDiffusersImageModels: [CuratedDiffusersImageModel] = [
        CuratedDiffusersImageModel(
            id: "black-forest-labs/FLUX.2-klein-4B",
            displayName: "FLUX.2 klein 4B",
            details: "Fast distilled FLUX.2 model tuned for local generation."
        ),
        CuratedDiffusersImageModel(
            id: "black-forest-labs/FLUX.2-klein-base-4B",
            displayName: "FLUX.2 klein base 4B",
            details: "Base FLUX.2 klein variant with broader editing behavior."
        )
    ]

    static var defaultDiffusersAlias: String {
#if os(macOS)
        DiffusersRuntimeManager.defaultAlias
#else
        "default"
#endif
    }

    static let `default` = ModelSelectionSettings(
        textProvider: .appleFoundation,
        imageProvider: .imagePlayground,
        mlxModelID: defaultMLXModelID,
        diffusersModelID: defaultDiffusersModelID,
        hfTokenKeychainRef: HFTokenStore.defaultAlias,
        diffusersRuntimeAlias: defaultDiffusersAlias,
        enableFoundationFallback: true,
        enableImageFallback: true,
        openRouterTextModelID: CloudProvider.openRouter.defaultTextModelID,
        openRouterImageModelID: CloudProvider.openRouter.defaultImageModelID,
        togetherTextModelID: CloudProvider.togetherAI.defaultTextModelID,
        togetherImageModelID: CloudProvider.togetherAI.defaultImageModelID,
        huggingFaceTextModelID: CloudProvider.huggingFace.defaultTextModelID,
        huggingFaceImageModelID: CloudProvider.huggingFace.defaultImageModelID
    )

    /// Human-readable name for the active text model (e.g., "FLUX.1-schnell" not "black-forest-labs/FLUX.1-schnell").
    var resolvedTextModelLabel: String {
        switch textProvider {
        case .appleFoundation:
            return "Apple Foundation"
        case .mlxSwift:
            if let curated = Self.curatedMLXModels.first(where: { $0.id == mlxModelID }) {
                return curated.displayName
            }
            return Self.shortModelName(mlxModelID)
        case .huggingFace:
            let id = huggingFaceTextModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? "Hugging Face" : Self.shortModelName(id)
        case .openRouter:
            let id = openRouterTextModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? "OpenRouter" : Self.shortModelName(id)
        case .togetherAI:
            let id = togetherTextModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? "Together AI" : Self.shortModelName(id)
        }
    }

    /// Human-readable name for the active image model.
    var resolvedImageModelLabel: String {
        switch imageProvider {
        case .imagePlayground:
            return "Image Playground"
        case .diffusers:
            if let curated = Self.curatedDiffusersImageModels.first(where: { $0.id == diffusersModelID }) {
                return curated.displayName
            }
            return Self.shortModelName(diffusersModelID)
        case .huggingFace:
            let id = huggingFaceImageModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? "Hugging Face" : Self.shortModelName(id)
        case .openRouter:
            let id = openRouterImageModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? "OpenRouter" : Self.shortModelName(id)
        case .togetherAI:
            let id = togetherImageModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? "Together AI" : Self.shortModelName(id)
        }
    }

    /// Strips the org prefix from a model ID: "black-forest-labs/FLUX.1-schnell" → "FLUX.1-schnell".
    private static func shortModelName(_ fullID: String) -> String {
        if let slashIndex = fullID.lastIndex(of: "/") {
            let afterSlash = fullID[fullID.index(after: slashIndex)...]
            return afterSlash.isEmpty ? fullID : String(afterSlash)
        }
        return fullID
    }

    var resolvedHFTokenAlias: String {
        let alias = hfTokenKeychainRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return alias.isEmpty ? HFTokenStore.defaultAlias : alias
    }

    var resolvedDiffusersRuntimeAlias: String {
        let alias = diffusersRuntimeAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        return alias.isEmpty ? Self.defaultDiffusersAlias : alias
    }

    // MARK: - Backward-Compatible Codable

    enum CodingKeys: String, CodingKey {
        case textProvider, imageProvider, mlxModelID, diffusersModelID
        case hfTokenKeychainRef, diffusersRuntimeAlias
        case enableFoundationFallback, enableImageFallback
        case openRouterTextModelID, openRouterImageModelID
        case togetherTextModelID, togetherImageModelID
        case huggingFaceTextModelID, huggingFaceImageModelID
        case audienceMode
    }

    init(
        textProvider: StoryTextProvider,
        imageProvider: StoryImageProvider,
        mlxModelID: String,
        diffusersModelID: String,
        hfTokenKeychainRef: String?,
        diffusersRuntimeAlias: String,
        enableFoundationFallback: Bool,
        enableImageFallback: Bool,
        audienceMode: AudienceMode = .kid,
        openRouterTextModelID: String = CloudProvider.openRouter.defaultTextModelID,
        openRouterImageModelID: String = CloudProvider.openRouter.defaultImageModelID,
        togetherTextModelID: String = CloudProvider.togetherAI.defaultTextModelID,
        togetherImageModelID: String = CloudProvider.togetherAI.defaultImageModelID,
        huggingFaceTextModelID: String = CloudProvider.huggingFace.defaultTextModelID,
        huggingFaceImageModelID: String = CloudProvider.huggingFace.defaultImageModelID
    ) {
        self.textProvider = textProvider
        self.imageProvider = imageProvider
        self.mlxModelID = mlxModelID
        self.diffusersModelID = diffusersModelID
        self.hfTokenKeychainRef = hfTokenKeychainRef
        self.diffusersRuntimeAlias = diffusersRuntimeAlias
        self.enableFoundationFallback = enableFoundationFallback
        self.enableImageFallback = enableImageFallback
        self.audienceMode = audienceMode
        self.openRouterTextModelID = openRouterTextModelID
        self.openRouterImageModelID = openRouterImageModelID
        self.togetherTextModelID = togetherTextModelID
        self.togetherImageModelID = togetherImageModelID
        self.huggingFaceTextModelID = huggingFaceTextModelID
        self.huggingFaceImageModelID = huggingFaceImageModelID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textProvider = try container.decode(StoryTextProvider.self, forKey: .textProvider)
        imageProvider = try container.decode(StoryImageProvider.self, forKey: .imageProvider)
        mlxModelID = try container.decode(String.self, forKey: .mlxModelID)
        diffusersModelID = try container.decode(String.self, forKey: .diffusersModelID)
        hfTokenKeychainRef = try container.decodeIfPresent(String.self, forKey: .hfTokenKeychainRef)
        diffusersRuntimeAlias = try container.decode(String.self, forKey: .diffusersRuntimeAlias)
        enableFoundationFallback = try container.decode(Bool.self, forKey: .enableFoundationFallback)
        enableImageFallback = try container.decode(Bool.self, forKey: .enableImageFallback)

        audienceMode = try container.decodeIfPresent(AudienceMode.self, forKey: .audienceMode) ?? .kid

        // Cloud model IDs — use defaults for backward compatibility with v2 settings
        openRouterTextModelID = try container.decodeIfPresent(String.self, forKey: .openRouterTextModelID)
            ?? CloudProvider.openRouter.defaultTextModelID
        openRouterImageModelID = try container.decodeIfPresent(String.self, forKey: .openRouterImageModelID)
            ?? CloudProvider.openRouter.defaultImageModelID
        togetherTextModelID = try container.decodeIfPresent(String.self, forKey: .togetherTextModelID)
            ?? CloudProvider.togetherAI.defaultTextModelID
        togetherImageModelID = try container.decodeIfPresent(String.self, forKey: .togetherImageModelID)
            ?? CloudProvider.togetherAI.defaultImageModelID
        huggingFaceTextModelID = try container.decodeIfPresent(String.self, forKey: .huggingFaceTextModelID)
            ?? CloudProvider.huggingFace.defaultTextModelID
        huggingFaceImageModelID = try container.decodeIfPresent(String.self, forKey: .huggingFaceImageModelID)
            ?? CloudProvider.huggingFace.defaultImageModelID
    }
}

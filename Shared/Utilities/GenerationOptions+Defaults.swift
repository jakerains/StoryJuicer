import Foundation

struct GenerationConfig: Sendable {
    #if os(macOS)
    // Image Playground is most reliable when requests are serialized.
    static let maxConcurrentImages = 1
    #else
    static let maxConcurrentImages = 1
    #endif

    static let defaultTemperature: Float = 0.9

    // MARK: - Per-Provider Token Budgets
    //
    // Each provider has its own token budget so tuning one never affects another.
    // Foundation Models: on-device ~3B model, needs generous budgets to avoid truncation.
    // MLX: local open-weight models, varies by model size.
    // Cloud: remote models (HF, OpenRouter, Together AI), most capable, cheapest to be generous.
    // Premium: OpenAI proxy, large context, generous budgets.

    /// Foundation Models (on-device ~3B) — Pass 1 (story text only, no image prompts).
    /// No API cost — runs on Apple Silicon. Be very generous to prevent truncation.
    static func foundationModelTokens(for pageCount: Int) -> Int {
        (400 * pageCount) + 600
    }

    /// Foundation Models — Pass 2 (image prompts from story context).
    /// Same rationale — free compute, never truncate image prompts.
    static func foundationModelImagePromptTokens(for pageCount: Int) -> Int {
        (300 * pageCount) + 400
    }

    /// MLX (local open-weight models) — also on-device, no API cost.
    /// Be generous to avoid truncation on larger page counts.
    static func mlxTokens(for pageCount: Int) -> Int {
        (400 * pageCount) + 600
    }

    /// Cloud providers (HF, OpenRouter, Together AI) — story text generation.
    /// Remote models are more capable; generous budget avoids any truncation.
    static func cloudTokens(for pageCount: Int) -> Int {
        (300 * pageCount) + 500
    }

    /// Premium (OpenAI proxy) — story text generation.
    /// Large-context models; very generous budget.
    static func premiumTokens(for pageCount: Int) -> Int {
        (400 * pageCount) + 600
    }

    static let minPages = 4
    static let maxPages = 16
    static let defaultPages = 8

    /// Max retry attempts when a guardrail false positive is detected.
    static let guardrailRetryAttempts = 1

    /// Timeout for one Image Playground request before moving to the next prompt variant.
    static let imagePlaygroundGenerationTimeoutSeconds: TimeInterval = 45

    /// Number of sequential recovery rounds for pages that failed in the parallel pass.
    static let imageRecoveryPasses = 3

    /// Timeout for a single local Diffusers image generation call.
    static let diffusersGenerationTimeoutSeconds: TimeInterval = 240

    /// Timeout for a single cloud text generation call.
    static let cloudTextGenerationTimeoutSeconds: TimeInterval = 120

    /// Timeout for a single cloud image generation call.
    static let cloudImageGenerationTimeoutSeconds: TimeInterval = 180
}

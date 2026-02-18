import Foundation

struct GenerationConfig: Sendable {
    #if os(macOS)
    static let maxConcurrentImages = 2
    #else
    static let maxConcurrentImages = 2
    #endif

    static let defaultTemperature: Float = 1.2

    /// Estimate token budget based on page count.
    /// Each page needs ~100-150 tokens for text + imagePrompt, plus overhead for title/moral/structure.
    static func maximumResponseTokens(for pageCount: Int) -> Int {
        let perPageTokens = 150
        let overhead = 200
        return (perPageTokens * pageCount) + overhead
    }

    static let minPages = 4
    static let maxPages = 16
    static let defaultPages = 8

    /// Max retry attempts when a guardrail false positive is detected.
    static let guardrailRetryAttempts = 2
}

import Foundation
import FoundationModels

enum StoryGenerationState: Sendable {
    case idle
    case generating(partialText: String)
    case complete(StoryBook)
    case failed(Error)

    var isGenerating: Bool {
        if case .generating = self { return true }
        return false
    }
}

@Observable
@MainActor
final class StoryGenerator {

    private(set) var state: StoryGenerationState = .idle
    private var generationTask: Task<Void, Never>?

    /// Check if the on-device language model is available.
    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// The reason the model is unavailable, if applicable.
    var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
#if os(macOS)
                return "This Mac doesn't support Apple Intelligence. An Apple Silicon Mac is required."
#else
                return "This device doesn't support Apple Intelligence. A compatible iPhone or iPad is required."
#endif
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled. Please enable it in System Settings."
            case .modelNotReady:
                return "The language model is still downloading. Please try again shortly."
            @unknown default:
                return "The on-device language model is currently unavailable."
            }
        @unknown default:
            return "The on-device language model is currently unavailable."
        }
    }

    /// Generate a storybook from a concept using the on-device LLM.
    /// Retries automatically on guardrail false positives.
    func generateStory(
        concept: String,
        pageCount: Int,
        onProgress: @escaping @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> StoryBook {
        state = .generating(partialText: "")
        onProgress("")

        var lastError: Error?

        for attempt in 0...GenerationConfig.guardrailRetryAttempts {
            do {
                let book = try await attemptGeneration(
                    concept: concept,
                    pageCount: pageCount,
                    onProgress: onProgress
                )
                state = .complete(book)
                return book
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error,
                   attempt < GenerationConfig.guardrailRetryAttempts {
                    // Guardrail false positive — retry with a fresh session
                    lastError = error
                    state = .generating(partialText: "Safety filter triggered, retrying...")
                    onProgress("Safety filter triggered, retrying...")
                    try await Task.sleep(for: .milliseconds(500))
                    continue
                }
                throw error
            }
        }

        // Should not reach here, but just in case
        throw lastError ?? StoryGeneratorError.emptyResponse
    }

    /// Two-pass generation: story text first, then image prompts with full context.
    private func attemptGeneration(
        concept: String,
        pageCount: Int,
        onProgress: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> StoryBook {
        let safeConcept = ContentSafetyPolicy.sanitizeConcept(concept)

        // ── Pass 1: Generate story text (no image prompts) ──
        let textSession = LanguageModelSession(
            instructions: StoryPromptTemplates.systemInstructions
        )

        let textPrompt = StoryPromptTemplates.textOnlyPrompt(
            concept: safeConcept,
            pageCount: pageCount
        )

        let textOptions = GenerationOptions(
            temperature: Double(GenerationConfig.defaultTemperature),
            maximumResponseTokens: GenerationConfig.maximumResponseTokens(for: pageCount)
        )

        let textStream = textSession.streamResponse(
            to: textPrompt,
            generating: TextOnlyStoryBook.self,
            options: textOptions
        )

        // Stream partial results to show progress
        for try await snapshot in textStream {
            let partial = snapshot.content
            let pages = partial.pages ?? []
            let previewText = pages.compactMap(\.text).joined(separator: "\n\n")
            state = .generating(partialText: previewText)
            onProgress(previewText)
        }

        let textResponse = try await textStream.collect()
        let textOnly = textResponse.content

        // ── Pass 2: Generate image prompts with full story context ──
        state = .generating(partialText: "Writing illustration prompts...")
        onProgress("Writing illustration prompts...")

        let pages = textOnly.pages.map { (pageNumber: $0.pageNumber, text: $0.text) }
        let imagePromptPrompt = StoryPromptTemplates.imagePromptPassPrompt(
            characterDescriptions: textOnly.characterDescriptions,
            pages: pages
        )

        let artSession = LanguageModelSession(
            instructions: "You are an art director for a children's storybook illustration team."
        )

        let promptOptions = GenerationOptions(
            temperature: Double(GenerationConfig.defaultTemperature),
            maximumResponseTokens: 600
        )

        let promptResponse = try await artSession.respond(
            to: imagePromptPrompt,
            generating: ImagePromptSheet.self,
            options: promptOptions
        )

        let promptSheet = promptResponse.content

        // ── Merge text + prompts into a StoryBook ──
        let promptsByPage = Dictionary(
            promptSheet.prompts.map { ($0.pageNumber, $0.imagePrompt) },
            uniquingKeysWith: { _, last in last }
        )

        let mergedPages = textOnly.pages
            .sorted { $0.pageNumber < $1.pageNumber }
            .prefix(pageCount)
            .enumerated()
            .map { offset, page -> StoryPage in
                let pageNumber = offset + 1
                let prompt = promptsByPage[page.pageNumber]?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let fallbackPrompt = ContentSafetyPolicy.safeIllustrationPrompt(
                    "A gentle scene inspired by \(safeConcept)"
                )
                return StoryPage(
                    pageNumber: pageNumber,
                    text: page.text,
                    imagePrompt: prompt.isEmpty ? fallbackPrompt : prompt
                )
            }

        let validatedDescriptions = CharacterDescriptionValidator.validate(
            descriptions: textOnly.characterDescriptions,
            pages: mergedPages,
            title: textOnly.title
        )

        return StoryBook(
            title: textOnly.title,
            authorLine: textOnly.authorLine,
            moral: textOnly.moral,
            characterDescriptions: validatedDescriptions,
            pages: mergedPages
        )
    }

    /// Cancel any in-progress generation.
    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        state = .idle
    }

    func reset() {
        cancel()
        state = .idle
    }
}

enum StoryGeneratorError: LocalizedError {
    case emptyResponse
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            "The story generator returned an empty response. Please try again."
        case .modelUnavailable(let reason):
            reason
        }
    }
}

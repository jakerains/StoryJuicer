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
                    state = .generating(partialText: "Hmm, let's try that again...")
                    onProgress("Hmm, let's try that again...")
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
        let pass1System = StoryPromptTemplates.systemInstructions
        let textSession = LanguageModelSession(
            instructions: pass1System
        )

        let textPrompt = StoryPromptTemplates.textOnlyPrompt(
            concept: safeConcept,
            pageCount: pageCount
        )

        let textOptions = GenerationOptions(
            temperature: Double(GenerationConfig.defaultTemperature),
            maximumResponseTokens: GenerationConfig.foundationModelTokens(for: pageCount)
        )

        let pass1Clock = ContinuousClock()
        let pass1Start = pass1Clock.now

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

        let pass1Duration = pass1Start.duration(to: pass1Clock.now)
        let pass1Seconds = Double(pass1Duration.components.seconds) + Double(pass1Duration.components.attoseconds) / 1e18

        // Log Pass 1
        let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
        await VerboseGenerationLogger.shared.logTextPass(
            sessionID: verboseSession,
            passLabel: "Pass 1: Story Text (Foundation Models)",
            provider: "Apple Foundation Models", model: "on-device",
            systemPrompt: pass1System, userPrompt: textPrompt,
            rawResponse: "Title: \(textOnly.title)\nPages: \(textOnly.pages.count)\nCharacters: \(textOnly.characterDescriptions)",
            parseSuccess: true,
            duration: pass1Seconds
        )

        // ── Pass 2: Generate image prompts with full story context ──
        state = .generating(partialText: "Dreaming up illustrations for each page...")
        onProgress("Dreaming up illustrations for each page...")

        let pages = textOnly.pages.map { (pageNumber: $0.pageNumber, text: $0.text) }
        let imagePromptPrompt = StoryPromptTemplates.imagePromptPassPrompt(
            characterDescriptions: textOnly.characterDescriptions,
            pages: pages
        )

        let pass2System = "You are an art director for a children's storybook illustration team."
        let promptOptions = GenerationOptions(
            temperature: Double(GenerationConfig.defaultTemperature),
            maximumResponseTokens: GenerationConfig.foundationModelImagePromptTokens(for: pageCount)
        )

        let pass2Clock = ContinuousClock()
        let pass2Start = pass2Clock.now

        // Try structured generation with retry, fall back to synthesized prompts
        var promptSheet: ImagePromptSheet?
        for attempt in 0...1 {
            do {
                let artSession = LanguageModelSession(instructions: pass2System)
                let promptResponse = try await artSession.respond(
                    to: imagePromptPrompt,
                    generating: ImagePromptSheet.self,
                    options: promptOptions
                )
                promptSheet = promptResponse.content
                break
            } catch {
                if attempt == 0 {
                    state = .generating(partialText: "Hmm, let's sketch those illustrations again...")
                    onProgress("Hmm, let's sketch those illustrations again...")
                    try await Task.sleep(for: .milliseconds(500))
                }
            }
        }

        // If structured generation failed twice, synthesize prompts from story text
        let finalPrompts: [PageImagePrompt]
        if let sheet = promptSheet {
            finalPrompts = sheet.prompts
        } else {
            finalPrompts = textOnly.pages.map { page in
                let description = textOnly.characterDescriptions.isEmpty
                    ? ""
                    : " Characters: \(textOnly.characterDescriptions)."
                let synthesized = "A children's book illustration of: \(page.text)\(description) Warm, gentle, colorful scene."
                return PageImagePrompt(pageNumber: page.pageNumber, imagePrompt: synthesized)
            }
        }

        let pass2Duration = pass2Start.duration(to: pass2Clock.now)
        let pass2Seconds = Double(pass2Duration.components.seconds) + Double(pass2Duration.components.attoseconds) / 1e18

        // Log Pass 2
        let pass2ResponseSummary = finalPrompts.map { "Page \($0.pageNumber): \($0.imagePrompt)" }.joined(separator: "\n")
        await VerboseGenerationLogger.shared.logTextPass(
            sessionID: verboseSession,
            passLabel: "Pass 2: Image Prompts (Foundation Models)",
            provider: "Apple Foundation Models", model: "on-device",
            systemPrompt: pass2System, userPrompt: imagePromptPrompt,
            rawResponse: pass2ResponseSummary,
            parseSuccess: promptSheet != nil,
            duration: pass2Seconds
        )

        // ── Merge text + prompts into a StoryBook ──
        let promptsByPage = Dictionary(
            finalPrompts.map { ($0.pageNumber, $0.imagePrompt) },
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

        let story = StoryBook(
            title: textOnly.title,
            authorLine: textOnly.authorLine,
            moral: textOnly.moral,
            characterDescriptions: validatedDescriptions,
            pages: mergedPages
        )

        // Log merged storybook
        await VerboseGenerationLogger.shared.logMergedStoryBook(
            sessionID: verboseSession,
            title: story.title,
            characterDescriptions: story.characterDescriptions,
            pages: story.pages.map { ($0.pageNumber, $0.text, $0.imagePrompt) }
        )

        return story
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

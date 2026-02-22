import Foundation
import FoundationModels
import CoreGraphics
import ImagePlayground
import os

enum IllustrationGenerationState: Sendable {
    case idle
    case generating(currentPage: Int, completedCount: Int, totalCount: Int)
    case complete
    case failed(Error)

    var isGenerating: Bool {
        if case .generating = self { return true }
        return false
    }
}

@Observable
@MainActor
final class IllustrationGenerator {
    private nonisolated(unsafe) static let logger = Logger(subsystem: "com.storyfox.app", category: "Illustrations")

    private static let variantLabels = [
        "sanitized",          // full sanitized scene (~180 chars)
        "llmRewritten",       // inserted dynamically at index 1 when rewrite succeeds
        "shortened",          // first 18 keywords
        "highReliability",    // first 12 keywords
        "fallback",           // first 8 keywords + scene framing
        "ultraSafe",          // first 4 keywords + "sunny day"
    ]

    private let router: ImageGenerationRouter

    private(set) var state: IllustrationGenerationState = .idle
    private(set) var generatedImages: [Int: CGImage] = [:]
    private(set) var lastStatusMessage: String?
    /// Tracks the actual provider used for the most recent image (reflects fallbacks).
    private(set) var activeImageProvider: StoryImageProvider?
    private(set) var variantSuccessCounts: [String: Int] = [:]

    /// When true, the cover image is passed as a reference to Page 1's generation
    /// to help anchor the character's visual appearance. When false, all pages rely
    /// solely on the enriched text prompt — useful for A/B testing prompt quality.
    var useReferenceImage: Bool = false

    /// Semantic analyses for each page, populated before image generation begins.
    /// Keyed by page index (0 = cover, 1...N = story pages).
    private var promptAnalyses: [Int: PromptAnalysis] = [:]

    /// Multi-concept decompositions for each page, used by the progressive shedding
    /// retry loop in `generateSingleImage()`. Keyed by page index (0 = cover).
    private(set) var conceptDecompositions: [Int: ImageConceptDecomposition] = [:]

    init(router: ImageGenerationRouter = ImageGenerationRouter()) {
        self.router = router
    }

    /// Generate illustrations for all story pages concurrently with limited parallelism.
    /// - Parameter parsedCharacters: Pre-parsed character entries from Foundation Model (Upgrade 1).
    ///   When provided, skips re-parsing `characterDescriptions` for every prompt.
    func generateIllustrations(
        for pages: [StoryPage],
        coverPrompt: String,
        characterDescriptions: String = "",
        style: IllustrationStyle,
        format: BookFormat = .standard,
        analyses: [Int: PromptAnalysis] = [:],
        parsedCharacters: [ImagePromptEnricher.CharacterEntry] = [],
        onImageReady: @MainActor @Sendable (Int, CGImage) -> Void
    ) async throws {
        generatedImages = [:]
        lastStatusMessage = nil
        activeImageProvider = nil
        variantSuccessCounts = [:]
        promptAnalyses = analyses
        conceptDecompositions = [:]
        let totalCount = pages.count + 1 // +1 for cover
        state = .generating(currentPage: 0, completedCount: 0, totalCount: totalCount)
        let sessionStart = ContinuousClock.now

        // Enrich prompts with character descriptions, skipping if the enricher already
        // injected species inline (avoids duplicate descriptors for ImagePlayground).
        let enrichedCover = Self.enrichPromptWithCharacters(coverPrompt, characterDescriptions: characterDescriptions, parsedCharacters: parsedCharacters)

        // Decompose each prompt into ranked concepts for multi-concept ImagePlayground generation.
        // Uses FM when available, falls back to heuristic extraction from PromptAnalysis.
        let allIndexedPrompts = [(0, enrichedCover)] + pages.map { ($0.pageNumber, Self.enrichPromptWithCharacters($0.imagePrompt, characterDescriptions: characterDescriptions, parsedCharacters: parsedCharacters)) }
        for (index, prompt) in allIndexedPrompts {
            if let decomposition = await PromptAnalysisEngine.decomposeIntoConcepts(prompt: prompt) {
                conceptDecompositions[index] = decomposition
            } else if let analysis = promptAnalyses[index] {
                conceptDecompositions[index] = PromptAnalysisEngine.heuristicConcepts(from: analysis)
            }
        }

        let semaphore = AsyncSemaphore(limit: GenerationConfig.maxConcurrentImages)
        var completedCount = 0
        var failedJobs: [(index: Int, prompt: String)] = []

        // Phase A: Generate cover first (index 0) — becomes character reference for remaining pages
        var characterReferenceImage: CGImage?
        do {
            let coverImage = try await generateSingleImage(
                prompt: enrichedCover,
                style: style,
                format: format,
                pageIndex: 0
            )
            generatedImages[0] = coverImage
            characterReferenceImage = coverImage
            onImageReady(0, coverImage)
            completedCount += 1
            state = .generating(currentPage: 0, completedCount: completedCount, totalCount: totalCount)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.warning("Cover image failed in initial pass: \(String(describing: error), privacy: .public)")
            failedJobs.append((0, enrichedCover))
            completedCount += 1
            state = .generating(currentPage: 0, completedCount: completedCount, totalCount: totalCount)
        }

        // Phase B: Generate page illustrations concurrently.
        // When useReferenceImage is true, pass cover as character reference for page 1
        // to anchor the character's visual appearance. When false, all pages rely on
        // the enriched text prompt alone — lets you A/B test prompt quality.
        try await withThrowingTaskGroup(of: (Int, String, CGImage?).self) { group in
            for page in pages {
                let enrichedPrompt = Self.enrichPromptWithCharacters(page.imagePrompt, characterDescriptions: characterDescriptions, parsedCharacters: parsedCharacters)
                let refImage = (useReferenceImage && page.pageNumber == 1) ? characterReferenceImage : nil
                let pageNum = page.pageNumber
                group.addTask { [style] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    do {
                        let image = try await self.generateSingleImage(
                            prompt: enrichedPrompt,
                            style: style,
                            format: format,
                            referenceImage: refImage,
                            pageIndex: pageNum
                        )
                        return (page.pageNumber, enrichedPrompt, image)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        Self.logger.warning("Page \(page.pageNumber) failed in parallel pass: \(String(describing: error), privacy: .public)")
                        return (page.pageNumber, enrichedPrompt, nil)
                    }
                }
            }

            for try await (index, prompt, image) in group {
                completedCount += 1
                if let image {
                    generatedImages[index] = image
                    onImageReady(index, image)
                } else {
                    failedJobs.append((index, prompt))
                }
                state = .generating(
                    currentPage: index,
                    completedCount: completedCount,
                    totalCount: totalCount
                )
            }
        }

        if !failedJobs.isEmpty {
            Self.logger.info("Starting recovery passes for \(failedJobs.count) failed page(s)")
            // Recovery pass: retry missing frames one-by-one with safer prompt variants.
            var pending = failedJobs.sorted(by: { $0.index < $1.index })
            for pass in 1...GenerationConfig.imageRecoveryPasses {
                if pending.isEmpty {
                    break
                }

                // Skip variants that already failed during the parallel pass.
                let startVariant = min(pass, 5)

                lastStatusMessage = "Retrying \(pending.count) missing page(s) with safer prompts (pass \(pass)/\(GenerationConfig.imageRecoveryPasses))..."
                var nextPending: [(index: Int, prompt: String)] = []

                for job in pending {
                    if generatedImages[job.index] != nil {
                        continue
                    }
                    do {
                        let image = try await generateSingleImage(
                            prompt: job.prompt,
                            style: style,
                            format: format,
                            startingVariantIndex: startVariant
                        )
                        generatedImages[job.index] = image
                        onImageReady(job.index, image)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        Self.logger.warning("Recovery pass \(pass) failed for page \(job.index): \(String(describing: error), privacy: .public)")
                        nextPending.append(job)
                    }
                }

                pending = nextPending
                if !pending.isEmpty && pass < GenerationConfig.imageRecoveryPasses {
                    try await Task.sleep(for: .milliseconds(350))
                }
            }
        }

        // Final cover rescue — if cover is still missing after all recovery passes,
        // make one dedicated attempt with the safest prompt variants.
        if generatedImages[0] == nil {
            Self.logger.info("Cover still missing — attempting final cover rescue")
            lastStatusMessage = "Retrying cover image with safest prompt..."
            do {
                let coverImage = try await generateSingleImage(
                    prompt: coverPrompt,
                    style: style,
                    format: format,
                    startingVariantIndex: 4
                )
                generatedImages[0] = coverImage
                onImageReady(0, coverImage)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Self.logger.warning("Final cover rescue failed: \(String(describing: error), privacy: .public)")
            }
        }

        // Log session summary
        let sessionDuration = ContinuousClock.now - sessionStart
        let totalSeconds = Double(sessionDuration.components.seconds) + Double(sessionDuration.components.attoseconds) / 1e18
        let successCount = generatedImages.count
        let failureCount = totalCount - successCount
        Self.logger.info(
            "Session complete: \(successCount)/\(totalCount) succeeded in \(String(format: "%.1f", totalSeconds))s. Variant wins: \(self.variantSuccessCounts, privacy: .public)"
        )
        await GenerationDiagnosticsLogger.shared.logSessionSummary(
            totalPages: totalCount,
            successCount: successCount,
            failureCount: failureCount,
            variantSuccessRates: variantSuccessCounts,
            totalDurationSeconds: totalSeconds
        )

        state = .complete
    }

    /// Generate a single illustration from a text prompt.
    /// Retries automatically on guardrail false positives.
    /// - Parameters:
    ///   - startingVariantIndex: Skip earlier variants (used by recovery passes to avoid replaying failures).
    ///   - referenceImage: Optional character reference image for ImagePlayground visual consistency.
    ///   - pageIndex: The page index for looking up `PromptAnalysis` (0 = cover).
    ///   - analysis: Optional pre-computed analysis for this prompt. If nil, falls back to positional keywords.
    func generateSingleImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat = .standard,
        startingVariantIndex: Int = 0,
        referenceImage: CGImage? = nil,
        pageIndex: Int? = nil,
        analysis: PromptAnalysis? = nil
    ) async throws -> CGImage {
        var lastError: Error = IllustrationError.noImageGenerated
        lastStatusMessage = nil
        let allVariantsStart = ContinuousClock.now
        let hasCharPrefix = prompt.hasPrefix("Featuring ") || prompt.hasPrefix("Characters: ")

        // Resolve analysis: explicit parameter > stored analyses > nil
        let resolvedAnalysis = analysis
            ?? pageIndex.flatMap { promptAnalyses[$0] }

        // --- Multi-concept progressive shedding (ImagePlayground only) ---
        // Try sending multiple short .text() concepts, dropping the least important on failure.
        let decomposition = pageIndex.flatMap { conceptDecompositions[$0] }

        if let decomposition, !decomposition.concepts.isEmpty, startingVariantIndex == 0 {
            var conceptCount = decomposition.concepts.count

            while conceptCount > 0 {
                let activeConcepts = Array(decomposition.concepts.prefix(conceptCount))
                let label = "multiConcept_\(conceptCount)"
                let attemptStart = ContinuousClock.now

                do {
                    let outcome = try await router.generateImage(
                        prompt: prompt,
                        style: style,
                        format: format,
                        referenceImage: referenceImage,
                        rankedConcepts: activeConcepts
                    ) { [weak self] status in
                        Task { @MainActor in
                            self?.lastStatusMessage = status
                        }
                    }

                    let elapsed = attemptStart.duration(to: .now)
                    let secs = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                    Self.logger.info("Image succeeded: variant=\(label, privacy: .public) concepts=\(conceptCount) duration=\(String(format: "%.1f", secs))s")
                    self.activeImageProvider = outcome.providerUsed
                    await GenerationDiagnosticsLogger.shared.logImageSuccess(
                        provider: outcome.providerUsed,
                        prompt: prompt,
                        variantLabel: label,
                        variantIndex: 0,
                        attemptIndex: 0,
                        durationSeconds: secs,
                        conceptCount: conceptCount,
                        conceptLabels: activeConcepts.map(\.label),
                        usedMultiConcept: true
                    )
                    variantSuccessCounts[label, default: 0] += 1
                    return outcome.image
                } catch {
                    let elapsed = attemptStart.duration(to: .now)
                    let secs = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                    lastError = error
                    if error is CancellationError { throw error }

                    let errorDesc = String(describing: error)
                    Self.logger.info("Multi-concept failed with \(conceptCount) concepts, shedding to \(conceptCount - 1): \(errorDesc, privacy: .public)")
                    let currentSettings = ModelSelectionStore.load()
                    await GenerationDiagnosticsLogger.shared.logImageAttemptFailure(
                        provider: currentSettings.imageProvider,
                        prompt: prompt,
                        variantLabel: label,
                        variantIndex: 0,
                        attemptIndex: 0,
                        retryable: false,
                        errorType: String(describing: type(of: error)),
                        errorDescription: errorDesc,
                        durationSeconds: secs,
                        conceptCount: conceptCount,
                        conceptLabels: activeConcepts.map(\.label),
                        usedMultiConcept: true
                    )

                    // Shed least important concept and retry
                    conceptCount -= 1
                }
            }

            // All multi-concept attempts exhausted — fall through to single-string fallback
            Self.logger.warning("All multi-concept attempts failed for page \(pageIndex ?? -1), falling back to single-string variants")
        }

        // --- Single-string variant chain (existing fallback) ---
        // Variant 0: Use async FM rewrite when unsafe content detected (Upgrade 3),
        // otherwise falls back to sync regex sanitization
        let safeVariant0 = await ContentSafetyPolicy.safeIllustrationPromptAsync(prompt, extendedLimit: hasCharPrefix)

        var promptVariants = [
            safeVariant0,
            shortenedScenePrompt(from: prompt, analysis: resolvedAnalysis),
            highReliabilityIllustrationPrompt(from: prompt, analysis: resolvedAnalysis),
            fallbackIllustrationPrompt(from: prompt, analysis: resolvedAnalysis),
            ultraSafeIllustrationPrompt(from: prompt, analysis: resolvedAnalysis)
        ]
        var variantIndex = startingVariantIndex

        while variantIndex < promptVariants.count {
            let variant = promptVariants[variantIndex]
            let label = variantIndex < Self.variantLabels.count
                ? Self.variantLabels[variantIndex]
                : "variant\(variantIndex)"

            for attempt in 0...GenerationConfig.guardrailRetryAttempts {
                let attemptStart = ContinuousClock.now
                do {
                    let outcome = try await router.generateImage(
                        prompt: variant,
                        style: style,
                        format: format,
                        referenceImage: referenceImage
                    ) { [weak self] status in
                        Task { @MainActor in
                            self?.lastStatusMessage = status
                        }
                    }

                    let elapsed = attemptStart.duration(to: .now)
                    let secs = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                    Self.logger.info("Image succeeded: variant=\(label, privacy: .public) attempt=\(attempt) duration=\(String(format: "%.1f", secs))s")
                    let actualProvider = outcome.providerUsed
                    self.activeImageProvider = actualProvider
                    await GenerationDiagnosticsLogger.shared.logImageSuccess(
                        provider: actualProvider,
                        prompt: prompt,
                        variantLabel: label,
                        variantIndex: variantIndex,
                        attemptIndex: attempt,
                        durationSeconds: secs,
                        usedMultiConcept: false
                    )
                    variantSuccessCounts[label, default: 0] += 1
                    return outcome.image
                } catch {
                    let elapsed = attemptStart.duration(to: .now)
                    let secs = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                    lastError = error
                    if error is CancellationError {
                        throw error
                    }

                    let errorDesc = String(describing: error)
                    let shouldRetry = shouldRetrySameVariant(after: error)
                    Self.logger.warning("Image failed: variant=\(label, privacy: .public) attempt=\(attempt) retryable=\(shouldRetry) duration=\(String(format: "%.1f", secs))s error=\(errorDesc, privacy: .public)")
                    let currentSettings = ModelSelectionStore.load()
                    await GenerationDiagnosticsLogger.shared.logImageAttemptFailure(
                        provider: currentSettings.imageProvider,
                        prompt: prompt,
                        variantLabel: label,
                        variantIndex: variantIndex,
                        attemptIndex: attempt,
                        retryable: shouldRetry,
                        errorType: String(describing: type(of: error)),
                        errorDescription: errorDesc,
                        durationSeconds: secs,
                        usedMultiConcept: false
                    )

                    // Retry the current variant only for likely transient failures.
                    if attempt < GenerationConfig.guardrailRetryAttempts,
                       shouldRetry {
                        try await Task.sleep(for: .milliseconds(450))
                        continue
                    }

                    // Non-transient failures should move to the next safer variant quickly.
                    if !shouldRetry {
                        break
                    }
                }
            }

            // After exhausting the primary variant, ask Foundation Models to reword.
            if variantIndex == 0,
               let rewritten = await rewrittenPromptFromFoundationModel(originalPrompt: prompt),
               !promptVariants.contains(rewritten)
            {
                promptVariants.insert(rewritten, at: 1)
            }
            variantIndex += 1
        }

        // Log final failure with total duration across all variants
        let totalElapsed = allVariantsStart.duration(to: .now)
        let totalSecs = Double(totalElapsed.components.seconds) + Double(totalElapsed.components.attoseconds) / 1e18
        Self.logger.error("All variants exhausted for prompt after \(String(format: "%.1f", totalSecs))s")
        let finalSettings = ModelSelectionStore.load()
        await GenerationDiagnosticsLogger.shared.logImageFailureFinal(
            provider: finalSettings.imageProvider,
            prompt: prompt,
            errorType: String(describing: type(of: lastError)),
            errorDescription: String(describing: lastError),
            durationSeconds: totalSecs
        )

        throw lastError
    }

    /// Split a prompt into character prefix and scene text.
    /// Supports both new "Featuring ..." format and legacy "Characters: ... Scene: ..." format.
    /// The prefix is preserved intact across all fallback variants so character
    /// consistency is never lost during retries.
    private func splitCharacterPrefix(from prompt: String) -> (prefix: String, scene: String) {
        // New format: "Featuring Luna, a small orange fox with a green scarf. <scene>"
        if prompt.hasPrefix("Featuring ") {
            // Find the end of the "Featuring ..." clause (first ". " after "Featuring")
            if let dotRange = prompt.range(of: ". ", range: prompt.index(prompt.startIndex, offsetBy: 10)..<prompt.endIndex) {
                let prefix = String(prompt[..<dotRange.upperBound])
                let scene = String(prompt[dotRange.upperBound...])
                return (prefix, scene)
            }
        }

        // Legacy format: "Characters: ... Scene: ..."
        if prompt.hasPrefix("Characters: "),
           let sceneRange = prompt.range(of: ". Scene: ") {
            let prefix = String(prompt[..<sceneRange.upperBound])
            let scene = String(prompt[sceneRange.upperBound...])
            return (prefix, scene)
        }

        return ("", prompt)
    }

    private func shortenedScenePrompt(from prompt: String, analysis: PromptAnalysis? = nil) -> String {
        let (prefix, scene) = splitCharacterPrefix(from: prompt)
        if let analysis, !analysis.characters.isEmpty {
            let keywords = semanticKeywords(from: analysis, count: 18)
            return prefix + keywords
        }
        let words = extractKeywords(from: scene, count: 18)
        let sceneText = words.isEmpty ? "friendly animals in a sunny meadow" : words
        return prefix + sceneText
    }

    private func highReliabilityIllustrationPrompt(from prompt: String, analysis: PromptAnalysis? = nil) -> String {
        let (prefix, scene) = splitCharacterPrefix(from: prompt)
        if let analysis, !analysis.characters.isEmpty {
            let keywords = semanticKeywords(from: analysis, count: 12)
            return prefix + keywords
        }
        let words = extractKeywords(from: scene, count: 12)
        let sceneText = words.isEmpty ? "friendly animals playing together" : words
        return prefix + sceneText
    }

    private func fallbackIllustrationPrompt(from prompt: String, analysis: PromptAnalysis? = nil) -> String {
        let (prefix, scene) = splitCharacterPrefix(from: prompt)
        if let analysis, !analysis.characters.isEmpty {
            // At fallback level, use all species + scene + "cheerful scene" framing
            let species = analysis.allSpecies
            let sceneSetting = analysis.sceneSetting.isEmpty ? "a cheerful scene" : analysis.sceneSetting
            return prefix + "\(species) \(sceneSetting)"
        }
        let words = extractKeywords(from: scene, count: 8)
        let sceneText = words.isEmpty ? "happy animals in a garden" : "\(words) in a cheerful scene"
        return prefix + sceneText
    }

    private func ultraSafeIllustrationPrompt(from prompt: String, analysis: PromptAnalysis? = nil) -> String {
        let (prefix, _) = splitCharacterPrefix(from: prompt)
        if let analysis, !analysis.characters.isEmpty {
            // Species-anchored safe prompt — guarantees correct animal/character type
            return prefix + "friendly \(analysis.allSpecies) in a colorful storybook scene, children's book illustration style"
        }
        let (_, scene) = splitCharacterPrefix(from: prompt)
        let words = extractKeywords(from: scene, count: 4)
        let sceneText = words.isEmpty ? "cute animals sunny day" : "\(words) sunny day"
        return prefix + sceneText
    }

    /// Build semantically-ordered keywords from a `PromptAnalysis`.
    /// All character species come first, then appearance words distributed across
    /// characters, then scene — so the most visually important elements survive truncation.
    private func semanticKeywords(from analysis: PromptAnalysis, count: Int) -> String {
        var keywords: [String] = []

        // All character species first — most important for identity
        for character in analysis.characters {
            if !character.species.isEmpty {
                keywords.append(character.species)
            }
        }

        // Appearance words from each character (up to 2 per character, skip duplicates)
        for character in analysis.characters {
            let words = character.appearance
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty && !keywords.contains($0) }
            keywords.append(contentsOf: words.prefix(2))
        }

        // Scene setting
        let sceneWords = analysis.sceneSetting
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let remaining = max(0, count - keywords.count)
        keywords.append(contentsOf: sceneWords.prefix(remaining))

        // Action if we still have room
        if keywords.count < count, !analysis.mainAction.isEmpty {
            let actionWords = analysis.mainAction
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            let actionRemaining = max(0, count - keywords.count)
            keywords.append(contentsOf: actionWords.prefix(actionRemaining))
        }

        return keywords.prefix(count).joined(separator: " ")
    }

    private func extractKeywords(from text: String, count: Int) -> String {
        ContentSafetyPolicy.sanitizeConcept(text)
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .prefix(count)
            .joined(separator: " ")
    }

    private func rewrittenPromptFromFoundationModel(originalPrompt: String) async -> String? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let sanitized = ContentSafetyPolicy.sanitizeConcept(originalPrompt)
        guard !sanitized.isEmpty else {
            return nil
        }

        let session = LanguageModelSession(
            instructions: """
                You rewrite children's illustration prompts for safe on-device image generation.
                Output ONLY a short scene description (under 100 characters).
                Describe what is visible: characters, setting, colors, mood.
                Do NOT include instructions like "Create" or "Draw" or "Illustrate".
                Keep it family-friendly, cheerful, and specific.
                Never include copyrighted character names.
                """
        )

        let rewriteRequest = """
            Rewrite this into a short, child-safe scene description under 100 characters.
            Describe only what is visible in the scene. No instructions.
            Original: \(sanitized)
            """

        let options = GenerationOptions(
            temperature: 0.35,
            maximumResponseTokens: 120
        )

        do {
            let rewrite = try await session.respond(
                to: rewriteRequest,
                generating: IllustrationPromptRewrite.self,
                options: options
            )
            let candidate = rewrite.content.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty else { return nil }
            return ContentSafetyPolicy.safeIllustrationPrompt(candidate)
        } catch {
            return nil
        }
    }

    private func shouldRetrySameVariant(after error: Error) -> Bool {
        // Timeouts are worth retrying — the model may have been busy.
        if error is ImagePlaygroundGenerationError {
            return true
        }

        guard let imageError = error as? ImageCreator.Error else {
            // Unknown failures — retry once but don't burn time.
            return true
        }

        switch imageError {
        case .unavailable:
            // Transient system resource issue — retry.
            return true
        case .creationFailed:
            // Almost always content filtering. Don't waste time retrying
            // the same prompt — escalate to the next variant immediately.
            return false
        case .notSupported,
             .creationCancelled,
             .faceInImageTooSmall,
             .unsupportedLanguage,
             .unsupportedInputImage,
             .backgroundCreationForbidden,
             .conceptsRequirePersonIdentity:
            return false
        @unknown default:
            return true
        }
    }

    static func userFacingErrorMessage(for error: Error) -> String {
        let description = String(describing: error).lowercased()
        if description.contains("guardrail")
            || description.contains("unsafe")
            || description.contains("sensitive")
            || description.contains("policy")
        {
            return "Image safety filter blocked this frame. Try retrying or editing the story wording."
        }
        if description.contains("unsupportedlanguage") {
            return "This prompt couldn't be generated in the current language. Try simpler English wording."
        }
        if description.contains("timed out") {
            return "Image generation took too long for this frame. Please retry."
        }
        if description.contains("backgroundcreationforbidden")
            || description.contains("background") {
            return "Keep StoryFox in the foreground while images are generating."
        }
        return "Could not generate this frame right now. Please retry."
    }

    func reset() {
        generatedImages = [:]
        lastStatusMessage = nil
        variantSuccessCounts = [:]
        promptAnalyses = [:]
        conceptDecompositions = [:]
        state = .idle
    }

    /// Build a character description prefix from the LLM-generated character sheet.
    /// Uses natural language ("Featuring Luna, a small orange fox...") that diffusion
    /// models parse better than structured "Characters: ... Scene: " format.
    static func buildCharacterPrefix(from descriptions: String) -> String {
        let characters = ImagePromptEnricher.parseCharacterDescriptions(descriptions)
        return buildCharacterPrefix(from: characters)
    }

    /// Build a character description prefix from pre-parsed character entries (Upgrade 1).
    static func buildCharacterPrefix(from characters: [ImagePromptEnricher.CharacterEntry]) -> String {
        guard !characters.isEmpty else { return "" }

        // Cap at 2 characters to stay within prompt length limits
        let featured = characters.prefix(2)
        let phrases = featured.map { char in
            "\(char.name), \(char.injectionPhrase)"
        }

        let prefix = "Featuring \(phrases.joined(separator: " and ")). "
        let sanitized = ContentSafetyPolicy.sanitizeConcept(prefix, maxLength: 200)
        return sanitized
    }

    /// Enrich a prompt with character descriptions, avoiding duplication.
    ///
    /// If `ImagePromptEnricher` has already injected species descriptors inline
    /// (e.g. "Luna, a small orange fox with a green scarf, is digging..."),
    /// the prompt is returned as-is. Otherwise, a "Featuring ..." prefix is prepended.
    ///
    /// This prevents the double-descriptor bug where both the inline enricher and
    /// the prefix enricher stack on the same character descriptions.
    static func enrichPromptWithCharacters(
        _ prompt: String,
        characterDescriptions: String,
        parsedCharacters: [ImagePromptEnricher.CharacterEntry] = []
    ) -> String {
        let characters = parsedCharacters.isEmpty
            ? ImagePromptEnricher.parseCharacterDescriptions(characterDescriptions)
            : parsedCharacters
        guard !characters.isEmpty else { return prompt }

        let promptLower = prompt.lowercased()

        // Check which characters are mentioned by name in the prompt
        let mentionedChars = characters.prefix(2).filter { char in
            promptLower.contains(char.name.lowercased())
        }

        // If characters ARE mentioned and they all already have their species
        // described inline, the enricher already handled it — skip the prefix.
        let alreadyEnriched = !mentionedChars.isEmpty && mentionedChars.allSatisfy { char in
            !char.species.isEmpty && promptLower.contains(char.species)
        }

        if alreadyEnriched {
            return prompt
        }

        // Prompt has no inline character descriptions (e.g. cover prompts,
        // or LLM wrote bare names) — prepend the "Featuring ..." prefix.
        let prefix = buildCharacterPrefix(from: characters)
        return prefix + prompt
    }
}

enum IllustrationError: LocalizedError {
    case noImageGenerated
    case creatorUnavailable

    var errorDescription: String? {
        switch self {
        case .noImageGenerated:
            "Failed to generate an illustration. Please try again."
        case .creatorUnavailable:
            "Image Playground is not available on this device."
        }
    }
}

// MARK: - Async Semaphore for concurrency limiting

actor AsyncSemaphore {
    private let limit: Int
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
        self.count = limit
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if waiters.isEmpty {
            count += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

// MARK: - Debug Variant Chain Inspection

#if DEBUG
extension IllustrationGenerator {
    /// Information about a single prompt variant in the fallback chain.
    struct PromptVariantInfo: Sendable {
        let label: String
        let text: String
        let charCount: Int
        let exceedsLimit: Bool
    }

    /// Build the variant chain for a prompt WITHOUT generating images.
    /// Mirrors the logic in `generateSingleImage` but returns the variants for inspection.
    func inspectVariantChain(
        for prompt: String,
        characterDescriptions: String = "",
        analysis: PromptAnalysis? = nil
    ) -> [PromptVariantInfo] {
        let enrichedPrompt = Self.enrichPromptWithCharacters(prompt, characterDescriptions: characterDescriptions)
        let hasCharPrefix = enrichedPrompt.hasPrefix("Featuring ") || enrichedPrompt.hasPrefix("Characters: ")
        let limit = hasCharPrefix ? 300 : 180

        let variants: [(label: String, text: String)] = [
            ("sanitized", ContentSafetyPolicy.safeIllustrationPrompt(enrichedPrompt, extendedLimit: hasCharPrefix)),
            ("shortened", shortenedScenePrompt(from: enrichedPrompt, analysis: analysis)),
            ("highReliability", highReliabilityIllustrationPrompt(from: enrichedPrompt, analysis: analysis)),
            ("fallback", fallbackIllustrationPrompt(from: enrichedPrompt, analysis: analysis)),
            ("ultraSafe", ultraSafeIllustrationPrompt(from: enrichedPrompt, analysis: analysis)),
        ]

        return variants.map { v in
            PromptVariantInfo(
                label: v.label,
                text: v.text,
                charCount: v.text.count,
                exceedsLimit: v.text.count > limit
            )
        }
    }
}
#endif

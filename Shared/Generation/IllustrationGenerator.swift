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
    private nonisolated(unsafe) static let logger = Logger(subsystem: "com.storyjuicer.app", category: "Illustrations")

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
    private var variantSuccessCounts: [String: Int] = [:]

    init(router: ImageGenerationRouter = ImageGenerationRouter()) {
        self.router = router
    }

    /// Generate illustrations for all story pages concurrently with limited parallelism.
    func generateIllustrations(
        for pages: [StoryPage],
        coverPrompt: String,
        style: IllustrationStyle,
        format: BookFormat = .standard,
        onImageReady: @MainActor @Sendable (Int, CGImage) -> Void
    ) async throws {
        generatedImages = [:]
        lastStatusMessage = nil
        activeImageProvider = nil
        variantSuccessCounts = [:]
        let totalCount = pages.count + 1 // +1 for cover
        state = .generating(currentPage: 0, completedCount: 0, totalCount: totalCount)
        let sessionStart = ContinuousClock.now

        let semaphore = AsyncSemaphore(limit: GenerationConfig.maxConcurrentImages)
        var completedCount = 0
        var failedJobs: [(index: Int, prompt: String)] = []

        try await withThrowingTaskGroup(of: (Int, String, CGImage?).self) { group in
            // Cover image (index 0)
            group.addTask { [style] in
                await semaphore.wait()
                defer { Task { await semaphore.signal() } }
                do {
                    let image = try await self.generateSingleImage(
                        prompt: coverPrompt,
                        style: style,
                        format: format
                    )
                    return (0, coverPrompt, image)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    Self.logger.warning("Cover image failed in parallel pass: \(String(describing: error), privacy: .public)")
                    return (0, coverPrompt, nil)
                }
            }

            // Page illustrations (index = pageNumber)
            for page in pages {
                group.addTask { [style] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    do {
                        let image = try await self.generateSingleImage(
                            prompt: page.imagePrompt,
                            style: style,
                            format: format
                        )
                        return (page.pageNumber, page.imagePrompt, image)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        Self.logger.warning("Page \(page.pageNumber) failed in parallel pass: \(String(describing: error), privacy: .public)")
                        return (page.pageNumber, page.imagePrompt, nil)
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
    /// - Parameter startingVariantIndex: Skip earlier variants (used by recovery passes to avoid replaying failures).
    func generateSingleImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat = .standard,
        startingVariantIndex: Int = 0
    ) async throws -> CGImage {
        var lastError: Error = IllustrationError.noImageGenerated
        lastStatusMessage = nil
        let allVariantsStart = ContinuousClock.now
        var promptVariants = [
            ContentSafetyPolicy.safeIllustrationPrompt(prompt),
            shortenedScenePrompt(from: prompt),
            highReliabilityIllustrationPrompt(from: prompt),
            fallbackIllustrationPrompt(from: prompt),
            ultraSafeIllustrationPrompt(from: prompt)
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
                        format: format
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
                        durationSeconds: secs
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
                        durationSeconds: secs
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

    private func shortenedScenePrompt(from prompt: String) -> String {
        let sanitized = ContentSafetyPolicy.sanitizeConcept(prompt)
        let words = sanitized
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .prefix(18)
            .joined(separator: " ")

        return words.isEmpty ? "friendly animals in a sunny meadow" : words
    }

    private func highReliabilityIllustrationPrompt(from prompt: String) -> String {
        let sanitized = ContentSafetyPolicy.sanitizeConcept(prompt)
        let words = sanitized
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .prefix(12)
            .joined(separator: " ")

        return words.isEmpty ? "friendly animals playing together" : words
    }

    private func fallbackIllustrationPrompt(from prompt: String) -> String {
        let sanitized = ContentSafetyPolicy.sanitizeConcept(prompt)
        let words = sanitized
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .prefix(8)
            .joined(separator: " ")

        return words.isEmpty ? "happy animals in a garden" : "\(words) in a cheerful scene"
    }

    private func ultraSafeIllustrationPrompt(from prompt: String) -> String {
        let sanitized = ContentSafetyPolicy.sanitizeConcept(prompt)
        let words = sanitized
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .prefix(4)
            .joined(separator: " ")

        return words.isEmpty ? "cute animals sunny day" : "\(words) sunny day"
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
            return "Keep StoryJuicer in the foreground while images are generating."
        }
        return "Could not generate this frame right now. Please retry."
    }

    func reset() {
        generatedImages = [:]
        lastStatusMessage = nil
        variantSuccessCounts = [:]
        state = .idle
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

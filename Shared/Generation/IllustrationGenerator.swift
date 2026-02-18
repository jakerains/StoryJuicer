import Foundation
import FoundationModels
import ImagePlayground
import CoreGraphics

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

    private(set) var state: IllustrationGenerationState = .idle
    private(set) var generatedImages: [Int: CGImage] = [:]

    /// Generate illustrations for all story pages concurrently with limited parallelism.
    func generateIllustrations(
        for pages: [StoryPage],
        coverPrompt: String,
        style: IllustrationStyle,
        onImageReady: @MainActor @Sendable (Int, CGImage) -> Void
    ) async throws {
        generatedImages = [:]
        let totalCount = pages.count + 1 // +1 for cover
        state = .generating(currentPage: 0, completedCount: 0, totalCount: totalCount)

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
                        style: style
                    )
                    return (0, coverPrompt, image)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
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
                            style: style
                        )
                        return (page.pageNumber, page.imagePrompt, image)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
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
            // Recovery pass: retry missing frames one-by-one to reduce contention with Image Playground.
            for job in failedJobs.sorted(by: { $0.index < $1.index }) {
                if generatedImages[job.index] != nil {
                    continue
                }
                do {
                    let image = try await generateSingleImage(
                        prompt: job.prompt,
                        style: style
                    )
                    generatedImages[job.index] = image
                    onImageReady(job.index, image)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // Leave the frame missing; caller can still retry from the reader.
                    continue
                }
            }
        }

        state = .complete
    }

    /// Generate a single illustration from a text prompt.
    /// Retries automatically on guardrail false positives.
    func generateSingleImage(
        prompt: String,
        style: IllustrationStyle
    ) async throws -> CGImage {
        var lastError: Error = IllustrationError.noImageGenerated
        var promptVariants = [
            ContentSafetyPolicy.safeIllustrationPrompt(prompt),
            softenedIllustrationPrompt(from: prompt),
            fallbackIllustrationPrompt(from: prompt)
        ]
        var variantIndex = 0

        while variantIndex < promptVariants.count {
            let variant = promptVariants[variantIndex]
            for attempt in 0...GenerationConfig.guardrailRetryAttempts {
                do {
                    return try await requestImage(prompt: variant, style: style)
                } catch {
                    lastError = error
                    if error is CancellationError {
                        throw error
                    }

                    // Retry the current variant for likely guardrail/transient failures.
                    if attempt < GenerationConfig.guardrailRetryAttempts {
                        try await Task.sleep(for: .milliseconds(450))
                        continue
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

        throw lastError
    }

    private func requestImage(prompt: String, style: IllustrationStyle) async throws -> CGImage {
        guard ImagePlaygroundViewController.isAvailable else {
            throw IllustrationError.creatorUnavailable
        }
        let creator = try await ImageCreator()
        let images = creator.images(
            for: [.text(prompt)],
            style: style.playgroundStyle,
            limit: 1
        )
        for try await image in images {
            return image.cgImage
        }
        throw IllustrationError.noImageGenerated
    }

    private func softenedIllustrationPrompt(from prompt: String) -> String {
        let sanitized = ContentSafetyPolicy.sanitizeConcept(prompt)
        let words = sanitized
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .prefix(18)
            .joined(separator: " ")

        let seed = words.isEmpty ? "a gentle story scene" : words
        return """
            Child-friendly picture book scene of \(seed). \
            Bright daytime colors, warm expressions, playful and calm mood, no text, no conflict, no scary details.
            """
    }

    private func fallbackIllustrationPrompt(from prompt: String) -> String {
        let sanitized = ContentSafetyPolicy.sanitizeConcept(prompt)
        let context = sanitized.isEmpty ? "a gentle story moment" : String(sanitized.prefix(80))
        return """
            Whimsical children's book illustration inspired by \(context). \
            Friendly characters, soft rounded shapes, warm lighting, cheerful colors, family-friendly, no text.
            """
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
                Keep the output family-friendly, non-violent, cheerful, and specific enough to draw.
                Never include copyrighted character names, violence, horror, sensitive topics, or text overlays.
                """
        )

        let rewriteRequest = """
            Rewrite this prompt into a short, child-safe picture-book illustration description.
            Return only the rewritten prompt.
            Original prompt: \(sanitized)
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

    static func userFacingErrorMessage(for error: Error) -> String {
        let description = String(describing: error).lowercased()
        if description.contains("guardrail")
            || description.contains("unsafe")
            || description.contains("sensitive")
            || description.contains("policy")
        {
            return "Image safety filter blocked this frame. Try retrying or editing the story wording."
        }
        return "Could not generate this frame right now. Please retry."
    }

    func reset() {
        generatedImages = [:]
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

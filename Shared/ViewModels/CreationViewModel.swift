import Foundation
import CoreGraphics
import FoundationModels

enum GenerationPhase: Sendable, Equatable {
    case idle
    case generatingText(partialText: String)
    case generatingImages(completedCount: Int, totalCount: Int)
    case complete
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .generatingText, .generatingImages: true
        default: false
        }
    }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

@Observable
@MainActor
final class CreationViewModel {
    // MARK: - User Inputs
    var storyConcept: String = ""
    var pageCount: Int = GenerationConfig.defaultPages
    var selectedFormat: BookFormat = .standard
    var selectedStyle: IllustrationStyle = .illustration

    // MARK: - Generation State
    private(set) var phase: GenerationPhase = .idle
    private(set) var storyBook: StoryBook?
    private(set) var generatedImages: [Int: CGImage] = [:]

    // MARK: - Generators
    let storyGenerator = StoryGenerator()
    let remoteStoryGenerator = RemoteStoryGenerator()
    let illustrationGenerator = IllustrationGenerator()

    private var generationTask: Task<Void, Never>?

    var canGenerate: Bool {
        !storyConcept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phase.isWorking
    }

    var isAvailable: Bool {
        remoteStoryGenerator.isConfigured || storyGenerator.isAvailable
    }

    var unavailabilityReason: String? {
        if remoteStoryGenerator.isConfigured || storyGenerator.isAvailable {
            return nil
        }
        return storyGenerator.unavailabilityReason
    }

    // MARK: - Generation

    func squeezeStory() {
        guard canGenerate else { return }

        let conceptCheck = ContentSafetyPolicy.validateConcept(storyConcept)
        guard case .allowed(let safeConcept) = conceptCheck else {
            if case .blocked(let reason) = conceptCheck {
                phase = .failed(reason)
            }
            return
        }

        generationTask = Task {
            do {
                // Phase 1: Generate text
                phase = .generatingText(partialText: "")

                let book = try await generateStoryWithRouting(
                    concept: safeConcept,
                    pageCount: pageCount
                )
                storyBook = book

                // Phase 2: Generate illustrations
                let totalImages = book.pages.count + 1
                phase = .generatingImages(completedCount: 0, totalCount: totalImages)
                generatedImages = [:]

                let coverPrompt = ContentSafetyPolicy.safeCoverPrompt(
                    title: book.title,
                    concept: safeConcept
                )

                try await illustrationGenerator.generateIllustrations(
                    for: book.pages,
                    coverPrompt: coverPrompt,
                    style: selectedStyle
                ) { [weak self] index, image in
                    guard let self else { return }
                    self.generatedImages[index] = image
                    let completed = self.generatedImages.count
                    self.phase = .generatingImages(completedCount: completed, totalCount: totalImages)
                }

                generatedImages = illustrationGenerator.generatedImages
                phase = .complete

            } catch is CancellationError {
                phase = .idle
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error {
                    phase = .failed(
                        "Apple's safety filter blocked this request. "
                        + "Please rephrase with gentler, child-friendly wording and try again."
                    )
                } else {
                    phase = .failed(error.localizedDescription)
                }
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        storyGenerator.cancel()
        phase = .idle
    }

    func reset() {
        cancel()
        storyBook = nil
        generatedImages = [:]
        phase = .idle
    }

    /// Observe the story generator state to relay partial text to our phase.
    func syncTextProgress() {
        if case .generating(let partialText) = storyGenerator.state {
            phase = .generatingText(partialText: partialText)
        }
    }

    private func generateStoryWithRouting(
        concept: String,
        pageCount: Int
    ) async throws -> StoryBook {
        if remoteStoryGenerator.isConfigured {
            phase = .generatingText(partialText: "Using larger model for story drafting...")
            do {
                return try await remoteStoryGenerator.generateStory(
                    concept: concept,
                    pageCount: pageCount
                )
            } catch {
                if storyGenerator.isAvailable {
                    phase = .generatingText(partialText: "Large model unavailable, switching to on-device model...")
                } else {
                    throw error
                }
            }
        }

        return try await storyGenerator.generateStory(
            concept: concept,
            pageCount: pageCount
        ) { [weak self] partialText in
            guard let self else { return }
            self.phase = .generatingText(partialText: partialText)
        }
    }
}

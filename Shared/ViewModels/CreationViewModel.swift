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
    var isEnrichedConcept: Bool = false

    // MARK: - Author Mode Inputs
    var authorTitle: String = ""
    var authorCharacterDescriptions: String = ""
    var authorPages: [String] = ["", "", "", ""]

    // MARK: - Generation State
    private(set) var phase: GenerationPhase = .idle
    private(set) var storyBook: StoryBook?
    private(set) var generatedImages: [Int: CGImage] = [:]
    /// Pre-parsed character entries from Foundation Model (Upgrade 1).
    /// Set during `squeezeStory()`, passed to `BookReaderViewModel` for regeneration.
    private(set) var parsedCharacters: [ImagePromptEnricher.CharacterEntry] = []

    // MARK: - Generators
    let storyGenerator = StoryGenerator()
    let remoteStoryGenerator = RemoteStoryGenerator()
    let mlxStoryGenerator = MLXStoryGenerator()
    let illustrationGenerator = IllustrationGenerator()

    private var generationTask: Task<Void, Never>?

    var canGenerate: Bool {
        !storyConcept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phase.isWorking
    }

    /// Whether Author Mode has enough content to generate illustrations.
    var canIllustrateAuthorStory: Bool {
        !authorTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && authorPages.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            && !phase.isWorking
    }

    var isAvailable: Bool {
        let settings = ModelSelectionStore.load()
        switch settings.textProvider {
        case .appleFoundation:
            return remoteStoryGenerator.isConfigured || storyGenerator.isAvailable
        case .mlxSwift:
            return true
        case .openRouter:
            return CloudCredentialStore.isAuthenticated(for: .openRouter)
        case .togetherAI:
            return CloudCredentialStore.isAuthenticated(for: .togetherAI)
        case .huggingFace:
            return CloudCredentialStore.isAuthenticated(for: .huggingFace)
        }
    }

    var unavailabilityReason: String? {
        let settings = ModelSelectionStore.load()
        switch settings.textProvider {
        case .appleFoundation:
            if remoteStoryGenerator.isConfigured || storyGenerator.isAvailable {
                return nil
            }
            return storyGenerator.unavailabilityReason
        case .mlxSwift:
            return nil
        case .openRouter:
            return CloudCredentialStore.isAuthenticated(for: .openRouter)
                ? nil : "OpenRouter API key not configured. Add it in Settings."
        case .togetherAI:
            return CloudCredentialStore.isAuthenticated(for: .togetherAI)
                ? nil : "Together AI API key not configured. Add it in Settings."
        case .huggingFace:
            return CloudCredentialStore.isAuthenticated(for: .huggingFace)
                ? nil : "Hugging Face not authenticated. Log in via Settings."
        }
    }

    // MARK: - Generation

    func squeezeStory() {
        guard canGenerate else { return }

        // Enriched concepts from Q&A are longer — use a higher sanitization limit
        let maxLength = isEnrichedConcept ? 1500 : 220
        let conceptCheck = ContentSafetyPolicy.validateConcept(storyConcept, maxLength: maxLength)
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

                let rawBook = try await generateStoryWithRouting(
                    concept: safeConcept,
                    pageCount: pageCount
                )

                // Phase 1.2: Validate/repair character descriptions with Foundation Model
                let repairedDescriptions = await CharacterDescriptionValidator.validateAsync(
                    descriptions: rawBook.characterDescriptions,
                    pages: rawBook.pages,
                    title: rawBook.title
                )
                let descriptionRepairedBook = StoryBook(
                    title: rawBook.title,
                    authorLine: rawBook.authorLine,
                    moral: rawBook.moral,
                    characterDescriptions: repairedDescriptions,
                    pages: rawBook.pages
                )

                // Phase 1.3: Parse character descriptions with Foundation Model
                self.parsedCharacters = await ImagePromptEnricher.parseCharacterDescriptionsAsync(
                    descriptionRepairedBook.characterDescriptions
                )
                let parsedCharacters = self.parsedCharacters

                // Phase 1.5: Analyze image prompts with Foundation Model
                let promptsToAnalyze = [(index: 0, prompt: ContentSafetyPolicy.safeCoverPrompt(
                    title: descriptionRepairedBook.title, concept: safeConcept
                ))] + descriptionRepairedBook.pages.map { (index: $0.pageNumber, prompt: $0.imagePrompt) }
                let analyses = await PromptAnalysisEngine.analyzePrompts(promptsToAnalyze)

                let book = ImagePromptEnricher.enrichImagePrompts(
                    in: descriptionRepairedBook,
                    analyses: analyses,
                    parsedCharacters: parsedCharacters
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
                    characterDescriptions: book.characterDescriptions,
                    style: selectedStyle,
                    format: selectedFormat,
                    analyses: analyses,
                    parsedCharacters: parsedCharacters
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

    // MARK: - Author Mode Generation

    /// Assemble a StoryBook from author-written text, generate image prompts,
    /// run the full enrichment + illustration pipeline.
    func illustrateAuthorStory() {
        guard canIllustrateAuthorStory else { return }

        generationTask = Task {
            do {
                phase = .generatingText(partialText: "Preparing your story...")

                // Build pages from author input, filtering out empty pages
                let filledPages = authorPages.enumerated().compactMap { offset, text -> (pageNumber: Int, text: String)? in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    return (pageNumber: offset + 1, text: trimmed)
                }

                guard !filledPages.isEmpty else {
                    phase = .failed("Please write text for at least one page.")
                    return
                }

                let safeTitle = authorTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let charDescriptions = authorCharacterDescriptions.trimmingCharacters(in: .whitespacesAndNewlines)

                // Generate image prompts via Foundation Models (or heuristic fallback)
                let promptSheet = try await AuthorImagePromptGenerator.generateImagePrompts(
                    characterDescriptions: charDescriptions,
                    pages: filledPages,
                    onProgress: { [weak self] text in
                        guard let self else { return }
                        self.phase = .generatingText(partialText: text)
                    }
                )

                // Merge author text + generated prompts into a StoryBook
                let promptsByPage = Dictionary(
                    promptSheet.prompts.map { ($0.pageNumber, $0.imagePrompt) },
                    uniquingKeysWith: { _, last in last }
                )

                let storyPages = filledPages.enumerated().map { offset, page -> StoryPage in
                    let pageNumber = offset + 1
                    let prompt = promptsByPage[page.pageNumber]?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let fallbackPrompt = ContentSafetyPolicy.safeIllustrationPrompt(
                        "A gentle children's book illustration for a story page"
                    )
                    return StoryPage(
                        pageNumber: pageNumber,
                        text: page.text,
                        imagePrompt: prompt.isEmpty ? fallbackPrompt : prompt
                    )
                }

                let rawBook = StoryBook(
                    title: safeTitle,
                    authorLine: "Written by You",
                    moral: "",
                    characterDescriptions: charDescriptions,
                    pages: storyPages
                )

                // Run the same enrichment pipeline as squeezeStory()
                let repairedDescriptions = await CharacterDescriptionValidator.validateAsync(
                    descriptions: rawBook.characterDescriptions,
                    pages: rawBook.pages,
                    title: rawBook.title
                )
                let descriptionRepairedBook = StoryBook(
                    title: rawBook.title,
                    authorLine: rawBook.authorLine,
                    moral: rawBook.moral,
                    characterDescriptions: repairedDescriptions,
                    pages: rawBook.pages
                )

                self.parsedCharacters = await ImagePromptEnricher.parseCharacterDescriptionsAsync(
                    descriptionRepairedBook.characterDescriptions
                )
                let parsedCharacters = self.parsedCharacters

                let coverPrompt = AuthorImagePromptGenerator.coverPrompt(title: safeTitle)
                let promptsToAnalyze = [(index: 0, prompt: coverPrompt)]
                    + descriptionRepairedBook.pages.map { (index: $0.pageNumber, prompt: $0.imagePrompt) }
                let analyses = await PromptAnalysisEngine.analyzePrompts(promptsToAnalyze)

                let book = ImagePromptEnricher.enrichImagePrompts(
                    in: descriptionRepairedBook,
                    analyses: analyses,
                    parsedCharacters: parsedCharacters
                )
                storyBook = book

                // Generate illustrations
                let totalImages = book.pages.count + 1
                phase = .generatingImages(completedCount: 0, totalCount: totalImages)
                generatedImages = [:]

                try await illustrationGenerator.generateIllustrations(
                    for: book.pages,
                    coverPrompt: coverPrompt,
                    characterDescriptions: book.characterDescriptions,
                    style: selectedStyle,
                    format: selectedFormat,
                    analyses: analyses,
                    parsedCharacters: parsedCharacters
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
        parsedCharacters = []
        authorTitle = ""
        authorCharacterDescriptions = ""
        authorPages = ["", "", "", ""]
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
        let settings = ModelSelectionStore.load()
        switch settings.textProvider {
        case .appleFoundation:
            return try await generateFoundationRoutedStory(
                concept: concept,
                pageCount: pageCount
            )

        case .mlxSwift:
            phase = .generatingText(partialText: "Using MLX model for story drafting...")
            do {
                return try await mlxStoryGenerator.generateStory(
                    concept: concept,
                    pageCount: pageCount,
                    onProgress: { [weak self] partialText in
                        guard let self else { return }
                        self.phase = .generatingText(partialText: partialText)
                    }
                )
            } catch {
                if settings.enableFoundationFallback {
                    phase = .generatingText(partialText: "MLX model unavailable, switching to Apple Foundation path...")
                    return try await generateFoundationRoutedStory(
                        concept: concept,
                        pageCount: pageCount
                    )
                } else {
                    throw error
                }
            }

        case .openRouter, .togetherAI, .huggingFace:
            return try await generateCloudStory(
                concept: concept,
                pageCount: pageCount,
                provider: settings.textProvider.cloudProvider!,
                enableFallback: settings.enableFoundationFallback
            )
        }
    }

    private func generateCloudStory(
        concept: String,
        pageCount: Int,
        provider: CloudProvider,
        enableFallback: Bool
    ) async throws -> StoryBook {
        let generator = CloudTextGenerator(cloudProvider: provider)
        phase = .generatingText(partialText: "Using \(provider.displayName) for story drafting...")
        do {
            return try await generator.generateStory(
                concept: concept,
                pageCount: pageCount,
                onProgress: { [weak self] partialText in
                    guard let self else { return }
                    self.phase = .generatingText(partialText: partialText)
                }
            )
        } catch {
            if enableFallback {
                phase = .generatingText(partialText: "\(provider.displayName) unavailable, switching to Apple Foundation path...")
                return try await generateFoundationRoutedStory(
                    concept: concept,
                    pageCount: pageCount
                )
            } else {
                throw error
            }
        }
    }

    private func generateFoundationRoutedStory(
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

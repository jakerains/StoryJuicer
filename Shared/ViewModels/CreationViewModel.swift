import Foundation
import CoreGraphics
import FoundationModels
import os

enum GenerationPhase: Sendable, Equatable {
    case idle
    case generatingText(partialText: String)
    case generatingCharacterSheet
    case generatingImages(completedCount: Int, totalCount: Int)
    case complete
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .generatingText, .generatingCharacterSheet, .generatingImages: true
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
    private static let logger = Logger(subsystem: "com.storyfox.app", category: "CreationVM")

    // MARK: - User Inputs
    var storyConcept: String = ""
    var pageCount: Int = GenerationConfig.defaultPages
    var selectedFormat: BookFormat = .standard
    var selectedStyle: IllustrationStyle = .illustration
    var isEnrichedConcept: Bool = false

    // MARK: - Prompt Suggestions (typewriter cycle)
    private var promptSuggestions: [String] = []
    private var suggestionsGenerated = false
    private var suggestionsTask: Task<Void, Never>?
    private var suggestionCycleTask: Task<Void, Never>?
    private var suggestionRestartTask: Task<Void, Never>?
    private var currentSuggestionIndex: Int = 0

    /// The portion of the suggestion typed out so far (for display as placeholder).
    private(set) var suggestionDisplayText: String = ""
    /// The full text of the currently active suggestion (nil when idle).
    private(set) var activeSuggestion: String? = nil
    /// Opacity for fade-in/out of the typewriter text.
    private(set) var suggestionOpacity: Double = 0
    /// Whether the suggestion cycle is actively running (stable across inter-suggestion gaps).
    private(set) var isSuggestionCycleActive = false

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

    // MARK: - Premium
    /// Character photos uploaded by the user for reference-based generation.
    var characterPhotos: [CharacterPhotoReference] = []
    /// Generated character reference sheet for premium pipeline visual consistency.
    private(set) var characterSheetImage: CGImage?

    // MARK: - Generators
    let storyGenerator = StoryGenerator()
    let remoteStoryGenerator = RemoteStoryGenerator()
    let mlxStoryGenerator = MLXStoryGenerator()
    let illustrationGenerator = IllustrationGenerator()

    private var generationTask: Task<Void, Never>?

    var canGenerate: Bool {
        let hasConcept = !storyConcept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || activeSuggestion != nil
        return hasConcept && !phase.isWorking
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
        case .openAI:
            return true  // Uses server-side proxy, no client API key needed
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
        case .openAI:
            return nil  // Uses server-side proxy, no client API key needed
        }
    }

    // MARK: - Generation

    func squeezeStory() {
        // If concept is empty but a suggestion is active, use the full suggestion
        if storyConcept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let suggestion = activeSuggestion {
            storyConcept = suggestion
            stopSuggestionCycle()
        }

        guard canGenerate else { return }
        stopSuggestionCycle()

        // Enriched concepts from Q&A are longer — use a higher sanitization limit
        let maxLength = isEnrichedConcept ? 1500 : 220
        let conceptCheck = ContentSafetyPolicy.validateConcept(storyConcept, maxLength: maxLength)
        guard case .allowed(let safeConcept) = conceptCheck else {
            if case .blocked(let reason) = conceptCheck {
                phase = .failed(reason)
            }
            return
        }

        var settings = ModelSelectionStore.load()
        let premium = PremiumStore.load()
        if premium.tier.isActive {
            settings.textProvider = .openAI
            settings.imageProvider = .openAI
        }
        let useCloudTextPath = settings.textProvider.isCloud

        generationTask = Task {
            // Start verbose logging session (no-op when disabled)
            let verboseID = await VerboseGenerationLogger.shared.startSession(
                concept: safeConcept,
                pageCount: pageCount,
                format: selectedFormat.displayName,
                style: selectedStyle.displayName,
                textProvider: settings.textProvider.displayName,
                imageProvider: settings.imageProvider.displayName,
                textModel: settings.resolvedTextModelLabel,
                imageModel: settings.resolvedImageModelLabel,
                premiumTier: premium.tier.displayName
            )
            if let sid = verboseID {
                await VerboseGenerationLogger.shared.setActiveSession(sid)
            }
            let sessionClock = ContinuousClock()
            let sessionStart = sessionClock.now

            do {
                // Phase 1: Generate text
                phase = .generatingText(partialText: "")

                let rawBook = try await generateStoryWithRouting(
                    concept: safeConcept,
                    pageCount: pageCount,
                    settingsOverride: settings
                )

                let book: StoryBook
                let analyses: [Int: PromptAnalysis]
                let parsedCharacters: [ImagePromptEnricher.CharacterEntry]

                if useCloudTextPath {
                    // Cloud LLMs produce good text and image prompts — skip all
                    // Foundation Model post-processing (repair, parse, analyze).
                    book = rawBook
                    analyses = [:]
                    parsedCharacters = ImagePromptEnricher.parseCharacterDescriptions(
                        rawBook.characterDescriptions
                    )
                    self.parsedCharacters = parsedCharacters
                } else {
                    // On-device / MLX path: run Foundation Model enrichment pipeline.

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
                    parsedCharacters = self.parsedCharacters

                    // Phase 1.5: Analyze image prompts with Foundation Model
                    let promptsToAnalyze = [(index: 0, prompt: ContentSafetyPolicy.safeCoverPrompt(
                        title: descriptionRepairedBook.title, concept: safeConcept
                    ))] + descriptionRepairedBook.pages.map { (index: $0.pageNumber, prompt: $0.imagePrompt) }
                    analyses = await PromptAnalysisEngine.analyzePrompts(promptsToAnalyze)

                    book = ImagePromptEnricher.enrichImagePrompts(
                        in: descriptionRepairedBook,
                        analyses: analyses,
                        parsedCharacters: parsedCharacters
                    )
                }

                storyBook = book

                // Phase 2: Generate character sheet (Premium Plus only)
                // Creates a style-matched reference image of the main character
                // that anchors visual consistency across all page illustrations.
                var characterSheet: CGImage? = nil
                if premium.tier.usesCharacterSheet {
                    phase = .generatingCharacterSheet

                    do {
                        // Extract main character description (first entry)
                        let mainCharacter: String
                        if !parsedCharacters.isEmpty {
                            let first = parsedCharacters[0]
                            mainCharacter = "\(first.name) - \(first.injectionPhrase)"
                        } else {
                            // Fallback: use the raw characterDescriptions first line
                            mainCharacter = book.characterDescriptions
                                .components(separatedBy: .newlines)
                                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
                                ?? book.characterDescriptions
                        }

                        let sheetPrompt = StoryPromptTemplates.characterSheetPrompt(
                            characterDescription: mainCharacter,
                            style: selectedStyle
                        )

                        // Determine reference photo (first uploaded photo, if any)
                        let referencePhoto = characterPhotos.first?.photoData

                        let sheetGenerator = CloudImageGenerator(cloudProvider: .openAI)
                        characterSheet = try await sheetGenerator.generateCharacterSheet(
                            prompt: sheetPrompt,
                            referencePhoto: referencePhoto,
                            style: selectedStyle,
                            format: selectedFormat,
                            settings: settings
                        )
                        self.characterSheetImage = characterSheet
                    } catch {
                        // Character sheet failure is non-fatal — continue without it
                        Self.logger.warning("Character sheet generation failed: \(String(describing: error), privacy: .public)")
                        self.characterSheetImage = nil
                    }
                }

                // Phase 3: Generate illustrations
                if let sid = verboseID {
                    await VerboseGenerationLogger.shared.logSection(
                        sessionID: sid,
                        heading: "Image Generation",
                        content: "Generating \(book.pages.count + 1) images (cover + \(book.pages.count) pages)..."
                    )
                }
                let totalImages = book.pages.count + 1
                phase = .generatingImages(completedCount: 0, totalCount: totalImages)
                generatedImages = [:]

                let coverPrompt = ContentSafetyPolicy.safeCoverPrompt(
                    title: book.title,
                    concept: safeConcept
                )

                // Propagate premium tier to the illustration generator for tier-aware routing
                illustrationGenerator.setPremiumTier(premium.tier)

                // Pass character photos only when Premium Plus is active
                if premium.tier.supportsPhotoUpload {
                    illustrationGenerator.setCharacterPhotos(characterPhotos)
                } else {
                    illustrationGenerator.setCharacterPhotos([])
                }

                try await illustrationGenerator.generateIllustrations(
                    for: book.pages,
                    coverPrompt: coverPrompt,
                    characterDescriptions: book.characterDescriptions,
                    characterSheetImage: characterSheet,
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

                // End verbose logging session
                if let sid = verboseID {
                    let elapsed = sessionStart.duration(to: sessionClock.now)
                    let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                    await VerboseGenerationLogger.shared.endSession(
                        sid,
                        totalDuration: seconds,
                        imageStats: (total: totalImages, succeeded: generatedImages.count)
                    )
                    await VerboseGenerationLogger.shared.setActiveSession(nil)
                }

            } catch is CancellationError {
                await VerboseGenerationLogger.shared.setActiveSession(nil)
                phase = .idle
            } catch let error as LanguageModelSession.GenerationError {
                await VerboseGenerationLogger.shared.setActiveSession(nil)
                if case .guardrailViolation = error {
                    phase = .failed(
                        "Apple's safety filter blocked this request. "
                        + "Please rephrase with gentler, child-friendly wording and try again."
                    )
                } else {
                    phase = .failed(error.localizedDescription)
                }
            } catch {
                await VerboseGenerationLogger.shared.setActiveSession(nil)
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

    // MARK: - Prompt Suggestions

    func generateSuggestions() {
        guard !suggestionsGenerated else { return }
        suggestionsGenerated = true

        suggestionsTask = Task {
            let concepts = await SuggestionGenerator.generate()
            promptSuggestions = concepts ?? SuggestionGenerator.randomFallback()
            startSuggestionCycle()
        }
    }

    func stopSuggestionCycle() {
        suggestionRestartTask?.cancel()
        suggestionRestartTask = nil
        suggestionCycleTask?.cancel()
        suggestionCycleTask = nil
        suggestionDisplayText = ""
        activeSuggestion = nil
        suggestionOpacity = 0
        isSuggestionCycleActive = false
    }

    /// Restart the suggestion cycle after a brief delay (e.g. when the user clears the text).
    func restartSuggestionCycleAfterDelay() {
        suggestionRestartTask?.cancel()
        suggestionRestartTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            guard storyConcept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            startSuggestionCycle()
        }
    }

    private func startSuggestionCycle() {
        guard !promptSuggestions.isEmpty else { return }
        stopSuggestionCycle()
        isSuggestionCycleActive = true

        suggestionCycleTask = Task {
            while !Task.isCancelled {
                let suggestion = promptSuggestions[currentSuggestionIndex % promptSuggestions.count]
                activeSuggestion = suggestion

                // Type out character by character
                suggestionOpacity = 1.0
                for i in 1...suggestion.count {
                    guard !Task.isCancelled else { return }
                    suggestionDisplayText = String(suggestion.prefix(i))
                    try? await Task.sleep(for: .milliseconds(30))
                }

                // Hold for a few seconds so the user can read it
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(3))

                // Fade out
                guard !Task.isCancelled else { return }
                suggestionOpacity = 0
                try? await Task.sleep(for: .milliseconds(600))

                // Clear and advance to the next suggestion
                guard !Task.isCancelled else { return }
                suggestionDisplayText = ""
                activeSuggestion = nil
                currentSuggestionIndex += 1

                // Brief pause before next
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    // MARK: - Cancellation & Reset

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        suggestionsTask?.cancel()
        stopSuggestionCycle()
        storyGenerator.cancel()
        phase = .idle
    }

    func reset() {
        cancel()
        storyBook = nil
        generatedImages = [:]
        parsedCharacters = []
        characterSheetImage = nil
        authorTitle = ""
        authorCharacterDescriptions = ""
        authorPages = ["", "", "", ""]
        suggestionsGenerated = false
        currentSuggestionIndex = 0
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
        pageCount: Int,
        settingsOverride: ModelSelectionSettings? = nil
    ) async throws -> StoryBook {
        let settings = settingsOverride ?? ModelSelectionStore.load()
        switch settings.textProvider {
        case .appleFoundation:
            return try await generateFoundationRoutedStory(
                concept: concept,
                pageCount: pageCount
            )

        case .mlxSwift:
            phase = .generatingText(partialText: "The fox is opening its storybook...")
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
                    phase = .generatingText(partialText: "Trying a different quill...")
                    return try await generateFoundationRoutedStory(
                        concept: concept,
                        pageCount: pageCount
                    )
                } else {
                    throw error
                }
            }

        case .openRouter, .togetherAI, .huggingFace, .openAI:
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
        var generator = CloudTextGenerator(cloudProvider: provider)
        let premium = PremiumStore.load()
        generator.premiumTier = premium.tier
        generator.illustrationStyle = selectedStyle
        if premium.tier.supportsPhotoUpload {
            generator.characterNames = characterPhotos.map(\.name)
        }
        phase = .generatingText(partialText: "The fox is opening its storybook...")
        return try await generator.generateStory(
            concept: concept,
            pageCount: pageCount,
            onProgress: { [weak self] partialText in
                guard let self else { return }
                self.phase = .generatingText(partialText: partialText)
            }
        )
    }

    private func generateFoundationRoutedStory(
        concept: String,
        pageCount: Int
    ) async throws -> StoryBook {
        if remoteStoryGenerator.isConfigured {
            phase = .generatingText(partialText: "The fox is opening its storybook...")
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

import Foundation
import Hub
import MLXLLM
import MLXLMCommon

enum MLXStoryGeneratorError: LocalizedError {
    case missingModelID
    case emptyModelResponse

    var errorDescription: String? {
        switch self {
        case .missingModelID:
            return "No MLX model ID is configured."
        case .emptyModelResponse:
            return "MLX model returned an empty response."
        }
    }
}

private actor MLXStoryRuntime {
    static let shared = MLXStoryRuntime()

    private var cachedModelID: String?
    private var cachedContainer: ModelContainer?

    func loadContainer(
        modelID: String,
        hub: HubApi,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> ModelContainer {
        if cachedModelID == modelID, let cachedContainer {
            return cachedContainer
        }

        let configuration = ModelConfiguration(id: modelID)
        let container = try await LLMModelFactory.shared.loadContainer(
            hub: hub,
            configuration: configuration,
            progressHandler: progressHandler
        )

        cachedModelID = modelID
        cachedContainer = container
        return container
    }
}

struct MLXStoryGenerator: StoryTextGenerating, Sendable {
    private let runtime = MLXStoryRuntime.shared
    private let settingsProvider: @Sendable () -> ModelSelectionSettings

    init(
        settingsProvider: @escaping @Sendable () -> ModelSelectionSettings = { ModelSelectionStore.load() }
    ) {
        self.settingsProvider = settingsProvider
    }

    var availability: StoryProviderAvailability {
        get async {
            let settings = settingsProvider()
            let modelID = settings.mlxModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            if modelID.isEmpty {
                return .unavailable(reason: "Set an MLX model ID in Settings first.")
            }
            return .available
        }
    }

    func prewarmModel(
        onProgress: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws {
        let settings = settingsProvider()
        let modelID = try resolvedModelID(from: settings)
        let hub = makeHubAPI(settings: settings)

        _ = try await runtime.loadContainer(
            modelID: modelID,
            hub: hub
        ) { progress in
            onProgress("Fetching the fox's quill… \(Int(progress.fractionCompleted * 100))%")
        }
    }

    func generateStory(
        concept: String,
        pageCount: Int,
        onProgress: @escaping @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> StoryBook {
        let settings = settingsProvider()
        let modelID = try resolvedModelID(from: settings)
        let safeConcept = ContentSafetyPolicy.sanitizeConcept(concept)
        let hub = makeHubAPI(settings: settings)

        let container = try await runtime.loadContainer(
            modelID: modelID,
            hub: hub
        ) { progress in
            let message = "Fetching the fox's quill… \(Int(progress.fractionCompleted * 100))%"
            Task { @MainActor in
                onProgress(message)
            }
        }

        // ── Pass 1: Generate story text (no image prompts) ──
        await onProgress("Quill ready! Writing your story…")

        let pass1System = StoryPromptTemplates.jsonModeSystemInstructions
        let pass1UserPrompt = StoryPromptTemplates.textOnlyJSONPrompt(concept: safeConcept, pageCount: pageCount)

        let pass1Input = UserInput(
            chat: [
                .system(pass1System),
                .user(pass1UserPrompt)
            ]
        )

        let pass1LMInput = try await container.prepare(input: pass1Input)
        let pass1Params = GenerateParameters(
            maxTokens: GenerationConfig.mlxTokens(for: pageCount),
            temperature: Float(GenerationConfig.defaultTemperature)
        )

        let pass1Clock = ContinuousClock()
        let pass1Start = pass1Clock.now

        let pass1Stream = try await container.generate(
            input: pass1LMInput,
            parameters: pass1Params
        )

        var pass1Text = ""
        var hasReportedDraftingState = false
        var pass1Iterator = pass1Stream.makeAsyncIterator()
        while let generation = await pass1Iterator.next() {
            if Task.isCancelled { throw CancellationError() }
            if let chunk = generation.chunk, !chunk.isEmpty {
                pass1Text += chunk
                if !hasReportedDraftingState {
                    hasReportedDraftingState = true
                    await onProgress("Scribbling away...")
                }
            }
        }

        let pass1Duration = pass1Start.duration(to: pass1Clock.now)
        let pass1Seconds = Double(pass1Duration.components.seconds) + Double(pass1Duration.components.attoseconds) / 1e18

        let pass1Trimmed = pass1Text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pass1Trimmed.isEmpty else {
            throw MLXStoryGeneratorError.emptyModelResponse
        }

        let textDTO = try StoryDecoding.decodeTextOnlyStoryDTO(from: pass1Trimmed)

        // Log Pass 1
        let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
        await VerboseGenerationLogger.shared.logTextPass(
            sessionID: verboseSession,
            passLabel: "Pass 1: Story Text (MLX Swift)",
            provider: "MLX Swift", model: modelID,
            systemPrompt: pass1System, userPrompt: pass1UserPrompt,
            rawResponse: pass1Trimmed, parseSuccess: true,
            duration: pass1Seconds
        )

        // ── Pass 2: Generate image prompts with full story context ──
        await onProgress("Dreaming up illustrations for each page...")

        let pages = textDTO.pages.map { (pageNumber: $0.pageNumber, text: $0.text) }
        let pass2System = "You are an art director for a children's storybook. Respond with valid JSON only — no extra text."
        let pass2UserPrompt = StoryPromptTemplates.imagePromptJSONPrompt(
            characterDescriptions: textDTO.characterDescriptions ?? "",
            pages: pages
        )

        let pass2Input = UserInput(
            chat: [
                .system(pass2System),
                .user(pass2UserPrompt)
            ]
        )

        let pass2LMInput = try await container.prepare(input: pass2Input)
        let pass2Params = GenerateParameters(
            maxTokens: GenerationConfig.mlxTokens(for: pageCount),
            temperature: Float(GenerationConfig.defaultTemperature)
        )

        let pass2Clock = ContinuousClock()
        let pass2Start = pass2Clock.now

        let pass2Stream = try await container.generate(
            input: pass2LMInput,
            parameters: pass2Params
        )

        var pass2Text = ""
        var pass2Iterator = pass2Stream.makeAsyncIterator()
        while let generation = await pass2Iterator.next() {
            if Task.isCancelled { throw CancellationError() }
            if let chunk = generation.chunk, !chunk.isEmpty {
                pass2Text += chunk
            }
        }

        let pass2Duration = pass2Start.duration(to: pass2Clock.now)
        let pass2Seconds = Double(pass2Duration.components.seconds) + Double(pass2Duration.components.attoseconds) / 1e18

        let pass2Trimmed = pass2Text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pass2Trimmed.isEmpty else {
            throw MLXStoryGeneratorError.emptyModelResponse
        }

        let promptSheet = try StoryDecoding.decodeImagePromptSheetDTO(from: pass2Trimmed)

        // Log Pass 2
        await VerboseGenerationLogger.shared.logTextPass(
            sessionID: verboseSession,
            passLabel: "Pass 2: Image Prompts (MLX Swift)",
            provider: "MLX Swift", model: modelID,
            systemPrompt: pass2System, userPrompt: pass2UserPrompt,
            rawResponse: pass2Trimmed, parseSuccess: true,
            duration: pass2Seconds
        )

        // ── Merge text + prompts into a StoryBook ──
        let story = StoryDecoding.mergeIntoStoryBook(
            textDTO: textDTO,
            promptSheet: promptSheet,
            pageCount: pageCount,
            fallbackConcept: safeConcept
        )
        guard !story.pages.isEmpty else {
            throw StoryDecodingError.contentRejected
        }

        // Log merged storybook
        await VerboseGenerationLogger.shared.logMergedStoryBook(
            sessionID: verboseSession,
            title: story.title,
            characterDescriptions: story.characterDescriptions,
            pages: story.pages.map { ($0.pageNumber, $0.text, $0.imagePrompt) }
        )

        return story
    }

    private func resolvedModelID(from settings: ModelSelectionSettings) throws -> String {
        let modelID = settings.mlxModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty else {
            throw MLXStoryGeneratorError.missingModelID
        }
        return modelID
    }

    private func makeHubAPI(settings: ModelSelectionSettings) -> HubApi {
        if let token = HFTokenStore.loadToken(alias: settings.resolvedHFTokenAlias),
           !token.isEmpty {
            setenv("HF_TOKEN", token, 1)
            setenv("HUGGING_FACE_HUB_TOKEN", token, 1)
        }

        let downloadBase = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first
        return HubApi(downloadBase: downloadBase)
    }

    // Prompt templates are centralized in StoryPromptTemplates — no local copies.
}

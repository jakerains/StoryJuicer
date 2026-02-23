import Foundation
import HuggingFace
import os

/// Cloud-based text generator that implements `StoryTextGenerating`.
/// Uses `InferenceClient` for HuggingFace, `OpenAICompatibleClient` for others.
struct CloudTextGenerator: StoryTextGenerating {
    private static let logger = Logger(subsystem: "com.storyfox.app", category: "CloudText")

    let cloudProvider: CloudProvider
    private let client: OpenAICompatibleClient
    private let settingsProvider: @Sendable () -> ModelSelectionSettings

    /// The premium tier, used to select enhanced prompt templates.
    var premiumTier: PremiumTier = .off

    /// The book's illustration style, threaded into Pass 2 so the LLM
    /// writes image prompts natively in the target art style.
    var illustrationStyle: IllustrationStyle = .illustration

    /// Character names from uploaded photos (Premium Plus only).
    var characterNames: [String] = []

    init(
        cloudProvider: CloudProvider,
        client: OpenAICompatibleClient = OpenAICompatibleClient(),
        settingsProvider: @escaping @Sendable () -> ModelSelectionSettings = { ModelSelectionStore.load() }
    ) {
        self.cloudProvider = cloudProvider
        self.client = client
        self.settingsProvider = settingsProvider
    }

    var availability: StoryProviderAvailability {
        get async {
            if cloudProvider.usesProxy { return .available }
            guard CloudCredentialStore.isAuthenticated(for: cloudProvider) else {
                return .unavailable(reason: "\(cloudProvider.displayName) is not configured. Add an API key in Settings.")
            }
            return .available
        }
    }

    func generateStory(
        concept: String,
        pageCount: Int,
        onProgress: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> StoryBook {
        let apiKey: String
        if cloudProvider.usesProxy {
            apiKey = ""
        } else {
            guard let key = CloudCredentialStore.bearerToken(for: cloudProvider) else {
                throw CloudProviderError.noAPIKey(cloudProvider)
            }
            apiKey = key
        }

        let settings = settingsProvider()
        let modelID = textModelID(from: settings)
        let safeConcept = ContentSafetyPolicy.sanitizeConcept(concept)

        Self.logger.info("Starting cloud text generation: provider=\(cloudProvider.rawValue, privacy: .public) model=\(modelID, privacy: .public)")

        // ── Pass 1: Generate story text (no image prompts) ──
        await onProgress("Weaving words and wonder...")

        let pass1System = premiumTier.isActive
            ? StoryPromptTemplates.premiumJSONModeSystemInstructions
            : StoryPromptTemplates.jsonModeSystemInstructions

        let pass1UserPrompt: String
        switch premiumTier {
        case .premiumPlus where !characterNames.isEmpty:
            pass1UserPrompt = StoryPromptTemplates.premiumPlusTextOnlyJSONPrompt(
                concept: safeConcept, pageCount: pageCount, characterNames: characterNames
            )
        case .premium, .premiumPlus:
            pass1UserPrompt = StoryPromptTemplates.premiumTextOnlyJSONPrompt(
                concept: safeConcept, pageCount: pageCount
            )
        case .off:
            pass1UserPrompt = StoryPromptTemplates.textOnlyJSONPrompt(
                concept: safeConcept, pageCount: pageCount
            )
        }

        let pass1Text: String
        let pass1Clock = ContinuousClock()
        let pass1Start = pass1Clock.now

        if cloudProvider == .huggingFace {
            pass1Text = try await chatWithHFSDK(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: pass1System,
                userPrompt: pass1UserPrompt,
                maxTokens: GenerationConfig.maximumResponseTokens(for: pageCount) * 2
            )
        } else {
            pass1Text = try await chatWithOpenAIClient(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: pass1System,
                userPrompt: pass1UserPrompt,
                maxTokens: GenerationConfig.maximumResponseTokens(for: pageCount) * 2
            )
        }

        let pass1Duration = pass1Start.duration(to: pass1Clock.now)
        let pass1Seconds = Double(pass1Duration.components.seconds) + Double(pass1Duration.components.attoseconds) / 1e18

        Self.logger.debug("Pass 1 raw response (\(pass1Text.count) chars): \(String(pass1Text.prefix(500)), privacy: .public)")

        let textDTO: TextOnlyStoryDTO
        var pass1ParseSuccess = true
        do {
            textDTO = try StoryDecoding.decodeTextOnlyStoryDTO(from: pass1Text)
        } catch {
            pass1ParseSuccess = false
            // Log before throwing so the failed response is captured
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logTextPass(
                sessionID: verboseSession,
                passLabel: "Pass 1: Story Text",
                provider: cloudProvider.displayName, model: modelID,
                systemPrompt: pass1System, userPrompt: pass1UserPrompt,
                rawResponse: pass1Text, parseSuccess: false,
                duration: pass1Seconds
            )
            Self.logger.error("Pass 1 decode failed: \(error.localizedDescription, privacy: .public)")
            Self.logger.error("Pass 1 full text: \(pass1Text, privacy: .public)")
            throw CloudProviderError.custom("Story text could not be parsed. The \(cloudProvider.displayName) model may need a different prompt format. Raw start: \(String(pass1Text.prefix(200)))")
        }

        // Log Pass 1 success
        do {
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logTextPass(
                sessionID: verboseSession,
                passLabel: "Pass 1: Story Text",
                provider: cloudProvider.displayName, model: modelID,
                systemPrompt: pass1System, userPrompt: pass1UserPrompt,
                rawResponse: pass1Text, parseSuccess: pass1ParseSuccess,
                duration: pass1Seconds
            )
        }

        // ── Pass 2: Generate image prompts with full story context ──
        await onProgress("Dreaming up illustrations for each page...")

        let pages = textDTO.pages.map { (pageNumber: $0.pageNumber, text: $0.text) }
        let pass2UserPrompt: String
        if premiumTier.isActive {
            pass2UserPrompt = StoryPromptTemplates.premiumImagePromptJSONPrompt(
                characterDescriptions: textDTO.characterDescriptions ?? "",
                pages: pages,
                style: illustrationStyle
            )
        } else {
            pass2UserPrompt = StoryPromptTemplates.imagePromptJSONPrompt(
                characterDescriptions: textDTO.characterDescriptions ?? "",
                pages: pages,
                style: illustrationStyle
            )
        }
        let pass2System = premiumTier.isActive
            ? "You are an award-winning art director for a premium children's storybook. Respond with valid JSON only — no extra text."
            : "You are an art director for a children's storybook. Respond with valid JSON only — no extra text."

        let pass2Text: String
        let pass2Clock = ContinuousClock()
        let pass2Start = pass2Clock.now

        // Each page prompt is ~50-80 tokens; budget generously to avoid truncation.
        let pass2MaxTokens = max(800, pageCount * 100)

        if cloudProvider == .huggingFace {
            pass2Text = try await chatWithHFSDK(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: pass2System,
                userPrompt: pass2UserPrompt,
                maxTokens: pass2MaxTokens
            )
        } else {
            pass2Text = try await chatWithOpenAIClient(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: pass2System,
                userPrompt: pass2UserPrompt,
                maxTokens: pass2MaxTokens
            )
        }

        let pass2Duration = pass2Start.duration(to: pass2Clock.now)
        let pass2Seconds = Double(pass2Duration.components.seconds) + Double(pass2Duration.components.attoseconds) / 1e18

        Self.logger.debug("Pass 2 raw response (\(pass2Text.count) chars): \(String(pass2Text.prefix(500)), privacy: .public)")

        let promptSheet: ImagePromptSheetDTO
        do {
            promptSheet = try StoryDecoding.decodeImagePromptSheetDTO(from: pass2Text)
        } catch {
            // Log before throwing so the failed response is captured
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logTextPass(
                sessionID: verboseSession,
                passLabel: "Pass 2: Image Prompts",
                provider: cloudProvider.displayName, model: modelID,
                systemPrompt: pass2System, userPrompt: pass2UserPrompt,
                rawResponse: pass2Text, parseSuccess: false,
                duration: pass2Seconds
            )
            Self.logger.error("Pass 2 decode failed: \(error.localizedDescription, privacy: .public)")
            Self.logger.error("Pass 2 full text: \(pass2Text, privacy: .public)")
            throw CloudProviderError.custom("Image prompts could not be parsed. The model's response may have been truncated or malformed. Raw start: \(String(pass2Text.prefix(200)))")
        }

        // Log Pass 2 success
        do {
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logTextPass(
                sessionID: verboseSession,
                passLabel: "Pass 2: Image Prompts",
                provider: cloudProvider.displayName, model: modelID,
                systemPrompt: pass2System, userPrompt: pass2UserPrompt,
                rawResponse: pass2Text, parseSuccess: true,
                duration: pass2Seconds
            )
        }

        // ── Merge text + prompts into a StoryBook ──
        await onProgress("Tidying up the pages...")

        let story = StoryDecoding.mergeIntoStoryBook(
            textDTO: textDTO,
            promptSheet: promptSheet,
            pageCount: pageCount,
            fallbackConcept: safeConcept
        )

        guard !story.pages.isEmpty else {
            throw StoryDecodingError.contentRejected
        }

        // Log the merged storybook
        do {
            let verboseSession = await VerboseGenerationLogger.shared.activeSessionID ?? ""
            await VerboseGenerationLogger.shared.logMergedStoryBook(
                sessionID: verboseSession,
                title: story.title,
                characterDescriptions: story.characterDescriptions,
                pages: story.pages.map { ($0.pageNumber, $0.text, $0.imagePrompt) }
            )
        }

        Self.logger.info("Cloud text generation complete: \(story.pages.count) pages")
        return story
    }

    // MARK: - HuggingFace SDK Path

    private func chatWithHFSDK(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int
    ) async throws -> String {
        let hfClient = InferenceClient(host: InferenceClient.defaultHost, bearerToken: apiKey)

        let messages: [ChatCompletion.Message] = [
            .init(role: .system, content: .text(systemPrompt)),
            .init(role: .user, content: .text(userPrompt))
        ]

        let response = try await hfClient.chatCompletion(
            model: model,
            messages: messages,
            temperature: 0.7,
            maxTokens: maxTokens
        )

        guard let choice = response.choices.first else {
            throw CloudProviderError.unparsableResponse
        }

        switch choice.message.content {
        case .text(let text):
            return text
        case .mixed(let items):
            let textParts = items.compactMap { item -> String? in
                if case .text(let text) = item { return text }
                return nil
            }
            return textParts.joined(separator: "\n")
        case .none:
            throw CloudProviderError.unparsableResponse
        }
    }

    // MARK: - OpenAI-Compatible Client Path

    private func chatWithOpenAIClient(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int
    ) async throws -> String {
        // All providers (including premium proxy) use Chat Completions format.
        // The premium proxy translates messages → Responses API server-side,
        // so we don't need to send Responses API format from the client.
        // For premium, include the tier so the proxy picks the right model
        // (e.g. gpt-5-mini for standard, gpt-5.2 for plus).
        let tierParam: String? = cloudProvider == .openAI
            ? (premiumTier == .premiumPlus ? "plus" : "standard")
            : nil

        let data = try await client.chatCompletion(
            url: cloudProvider.chatCompletionURL,
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: 0.7,
            maxTokens: maxTokens,
            extraHeaders: cloudProvider.extraHeaders,
            skipAuth: cloudProvider.usesProxy,
            tier: tierParam
        )

        if let text = StoryDecoding.extractTextContent(from: data) {
            return text
        } else if let rawText = String(data: data, encoding: .utf8) {
            return rawText
        } else {
            throw CloudProviderError.unparsableResponse
        }
    }

    // MARK: - Helpers

    private func textModelID(from settings: ModelSelectionSettings) -> String {
        let modelID: String
        switch cloudProvider {
        case .openRouter:  modelID = settings.openRouterTextModelID
        case .togetherAI:  modelID = settings.togetherTextModelID
        case .huggingFace: modelID = settings.huggingFaceTextModelID
        case .openAI:      modelID = cloudProvider.defaultTextModelID  // Server-controlled
        }
        return modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? cloudProvider.defaultTextModelID
            : modelID
    }
}

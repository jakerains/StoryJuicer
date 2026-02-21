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
        guard let apiKey = CloudCredentialStore.bearerToken(for: cloudProvider) else {
            throw CloudProviderError.noAPIKey(cloudProvider)
        }

        let settings = settingsProvider()
        let modelID = textModelID(from: settings)
        let safeConcept = ContentSafetyPolicy.sanitizeConcept(concept)

        Self.logger.info("Starting cloud text generation: provider=\(cloudProvider.rawValue, privacy: .public) model=\(modelID, privacy: .public)")

        // ── Pass 1: Generate story text (no image prompts) ──
        await onProgress("Generating story text with \(cloudProvider.displayName)...")

        let pass1Text: String

        if cloudProvider == .huggingFace {
            pass1Text = try await chatWithHFSDK(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: StoryPromptTemplates.jsonModeSystemInstructions,
                userPrompt: StoryPromptTemplates.textOnlyJSONPrompt(concept: safeConcept, pageCount: pageCount),
                maxTokens: GenerationConfig.maximumResponseTokens(for: pageCount) * 2
            )
        } else {
            pass1Text = try await chatWithOpenAIClient(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: StoryPromptTemplates.jsonModeSystemInstructions,
                userPrompt: StoryPromptTemplates.textOnlyJSONPrompt(concept: safeConcept, pageCount: pageCount),
                maxTokens: GenerationConfig.maximumResponseTokens(for: pageCount) * 2
            )
        }

        let textDTO = try StoryDecoding.decodeTextOnlyStoryDTO(from: pass1Text)

        // ── Pass 2: Generate image prompts with full story context ──
        await onProgress("Generating illustration prompts...")

        let pages = textDTO.pages.map { (pageNumber: $0.pageNumber, text: $0.text) }
        let pass2UserPrompt = StoryPromptTemplates.imagePromptJSONPrompt(
            characterDescriptions: textDTO.characterDescriptions ?? "",
            pages: pages
        )
        let pass2System = "You are an art director for a children's storybook. Respond with valid JSON only — no extra text."

        let pass2Text: String

        if cloudProvider == .huggingFace {
            pass2Text = try await chatWithHFSDK(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: pass2System,
                userPrompt: pass2UserPrompt,
                maxTokens: 600
            )
        } else {
            pass2Text = try await chatWithOpenAIClient(
                apiKey: apiKey,
                model: modelID,
                systemPrompt: pass2System,
                userPrompt: pass2UserPrompt,
                maxTokens: 600
            )
        }

        let promptSheet = try StoryDecoding.decodeImagePromptSheetDTO(from: pass2Text)

        // ── Merge text + prompts into a StoryBook ──
        await onProgress("Parsing story response...")

        let story = StoryDecoding.mergeIntoStoryBook(
            textDTO: textDTO,
            promptSheet: promptSheet,
            pageCount: pageCount,
            fallbackConcept: safeConcept
        )

        guard !story.pages.isEmpty else {
            throw StoryDecodingError.contentRejected
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
        let data = try await client.chatCompletion(
            url: cloudProvider.chatCompletionURL,
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: 0.7,
            maxTokens: maxTokens,
            extraHeaders: cloudProvider.extraHeaders
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
        }
        return modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? cloudProvider.defaultTextModelID
            : modelID
    }
}

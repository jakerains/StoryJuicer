import Foundation
import FoundationModels
import HuggingFace
import os

@Observable
@MainActor
final class StoryQAViewModel {
    private static let logger = Logger(subsystem: "com.storyfox.app", category: "StoryQA")

    // MARK: - Configuration

    /// Safety cap — the model decides when to stop, but we won't exceed this.
    let maxRounds = 4

    // MARK: - State

    private(set) var phase: StoryQAPhase = .idle
    private(set) var rounds: [StoryQARound] = []
    private(set) var currentRoundIndex: Int = 0

    /// Set by the model when it reports having enough context.
    private(set) var modelSaysDone: Bool = false

    private var originalConcept: String = ""
    private var generationTask: Task<Void, Never>?

    private let client = OpenAICompatibleClient()

    // MARK: - Computed

    var currentRound: StoryQARound? {
        guard currentRoundIndex < rounds.count else { return nil }
        return rounds[currentRoundIndex]
    }

    var canProceed: Bool {
        guard let round = currentRound else { return false }
        return round.questions.contains(where: \.isAnswered)
    }

    var canGenerateNow: Bool {
        // Allow early generation once any question has been answered
        currentRound?.questions.contains(where: \.isAnswered) == true
    }

    var isLastRound: Bool {
        modelSaysDone || currentRoundIndex >= maxRounds - 1
    }

    // MARK: - Actions

    func startQA(concept: String) {
        guard !concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        originalConcept = concept
        rounds = []
        currentRoundIndex = 0
        modelSaysDone = false
        generateNextRound()
    }

    func updateAnswer(questionID: UUID, answer: String) {
        guard currentRoundIndex < rounds.count else { return }
        if let qIndex = rounds[currentRoundIndex].questions.firstIndex(where: { $0.id == questionID }) {
            rounds[currentRoundIndex].questions[qIndex].userAnswer = answer
        }
    }

    func submitCurrentRound() {
        guard canProceed else { return }
        currentRoundIndex += 1

        if modelSaysDone || currentRoundIndex >= maxRounds {
            finalize()
        } else {
            generateNextRound()
        }
    }

    func generateNow() {
        finalize()
    }

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        phase = .idle
        rounds = []
        currentRoundIndex = 0
        modelSaysDone = false
        originalConcept = ""
    }

    func reset() {
        cancel()
    }

    // MARK: - Question Generation

    private func generateNextRound() {
        let roundNumber = currentRoundIndex + 1

        generationTask = Task {
            phase = .generatingQuestions

            do {
                let result = try await generateQuestions(roundNumber: roundNumber)

                guard !Task.isCancelled else { return }

                if result.done {
                    modelSaysDone = true
                }

                // If model says done AND returned no questions, auto-finalize
                if result.questions.isEmpty {
                    if !rounds.isEmpty {
                        finalize()
                    } else {
                        // Edge case: model said done on first round with no questions — retry
                        phase = .failed("The AI didn't generate any questions. Please try again.")
                    }
                    return
                }

                let round = StoryQARound(roundNumber: roundNumber, questions: result.questions)
                rounds.append(round)
                phase = .awaitingAnswers(round: roundNumber, isFinalRound: modelSaysDone)
            } catch is CancellationError {
                phase = .idle
            } catch {
                Self.logger.error("Q&A generation failed: \(error.localizedDescription, privacy: .public)")
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func generateQuestions(roundNumber: Int) async throws -> (questions: [StoryQuestion], done: Bool) {
        var settings = ModelSelectionStore.load()
        let premium = PremiumStore.load()
        if premium.tier.isActive {
            settings.textProvider = .openAI
        }
        let audience = settings.audienceMode

        let previousQA: [(question: String, answer: String)] = rounds.flatMap { round in
            round.questions.filter(\.isAnswered).map { q in
                (q.questionText, q.userAnswer)
            }
        }

        let systemPrompt = StoryQAPromptTemplates.systemInstructions(for: audience)
        let userPrompt = StoryQAPromptTemplates.questionGenerationPrompt(
            concept: originalConcept,
            roundNumber: roundNumber,
            previousQA: previousQA,
            audience: audience
        )

        let responseText: String

        switch settings.textProvider {
        case .appleFoundation:
            responseText = try await generateWithFoundationModels(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        case .huggingFace:
            responseText = try await generateWithHuggingFace(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                settings: settings
            )
        case .openRouter, .togetherAI, .openAI:
            guard let provider = settings.textProvider.cloudProvider else {
                throw StoryQAError.providerUnavailable
            }
            responseText = try await generateWithOpenAICompatible(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                provider: provider,
                settings: settings
            )
        case .mlxSwift:
            // MLX doesn't have a simple text API — fall back to Foundation
            responseText = try await generateWithFoundationModels(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        }

        guard let result = StoryQAPromptTemplates.parseRound(from: responseText) else {
            throw StoryQAError.failedToParseQuestions
        }

        return (Array(result.questions.prefix(3)), result.done)
    }

    // MARK: - Provider Implementations

    private func generateWithFoundationModels(
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        let session = LanguageModelSession(instructions: systemPrompt)
        let response = try await session.respond(to: userPrompt)
        return response.content
    }

    private func generateWithHuggingFace(
        systemPrompt: String,
        userPrompt: String,
        settings: ModelSelectionSettings
    ) async throws -> String {
        guard let apiKey = CloudCredentialStore.bearerToken(for: .huggingFace) else {
            throw StoryQAError.providerUnavailable
        }

        let modelID = settings.huggingFaceTextModelID.isEmpty
            ? CloudProvider.huggingFace.defaultTextModelID
            : settings.huggingFaceTextModelID

        let hfClient = InferenceClient(host: InferenceClient.defaultHost, bearerToken: apiKey)
        let messages: [ChatCompletion.Message] = [
            .init(role: .system, content: .text(systemPrompt)),
            .init(role: .user, content: .text(userPrompt))
        ]

        let response = try await hfClient.chatCompletion(
            model: modelID,
            messages: messages,
            temperature: 0.7,
            maxTokens: 1200
        )

        guard let choice = response.choices.first else {
            throw StoryQAError.emptyResponse
        }

        switch choice.message.content {
        case .text(let text): return text
        case .mixed(let items):
            return items.compactMap { item -> String? in
                if case .text(let text) = item { return text }
                return nil
            }.joined(separator: "\n")
        case .none:
            throw StoryQAError.emptyResponse
        }
    }

    private func generateWithOpenAICompatible(
        systemPrompt: String,
        userPrompt: String,
        provider: CloudProvider,
        settings: ModelSelectionSettings
    ) async throws -> String {
        let apiKey: String
        if provider.usesProxy {
            apiKey = ""
        } else {
            guard let key = CloudCredentialStore.bearerToken(for: provider) else {
                throw StoryQAError.providerUnavailable
            }
            apiKey = key
        }

        let modelID: String
        switch provider {
        case .openRouter: modelID = settings.openRouterTextModelID
        case .togetherAI: modelID = settings.togetherTextModelID
        case .huggingFace: modelID = settings.huggingFaceTextModelID
        case .openAI:     modelID = provider.defaultTextModelID  // Server-controlled
        }

        let resolvedModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultTextModelID
            : modelID

        let data = try await client.chatCompletion(
            url: provider.chatCompletionURL,
            apiKey: apiKey,
            model: resolvedModel,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: 0.7,
            maxTokens: 1200,
            extraHeaders: provider.extraHeaders,
            skipAuth: provider.usesProxy
        )

        if let text = StoryDecoding.extractTextContent(from: data) {
            return text
        } else if let rawText = String(data: data, encoding: .utf8) {
            return rawText
        }

        throw StoryQAError.emptyResponse
    }

    // MARK: - Finalization

    private func finalize() {
        phase = .compilingConcept

        let enriched = StoryQAPromptTemplates.compileEnrichedConcept(
            originalConcept: originalConcept,
            rounds: rounds
        )

        phase = .complete(enrichedConcept: enriched)
    }
}

// MARK: - Errors

enum StoryQAError: LocalizedError {
    case providerUnavailable
    case failedToParseQuestions
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return "The text provider is not available. Check your settings."
        case .failedToParseQuestions:
            return "Could not parse follow-up questions from the AI response. Please try again."
        case .emptyResponse:
            return "The AI returned an empty response. Please try again."
        }
    }
}

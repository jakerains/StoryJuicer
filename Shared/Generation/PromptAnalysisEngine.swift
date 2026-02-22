import Foundation
import FoundationModels
import os

/// Analyzes image generation prompts using Foundation Model structured output
/// to extract semantic elements (species, appearance, scene, action, mood).
///
/// When the on-device Foundation Model is available, each prompt is passed through
/// a short `LanguageModelSession` call that returns a typed `PromptAnalysis`.
/// When unavailable, falls back to heuristic keyword extraction using the same
/// species word list from `ImagePromptEnricher`.
enum PromptAnalysisEngine {

    private static let logger = Logger(subsystem: "com.storyfox.app", category: "PromptAnalysis")

    // MARK: - Public API

    /// Analyze all image prompts in a story using Foundation Model.
    /// Falls back to heuristic extraction if Foundation Model unavailable.
    ///
    /// - Parameter prompts: Array of `(index, prompt)` pairs where index 0 = cover.
    /// - Returns: Dictionary keyed by page index with the analysis for each prompt.
    static func analyzePrompts(
        _ prompts: [(index: Int, prompt: String)]
    ) async -> [Int: PromptAnalysis] {
        var results: [Int: PromptAnalysis] = [:]

        let useFoundationModel = SystemLanguageModel.default.availability == .available

        if useFoundationModel {
            logger.info("Analyzing \(prompts.count) prompts with Foundation Model")
        } else {
            logger.info("Foundation Model unavailable — using heuristic analysis for \(prompts.count) prompts")
        }

        // Process sequentially — on-device model is a single shared resource
        for (index, prompt) in prompts {
            if useFoundationModel {
                if let analysis = await analyzeSingle(prompt: prompt) {
                    results[index] = analysis
                    continue
                }
                // Foundation Model call failed for this prompt — fall back to heuristic
                logger.warning("Foundation Model analysis failed for page \(index), using heuristic")
            }

            results[index] = heuristicAnalysis(of: prompt)
        }

        return results
    }

    /// Analyze a single prompt using Foundation Model.
    /// Returns nil if the model is unavailable or the call fails.
    static func analyzeSingle(prompt: String) async -> PromptAnalysis? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let session = LanguageModelSession(
            instructions: """
                You are analyzing an image generation prompt for a children's storybook illustration. \
                Extract the structured visual elements from the prompt. \
                List every character visible in the scene — each one with their species and visual appearance. \
                Also extract the scene setting, the main action, and the overall mood. \
                Use lowercase for species. Keep all fields concise.
                """
        )

        let request = """
            Analyze this illustration prompt and extract the visual elements:
            "\(prompt)"
            """

        let options = GenerationOptions(
            temperature: 0.2,
            maximumResponseTokens: 250
        )

        do {
            let response = try await session.respond(
                to: request,
                generating: PromptAnalysis.self,
                options: options
            )
            let analysis = response.content
            logger.debug("Analysis: characters=\(analysis.characters.map(\.species)) scene=\(analysis.sceneSetting)")
            return analysis
        } catch {
            logger.warning("Foundation Model analysis failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: - Multi-Concept Decomposition

    /// Decompose an image prompt into priority-ranked concept chunks for multi-concept generation.
    /// Returns nil if Foundation Model is unavailable or decomposition fails —
    /// caller should fall back to `heuristicConcepts(from:)`.
    static func decomposeIntoConcepts(prompt: String) async -> ImageConceptDecomposition? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let session = LanguageModelSession(
            instructions: """
                You are extracting keyword chunks from a children's storybook image prompt. \
                Each chunk will be sent as a separate concept to an image generator. \
                Rules: \
                - Use ONLY words and details present in the original prompt. Never invent or embellish. \
                - Keep each chunk short (2-6 words). No full sentences. \
                - Order by importance: CHARACTER first (species/breed + color), then SETTING, ACTION, \
                  then additional DETAIL, PROPS, ATMOSPHERE concepts as needed. \
                - Extract as many concepts as the prompt warrants. Richer prompts get more concepts.
                """
        )

        let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 400)

        do {
            let response = try await session.respond(
                to: "Decompose this illustration prompt into ranked concept chunks:\n\"\(prompt)\"",
                generating: ImageConceptDecomposition.self,
                options: options
            )
            let result = response.content
            // Validate: must have at least one concept
            return result.concepts.isEmpty ? nil : result
        } catch {
            logger.warning("Concept decomposition failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Build concepts heuristically from a pre-computed `PromptAnalysis` when
    /// Foundation Model is unavailable for decomposition.
    static func heuristicConcepts(from analysis: PromptAnalysis) -> ImageConceptDecomposition {
        var concepts: [RankedImageConcept] = []

        // Characters first (highest priority)
        for char in analysis.characters {
            let value = [char.appearance, char.species]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !value.isEmpty {
                concepts.append(RankedImageConcept(label: "CHARACTER", value: value))
            }
        }

        if !analysis.sceneSetting.isEmpty {
            concepts.append(RankedImageConcept(label: "SETTING", value: analysis.sceneSetting))
        }
        if !analysis.mainAction.isEmpty {
            concepts.append(RankedImageConcept(label: "ACTION", value: analysis.mainAction))
        }
        if !analysis.mood.isEmpty {
            concepts.append(RankedImageConcept(label: "ATMOSPHERE", value: analysis.mood))
        }

        return ImageConceptDecomposition(concepts: concepts)
    }

    // MARK: - Heuristic Fallback

    /// Heuristic fallback when Foundation Model is unavailable.
    /// Uses `ImagePromptEnricher.speciesWords` for species detection and
    /// positional/structural extraction for other fields.
    static func heuristicAnalysis(of prompt: String) -> PromptAnalysis {
        let words = prompt
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        // Species detection — find ALL unique species words (preserving order)
        var seenSpecies = Set<String>()
        let foundSpecies = words.filter { word in
            ImagePromptEnricher.speciesWords.contains(word) && seenSpecies.insert(word).inserted
        }

        // Build one CharacterAnalysis per unique species, with positional appearance
        let characters = foundSpecies.map { sp in
            CharacterAnalysis(
                species: sp,
                appearance: extractAppearance(from: words, species: sp)
            )
        }

        // Scene — extract prepositional phrases ("in the forest", "at the pond")
        let scene = extractScene(from: prompt)

        // Action — look for verbs/gerunds
        let action = extractAction(from: words)

        // Mood — look for mood/atmosphere words
        let mood = extractMood(from: words)

        return PromptAnalysis(
            characters: characters,
            sceneSetting: scene,
            mainAction: action,
            mood: mood
        )
    }

    // MARK: - Heuristic Helpers

    private static let colorWords: Set<String> = [
        "red", "orange", "yellow", "green", "blue", "purple", "pink",
        "white", "black", "brown", "gray", "grey", "golden", "silver",
        "teal", "coral", "turquoise", "amber", "cream", "ivory",
    ]

    private static let sizeWords: Set<String> = [
        "small", "tiny", "little", "big", "large", "tall", "short",
        "plump", "round", "fluffy", "slender",
    ]

    private static let moodWords: Set<String> = [
        "warm", "cozy", "bright", "cheerful", "peaceful", "magical",
        "mysterious", "dreamy", "gentle", "joyful", "playful", "serene",
        "whimsical", "enchanting", "sunny", "starlit", "moonlit",
        "happy", "calm", "exciting", "adventurous", "sparkly",
    ]

    private static let actionVerbs: Set<String> = [
        "running", "walking", "sitting", "standing", "flying", "jumping",
        "playing", "reading", "dancing", "singing", "swimming", "climbing",
        "sleeping", "eating", "looking", "holding", "carrying", "building",
        "painting", "exploring", "discovering", "gathering", "collecting",
        "hiding", "peeking", "waving", "hugging", "laughing", "smiling",
        "digging", "planting", "cooking", "baking", "writing", "drawing",
    ]

    private static func extractAppearance(from words: [String], species: String) -> String {
        var parts: [String] = []

        if let speciesIdx = words.firstIndex(of: species) {
            // Proximity-based: look ±4 words around the species for color/size adjectives
            let start = max(0, speciesIdx - 4)
            let end = min(words.count, speciesIdx + 4)
            let window = Array(words[start..<end])
            parts.append(contentsOf: window.filter { sizeWords.contains($0) }.prefix(1))
            parts.append(contentsOf: window.filter { colorWords.contains($0) }.prefix(2))
        } else {
            // Fallback: scan entire prompt
            parts.append(contentsOf: words.filter { sizeWords.contains($0) }.prefix(1))
            parts.append(contentsOf: words.filter { colorWords.contains($0) }.prefix(2))
        }

        if !species.isEmpty {
            parts.append(species)
        }

        return parts.isEmpty ? "" : parts.joined(separator: " ")
    }

    private static func extractScene(from prompt: String) -> String {
        let lower = prompt.lowercased()
        // Look for "in/at/by/near/under the ..." prepositional phrases
        let prepositionPattern = #"(?:in|at|by|near|under|beside|through|inside|outside|around)\s+(?:a|an|the)?\s*[\w\s]{3,30}?"#
        if let match = lower.range(of: prepositionPattern, options: .regularExpression) {
            let scene = String(lower[match])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Cap at ~5 words
            let sceneWords = scene.split(whereSeparator: \.isWhitespace).prefix(6)
            return sceneWords.joined(separator: " ")
        }

        return ""
    }

    private static func extractAction(from words: [String]) -> String {
        let actions = words.filter { actionVerbs.contains($0) }
        return actions.first ?? ""
    }

    private static func extractMood(from words: [String]) -> String {
        let moods = words.filter { moodWords.contains($0) }
        return moods.prefix(2).joined(separator: " ")
    }
}

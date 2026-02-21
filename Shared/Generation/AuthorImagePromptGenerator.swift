import Foundation
import FoundationModels

/// Generates image prompts for user-authored story text.
///
/// Author Mode skips Pass 1 (LLM story text) and reuses Pass 2
/// (`ImagePromptSheet` via `StoryPromptTemplates.imagePromptPassPrompt`)
/// to create illustration prompts from the author's own writing.
/// Falls back to heuristic prompts when Foundation Models is unavailable.
enum AuthorImagePromptGenerator {

    /// Generate image prompts for author-written pages using Foundation Models.
    /// Falls back to heuristic prompts when the on-device model is unavailable.
    static func generateImagePrompts(
        characterDescriptions: String,
        pages: [(pageNumber: Int, text: String)],
        onProgress: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> ImagePromptSheet {
        guard SystemLanguageModel.default.availability == .available else {
            await onProgress("Using heuristic prompts (on-device model unavailable)...")
            return heuristicPrompts(pages: pages, characterDescriptions: characterDescriptions)
        }

        await onProgress("Writing illustration prompts...")

        let prompt = StoryPromptTemplates.imagePromptPassPrompt(
            characterDescriptions: characterDescriptions,
            pages: pages
        )

        let session = LanguageModelSession(
            instructions: "You are an art director for a children's storybook illustration team."
        )

        let options = GenerationOptions(
            temperature: Double(GenerationConfig.defaultTemperature),
            maximumResponseTokens: 600
        )

        let response = try await session.respond(
            to: prompt,
            generating: ImagePromptSheet.self,
            options: options
        )

        return response.content
    }

    /// Build a cover prompt from the story title.
    static func coverPrompt(title: String) -> String {
        let safeTitle = ContentSafetyPolicy.sanitizeConcept(title)
        return "\(safeTitle) book cover, warm whimsical colors, friendly characters, storybook illustration"
    }

    // MARK: - Heuristic Fallback

    /// Extracts a short scene description from each page's text when no LLM is available.
    private static func heuristicPrompts(
        pages: [(pageNumber: Int, text: String)],
        characterDescriptions: String
    ) -> ImagePromptSheet {
        let descriptionPrefix = characterDescriptions
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? "" : "\(characterDescriptions.prefix(120)). "

        let prompts = pages.map { page in
            let scene = page.text
                .components(separatedBy: ".")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? page.text
            let prompt = "\(descriptionPrefix)\(scene), children's book illustration, warm colors"
            return PageImagePrompt(
                pageNumber: page.pageNumber,
                imagePrompt: String(prompt.prefix(280))
            )
        }

        return ImagePromptSheet(prompts: prompts)
    }
}

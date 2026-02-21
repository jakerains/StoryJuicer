import Foundation
import FoundationModels

@Generable
struct StoryBook {
    @Guide(description: "A captivating title for this children's storybook")
    var title: String

    @Guide(description: "The author attribution line, e.g. 'Written by StoryFox AI'")
    var authorLine: String

    @Guide(description: "A one-sentence summary of the story's moral or theme")
    var moral: String

    @Guide(description: "A brief visual reference for each main character based on the story concept. One line per character: name - species or breed, colors, clothing, one distinguishing feature. Use the species from the concept — do not substitute a different animal.")
    var characterDescriptions: String

    @Guide(description: "The story pages array - generate exactly the number of pages the user requested")
    var pages: [StoryPage]
}

@Generable
struct StoryPage {
    @Guide(description: "The page number, starting from 1")
    var pageNumber: Int

    @Guide(description: "2-4 sentences of story text for this page. Use simple vocabulary appropriate for children ages 3-8. Each page should advance the narrative. Use vivid, sensory language that paints a picture.")
    var text: String

    @Guide(description: "A detailed visual scene description for generating an illustration. IMPORTANT: Describe each character by their species and visual appearance, NOT just their name. Image models cannot look up character names. Include species, color, clothing, setting, expressions, actions, and mood. Do NOT include any text or words in the image description.")
    var imagePrompt: String
}

// MARK: - Two-Pass Generation Structs (Test Harness Only)

/// Pass 1 output: Story text without image prompts.
/// Used by the test harness A/B experiment to separate narrative generation
/// from visual prompt generation. The LLM focuses purely on storytelling.
@Generable
struct TextOnlyStoryBook: Sendable {
    @Guide(description: "A captivating title for this children's storybook")
    var title: String

    @Guide(description: "The author attribution line, e.g. 'Written by StoryFox AI'")
    var authorLine: String

    @Guide(description: "A one-sentence summary of the story's moral or theme")
    var moral: String

    @Guide(description: "A brief visual reference for each main character based on the story concept. One line per character: name - species or breed, colors, clothing, one distinguishing feature. Use the species from the concept — do not substitute a different animal.")
    var characterDescriptions: String

    @Guide(description: "Story pages with text only — no image prompts needed")
    var pages: [TextOnlyStoryPage]
}

/// A single page of story text without an image prompt.
@Generable
struct TextOnlyStoryPage: Sendable {
    @Guide(description: "The page number, starting from 1")
    var pageNumber: Int

    @Guide(description: "2-4 sentences of story text for this page. Use simple vocabulary appropriate for children ages 3-8. Each page should advance the narrative. Use vivid, sensory language that paints a picture.")
    var text: String
}

/// Pass 2 output: Image prompts written with full narrative context.
/// The LLM receives the complete story text + character sheet and writes
/// detailed illustration prompts for every page at once.
@Generable
struct ImagePromptSheet: Sendable {
    @Guide(description: "One image prompt per story page, in page order")
    var prompts: [PageImagePrompt]
}

/// A single page's image prompt, produced with full story context.
@Generable
struct PageImagePrompt: Sendable {
    @Guide(description: "The page number this prompt corresponds to")
    var pageNumber: Int

    @Guide(description: "Detailed visual scene description for illustration. Describe characters by species and appearance, NOT by name — image models cannot look up names. Include species, color, clothing, setting, action, expressions, and mood. Do NOT include any text or words in the scene.")
    var imagePrompt: String
}

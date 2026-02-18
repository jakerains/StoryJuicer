import Foundation
import FoundationModels

@Generable
struct StoryBook {
    @Guide(description: "A captivating title for this children's storybook")
    var title: String

    @Guide(description: "The author attribution line, e.g. 'Written by StoryJuicer AI'")
    var authorLine: String

    @Guide(description: "A one-sentence summary of the story's moral or theme")
    var moral: String

    @Guide(description: "The story pages array - generate exactly the number of pages the user requested")
    var pages: [StoryPage]
}

@Generable
struct StoryPage {
    @Guide(description: "The page number, starting from 1")
    var pageNumber: Int

    @Guide(description: "2-4 sentences of story text for this page. Use simple vocabulary appropriate for children ages 3-8. Each page should advance the narrative. Use vivid, sensory language that paints a picture.")
    var text: String

    @Guide(description: "A detailed visual scene description for generating an illustration. Describe the setting, characters, their expressions, actions, colors, and mood. Write it as a children's book illustration prompt. Do NOT include any text or words in the image description.")
    var imagePrompt: String
}

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

    @Guide(description: "A brief visual reference for each main character. List each character on one line: name, species or type, colors, clothing, and one distinguishing feature. Example line: 'Luna - small white rabbit, pink dress, floppy left ear, blue eyes'")
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

    @Guide(description: "A detailed visual scene description for generating an illustration. IMPORTANT: Describe each character by their species and visual appearance (e.g. 'a small orange fox with a green scarf'), NOT just their name. Image models cannot look up character names. Include setting, expressions, actions, colors, and mood. Do NOT include any text or words in the image description.")
    var imagePrompt: String
}

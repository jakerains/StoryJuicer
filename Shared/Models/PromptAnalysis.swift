import Foundation
import FoundationModels

/// A single character detected in an image prompt.
/// Used as an element in `PromptAnalysis.characters` — Foundation Models generates
/// one entry per visible character, just like `StoryBook.pages: [StoryPage]`.
@Generable
struct CharacterAnalysis: Sendable {
    @Guide(description: "The character's species, creature type, or breed in lowercase as stated in the prompt")
    var species: String

    @Guide(description: "2-4 word visual appearance: size, color, and any clothing or accessories mentioned in the prompt")
    var appearance: String
}

/// Structured semantic analysis of an image generation prompt.
/// Used by `PromptAnalysisEngine` to extract visual elements via Foundation Model
/// or heuristic fallback, enabling smarter keyword selection and species-anchored
/// variant prompts in `IllustrationGenerator`.
@Generable
struct PromptAnalysis: Sendable {
    @Guide(description: "Every character visible in the scene. List each one with their species and appearance.")
    var characters: [CharacterAnalysis]

    @Guide(description: "The scene setting in 3-5 words, e.g. 'moonlit forest clearing'")
    var sceneSetting: String

    @Guide(description: "The main action or pose, e.g. 'running through flowers'")
    var mainAction: String

    @Guide(description: "The dominant mood or atmosphere, e.g. 'warm and cozy'")
    var mood: String
}

// MARK: - Character Description Repair (Upgrade 2)

/// Foundation Model output for repairing malformed or missing character descriptions.
/// Used by `CharacterDescriptionValidator.validateAsync()` when the heuristic validator
/// detects inadequate descriptions — the LLM generates proper "Name - species, appearance"
/// lines from the story's image prompts.
@Generable
struct RepairedCharacterDescriptions: Sendable {
    @Guide(description: "One line per character: Name - species/breed, colors, clothing, one distinguishing feature. Derived from the story's image prompts.")
    var descriptions: String
}

// MARK: - Character Description Parsing (Upgrade 1)

/// Foundation Model output for parsing character description text into structured entries.
/// Replaces regex-based splitting on " - ", " – ", ": " with natural language understanding.
@Generable
struct ParsedCharacterSheet: Sendable {
    @Guide(description: "Array of characters parsed from the text")
    var characters: [ParsedCharacter]
}

/// A single parsed character from the character descriptions field.
@Generable
struct ParsedCharacter: Sendable {
    @Guide(description: "The character's proper name")
    var name: String
    @Guide(description: "The character's species, breed, or creature type in lowercase")
    var species: String
    @Guide(description: "Comma-separated visual details: size, color, clothing, features")
    var visualSummary: String
    @Guide(description: "A natural English phrase for image generation describing the character's appearance, e.g. 'a brown dachshund wearing a tiny cowboy hat'")
    var injectionPhrase: String
}

// MARK: - Convenience Accessors

extension PromptAnalysis {
    /// Primary character's species (first in the array) — backward compat for
    /// call sites that only need the protagonist's species.
    var characterSpecies: String { characters.first?.species ?? "" }

    /// Primary character's appearance — backward compat.
    var appearanceSummary: String { characters.first?.appearance ?? "" }

    /// All species joined with natural language: "fox", "fox and owl", "fox, owl, and bear".
    var allSpecies: String {
        let list = characters.map(\.species).filter { !$0.isEmpty }
        switch list.count {
        case 0: return ""
        case 1: return list[0]
        case 2: return "\(list[0]) and \(list[1])"
        default: return list.dropLast().joined(separator: ", ") + ", and " + list.last!
        }
    }

    /// Primary character's appearance — alias for `appearanceSummary`.
    var primaryAppearance: String { characters.first?.appearance ?? "" }
}

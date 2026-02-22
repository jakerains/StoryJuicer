import Foundation
import FoundationModels

/// Post-generation safety net that enriches weak image prompts with character
/// visual descriptions parsed from the story's `characterDescriptions` field.
///
/// Small on-device LLMs (~3B) reliably fill in `characterDescriptions` but often
/// generate imagePrompts that reference characters by name only ("Luna walking
/// through a forest"). Image models can't look up who "Luna" is, so this enricher
/// detects bare-name references and injects the species/appearance via appositive
/// grammar: "Luna, a small orange fox with a green scarf, walking through..."
enum ImagePromptEnricher {

    // MARK: - Public API

    /// Enrich all imagePrompts in a StoryBook by injecting character visual details
    /// where the prompt mentions a character by name but omits their species.
    static func enrichImagePrompts(in book: StoryBook) -> StoryBook {
        let characters = parseCharacterDescriptions(book.characterDescriptions)
        guard !characters.isEmpty else { return book }

        let enrichedPages = book.pages.map { page in
            let enrichedPrompt = enrichPrompt(page.imagePrompt, characters: characters)
            return StoryPage(
                pageNumber: page.pageNumber,
                text: page.text,
                imagePrompt: enrichedPrompt
            )
        }

        return StoryBook(
            title: book.title,
            authorLine: book.authorLine,
            moral: book.moral,
            characterDescriptions: book.characterDescriptions,
            pages: enrichedPages
        )
    }

    /// Analysis-aware enrichment that uses `PromptAnalysis` data when available.
    /// Falls back to the standard string-based method for pages without analysis.
    static func enrichImagePrompts(
        in book: StoryBook,
        analyses: [Int: PromptAnalysis]
    ) -> StoryBook {
        // If no analyses provided, fall back to string-based enrichment
        guard !analyses.isEmpty else {
            return enrichImagePrompts(in: book)
        }

        let characters = parseCharacterDescriptions(book.characterDescriptions)
        guard !characters.isEmpty else { return book }

        let enrichedPages = book.pages.map { page in
            if let analysis = analyses[page.pageNumber],
               !analysis.characters.isEmpty {
                // Use analysis-derived species + appearance for enrichment
                let prompt = enrichPromptWithAnalysis(
                    page.imagePrompt,
                    analysis: analysis,
                    characters: characters
                )
                return StoryPage(
                    pageNumber: page.pageNumber,
                    text: page.text,
                    imagePrompt: prompt
                )
            } else {
                // Fall back to string-based enrichment
                let enrichedPrompt = enrichPrompt(page.imagePrompt, characters: characters)
                return StoryPage(
                    pageNumber: page.pageNumber,
                    text: page.text,
                    imagePrompt: enrichedPrompt
                )
            }
        }

        return StoryBook(
            title: book.title,
            authorLine: book.authorLine,
            moral: book.moral,
            characterDescriptions: book.characterDescriptions,
            pages: enrichedPages
        )
    }

    /// Enrich a prompt using analysis data — matches each character entry against
    /// the analysis characters by species, injecting per-character appearance data
    /// from the Foundation Model's structured extraction.
    private static func enrichPromptWithAnalysis(
        _ prompt: String,
        analysis: PromptAnalysis,
        characters: [CharacterEntry]
    ) -> String {
        var result = prompt

        for character in characters {
            let nameLower = character.name.lowercased()
            let promptLower = result.lowercased()

            guard promptLower.contains(nameLower) else { continue }

            // Find the matching analysis character by species overlap
            let matchingAnalysis = analysis.characters.first {
                $0.species == character.species
            }

            // Skip if this character's species is already present in the prompt
            let species = (matchingAnalysis?.species ?? character.species).lowercased()
            if !species.isEmpty, promptLower.contains(species) {
                continue
            }

            // Use matching analysis appearance, or fall back to parsed injection phrase
            let injection: String
            if let match = matchingAnalysis, !match.appearance.isEmpty {
                let summary = match.appearance
                let hasArticle = summary.lowercased().hasPrefix("a ") || summary.lowercased().hasPrefix("an ")
                injection = hasArticle ? summary : "a \(summary)"
            } else {
                injection = character.injectionPhrase
            }

            result = injectDescription(
                in: result,
                name: character.name,
                injection: injection
            )
        }

        return result
    }

    // MARK: - Pre-Parsed Overloads (Upgrade 1)

    /// Enrich all imagePrompts using pre-parsed character entries.
    /// Skips re-parsing `characterDescriptions` — uses the Foundation Model results directly.
    static func enrichImagePrompts(
        in book: StoryBook,
        analyses: [Int: PromptAnalysis],
        parsedCharacters: [CharacterEntry]
    ) -> StoryBook {
        guard !parsedCharacters.isEmpty else {
            return enrichImagePrompts(in: book, analyses: analyses)
        }

        let enrichedPages = book.pages.map { page in
            if let analysis = analyses[page.pageNumber],
               !analysis.characters.isEmpty {
                let prompt = enrichPromptWithAnalysis(
                    page.imagePrompt,
                    analysis: analysis,
                    characters: parsedCharacters
                )
                return StoryPage(
                    pageNumber: page.pageNumber,
                    text: page.text,
                    imagePrompt: prompt
                )
            } else {
                let enrichedPrompt = enrichPrompt(page.imagePrompt, characters: parsedCharacters)
                return StoryPage(
                    pageNumber: page.pageNumber,
                    text: page.text,
                    imagePrompt: enrichedPrompt
                )
            }
        }

        return StoryBook(
            title: book.title,
            authorLine: book.authorLine,
            moral: book.moral,
            characterDescriptions: book.characterDescriptions,
            pages: enrichedPages
        )
    }

    // MARK: - Async Parsing (Upgrade 1)

    /// Parse character descriptions using Foundation Model for structured extraction.
    /// Falls back to the existing regex-based parser if Foundation Model is unavailable.
    static func parseCharacterDescriptionsAsync(_ descriptions: String) async -> [CharacterEntry] {
        guard !descriptions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // Try Foundation Model first
        if let parsed = await parseWithFoundationModel(descriptions) {
            return parsed
        }

        // Fall back to regex parser
        return parseCharacterDescriptions(descriptions)
    }

    /// Use Foundation Model to parse character descriptions into structured entries.
    private static func parseWithFoundationModel(_ descriptions: String) async -> [CharacterEntry]? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let session = LanguageModelSession(
            instructions: """
                You are parsing a character description sheet from a children's storybook. \
                Extract each character's name, species/breed (lowercase), visual details, \
                and a natural injection phrase for image generation. \
                The injection phrase should read naturally in a sentence, e.g. \
                "a brown dachshund wearing a tiny cowboy hat" or "a small orange fox with a green scarf". \
                Always start the injection phrase with "a" or "an".
                """
        )

        let request = """
            Parse these character descriptions into structured entries:
            "\(descriptions)"
            """

        let options = GenerationOptions(
            temperature: 0.15,
            maximumResponseTokens: 400
        )

        do {
            let response = try await session.respond(
                to: request,
                generating: ParsedCharacterSheet.self,
                options: options
            )
            let parsed = response.content.characters
            guard !parsed.isEmpty else { return nil }

            return parsed.map { pc in
                CharacterEntry(
                    name: pc.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    species: pc.species.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                    visualSummary: pc.visualSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                    injectionPhrase: pc.injectionPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } catch {
            return nil
        }
    }

    // MARK: - Character Parsing

    /// A parsed character entry from the characterDescriptions field.
    struct CharacterEntry: Sendable {
        let name: String
        let species: String
        let visualSummary: String
        /// Compact injection phrase: "a small orange fox with a green scarf"
        let injectionPhrase: String
    }

    /// Parse "Name - species, colors, clothing" lines into structured entries.
    ///
    /// Expected format (one line per character):
    /// ```
    /// Luna - small orange fox, green scarf, curious eyes
    /// Ollie - round gray owl, red bow tie, big amber eyes
    /// ```
    static func parseCharacterDescriptions(_ descriptions: String) -> [CharacterEntry] {
        // Split by newlines, semicolons, and periods to handle all LLM formatting:
        //   "Luna - fox\nOliver - owl"           (newline-separated)
        //   "Luna - fox; Oliver - owl"            (semicolon-separated)
        //   "Luna - fox, details. Oliver - owl"   (period-separated)
        let lines = descriptions
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: "; ") }
            .flatMap { splitOnPeriodBoundaries($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.compactMap { line -> CharacterEntry? in
            // Split on " - " or " – " (em dash) or ": "
            let separators = [" - ", " – ", ": "]
            var name: String?
            var details: String?

            for sep in separators {
                if let range = line.range(of: sep) {
                    name = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    details = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }

            guard let charName = name, !charName.isEmpty,
                  var charDetails = details, !charDetails.isEmpty else {
                return nil
            }

            // Strip trailing punctuation that LLMs sometimes add (e.g., "green scarf.")
            // to prevent period-comma ("scarf.,") or double-period ("scarf..") in injections
            while let last = charDetails.last, ".!?;".contains(last) {
                charDetails.removeLast()
            }
            charDetails = charDetails.trimmingCharacters(in: .whitespaces)
            guard !charDetails.isEmpty else { return nil }

            // Extract species from the details
            let detailsLower = charDetails.lowercased()
            let species = speciesWords.first { detailsLower.contains($0) } ?? ""

            // Build injection phrase: "a small orange fox with a green scarf"
            let injection = buildInjectionPhrase(from: charDetails)

            return CharacterEntry(
                name: charName,
                species: species,
                visualSummary: charDetails,
                injectionPhrase: injection
            )
        }
    }

    // MARK: - Species Word List

    /// Common species/creature words for children's stories.
    /// Shared with enrichment detection — if a prompt contains the character's
    /// species word, we assume it's already well-described.
    static let speciesWords: Set<String> = [
        "fox", "rabbit", "bunny", "bear", "cat", "kitten", "dog", "puppy",
        "mouse", "owl", "deer", "bird", "dragon", "unicorn", "frog", "turtle",
        "squirrel", "hedgehog", "penguin", "lion", "wolf", "elephant",
        "butterfly", "otter", "raccoon", "badger", "monkey", "panda",
        "pig", "piglet", "horse", "pony", "duck", "duckling", "goose",
        "chicken", "rooster", "cow", "sheep", "lamb", "goat", "bee",
        "ladybug", "ant", "snail", "fish", "whale", "dolphin", "octopus",
        "crab", "starfish", "seahorse", "parrot", "flamingo", "peacock",
        "tiger", "leopard", "cheetah", "giraffe", "zebra", "hippo",
        "hippopotamus", "rhino", "rhinoceros", "koala", "kangaroo",
        "sloth", "armadillo", "chameleon", "gecko", "lizard", "snake",
        "robin", "sparrow", "eagle", "hawk", "fairy", "gnome", "elf",
        "wizard", "witch", "mermaid", "robot", "dinosaur", "caterpillar",
        "firefly", "dragonfly", "chipmunk", "hamster", "guinea pig",
        // Dog breeds
        "dachshund", "corgi", "poodle", "beagle", "bulldog", "dalmatian",
        "retriever", "labrador", "terrier", "spaniel", "collie", "husky",
        "pug", "chihuahua", "schnauzer", "greyhound", "mastiff",
        // Cat breeds
        "tabby", "siamese", "persian", "calico",
        // Additional animals
        "moose", "beaver", "wombat", "platypus", "alpaca", "llama",
        "ferret", "chinchilla", "toucan", "hummingbird", "stork", "pelican",
        "boy", "girl", "child", "kid", "person", "man", "woman",
    ]

    /// Split a segment on ". " only when the text after the period looks like
    /// a new "Name - details" entry (starts with a capitalized word followed
    /// by a name separator). This avoids splitting mid-sentence within a
    /// single character's description.
    private static func splitOnPeriodBoundaries(_ segment: String) -> [String] {
        let nameSeparators = [" - ", " – ", ": "]
        var results: [String] = []
        var searchStart = segment.startIndex

        while let dotRange = segment.range(of: ". ", range: searchStart..<segment.endIndex) {
            let afterDot = segment[dotRange.upperBound...]
            // Check: starts with uppercase letter AND contains a name separator
            let startsWithUpper = afterDot.first?.isUppercase == true
            let hasNameSep = startsWithUpper && nameSeparators.contains { afterDot.contains($0) }

            if hasNameSep {
                let before = String(segment[searchStart..<dotRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty { results.append(before) }
                searchStart = dotRange.upperBound
            } else {
                // Not a character boundary — skip past this ". "
                searchStart = dotRange.upperBound
            }
        }

        let remainder = String(segment[searchStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty { results.append(remainder) }
        return results.isEmpty ? [segment] : results
    }

    // MARK: - Private Helpers

    /// Enrich a single image prompt by injecting character descriptions where
    /// the character is mentioned by name but their species is absent.
    private static func enrichPrompt(_ prompt: String, characters: [CharacterEntry]) -> String {
        var result = prompt

        for character in characters {
            let nameLower = character.name.lowercased()
            let promptLower = result.lowercased()

            // Skip if this character isn't mentioned at all
            guard promptLower.contains(nameLower) else { continue }

            // Skip if species is already present in the prompt
            if !character.species.isEmpty, promptLower.contains(character.species) {
                continue
            }

            // Check if this character's own species word is near their name
            if hasSpeciesNearName(in: result, name: character.name, species: character.species) {
                continue
            }

            // Inject: replace "Luna" with "Luna, a small orange fox with a green scarf,"
            result = injectDescription(
                in: result,
                name: character.name,
                injection: character.injectionPhrase
            )
        }

        return result
    }

    /// Check if this character's own species word appears near their name.
    /// Only matches the character's parsed species — not other characters' species.
    private static func hasSpeciesNearName(in prompt: String, name: String, species: String) -> Bool {
        guard !species.isEmpty else { return false }

        let promptLower = prompt.lowercased()
        let nameLower = name.lowercased()

        guard let nameRange = promptLower.range(of: nameLower) else { return false }

        // Look at a window of ~60 characters around the name
        let windowStart = promptLower.index(nameRange.lowerBound, offsetBy: -30, limitedBy: promptLower.startIndex) ?? promptLower.startIndex
        let windowEnd = promptLower.index(nameRange.upperBound, offsetBy: 30, limitedBy: promptLower.endIndex) ?? promptLower.endIndex
        let window = String(promptLower[windowStart..<windowEnd])

        return window.contains(species.lowercased())
    }

    /// Replace the first occurrence of a bare character name with name + appositive description.
    private static func injectDescription(in prompt: String, name: String, injection: String) -> String {
        // Find the name in the prompt (case-insensitive match, but preserve original casing)
        guard let range = prompt.range(of: name, options: .caseInsensitive) else {
            return prompt
        }

        let originalName = String(prompt[range])

        // Check what follows the name to decide punctuation
        let afterName = prompt[range.upperBound...]
        let trimmedAfter = afterName.trimmingCharacters(in: .whitespaces)

        // If already followed by a comma or description, just append
        if trimmedAfter.hasPrefix(",") {
            // Already has a comma — insert description after the existing comma
            return prompt.replacingCharacters(in: range, with: "\(originalName), \(injection),")
        }

        // Standard appositive injection
        return prompt.replacingCharacters(in: range, with: "\(originalName), \(injection),")
    }

    /// Build a natural injection phrase from character details.
    ///
    /// Input: "small orange fox, green scarf, curious eyes"
    /// Output: "a small orange fox with a green scarf"
    private static func buildInjectionPhrase(from details: String) -> String {
        let parts = details
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = parts.first else { return details }

        // First part is usually "species + color" — prefix with "a" if needed
        let article = first.lowercased().hasPrefix("a ") || first.lowercased().hasPrefix("an ") ? "" : "a "
        var phrase = "\(article)\(first)"

        // Add up to one more visual detail with "with" — skip behavioral traits
        // like "loves collecting books" which aren't useful for image generation
        if parts.count > 1 {
            let detail = parts[1]
            let detailLower = detail.lowercased()
            let behavioralStarters = ["loves", "likes", "enjoys", "helps", "always",
                                      "often", "can", "is known", "tends to", "known for"]
            let isBehavioral = behavioralStarters.contains { detailLower.hasPrefix($0) }

            if !isBehavioral {
                let needsWith = !detailLower.hasPrefix("with ") && !detailLower.hasPrefix("wearing ")
                if needsWith {
                    phrase += " with \(detail)"
                } else {
                    phrase += " \(detail)"
                }
            }
        }

        return phrase
    }

    // MARK: - Evaluation (for Test Harness)

    /// Result of evaluating a StoryBook for character consistency.
    struct HarnessResult: Sendable {
        let concept: String
        let rawBook: StoryBook
        let enrichedBook: StoryBook
        let characterDescriptionScore: Double
        let speciesInPromptsScore: Double
        let appearanceInPromptsScore: Double
        let nameConsistencyScore: Double
        let overallScore: Double
        let details: [PageCheckResult]
    }

    /// Per-page evaluation result.
    struct PageCheckResult: Sendable, Identifiable {
        var id: Int { pageNumber }
        let pageNumber: Int
        let rawImagePrompt: String
        let enrichedImagePrompt: String
        let hasSpecies: Bool
        let hasAppearance: Bool
        let hasCharacterName: Bool
    }

    /// Evaluate character consistency in a story book.
    /// - Parameters:
    ///   - rawBook: The book as generated by the LLM (before enrichment).
    ///   - expectedSpecies: The species we expect (e.g., "fox" for a fox story).
    ///   - concept: The original story concept.
    static func evaluate(
        rawBook: StoryBook,
        expectedSpecies: String,
        concept: String
    ) -> HarnessResult {
        let enrichedBook = enrichImagePrompts(in: rawBook)
        let characters = parseCharacterDescriptions(rawBook.characterDescriptions)

        // 1. Character description quality
        let descLower = rawBook.characterDescriptions.lowercased()
        let descHasSpecies = descLower.contains(expectedSpecies.lowercased())
        // Accept either comma-separated traits OR a phrase with 3+ meaningful words
        let descHasDetail = characters.first.map { char -> Bool in
            let commaParts = char.visualSummary.components(separatedBy: ",").count
            if commaParts >= 2 { return true }
            let meaningfulWords = char.visualSummary
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }
            return meaningfulWords.count >= 3
        } ?? false
        let characterDescriptionScore: Double = {
            var score = 0.0
            if descHasSpecies { score += 0.5 }
            if descHasDetail { score += 0.5 }
            return score
        }()

        // 2. Gather appearance keywords from character descriptions
        // Use both comma-separated phrases AND individual words for robust matching
        let appearanceStopWords: Set<String> = ["with", "from", "that", "this", "have", "their", "about", "some", "when", "were"]
        let appearanceKeywords: [String] = characters.flatMap { char -> [String] in
            let summary = char.visualSummary.lowercased()
            // Comma-separated phrases (works when LLM uses commas)
            var keywords = summary
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            // Also extract individual significant words for single-phrase descriptions
            let words = summary
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 3 && !appearanceStopWords.contains($0) }
            keywords.append(contentsOf: words)
            return keywords
        }

        // 3. Per-page checks (on enriched prompts)
        let pageResults: [PageCheckResult] = enrichedBook.pages.map { page in
            let rawPage = rawBook.pages.first { $0.pageNumber == page.pageNumber }
            let promptLower = page.imagePrompt.lowercased()
            let hasSpecies = promptLower.contains(expectedSpecies.lowercased())
            let hasAppearance = appearanceKeywords.contains { keyword in
                promptLower.contains(keyword)
            }
            let hasName = characters.contains { char in
                promptLower.contains(char.name.lowercased())
            }

            return PageCheckResult(
                pageNumber: page.pageNumber,
                rawImagePrompt: rawPage?.imagePrompt ?? page.imagePrompt,
                enrichedImagePrompt: page.imagePrompt,
                hasSpecies: hasSpecies,
                hasAppearance: hasAppearance,
                hasCharacterName: hasName
            )
        }

        // 4. Aggregate scores
        let pageCount = max(pageResults.count, 1)
        let speciesScore = Double(pageResults.filter(\.hasSpecies).count) / Double(pageCount)
        let appearanceScore = Double(pageResults.filter(\.hasAppearance).count) / Double(pageCount)
        let nameScore = Double(pageResults.filter(\.hasCharacterName).count) / Double(pageCount)

        // Weighted average: species matters most for visual consistency
        let overall = characterDescriptionScore * 0.2
            + speciesScore * 0.35
            + appearanceScore * 0.25
            + nameScore * 0.2

        return HarnessResult(
            concept: concept,
            rawBook: rawBook,
            enrichedBook: enrichedBook,
            characterDescriptionScore: characterDescriptionScore,
            speciesInPromptsScore: speciesScore,
            appearanceInPromptsScore: appearanceScore,
            nameConsistencyScore: nameScore,
            overallScore: overall,
            details: pageResults
        )
    }
}

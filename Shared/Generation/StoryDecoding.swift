import Foundation

enum StoryDecodingError: LocalizedError {
    case unparsableResponse
    case contentRejected

    var errorDescription: String? {
        switch self {
        case .unparsableResponse:
            return "Model response could not be parsed into a story."
        case .contentRejected:
            return "Model response did not include valid pages."
        }
    }
}

struct StoryDTO: Decodable {
    let title: String
    let authorLine: String
    let moral: String
    let characterDescriptions: String?
    let pages: [StoryPageDTO]

    func toStoryBook(pageCount: Int, fallbackConcept: String) -> StoryBook {
        let orderedPages = pages
            .sorted { $0.pageNumber < $1.pageNumber }
            .prefix(pageCount)
            .enumerated()
            .map { offset, page -> StoryPage in
                let pageNumber = offset + 1
                let safeText = StoryTextCleanup.clean(page.text)
                let safePrompt = page.imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackPrompt = ContentSafetyPolicy.safeIllustrationPrompt(
                    "A gentle scene inspired by \(fallbackConcept)"
                )

                return StoryPage(
                    pageNumber: pageNumber,
                    text: safeText.isEmpty ? "A gentle moment unfolds." : safeText,
                    imagePrompt: safePrompt.isEmpty ? fallbackPrompt : safePrompt
                )
            }

        let cleanTitle = StoryTextCleanup.clean(title)
        let cleanAuthor = StoryTextCleanup.clean(authorLine)
        let cleanMoral = StoryTextCleanup.clean(moral)

        // Validate character descriptions — if the model returned garbage or nothing,
        // try to extract character references from image prompts as a fallback.
        let validatedDescriptions = CharacterDescriptionValidator.validate(
            descriptions: characterDescriptions ?? "",
            pages: orderedPages,
            title: cleanTitle
        )

        return StoryBook(
            title: cleanTitle.isEmpty ? "StoryFox Book" : cleanTitle,
            authorLine: cleanAuthor.isEmpty ? "Written by StoryFox" : cleanAuthor,
            moral: cleanMoral.isEmpty ? "Kindness and curiosity guide every adventure." : cleanMoral,
            characterDescriptions: validatedDescriptions,
            pages: orderedPages
        )
    }
}

/// Strips markdown formatting artifacts that cloud and MLX models often
/// embed in JSON string values (bold, italic, headings, etc.) and
/// normalizes whitespace so story text renders cleanly in the reader, PDF,
/// and EPUB exports.
enum StoryTextCleanup {
    static func clean(_ text: String) -> String {
        var s = text

        // Strip markdown bold/italic wrappers: ***bold italic***, **bold**, *italic*, __bold__, _italic_
        // Process longest patterns first so we don't leave orphaned markers.
        s = s.replacingOccurrences(of: "\\*{3}(.+?)\\*{3}", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\*{2}(.+?)\\*{2}", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?<=\\s|^)\\*(?=\\S)(.+?)(?<=\\S)\\*(?=\\s|$|[.,!?])", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "__(.+?)__", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?<=\\s|^)_(?=\\S)(.+?)(?<=\\S)_(?=\\s|$|[.,!?])", with: "$1", options: .regularExpression)

        // Strip markdown heading prefixes (# Title, ## Subtitle, etc.)
        s = s.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)

        // Normalize smart/curly quotes to straight quotes
        s = s.replacingOccurrences(of: "\u{201C}", with: "\"") // left double
        s = s.replacingOccurrences(of: "\u{201D}", with: "\"") // right double
        s = s.replacingOccurrences(of: "\u{2018}", with: "'")  // left single
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")  // right single

        // Strip wrapping quotes that some models put around the entire value
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count > 2 {
            s = String(s.dropFirst().dropLast())
        }

        // Collapse multiple whitespace/newlines into a single space
        s = s.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)

        // Final trim
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        return s
    }
}

struct StoryPageDTO: Decodable {
    let pageNumber: Int
    let text: String
    let imagePrompt: String
}

private struct StoryEnvelopeDTO: Decodable {
    let story: StoryDTO
}

enum StoryDecoding {
    static func decodeStoryDTO(from data: Data) throws -> StoryDTO {
        let decoder = JSONDecoder()
        if let story = try? decoder.decode(StoryDTO.self, from: data) {
            return story
        }
        if let envelope = try? decoder.decode(StoryEnvelopeDTO.self, from: data) {
            return envelope.story
        }
        if let content = extractTextContent(from: data),
           let json = extractFirstJSONObjectString(from: content)?.data(using: .utf8),
           let story = try? decoder.decode(StoryDTO.self, from: json) {
            return story
        }
        throw StoryDecodingError.unparsableResponse
    }

    static func decodeStoryDTO(from text: String) throws -> StoryDTO {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw StoryDecodingError.unparsableResponse
        }

        let decoder = JSONDecoder()

        // Try direct decode
        if let data = trimmed.data(using: .utf8),
           let story = try? decoder.decode(StoryDTO.self, from: data) {
            return story
        }

        // Try extracting JSON object from surrounding text
        if let jsonString = extractFirstJSONObjectString(from: trimmed),
           let data = jsonString.data(using: .utf8),
           let story = try? decoder.decode(StoryDTO.self, from: data) {
            return story
        }

        // Last resort: attempt JSON repair for truncated output from small models
        if let repaired = repairTruncatedJSON(trimmed),
           let data = repaired.data(using: .utf8),
           let story = try? decoder.decode(StoryDTO.self, from: data) {
            return story
        }

        // Also try repair on extracted JSON
        if let jsonString = extractFirstJSONObjectString(from: trimmed),
           let repaired = repairTruncatedJSON(jsonString),
           let data = repaired.data(using: .utf8),
           let story = try? decoder.decode(StoryDTO.self, from: data) {
            return story
        }

        throw StoryDecodingError.unparsableResponse
    }

    static func extractTextContent(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let content = object["content"] as? String {
            return content
        }

        if let story = object["story"] as? [String: Any],
           let storyData = try? JSONSerialization.data(withJSONObject: story),
           let storyJSON = String(data: storyData, encoding: .utf8) {
            return storyJSON
        }

        if let choices = object["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any] {
            if let content = message["content"] as? String {
                return content
            }
            if let contentItems = message["content"] as? [[String: Any]] {
                let parts = contentItems.compactMap { item -> String? in
                    if let text = item["text"] as? String {
                        return text
                    }
                    if let text = item["output_text"] as? String {
                        return text
                    }
                    return nil
                }
                if !parts.isEmpty {
                    return parts.joined(separator: "\n")
                }
            }
        }

        return nil
    }

    static func extractFirstJSONObjectString(from text: String) -> String? {
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[firstBrace...lastBrace])
    }

    // MARK: - Two-Pass Decoding

    /// Decode a text-only story DTO (Pass 1 output — no imagePrompts).
    static func decodeTextOnlyStoryDTO(from text: String) throws -> TextOnlyStoryDTO {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw StoryDecodingError.unparsableResponse
        }

        let decoder = JSONDecoder()

        if let data = trimmed.data(using: .utf8),
           let dto = try? decoder.decode(TextOnlyStoryDTO.self, from: data) {
            return dto
        }

        if let jsonString = extractFirstJSONObjectString(from: trimmed),
           let data = jsonString.data(using: .utf8),
           let dto = try? decoder.decode(TextOnlyStoryDTO.self, from: data) {
            return dto
        }

        if let repaired = repairTruncatedJSON(trimmed),
           let data = repaired.data(using: .utf8),
           let dto = try? decoder.decode(TextOnlyStoryDTO.self, from: data) {
            return dto
        }

        if let jsonString = extractFirstJSONObjectString(from: trimmed),
           let repaired = repairTruncatedJSON(jsonString),
           let data = repaired.data(using: .utf8),
           let dto = try? decoder.decode(TextOnlyStoryDTO.self, from: data) {
            return dto
        }

        throw StoryDecodingError.unparsableResponse
    }

    /// Decode an image prompt sheet DTO (Pass 2 output — prompts only).
    static func decodeImagePromptSheetDTO(from text: String) throws -> ImagePromptSheetDTO {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw StoryDecodingError.unparsableResponse
        }

        let decoder = JSONDecoder()

        if let data = trimmed.data(using: .utf8),
           let dto = try? decoder.decode(ImagePromptSheetDTO.self, from: data) {
            return dto
        }

        if let jsonString = extractFirstJSONObjectString(from: trimmed),
           let data = jsonString.data(using: .utf8),
           let dto = try? decoder.decode(ImagePromptSheetDTO.self, from: data) {
            return dto
        }

        if let repaired = repairTruncatedJSON(trimmed),
           let data = repaired.data(using: .utf8),
           let dto = try? decoder.decode(ImagePromptSheetDTO.self, from: data) {
            return dto
        }

        if let jsonString = extractFirstJSONObjectString(from: trimmed),
           let repaired = repairTruncatedJSON(jsonString),
           let data = repaired.data(using: .utf8),
           let dto = try? decoder.decode(ImagePromptSheetDTO.self, from: data) {
            return dto
        }

        throw StoryDecodingError.unparsableResponse
    }

    /// Merge Pass 1 text + Pass 2 prompts into a complete StoryBook.
    /// Applies the same cleanup and validation pipeline as StoryDTO.toStoryBook().
    static func mergeIntoStoryBook(
        textDTO: TextOnlyStoryDTO,
        promptSheet: ImagePromptSheetDTO,
        pageCount: Int,
        fallbackConcept: String
    ) -> StoryBook {
        // Index prompts by page number for fast lookup
        let promptsByPage = Dictionary(
            promptSheet.prompts.map { ($0.pageNumber, $0.imagePrompt) },
            uniquingKeysWith: { _, last in last }
        )

        let orderedPages = textDTO.pages
            .sorted { $0.pageNumber < $1.pageNumber }
            .prefix(pageCount)
            .enumerated()
            .map { offset, page -> StoryPage in
                let pageNumber = offset + 1
                let safeText = StoryTextCleanup.clean(page.text)
                let prompt = promptsByPage[page.pageNumber]?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let fallbackPrompt = ContentSafetyPolicy.safeIllustrationPrompt(
                    "A gentle scene inspired by \(fallbackConcept)"
                )

                return StoryPage(
                    pageNumber: pageNumber,
                    text: safeText.isEmpty ? "A gentle moment unfolds." : safeText,
                    imagePrompt: prompt.isEmpty ? fallbackPrompt : prompt
                )
            }

        let cleanTitle = StoryTextCleanup.clean(textDTO.title)
        let cleanAuthor = StoryTextCleanup.clean(textDTO.authorLine)
        let cleanMoral = StoryTextCleanup.clean(textDTO.moral)

        let validatedDescriptions = CharacterDescriptionValidator.validate(
            descriptions: textDTO.characterDescriptions ?? "",
            pages: orderedPages,
            title: cleanTitle
        )

        return StoryBook(
            title: cleanTitle.isEmpty ? "StoryFox Book" : cleanTitle,
            authorLine: cleanAuthor.isEmpty ? "Written by StoryFox" : cleanAuthor,
            moral: cleanMoral.isEmpty ? "Kindness and curiosity guide every adventure." : cleanMoral,
            characterDescriptions: validatedDescriptions,
            pages: orderedPages
        )
    }

    // MARK: - JSON Repair

    /// Attempt to repair truncated JSON from small models that ran out of tokens.
    /// Closes unclosed brackets, braces, and strings to salvage partial output.
    static func repairTruncatedJSON(_ text: String) -> String? {
        var json = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard json.hasPrefix("{") || json.hasPrefix("[") else { return nil }

        // Strip trailing comma (common truncation artifact)
        while json.hasSuffix(",") {
            json = String(json.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Count open brackets/braces and close them
        var openBraces = 0
        var openBrackets = 0
        var inString = false
        var prevChar: Character = " "

        for char in json {
            if char == "\"" && prevChar != "\\" {
                inString.toggle()
            }
            if !inString {
                switch char {
                case "{": openBraces += 1
                case "}": openBraces -= 1
                case "[": openBrackets += 1
                case "]": openBrackets -= 1
                default: break
                }
            }
            prevChar = char
        }

        // Close unclosed string
        if inString {
            json += "\""
        }

        // Close brackets and braces in reverse order of expected nesting
        // Pages array is typically the deepest nesting level
        for _ in 0..<max(0, openBrackets) {
            json += "]"
        }
        for _ in 0..<max(0, openBraces) {
            json += "}"
        }

        return json
    }
}

// MARK: - Two-Pass DTO Types

/// Pass 1 output: story text without image prompts.
struct TextOnlyStoryDTO: Decodable {
    let title: String
    let authorLine: String
    let moral: String
    let characterDescriptions: String?
    let pages: [TextOnlyPageDTO]
}

/// A single page of story text without an image prompt.
struct TextOnlyPageDTO: Decodable {
    let pageNumber: Int
    let text: String
}

/// Pass 2 output: image prompts only.
struct ImagePromptSheetDTO: Decodable {
    let prompts: [ImagePromptDTO]
}

/// A single page's image prompt from Pass 2.
struct ImagePromptDTO: Decodable {
    let pageNumber: Int
    let imagePrompt: String
}

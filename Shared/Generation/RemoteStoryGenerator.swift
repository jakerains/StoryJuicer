import Foundation

struct RemoteStoryGeneratorConfig: Sendable {
    let endpointURL: URL
    let apiKey: String?
    let model: String?
    let timeoutSeconds: TimeInterval
    let apiHeaderName: String
    let apiHeaderPrefix: String

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> RemoteStoryGeneratorConfig? {
        let endpointValue = value(
            envKeys: ["STORYJUICER_LARGE_MODEL_ENDPOINT", "STORYJUICER_REMOTE_LLM_ENDPOINT"],
            defaultKey: "storyjuicer.largeModelEndpoint",
            environment: environment,
            defaults: defaults
        )
        guard let endpointValue,
              let endpointURL = URL(string: endpointValue) else {
            return nil
        }

        let apiKey = value(
            envKeys: ["STORYJUICER_LARGE_MODEL_API_KEY", "STORYJUICER_REMOTE_LLM_API_KEY"],
            defaultKey: "storyjuicer.largeModelApiKey",
            environment: environment,
            defaults: defaults
        )
        let model = value(
            envKeys: ["STORYJUICER_LARGE_MODEL_NAME", "STORYJUICER_REMOTE_LLM_MODEL"],
            defaultKey: "storyjuicer.largeModelName",
            environment: environment,
            defaults: defaults
        )
        let apiHeaderName = value(
            envKeys: ["STORYJUICER_LARGE_MODEL_API_HEADER", "STORYJUICER_REMOTE_LLM_API_HEADER"],
            defaultKey: "storyjuicer.largeModelApiHeader",
            environment: environment,
            defaults: defaults
        ) ?? "Authorization"
        let apiHeaderPrefix = value(
            envKeys: ["STORYJUICER_LARGE_MODEL_API_PREFIX", "STORYJUICER_REMOTE_LLM_API_PREFIX"],
            defaultKey: "storyjuicer.largeModelApiPrefix",
            environment: environment,
            defaults: defaults
        ) ?? "Bearer "

        let timeoutRaw = value(
            envKeys: ["STORYJUICER_LARGE_MODEL_TIMEOUT_SECONDS", "STORYJUICER_REMOTE_LLM_TIMEOUT_SECONDS"],
            defaultKey: "storyjuicer.largeModelTimeoutSeconds",
            environment: environment,
            defaults: defaults
        )
        let timeoutSeconds = timeoutRaw.flatMap(TimeInterval.init) ?? 60

        return RemoteStoryGeneratorConfig(
            endpointURL: endpointURL,
            apiKey: apiKey,
            model: model,
            timeoutSeconds: timeoutSeconds,
            apiHeaderName: apiHeaderName,
            apiHeaderPrefix: apiHeaderPrefix
        )
    }

    private static func value(
        envKeys: [String],
        defaultKey: String,
        environment: [String: String],
        defaults: UserDefaults
    ) -> String? {
        for key in envKeys {
            if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        if let value = defaults.string(forKey: defaultKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        return nil
    }
}

enum RemoteStoryGeneratorError: LocalizedError {
    case notConfigured
    case invalidResponse(statusCode: Int, message: String)
    case unparsableResponse
    case contentRejected

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Remote large-model generator is not configured."
        case .invalidResponse(let statusCode, let message):
            return "Large-model request failed (\(statusCode)): \(message)"
        case .unparsableResponse:
            return "Large-model response could not be parsed into a story."
        case .contentRejected:
            return "Large-model response did not include valid pages."
        }
    }
}

/// Calls an optional remote "larger model" endpoint for story generation.
/// If endpoint details are missing, caller should fall back to local generation.
struct RemoteStoryGenerator: Sendable {
    var config: RemoteStoryGeneratorConfig? = RemoteStoryGeneratorConfig.load()
    var urlSession: URLSession = .shared

    var isConfigured: Bool {
        config != nil
    }

    func generateStory(
        concept: String,
        pageCount: Int
    ) async throws -> StoryBook {
        guard let config else {
            throw RemoteStoryGeneratorError.notConfigured
        }

        let safeConcept = ContentSafetyPolicy.sanitizeConcept(concept)
        var request = URLRequest(url: config.endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeoutSeconds

        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.setValue(
                "\(config.apiHeaderPrefix)\(apiKey)",
                forHTTPHeaderField: config.apiHeaderName
            )
        }

        let payload = RemoteStoryRequestPayload(
            model: config.model,
            concept: safeConcept,
            pageCount: pageCount,
            systemInstructions: Self.remoteSystemInstructions,
            userPrompt: Self.remoteUserPrompt(concept: safeConcept, pageCount: pageCount)
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteStoryGeneratorError.unparsableResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RemoteStoryGeneratorError.invalidResponse(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        let dto = try decodeStoryDTO(from: data)
        let story = dto.toStoryBook(
            pageCount: pageCount,
            fallbackConcept: safeConcept
        )
        guard !story.pages.isEmpty else {
            throw RemoteStoryGeneratorError.contentRejected
        }
        return story
    }

    private func decodeStoryDTO(from data: Data) throws -> RemoteStoryDTO {
        let decoder = JSONDecoder()
        if let story = try? decoder.decode(RemoteStoryDTO.self, from: data) {
            return story
        }
        if let envelope = try? decoder.decode(RemoteStoryEnvelope.self, from: data) {
            return envelope.story
        }
        if let content = extractTextContent(from: data),
           let json = extractFirstJSONObjectString(from: content)?.data(using: .utf8),
           let story = try? decoder.decode(RemoteStoryDTO.self, from: json) {
            return story
        }
        throw RemoteStoryGeneratorError.unparsableResponse
    }

    private func extractTextContent(from data: Data) -> String? {
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

    private func extractFirstJSONObjectString(from text: String) -> String? {
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else {
            return nil
        }
        let jsonSlice = text[firstBrace...lastBrace]
        return String(jsonSlice)
    }

    private static var remoteSystemInstructions: String {
        """
        You are an award-winning children's storybook writer and art director.
        Output only content that is safe for ages 3-8 and suitable for on-device image generation.
        Avoid violence, weapons, gore, horror, nudity, substance use, hateful content, or unsafe scenarios.
        """
    }

    private static func remoteUserPrompt(concept: String, pageCount: Int) -> String {
        """
        Create a \(pageCount)-page children's storybook from this concept: "\(concept)".
        Return JSON with this exact shape:
        {
          "title": "string",
          "authorLine": "string",
          "moral": "string",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-4 child-friendly sentences",
              "imagePrompt": "Detailed illustration prompt with subject, setting, mood, palette, lighting, and composition. No text overlays."
            }
          ]
        }
        Requirements:
        - Exactly \(pageCount) pages, numbered 1...\(pageCount).
        - Keep language warm, gentle, and easy to read aloud.
        - Each imagePrompt must be child-safe and vivid.
        """
    }
}

private struct RemoteStoryRequestPayload: Encodable {
    let model: String?
    let concept: String
    let pageCount: Int
    let systemInstructions: String
    let userPrompt: String
}

private struct RemoteStoryEnvelope: Decodable {
    let story: RemoteStoryDTO
}

private struct RemoteStoryDTO: Decodable {
    let title: String
    let authorLine: String
    let moral: String
    let pages: [RemoteStoryPageDTO]

    func toStoryBook(pageCount: Int, fallbackConcept: String) -> StoryBook {
        let orderedPages = pages
            .sorted { $0.pageNumber < $1.pageNumber }
            .prefix(pageCount)
            .enumerated()
            .map { offset, page -> StoryPage in
                let pageNumber = offset + 1
                let safeText = page.text.trimmingCharacters(in: .whitespacesAndNewlines)
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

        return StoryBook(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "StoryJuicer Book" : title,
            authorLine: authorLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Written by StoryJuicer" : authorLine,
            moral: moral.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Kindness and curiosity guide every adventure." : moral,
            pages: orderedPages
        )
    }
}

private struct RemoteStoryPageDTO: Decodable {
    let pageNumber: Int
    let text: String
    let imagePrompt: String
}

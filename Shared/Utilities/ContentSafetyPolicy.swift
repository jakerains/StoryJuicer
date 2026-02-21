import Foundation
import FoundationModels

enum ContentSafetyCheckResult: Equatable, Sendable {
    case allowed(sanitizedConcept: String)
    case blocked(reason: String)
}

struct ContentSafetyPolicy: Sendable {

    // MARK: - Unsafe Content Detection (Upgrade 3)

    /// Check if a prompt contains any words that would trigger illustration replacements.
    /// Used as a fast gate before invoking the Foundation Model rewrite.
    static func hasUnsafeContent(_ text: String) -> Bool {
        for rule in illustrationPromptReplacements {
            if text.range(of: rule.pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Async Safety Rewrite (Upgrade 3)

    /// Async version of `safeIllustrationPrompt` that uses Foundation Model for
    /// grammatically correct rewrites when unsafe content is detected.
    /// Falls back to the sync regex method if Foundation Model is unavailable.
    static func safeIllustrationPromptAsync(_ prompt: String, extendedLimit: Bool = false) async -> String {
        let sanitized = sanitizeConcept(prompt)

        // Fast path: no unsafe content → skip LLM entirely
        guard hasUnsafeContent(sanitized) else {
            return safeIllustrationPrompt(prompt, extendedLimit: extendedLimit)
        }

        // Try Foundation Model rewrite
        if let rewritten = await rewriteForSafety(sanitized) {
            let limit = extendedLimit ? 300 : 180
            let trimmed = rewritten.count > limit ? String(rewritten.prefix(limit)) : rewritten
            return trimmed
        }

        // Fall back to sync regex replacement
        return safeIllustrationPrompt(prompt, extendedLimit: extendedLimit)
    }

    /// Use Foundation Model to rewrite an unsafe prompt into a child-safe version
    /// while preserving the visual intent and correct grammar.
    private static func rewriteForSafety(_ prompt: String) async -> String? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let session = LanguageModelSession(
            instructions: """
                You rewrite children's illustration prompts to make them safe for young children. \
                Replace any violence, weapons, death, or scary elements with playful, cheerful alternatives. \
                Keep the same characters and setting. Preserve the visual composition. \
                Output ONLY the rewritten prompt — no explanation, no quotes. \
                Keep it under 150 characters. Use natural, grammatically correct English.
                """
        )

        let request = """
            Rewrite this illustration prompt to be child-safe while keeping the same characters and scene:
            "\(prompt)"
            """

        let options = GenerationOptions(
            temperature: 0.3,
            maximumResponseTokens: 120
        )

        do {
            let response = try await session.respond(
                to: request,
                generating: IllustrationPromptRewrite.self,
                options: options
            )
            let result = response.content.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? nil : result
        } catch {
            return nil
        }
    }
    private static let blockedPatterns: [(pattern: String, reason: String)] = [
        (
            pattern: #"\b(kill|killing|murder|stab|stabbing|blood|gore|dismember|weapon|gun|knife|shoot|war|battle|terror)\b"#,
            reason: "Please keep story concepts gentle and avoid violence or weapon themes for kids."
        ),
        (
            pattern: #"\b(sex|sexual|nude|nudity|porn|erotic|fetish|intimate)\b"#,
            reason: "Please keep story concepts child-appropriate and avoid sexual content."
        ),
        (
            pattern: #"\b(drug|drugs|alcohol|beer|vodka|whiskey|cocaine|meth|opioid|smoking)\b"#,
            reason: "Please avoid substance-related themes in story concepts for children."
        ),
        (
            pattern: #"\b(hate|racist|slur|abuse|self-harm|suicide)\b"#,
            reason: "Please avoid harmful or abusive themes and try a kinder story concept."
        )
    ]

    private static let illustrationPromptReplacements: [(pattern: String, replacement: String)] = [
        (#"\b(weapon|gun|knife|sword)\b"#, "toy prop"),
        (#"\b(kill|killing|murder|stab|stabbing|fight|battle|war)\b"#, "playful challenge"),
        (#"\b(blood|gore|dismember)\b"#, "colorful confetti"),
        (#"\b(demon|devil|zombie|horror|ghost|haunted)\b"#, "friendly fantasy creature"),
        (#"\b(explosion|explode|fireball|burning|destroy|destruction)\b"#, "festive sparkles"),
        (#"\b(dead|death|dying)\b"#, "sleepy"),
        (#"\b(police chase|chase scene|car crash)\b"#, "adventure walk")
    ]

    static func validateConcept(_ rawConcept: String, maxLength: Int = 220) -> ContentSafetyCheckResult {
        let normalized = normalizeWhitespace(rawConcept)

        guard !normalized.isEmpty else {
            return .blocked(reason: "Please enter a story idea to get started.")
        }

        for blocked in blockedPatterns {
            if normalized.range(
                of: blocked.pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil {
                return .blocked(reason: blocked.reason)
            }
        }

        return .allowed(sanitizedConcept: sanitizeConcept(normalized, maxLength: maxLength))
    }

    static func safeCoverPrompt(title: String, concept: String) -> String {
        let safeTitle = sanitizeConcept(title)
        let safeConcept = sanitizeConcept(concept)
        // Short descriptive phrase — no instructions for the diffusion model.
        return "\(safeTitle) book cover, \(safeConcept), warm whimsical colors, friendly characters"
    }

    static func safeIllustrationPrompt(_ prompt: String, extendedLimit: Bool = false) -> String {
        var sanitized = sanitizeConcept(prompt)

        for rule in illustrationPromptReplacements {
            sanitized = sanitized.replacingOccurrences(
                of: rule.pattern,
                with: rule.replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Keep prompts short and purely descriptive for Image Playground.
        // Extended limit (300) accommodates character description prefix (~120 chars)
        // plus scene description (~180 chars).
        let limit = extendedLimit ? 300 : 180
        if sanitized.count > limit {
            sanitized = String(sanitized.prefix(limit))
        }

        return sanitized
    }

    static func sanitizeConcept(_ text: String, maxLength: Int = 220) -> String {
        let normalized = normalizeWhitespace(text)
        let cleaned = normalized.replacingOccurrences(
            of: #"[<>`\"']"#,
            with: "",
            options: .regularExpression
        )
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength))
        }
        return cleaned
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

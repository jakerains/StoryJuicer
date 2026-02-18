import Foundation

enum ContentSafetyCheckResult: Equatable, Sendable {
    case allowed(sanitizedConcept: String)
    case blocked(reason: String)
}

struct ContentSafetyPolicy: Sendable {
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
        (#"\b(demon|devil|zombie|horror)\b"#, "friendly fantasy creature")
    ]

    static func validateConcept(_ rawConcept: String) -> ContentSafetyCheckResult {
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

        return .allowed(sanitizedConcept: sanitizeConcept(normalized))
    }

    static func safeCoverPrompt(title: String, concept: String) -> String {
        let safeTitle = sanitizeConcept(title)
        let safeConcept = sanitizeConcept(concept)
        return """
            Children's book cover illustration for "\(safeTitle)". \
            Theme: \(safeConcept). \
            Warm, whimsical, colorful, friendly characters, family-friendly tone, no violence, no scary imagery, no text in image.
            """
    }

    static func safeIllustrationPrompt(_ prompt: String) -> String {
        var sanitized = sanitizeConcept(prompt)

        for rule in illustrationPromptReplacements {
            sanitized = sanitized.replacingOccurrences(
                of: rule.pattern,
                with: rule.replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        if sanitized.count > 360 {
            sanitized = String(sanitized.prefix(360))
        }

        return """
            \(sanitized). \
            Children's book illustration style, gentle, cheerful, family-friendly, no text, no violence, no scary imagery.
            """
    }

    static func sanitizeConcept(_ text: String) -> String {
        let normalized = normalizeWhitespace(text)
        let cleaned = normalized.replacingOccurrences(
            of: #"[<>`]"#,
            with: "",
            options: .regularExpression
        )
        if cleaned.count > 220 {
            return String(cleaned.prefix(220))
        }
        return cleaned
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

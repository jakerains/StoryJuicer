import Foundation

/// Single source of truth for all story generation prompts.
/// Every text generator (Foundation Models, MLX, Cloud, Remote) funnels through here.
enum StoryPromptTemplates {

    // MARK: - System Instructions

    /// Default system instructions (kid audience).
    static var systemInstructions: String {
        systemInstructions(for: .kid)
    }

    /// System instructions with "Respond with JSON only." appended.
    /// Use for generators that produce raw JSON text (MLX, Cloud, Remote).
    static var jsonModeSystemInstructions: String {
        systemInstructions + "\nRespond with valid JSON only — no extra text before or after."
    }

    static func systemInstructions(for audience: AudienceMode) -> String {
        switch audience {
        case .kid:
            return """
            You are an award-winning children's storybook writer and art director. \
            You write engaging, age-appropriate stories for children ages 3-8. \
            Your stories have clear beginnings, middles, and endings. \
            Each page has vivid, simple prose that's fun to read aloud. \
            You create detailed scene descriptions that would make beautiful illustrations. \
            Stories should have a positive message or gentle moral. \
            Safety requirements are strict and non-negotiable: \
            never include violence, weapons, gore, horror, sexual content, nudity, \
            substance use, hate, abuse, or self-harm. \
            If the concept hints at unsafe content, reinterpret it into a gentle, child-safe adventure.
            """
        case .adult:
            return """
            You are an award-winning storybook writer and art director. \
            Output family-appropriate content suitable for all ages. You may use richer vocabulary, \
            more complex themes, nuanced character development, and sophisticated narrative structure. \
            Still avoid explicit violence, sexual content, substance use, or hateful content. \
            Content must be suitable for on-device image generation. \
            If the concept hints at unsafe content, reinterpret it into a safe, thoughtful story.
            """
        }
    }

    // MARK: - Shared Requirements

    /// The story-level requirements shared by ALL generators, regardless of output format.
    private static func storyRequirements(pageCount: Int) -> String {
        """
        Requirements:
        - Exactly \(pageCount) pages, numbered 1...\(pageCount).
        - characterDescriptions: One line per character — name, species, colors, clothing, one unique feature.
        - CRITICAL for imagePrompt: Every imagePrompt MUST describe the character by species \
        and appearance — not just name. Image models cannot look up who "Luna" is.
          BAD: "Luna walking through a moonlit forest."
          GOOD: "A small orange fox with a green scarf walks through a moonlit forest, \
        curious expression, warm golden light."
          Always state WHAT the character is (species/type), their COLOR, and what they WEAR.
        - Keep language warm, gentle, and easy to read aloud.
        """
    }

    // MARK: - JSON Mode Prompt (MLX, Cloud, Remote)

    /// Full prompt with JSON schema for generators that produce raw JSON text.
    static func userPrompt(concept: String, pageCount: Int) -> String {
        """
        Create a \(pageCount)-page children's storybook from this concept: "\(concept)".
        Return JSON with this exact shape:
        {
          "title": "string",
          "authorLine": "string",
          "moral": "string",
          "characterDescriptions": "One line per character: name - species, colors, clothing, unique feature.\\nExample: Luna - small white rabbit, pink dress, floppy left ear, blue eyes",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-4 child-friendly sentences",
              "imagePrompt": "Describe character by species and appearance (not just name), then action, setting, mood, colors. Example: A small orange fox wearing a green scarf peers into a glowing tree hollow, warm golden light. No text overlays."
            }
          ]
        }
        \(storyRequirements(pageCount: pageCount))
        """
    }

    // MARK: - Structured Output Prompt (Foundation Models)

    /// Prompt for Foundation Models `@Generable` structured output.
    /// No JSON schema needed — the `@Guide` annotations on StoryBook/StoryPage provide the schema.
    /// This prompt focuses on story-level guidance and requirements.
    static func structuredOutputPrompt(concept: String, pageCount: Int) -> String {
        """
        Story concept: "\(concept)".
        Create a \(pageCount)-page children's storybook based on that concept. \
        Generate exactly \(pageCount) pages. Number them from 1 to \(pageCount). \
        Each page should have 2-4 sentences of story text and a detailed illustration prompt. \
        For characterDescriptions, list each character on one line with their name, \
        species, colors, clothing, and one unique feature. \
        CRITICAL: In each imagePrompt, describe the character's species and visual \
        appearance — not just their name. An image model cannot know that "Luna" is a fox. \
        Write "a small orange fox with a green scarf" instead of just "Luna." \
        Keep the story warm, comforting, and suitable for ages 3-8.
        """
    }
}

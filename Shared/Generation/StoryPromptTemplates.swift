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
        and appearance — not just their name. Image models cannot look up names.
          BAD: A character name alone with no visual description.
          GOOD: The character's species or breed, their color, what they wear, their action, and the setting.
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
          "characterDescriptions": "One line per character: name - species or breed, colors, clothing, unique feature. Use the species from the concept — do not substitute a different animal.",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-4 child-friendly sentences",
              "imagePrompt": "Describe character by species and visual appearance (not just name), then action, setting, mood, colors. No text overlays."
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
        CRITICAL: In each imagePrompt, describe the character by their species and visual \
        appearance — not just their name. An image model cannot look up character names. \
        Always include the character's species or breed, color, and clothing in every imagePrompt. \
        Keep the story warm, comforting, and suitable for ages 3-8.
        """
    }

    // MARK: - Two-Pass Prompts

    /// Pass 1: Generate story text only — no image prompts.
    /// Lets the LLM focus entirely on narrative quality, character development,
    /// and story arc without splitting attention on visual descriptions.
    static func textOnlyPrompt(concept: String, pageCount: Int) -> String {
        """
        Story concept: "\(concept)".
        Create a \(pageCount)-page children's storybook based on that concept. \
        Generate exactly \(pageCount) pages, numbered 1 to \(pageCount). \
        Focus ONLY on the story text — do NOT write image prompts. \
        Each page should have 2-4 sentences of vivid, age-appropriate prose. \
        For characterDescriptions, list each character on one line: \
        name - species or breed, colors, clothing, one distinguishing feature. \
        Use the species from the concept — do not substitute a different animal. \
        Build a complete narrative arc with a clear beginning, middle, and end. \
        Keep the story warm, comforting, and suitable for ages 3-8.
        """
    }

    /// Pass 2: Generate image prompts given the complete story text.
    /// The LLM receives the full narrative + character sheet so it can maintain
    /// visual consistency across all pages and reference the full story arc.
    static func imagePromptPassPrompt(
        characterDescriptions: String,
        pages: [(pageNumber: Int, text: String)]
    ) -> String {
        let pageList = pages.map { "Page \($0.pageNumber): \($0.text)" }.joined(separator: "\n")
        return """
        You are an art director writing illustration prompts for a children's storybook.

        CHARACTER SHEET:
        \(characterDescriptions)

        COMPLETE STORY TEXT:
        \(pageList)

        Write one detailed image prompt for each page. \
        Generate exactly \(pages.count) prompts, one per page.

        CRITICAL RULES:
        - Describe every character by their SPECIES and VISUAL APPEARANCE — never by name alone. \
        Image models cannot look up character names.
        - Always state WHAT the character is (species/type), their COLOR, and what they WEAR.
        - Include setting, action, expressions, mood, and lighting.
        - Maintain visual consistency: same character colors, clothing, and features across all pages.
        - Reference earlier and later scenes to ensure the illustrations tell a cohesive visual story.
        - Do NOT include any text, words, or letters in the scene descriptions.
        """
    }

    // MARK: - Two-Pass JSON Prompts (MLX, Cloud)

    /// Pass 1 (JSON mode): Generate story text + character descriptions without image prompts.
    /// For generators that produce raw JSON text (MLX, Cloud).
    static func textOnlyJSONPrompt(concept: String, pageCount: Int) -> String {
        """
        Create a \(pageCount)-page children's storybook from this concept: "\(concept)".
        Focus ONLY on the story text — do NOT write image prompts.
        Return JSON with this exact shape:
        {
          "title": "string",
          "authorLine": "string",
          "moral": "string",
          "characterDescriptions": "One line per character: name - species or breed, colors, clothing, unique feature. Use the species from the concept — do not substitute a different animal.",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-4 child-friendly sentences"
            }
          ]
        }
        Requirements:
        - Exactly \(pageCount) pages, numbered 1...\(pageCount).
        - characterDescriptions: One line per character — name, species, colors, clothing, one unique feature.
        - Build a complete narrative arc with a clear beginning, middle, and end.
        - Keep language warm, gentle, and easy to read aloud.
        """
    }

    /// Pass 2 (JSON mode): Generate image prompts given the complete story + character sheet.
    /// For generators that produce raw JSON text (MLX, Cloud).
    static func imagePromptJSONPrompt(
        characterDescriptions: String,
        pages: [(pageNumber: Int, text: String)]
    ) -> String {
        let pageList = pages.map { "Page \($0.pageNumber): \($0.text)" }.joined(separator: "\n")
        return """
        You are an art director writing illustration prompts for a children's storybook.

        CHARACTER SHEET:
        \(characterDescriptions)

        COMPLETE STORY TEXT:
        \(pageList)

        Write one detailed image prompt for each page.
        Return JSON with this exact shape:
        {
          "prompts": [
            {
              "pageNumber": 1,
              "imagePrompt": "Detailed visual scene description"
            }
          ]
        }
        Generate exactly \(pages.count) prompts, one per page.

        CRITICAL RULES:
        - Describe every character by their SPECIES and VISUAL APPEARANCE — never by name alone. \
        Image models cannot look up character names.
        - Always state WHAT the character is (species/type), their COLOR, and what they WEAR.
        - Include setting, action, expressions, mood, and lighting.
        - Maintain visual consistency: same character colors, clothing, and features across all pages.
        - Reference earlier and later scenes to ensure the illustrations tell a cohesive visual story.
        - Do NOT include any text, words, or letters in the scene descriptions.
        """
    }
}

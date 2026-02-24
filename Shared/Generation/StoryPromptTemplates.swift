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
        - characterDescriptions: One line per character — name, specific species or breed, colors, clothing, one unique feature. \
        For common animals (dogs, cats, birds), use the exact breed (e.g. "golden retriever" not "dog", "tabby cat" not "cat"). \
        Use the species from the concept — do not substitute a different animal.
        - CRITICAL for imagePrompt: Every single imagePrompt MUST include the character's exact species or breed \
        and their key visual traits (color, clothing). Each image is generated independently — the model \
        cannot see previous pages. If the character is a red squirrel, EVERY prompt must say "red squirrel". \
        Never switch species or breed mid-story.
          BAD: A character name alone, or vague terms like "the little animal" or "the creature".
          GOOD: "A red squirrel wearing a blue scarf" — specific species, color, and clothing on every page.
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
          "authorLine": "Always 'Written by StoryFox' unless user specifies an author",
          "moral": "string",
          "characterDescriptions": "One line per character: name - specific species or breed (e.g. 'golden retriever' not 'dog'), colors, clothing, unique feature. Use the species from the concept — do not substitute a different animal.",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-4 child-friendly sentences",
              "imagePrompt": "MUST include exact species/breed + color + clothing on EVERY page. Each image is generated independently. No text overlays."
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
        specific species or breed (e.g. "golden retriever" not "dog", "red squirrel" not "squirrel"), \
        colors, clothing, and one unique feature. \
        CRITICAL: Every single imagePrompt MUST state the character's exact species or breed \
        and their key visual traits. Each image is generated independently — the model cannot \
        see other pages. Repeat the species/breed and appearance on EVERY page. \
        Never switch species mid-story. Never use vague terms like "the little animal". \
        Keep the story warm, comforting, and suitable for ages 3-8.
        """
    }

    // MARK: - Character Sheet Prompt

    /// Builds a prompt for generating a character reference sheet in the book's art style.
    /// Used in the premium pipeline to create a visual anchor for all page illustrations.
    ///
    /// - Parameters:
    ///   - characterDescription: The main character's description from `characterDescriptions`
    ///     (e.g., "Luna - a small orange fox with bright green eyes and a tattered green scarf").
    ///   - style: The book's selected illustration style, used to match the sheet's art direction.
    /// - Returns: A prompt suitable for image generation (edit or text-to-image).
    static func characterSheetPrompt(
        characterDescription: String,
        style: IllustrationStyle
    ) -> String {
        let styleSuffix: String
        switch style {
        case .illustration:
            styleSuffix = "Warm watercolor textures, children's book illustration style"
        case .animation:
            styleSuffix = "3D animated cartoon style, Pixar-inspired, soft lighting"
        case .sketch:
            styleSuffix = "Pencil sketch style, hand-drawn, delicate linework"
        }

        return """
        Character reference sheet: [\(characterDescription)]. \
        Full body, front-facing pose, simple clean storybook background. \
        [\(styleSuffix)]. \
        No text, words, or letters.
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
        name - specific species or breed (e.g. "golden retriever" not "dog"), colors, clothing, \
        one distinguishing feature. Use the species from the concept — do not substitute a different animal. \
        For common animals like dogs, cats, or birds, always specify the exact breed or variety. \
        Build a complete narrative arc with a clear beginning, middle, and end. \
        Keep the story warm, comforting, and suitable for ages 3-8.
        """
    }

    /// Pass 2: Generate image prompts given the complete story text.
    /// The LLM receives the full narrative + character sheet so it can maintain
    /// visual consistency across all pages and reference the full story arc.
    static func imagePromptPassPrompt(
        characterDescriptions: String,
        pages: [(pageNumber: Int, text: String)],
        style: IllustrationStyle = .illustration
    ) -> String {
        let pageList = pages.map { "Page \($0.pageNumber): \($0.text)" }.joined(separator: "\n")
        return """
        You are an art director writing illustration prompts for a children's storybook.

        ART STYLE: \(styleDirective(for: style))

        CHARACTER SHEET:
        \(characterDescriptions)

        COMPLETE STORY TEXT:
        \(pageList)

        Write one detailed image prompt for each page. \
        Generate exactly \(pages.count) prompts, one per page.

        CRITICAL RULES:
        - EVERY prompt must describe the scene in \(style.displayName.lowercased()) style — \
        include medium-specific textures, lighting, and rendering language.
        - EVERY prompt MUST state the character's exact species or breed and key visual traits. \
        Each image is generated independently — the model cannot see other pages. \
        If the character is a red squirrel, write "red squirrel" in EVERY prompt. Never switch species.
        - For common animals (dogs, cats, birds), always use the specific breed from the character sheet.
        - Never use vague terms like "the little animal", "the creature", or just the character's name.
        - Always state WHAT the character is (species/breed), their COLOR, and what they WEAR.
        - Include setting, action, expressions, mood, and lighting.
        - Maintain visual consistency: same character colors, clothing, and features across all pages.
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
          "authorLine": "Always 'Written by StoryFox' unless user specifies an author",
          "moral": "string",
          "characterDescriptions": "One line per character: name - specific species or breed (e.g. 'golden retriever' not 'dog'), colors, clothing, unique feature. Use the species from the concept — do not substitute a different animal.",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-4 child-friendly sentences"
            }
          ]
        }
        Requirements:
        - Exactly \(pageCount) pages, numbered 1...\(pageCount).
        - characterDescriptions: One line per character — name, specific species or breed, colors, clothing, one unique feature. \
        For common animals (dogs, cats, birds), use the exact breed (e.g. "golden retriever" not "dog").
        - Build a complete narrative arc with a clear beginning, middle, and end.
        - Keep language warm, gentle, and easy to read aloud.
        """
    }

    /// Pass 2 (JSON mode): Generate image prompts given the complete story + character sheet.
    /// For generators that produce raw JSON text (MLX, Cloud).
    static func imagePromptJSONPrompt(
        characterDescriptions: String,
        pages: [(pageNumber: Int, text: String)],
        style: IllustrationStyle = .illustration
    ) -> String {
        let pageList = pages.map { "Page \($0.pageNumber): \($0.text)" }.joined(separator: "\n")
        return """
        You are an art director writing illustration prompts for a children's storybook.

        ART STYLE: \(styleDirective(for: style))

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
        - EVERY prompt must describe the scene in \(style.displayName.lowercased()) style — \
        include medium-specific textures, lighting, and rendering language.
        - EVERY prompt MUST state the character's exact species or breed and key visual traits. \
        Each image is generated independently — the model cannot see other pages. \
        If the character is a red squirrel, write "red squirrel" in EVERY prompt. Never switch species.
        - For common animals (dogs, cats, birds), always use the specific breed from the character sheet.
        - Never use vague terms like "the little animal", "the creature", or just the character's name.
        - Always state WHAT the character is (species/breed), their COLOR, and what they WEAR.
        - Include setting, action, expressions, mood, and lighting.
        - Maintain visual consistency: same character colors, clothing, and features across all pages.
        - Do NOT include any text, words, or letters in the scene descriptions.
        """
    }

    // MARK: - Style Directives

    /// Brief art-direction string for standard-tier prompts.
    private static func styleDirective(for style: IllustrationStyle) -> String {
        switch style {
        case .illustration:
            return "Children's book watercolor illustration — soft brushstrokes, warm muted palette, hand-painted textures, gentle lighting."
        case .animation:
            return "3D animated cartoon (Pixar-inspired) — smooth rounded forms, soft ambient occlusion, warm rim lighting, playful proportions."
        case .sketch:
            return "Pencil sketch illustration — delicate linework, crosshatching for shading, hand-drawn quality, minimal color."
        }
    }

    /// Concise art-direction string for premium-tier prompts.
    /// Kept short so the LLM doesn't echo verbose style text into every prompt.
    private static func premiumStyleDirective(for style: IllustrationStyle) -> String {
        switch style {
        case .illustration:
            return "Children's book watercolor illustration — warm palette, soft brushstrokes, hand-painted quality."
        case .animation:
            return "3D animated cartoon (Pixar-inspired) — soft lighting, rounded forms, warm rim lighting."
        case .sketch:
            return "Pencil sketch illustration — expressive linework, crosshatching, hand-drawn quality."
        }
    }

    // MARK: - Premium Prompt Templates

    /// Enhanced system instructions for premium tiers.
    /// Builds on `systemInstructions` with a literary-craft emphasis.
    static var premiumSystemInstructions: String {
        systemInstructions + """
         You are writing for a premium storybook service. \
        Prioritize literary craft, emotional resonance, and rich sensory detail. \
        Every page should feel like a beautifully written children's book that parents enjoy reading aloud. \
        Use varied sentence rhythm — mix short, punchy sentences with longer, flowing ones. \
        Weave in multi-sensory descriptions (sounds, textures, smells) alongside visual imagery.
        """
    }

    /// JSON variant of premium system instructions.
    static var premiumJSONModeSystemInstructions: String {
        premiumSystemInstructions + "\nRespond with valid JSON only — no extra text before or after."
    }

    /// Pass 1 (Premium): Generate story text with richer narrative instructions.
    /// Same JSON schema as `textOnlyJSONPrompt` but with enhanced storytelling guidance.
    static func premiumTextOnlyJSONPrompt(concept: String, pageCount: Int) -> String {
        """
        Create a \(pageCount)-page children's storybook from this concept: "\(concept)".
        Focus ONLY on the story text — do NOT write image prompts.
        Return JSON with this exact shape:
        {
          "title": "string",
          "authorLine": "Always 'Written by StoryFox' unless user specifies an author",
          "moral": "string",
          "characterDescriptions": "One line per character: name - specific species or breed (e.g. 'golden retriever' not 'dog', 'red squirrel' not 'squirrel'), 2-3 physical traits (color, size, distinguishing marks), personality hint, one signature visual detail (e.g. a chipped ear, a sparkly bow, mismatched socks).",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-3 short sentences — easy for a young child to follow"
            }
          ]
        }
        Requirements:
        - Exactly \(pageCount) pages, numbered 1...\(pageCount).
        - characterDescriptions: One line per character — name, specific species or breed (e.g. "golden retriever" not "dog"), 2-3 physical traits, personality hint, and a signature visual detail. Use the species from the concept — do not substitute a different animal. For common animals, always use the exact breed.
        - IMPORTANT: Each page must have only 2-3 SHORT sentences. This is a children's book for ages 3-8 — keep text brief and easy to read aloud in under 15 seconds.
        - Build a complete narrative arc: a compelling hook, rising tension, a meaningful climax, and a satisfying resolution.
        - Create an emotional arc — let characters feel wonder, doubt, courage, and joy.
        - Show emotion through action: trembling paws, wide eyes, a tentative step — not exposition.
        - Include at least one moment of gentle humor or surprise.
        - Keep language warm, gentle, and musical — favor short punchy sentences over long flowing ones.
        """
    }

    /// Pass 1 (Premium Plus with photos): Generate story text featuring named characters.
    /// Inherits premium narrative enrichments and adds character-name integration.
    static func premiumPlusTextOnlyJSONPrompt(concept: String, pageCount: Int, characterNames: [String]) -> String {
        let namesList = characterNames.joined(separator: ", ")
        return """
        Create a \(pageCount)-page children's storybook from this concept: "\(concept)".
        The story features these characters as the protagonists: \(namesList).
        Write vivid physical descriptions so illustrations match their real-world likeness.
        Focus ONLY on the story text — do NOT write image prompts.
        Return JSON with this exact shape:
        {
          "title": "string",
          "authorLine": "Always 'Written by StoryFox' unless user specifies an author",
          "moral": "string",
          "characterDescriptions": "One line per character: name - detailed visual description including hair/fur color, eye color, build, clothing, and one signature visual detail.",
          "pages": [
            {
              "pageNumber": 1,
              "text": "2-3 short sentences featuring the named characters"
            }
          ]
        }
        Requirements:
        - Exactly \(pageCount) pages, numbered 1...\(pageCount).
        - characterDescriptions: One line per character — name, detailed visual description (hair/fur color, eye color, build, clothing), personality hint, and a signature visual detail.
        - IMPORTANT: Every page must describe each character's physical appearance naturally within the prose, so illustrations accurately depict them.
        - IMPORTANT: Each page must have only 2-3 SHORT sentences. This is a children's book for ages 3-8 — keep text brief and easy to read aloud in under 15 seconds.
        - Build a complete narrative arc: a compelling hook, rising tension, a meaningful climax, and a satisfying resolution.
        - Create an emotional arc — let characters feel wonder, doubt, courage, and joy.
        - Show emotion through action: trembling paws, wide eyes, a tentative step — not exposition.
        - Include at least one moment of gentle humor or surprise.
        - Keep language warm, gentle, and musical — favor short punchy sentences over long flowing ones.
        """
    }

    /// Pass 2 (Premium): Generate image prompts for a premium children's storybook.
    /// Focused on who/what/where/expression/mood — no cinematic jargon that inflates prompt length.
    static func premiumImagePromptJSONPrompt(
        characterDescriptions: String,
        pages: [(pageNumber: Int, text: String)],
        style: IllustrationStyle = .illustration
    ) -> String {
        let pageList = pages.map { "Page \($0.pageNumber): \($0.text)" }.joined(separator: "\n")
        return """
        You are an art director writing illustration prompts for a premium children's storybook.

        ART STYLE: \(premiumStyleDirective(for: style))

        CHARACTER SHEET:
        \(characterDescriptions)

        COMPLETE STORY TEXT:
        \(pageList)

        Write one image prompt for each page.
        Return JSON with this exact shape:
        {
          "prompts": [
            {
              "pageNumber": 1,
              "imagePrompt": "Visual scene description"
            }
          ]
        }
        Generate exactly \(pages.count) prompts, one per page.

        CRITICAL RULES:
        - EVERY prompt must describe the scene in \(style.displayName.lowercased()) style.
        - EVERY prompt MUST state the character's exact species or breed and key visual traits. \
        Each image is generated independently — the model cannot see other pages. \
        If the character is a golden retriever, write "golden retriever" in EVERY prompt. Never switch species.
        - For common animals, always use the specific breed from the character sheet (not just "dog" or "cat").
        - Never use vague terms like "the little animal", "the creature", or just the character's name.
        - Always state WHAT the character is (species/breed), their COLOR, and what they WEAR.
        - Include setting, action, character expression, and mood.
        - Keep each prompt under 200 characters — be specific and concise.
        - Maintain visual consistency: same character colors, clothing, and features across all pages.
        - Describe body language to convey emotion (sparkling eyes, arms thrown wide, a tentative step).
        - Do NOT include any text, words, or letters in the scene descriptions.
        """
    }
}

import Foundation

/// Opt-in verbose logging system that writes one human-readable Markdown file per generation
/// session, capturing every prompt, response, and configuration detail.
///
/// Toggled via UserDefaults (`verboseLoggingEnabled`) and writes to a user-chosen folder
/// (`verboseLoggingFolderPath`). When disabled, all methods are no-ops.
actor VerboseGenerationLogger {
    static let shared = VerboseGenerationLogger()

    // MARK: - Configuration (read from UserDefaults)

    nonisolated var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "verboseLoggingEnabled")
    }

    nonisolated var logFolderPath: String? {
        let path = UserDefaults.standard.string(forKey: "verboseLoggingFolderPath") ?? ""
        return path.isEmpty ? nil : path
    }

    // MARK: - Active Session

    /// The session ID set by CreationViewModel before generation starts.
    /// Downstream generators read this to tag their log entries.
    private(set) var activeSessionID: String?

    func setActiveSession(_ id: String?) {
        activeSessionID = id
    }

    // MARK: - File Handles

    /// Maps session IDs to their log file URLs for efficient appending.
    private var sessionFiles: [String: URL] = [:]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Session Lifecycle

    /// Starts a new verbose logging session. Returns the session ID if logging is enabled,
    /// or `nil` if disabled. Writes the Markdown header to the log file.
    func startSession(
        concept: String,
        pageCount: Int,
        format: String,
        style: String,
        textProvider: String,
        imageProvider: String,
        textModel: String,
        imageModel: String,
        premiumTier: String
    ) -> String? {
        guard isEnabled, let folder = logFolderPath else { return nil }

        let sessionID = String(UUID().uuidString.prefix(8).lowercased())
        let fileName = "StoryFox-\(dateFormatter.string(from: Date())).md"
        let fileURL = URL(fileURLWithPath: folder).appendingPathComponent(fileName)

        // Ensure the folder exists
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: folder),
            withIntermediateDirectories: true
        )

        let header = """
        # StoryFox Generation Log

        **Session:** `\(sessionID)`
        **Date:** \(timestampFormatter.string(from: Date()))
        **Concept:** "\(concept)"

        | Setting | Value |
        |---------|-------|
        | Pages | \(pageCount) |
        | Format | \(format) |
        | Style | \(style) |
        | Premium Tier | \(premiumTier) |
        | Text Provider | \(textProvider) |
        | Image Provider | \(imageProvider) |
        | Text Model | \(textModel) |
        | Image Model | \(imageModel) |

        ---

        """

        sessionFiles[sessionID] = fileURL
        writeToFile(fileURL, content: header)
        return sessionID
    }

    /// Ends a verbose logging session and writes the summary footer.
    func endSession(
        _ sessionID: String,
        totalDuration: Double,
        imageStats: (total: Int, succeeded: Int)
    ) {
        guard let fileURL = sessionFiles[sessionID] else { return }

        let summary = """

        ---

        ## Summary

        | Metric | Value |
        |--------|-------|
        | Total Duration | \(String(format: "%.1f", totalDuration))s |
        | Images | \(imageStats.succeeded)/\(imageStats.total) succeeded |

        """

        appendToFile(fileURL, content: summary)
        sessionFiles.removeValue(forKey: sessionID)
    }

    // MARK: - Text Generation Logging

    /// Logs a text generation pass (Pass 1 or Pass 2).
    func logTextPass(
        sessionID: String,
        passLabel: String,
        provider: String,
        model: String,
        systemPrompt: String,
        userPrompt: String,
        rawResponse: String,
        parseSuccess: Bool,
        duration: Double
    ) {
        guard let fileURL = sessionFiles[sessionID] else { return }

        let section = """

        ## \(passLabel)

        **Provider:** \(provider) · **Model:** \(model) · **Duration:** \(String(format: "%.1f", duration))s

        ### System Prompt
        ```
        \(systemPrompt)
        ```

        ### User Prompt
        ```
        \(userPrompt)
        ```

        ### Response (\(rawResponse.count) chars)
        ```
        \(rawResponse)
        ```

        **Parse:** \(parseSuccess ? "Success" : "Failed")

        ---

        """

        appendToFile(fileURL, content: section)
    }

    // MARK: - Merged StoryBook Logging

    /// Logs the final merged storybook with title, characters, and page table.
    func logMergedStoryBook(
        sessionID: String,
        title: String,
        characterDescriptions: String,
        pages: [(pageNumber: Int, text: String, imagePrompt: String)]
    ) {
        guard let fileURL = sessionFiles[sessionID] else { return }

        var section = """

        ## Merged StoryBook

        **Title:** \(title)
        **Characters:**
        ```
        \(characterDescriptions)
        ```

        | Page | Text | Image Prompt |
        |------|------|-------------|

        """

        for page in pages {
            let textPreview = String(page.text.prefix(40)).replacingOccurrences(of: "\n", with: " ")
            let promptPreview = String(page.imagePrompt.prefix(40)).replacingOccurrences(of: "\n", with: " ")
            section += "| \(page.pageNumber) | \(textPreview)... | \(promptPreview)... |\n"
        }

        section += "\n---\n\n"
        appendToFile(fileURL, content: section)
    }

    // MARK: - Image Generation Logging

    /// Logs a single image generation attempt (success or failure).
    func logImageGeneration(
        sessionID: String,
        label: String,
        provider: String,
        model: String,
        originalPrompt: String,
        styledPrompt: String,
        result: ImageLogResult,
        duration: Double
    ) {
        guard let fileURL = sessionFiles[sessionID] else { return }

        let resultText: String
        switch result {
        case .success(let width, let height):
            resultText = "\(String(format: "%.1f", duration))s \u{00B7} Success (\(width)x\(height))"
        case .failure(let error):
            resultText = "\(String(format: "%.1f", duration))s \u{00B7} Failed: \(error)"
        }

        let section = """

        ### \(label) \u{2014} \(resultText)
        **Provider:** \(provider) · **Model:** \(model)
        **Original:** \(originalPrompt)
        **Styled:** \(styledPrompt)

        """

        appendToFile(fileURL, content: section)
    }

    // MARK: - Character Sheet Logging

    /// Logs a character sheet generation attempt.
    func logCharacterSheet(
        sessionID: String,
        prompt: String,
        hasReferencePhoto: Bool,
        result: ImageLogResult,
        duration: Double
    ) {
        guard let fileURL = sessionFiles[sessionID] else { return }

        let resultText: String
        switch result {
        case .success(let width, let height):
            resultText = "Success (\(width)x\(height))"
        case .failure(let error):
            resultText = "Failed: \(error)"
        }

        let section = """

        ## Character Sheet \u{2014} \(String(format: "%.1f", duration))s · \(resultText)

        **Has Reference Photo:** \(hasReferencePhoto ? "Yes" : "No")
        **Prompt:**
        ```
        \(prompt)
        ```

        ---

        """

        appendToFile(fileURL, content: section)
    }

    // MARK: - Arbitrary Section

    /// Logs an arbitrary section with a heading and content block.
    /// Useful for enrichment steps, safety checks, etc.
    func logSection(sessionID: String, heading: String, content: String) {
        guard let fileURL = sessionFiles[sessionID] else { return }

        let section = """

        ## \(heading)

        \(content)

        ---

        """

        appendToFile(fileURL, content: section)
    }

    // MARK: - File I/O

    private func writeToFile(_ url: URL, content: String) {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("VerboseGenerationLogger write failed: \(error.localizedDescription)")
        }
    }

    private func appendToFile(_ url: URL, content: String) {
        do {
            guard let data = content.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            print("VerboseGenerationLogger append failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

enum ImageLogResult: Sendable {
    case success(width: Int, height: Int)
    case failure(String)
}

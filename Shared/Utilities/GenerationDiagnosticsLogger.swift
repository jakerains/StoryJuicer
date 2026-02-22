import Foundation

struct ImageGenerationDiagnosticEntry: Codable, Sendable {
    let timestamp: String
    let event: String
    let provider: String
    let promptPreview: String
    let promptLength: Int
    let variantLabel: String?
    let variantIndex: Int?
    let attemptIndex: Int?
    let retryable: Bool?
    let errorType: String?
    let errorDescription: String?
    let durationSeconds: Double?
    // Multi-concept diagnostics
    let conceptCount: Int?
    let conceptLabels: [String]?
    let usedMultiConcept: Bool?
}

actor GenerationDiagnosticsLogger {
    static let shared = GenerationDiagnosticsLogger()
    private static let logFileName = "image-generation.jsonl"
    private static let maxLogFileSizeBytes = 2_000_000

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let timestampFormatter = ISO8601DateFormatter()

    func logImageAttemptFailure(
        provider: StoryImageProvider,
        prompt: String,
        variantLabel: String?,
        variantIndex: Int?,
        attemptIndex: Int?,
        retryable: Bool?,
        errorType: String,
        errorDescription: String,
        durationSeconds: Double? = nil,
        conceptCount: Int? = nil,
        conceptLabels: [String]? = nil,
        usedMultiConcept: Bool? = nil
    ) async {
        let entry = ImageGenerationDiagnosticEntry(
            timestamp: timestampFormatter.string(from: Date()),
            event: "image_attempt_failed",
            provider: provider.rawValue,
            promptPreview: normalizedPromptPreview(prompt),
            promptLength: prompt.count,
            variantLabel: variantLabel,
            variantIndex: variantIndex,
            attemptIndex: attemptIndex,
            retryable: retryable,
            errorType: errorType,
            errorDescription: errorDescription,
            durationSeconds: durationSeconds,
            conceptCount: conceptCount,
            conceptLabels: conceptLabels,
            usedMultiConcept: usedMultiConcept
        )
        await append(entry)
    }

    func logImageFailureFinal(
        provider: StoryImageProvider,
        prompt: String,
        errorType: String,
        errorDescription: String,
        durationSeconds: Double? = nil,
        conceptCount: Int? = nil,
        conceptLabels: [String]? = nil,
        usedMultiConcept: Bool? = nil
    ) async {
        let entry = ImageGenerationDiagnosticEntry(
            timestamp: timestampFormatter.string(from: Date()),
            event: "image_generation_failed_final",
            provider: provider.rawValue,
            promptPreview: normalizedPromptPreview(prompt),
            promptLength: prompt.count,
            variantLabel: nil,
            variantIndex: nil,
            attemptIndex: nil,
            retryable: nil,
            errorType: errorType,
            errorDescription: errorDescription,
            durationSeconds: durationSeconds,
            conceptCount: conceptCount,
            conceptLabels: conceptLabels,
            usedMultiConcept: usedMultiConcept
        )
        await append(entry)
    }

    func logImageSuccess(
        provider: StoryImageProvider,
        prompt: String,
        variantLabel: String?,
        variantIndex: Int?,
        attemptIndex: Int?,
        durationSeconds: Double? = nil,
        conceptCount: Int? = nil,
        conceptLabels: [String]? = nil,
        usedMultiConcept: Bool? = nil
    ) async {
        let entry = ImageGenerationDiagnosticEntry(
            timestamp: timestampFormatter.string(from: Date()),
            event: "image_attempt_succeeded",
            provider: provider.rawValue,
            promptPreview: normalizedPromptPreview(prompt),
            promptLength: prompt.count,
            variantLabel: variantLabel,
            variantIndex: variantIndex,
            attemptIndex: attemptIndex,
            retryable: nil,
            errorType: nil,
            errorDescription: nil,
            durationSeconds: durationSeconds,
            conceptCount: conceptCount,
            conceptLabels: conceptLabels,
            usedMultiConcept: usedMultiConcept
        )
        await append(entry)
    }

    func logSessionSummary(
        totalPages: Int,
        successCount: Int,
        failureCount: Int,
        variantSuccessRates: [String: Int],
        totalDurationSeconds: Double
    ) async {
        let summary: [String: Any] = [
            "totalPages": totalPages,
            "successCount": successCount,
            "failureCount": failureCount,
            "variantSuccessRates": variantSuccessRates,
            "totalDurationSeconds": round(totalDurationSeconds * 100) / 100,
        ]
        let summaryJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: summary, options: .sortedKeys),
           let str = String(data: data, encoding: .utf8)
        {
            summaryJSON = str
        } else {
            summaryJSON = "{}"
        }
        let entry = ImageGenerationDiagnosticEntry(
            timestamp: timestampFormatter.string(from: Date()),
            event: "session_summary",
            provider: "all",
            promptPreview: summaryJSON,
            promptLength: 0,
            variantLabel: nil,
            variantIndex: nil,
            attemptIndex: nil,
            retryable: nil,
            errorType: nil,
            errorDescription: nil,
            durationSeconds: totalDurationSeconds,
            conceptCount: nil,
            conceptLabels: nil,
            usedMultiConcept: nil
        )
        await append(entry)
    }

    static func logFilePathString() -> String {
        let path = ("~/Library/Application Support/StoryFox/Logs/" + logFileName) as NSString
        return path.expandingTildeInPath
    }

    private func append(_ entry: ImageGenerationDiagnosticEntry) async {
        do {
            let logFileURL = try logsDirectoryURL().appendingPathComponent(Self.logFileName, isDirectory: false)
            try rotateIfNeeded(logFileURL)

            var data = try encoder.encode(entry)
            data.append(0x0A)

            if fileManager.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: logFileURL, options: .atomic)
            }
        } catch {
            // Diagnostics should never interrupt generation flow.
            print("GenerationDiagnosticsLogger append failed: \(error.localizedDescription)")
        }
    }

    private func logsDirectoryURL() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "GenerationDiagnosticsLogger", code: 1)
        }
        let logsDirectory = appSupport
            .appendingPathComponent("StoryFox", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        return logsDirectory
    }

    private func rotateIfNeeded(_ logFileURL: URL) throws {
        guard fileManager.fileExists(atPath: logFileURL.path) else {
            return
        }
        let attributes = try fileManager.attributesOfItem(atPath: logFileURL.path)
        guard let size = attributes[.size] as? Int64,
              size >= Self.maxLogFileSizeBytes else {
            return
        }

        let rotatedURL = logFileURL.deletingPathExtension().appendingPathExtension("previous.jsonl")
        if fileManager.fileExists(atPath: rotatedURL.path) {
            try fileManager.removeItem(at: rotatedURL)
        }
        try fileManager.moveItem(at: logFileURL, to: rotatedURL)
    }

    private func normalizedPromptPreview(_ prompt: String) -> String {
        let compact = prompt
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 500 {
            return compact
        }
        return String(compact.prefix(500))
    }
}

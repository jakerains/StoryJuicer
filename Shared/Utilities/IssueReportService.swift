import Foundation
import CoreGraphics

/// Builds and uploads issue reports for storybooks with missing illustrations.
enum IssueReportService {

    // MARK: - Public API

    struct ReportMetadata: Encodable {
        let bookTitle: String
        let pageCount: Int
        let missingIndices: [Int]
        let format: String
        let style: String
        let textProvider: String
        let imageProvider: String
        let userNotes: String?
        let appVersion: String
        let osVersion: String
        let deviceModel: String
    }

    /// Builds a zip archive containing the story JSON, images, and diagnostics log.
    /// Returns the URL to the temporary zip file. Caller is responsible for cleanup.
    static func buildReportZip(
        storyBook: StoryBook,
        images: [Int: CGImage],
        missingIndices: [Int],
        format: BookFormat,
        style: IllustrationStyle
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoryFoxReport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 1. story.json — serializable snapshot of the book
        let storyPayload = StoryReportPayload(
            title: storyBook.title,
            authorLine: storyBook.authorLine,
            moral: storyBook.moral,
            characterDescriptions: storyBook.characterDescriptions,
            pages: storyBook.pages.map { page in
                StoryReportPayload.Page(
                    pageNumber: page.pageNumber,
                    text: page.text,
                    imagePrompt: page.imagePrompt
                )
            },
            missingIndices: missingIndices,
            format: format.rawValue,
            style: style.rawValue,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        let storyData = try JSONEncoder.prettyReport.encode(storyPayload)
        try storyData.write(to: tempDir.appendingPathComponent("story.json"))

        // 2. images/ — successful images as compressed JPEG
        let imagesDir = tempDir.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        for (index, cgImage) in images {
            let downscaled = downscaleIfNeeded(cgImage, maxEdge: 1024)
            guard let jpegData = cgImageToJPEGData(downscaled, quality: 0.6) else { continue }
            let filename = index == 0 ? "cover.jpg" : "page-\(index).jpg"
            try jpegData.write(to: imagesDir.appendingPathComponent(filename))
        }

        // 3. diagnostics.jsonl — copy if it exists
        let diagPath = GenerationDiagnosticsLogger.logFilePathString()
        let diagURL = URL(fileURLWithPath: diagPath)
        if FileManager.default.fileExists(atPath: diagPath) {
            try? FileManager.default.copyItem(
                at: diagURL,
                to: tempDir.appendingPathComponent("diagnostics.jsonl")
            )
        }

        // 4. Zip via NSFileCoordinator
        let zipURL = try zipDirectory(tempDir)

        // Clean up the unzipped temp directory
        try? FileManager.default.removeItem(at: tempDir)

        return zipURL
    }

    /// Uploads the zip + metadata to the reports API endpoint.
    static func submitReport(zipURL: URL, metadata: ReportMetadata) async throws {
        let endpoint = URL(string: "https://storyfox.app/api/reports")!
        let boundary = "StoryFoxReport-\(UUID().uuidString)"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let metadataJSON = try JSONEncoder().encode(metadata)
        let zipData = try Data(contentsOf: zipURL)

        var body = Data()

        // Part 1: metadata JSON
        body.appendMultipart(boundary: boundary, name: "metadata", filename: "metadata.json",
                             contentType: "application/json", data: metadataJSON)

        // Part 2: zip binary
        body.appendMultipart(boundary: boundary, name: "report", filename: "report.zip",
                             contentType: "application/zip", data: zipData)

        // Closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        // Clean up temp zip
        try? FileManager.default.removeItem(at: zipURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: responseData))?.error
                ?? "Server returned \(httpResponse.statusCode)"
            throw ReportError.serverError(message)
        }
    }

    /// Returns (osVersion, deviceModel, appVersion) from the running system.
    static func systemInfo() -> (osVersion: String, deviceModel: String, appVersion: String) {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let deviceModel = String(cString: model)

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        return (osVersion, deviceModel, appVersion)
    }

    // MARK: - Errors

    enum ReportError: LocalizedError {
        case zipFailed
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .zipFailed: return "Failed to create report archive."
            case .invalidResponse: return "Invalid response from server."
            case .serverError(let msg): return msg
            }
        }
    }

    // MARK: - Private Helpers

    /// Zips a directory using NSFileCoordinator's `.forUploading` option.
    private static func zipDirectory(_ directoryURL: URL) throws -> URL {
        var error: NSError?
        var resultURL: URL?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: directoryURL,
            options: .forUploading,
            error: &error
        ) { zipURL in
            // The system-provided zip is in a temp location that may be cleaned up,
            // so copy it to our own temp path.
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("StoryFoxReport-\(UUID().uuidString).zip")
            try? FileManager.default.copyItem(at: zipURL, to: destination)
            resultURL = destination
        }

        if let error { throw error }
        guard let url = resultURL else { throw ReportError.zipFailed }
        return url
    }

    /// Downscales a CGImage if its longest edge exceeds `maxEdge`.
    private static func downscaleIfNeeded(_ image: CGImage, maxEdge: Int) -> CGImage {
        let w = image.width
        let h = image.height
        let longest = max(w, h)
        guard longest > maxEdge else { return image }

        let scale = CGFloat(maxEdge) / CGFloat(longest)
        let newW = Int(CGFloat(w) * scale)
        let newH = Int(CGFloat(h) * scale)

        guard let context = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return context.makeImage() ?? image
    }
}

// MARK: - Serializable Story Snapshot

private struct StoryReportPayload: Encodable {
    let title: String
    let authorLine: String
    let moral: String
    let characterDescriptions: String
    let pages: [Page]
    let missingIndices: [Int]
    let format: String
    let style: String
    let timestamp: String

    struct Page: Encodable {
        let pageNumber: Int
        let text: String
        let imagePrompt: String
    }
}

private struct ErrorBody: Decodable {
    let error: String
}

// MARK: - Extensions

private extension JSONEncoder {
    static let prettyReport: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

private extension Data {
    mutating func appendMultipart(
        boundary: String,
        name: String,
        filename: String,
        contentType: String,
        data: Data
    ) {
        let header = "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
            + "Content-Type: \(contentType)\r\n\r\n"
        append(header.data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}

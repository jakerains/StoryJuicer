import CoreGraphics
import Foundation
import ImageIO
import os

/// Dedicated client for OpenAI's `/v1/images/edits` multipart endpoint.
/// Used when generating illustrations with character reference photos.
struct OpenAIImageEditClient: Sendable {
    private static let logger = Logger(subsystem: "com.storyfox.app", category: "OpenAIImageEdit")
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Generate an image using reference photos via the OpenAI image edit endpoint.
    ///
    /// - Parameters:
    ///   - prompt: The illustration prompt.
    ///   - referenceImages: JPEG/PNG data for each reference photo (up to 16).
    ///   - apiKey: OpenAI API key (ignored when using proxy).
    ///   - url: The endpoint URL. Defaults to OpenAI direct; pass proxy URL when using premium proxy.
    ///   - model: The image model ID (e.g. `gpt-image-1.5`).
    ///   - size: Image size string (e.g. `1024x1024`).
    ///   - quality: Image quality (`low`, `medium`, `high`, `auto`).
    ///   - inputFidelity: How closely to preserve reference details (`low` or `high`).
    /// - Returns: The generated `CGImage`.
    func generateWithReferences(
        prompt: String,
        referenceImages: [Data],
        apiKey: String,
        url: URL = URL(string: "https://api.openai.com/v1/images/edits")!,
        model: String = "gpt-image-1.5",
        size: String = "1024x1024",
        quality: String = "high",
        inputFidelity: String = "high"
    ) async throws -> CGImage {
        let boundary = "StoryFox-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = TimeInterval(GenerationConfig.cloudImageGenerationTimeoutSeconds)

        var body = Data()

        // model
        appendFormField(&body, boundary: boundary, name: "model", value: model)
        // prompt
        appendFormField(&body, boundary: boundary, name: "prompt", value: prompt)
        // size
        appendFormField(&body, boundary: boundary, name: "size", value: size)
        // quality
        appendFormField(&body, boundary: boundary, name: "quality", value: quality)
        // input_fidelity
        appendFormField(&body, boundary: boundary, name: "input_fidelity", value: inputFidelity)
        // output_format
        appendFormField(&body, boundary: boundary, name: "output_format", value: "jpeg")
        // n
        appendFormField(&body, boundary: boundary, name: "n", value: "1")

        // image[] — reference photos
        for (index, imageData) in referenceImages.enumerated() {
            appendFileField(
                &body,
                boundary: boundary,
                name: "image[]",
                filename: "reference_\(index).png",
                mimeType: "image/png",
                data: imageData
            )
        }

        // Close the multipart body
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        Self.logger.info("OpenAI image edit: model=\(model, privacy: .public) refs=\(referenceImages.count) size=\(size, privacy: .public)")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudProviderError.unparsableResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                throw CloudProviderError.rateLimited(retryAfterSeconds: retryAfter)
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudProviderError.httpError(
                statusCode: httpResponse.statusCode,
                message: String(message.prefix(500))
            )
        }

        // Parse response: { "data": [{ "b64_json": "..." }] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let b64String = first["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64String) else {
            throw CloudProviderError.unparsableResponse
        }

        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CloudProviderError.imageDecodingFailed
        }

        Self.logger.info("OpenAI image edit complete: \(cgImage.width)x\(cgImage.height)")
        return cgImage
    }

    // MARK: - Multipart Helpers

    private func appendFormField(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func appendFileField(_ body: inout Data, boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
    }
}

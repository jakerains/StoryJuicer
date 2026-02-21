import CoreGraphics
import Foundation
import ImageIO

#if os(macOS)

struct DiffusersImageGenerator: StoryImageGenerating {
    let provider: StoryImageProvider = .diffusers
    private let runtimeManager: DiffusersRuntimeManager

    init(runtimeManager: DiffusersRuntimeManager = .shared) {
        self.runtimeManager = runtimeManager
    }

    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings,
        referenceImage: CGImage? = nil,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> CGImage {
        let runtimeAlias = settings.resolvedDiffusersRuntimeAlias
        let modelID = settings.diffusersModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ModelSelectionSettings.defaultDiffusersModelID
            : settings.diffusersModelID
        let hfToken = HFTokenStore.loadToken(alias: settings.resolvedHFTokenAlias)

        onStatus("Preparing local Diffusers runtime...")
        try await runtimeManager.ensureRuntimeInstalled(alias: runtimeAlias, onStatus: onStatus)

        let layout = try await runtimeManager.runtimeLayout(alias: runtimeAlias)
        let outputURL = try buildOutputURL(cacheRoot: layout.cacheURL)
        let size = imageSize(for: format)
        let styledPrompt = styledPrompt(prompt: prompt, style: style)

        let request = DiffusersGenerateRequest(
            modelID: modelID,
            prompt: styledPrompt,
            width: size.width,
            height: size.height,
            steps: 4,
            guidanceScale: 1.0,
            seed: UInt64.random(in: 1...UInt64.max),
            outputPath: outputURL.path
        )

        let generatedURL = try await runtimeManager.generateImage(
            alias: runtimeAlias,
            request: request,
            hfToken: hfToken
        ) { event in
            if let message = event.message, !message.isEmpty {
                onStatus(message)
            }
        }

        return try loadImage(from: generatedURL)
    }

    private func buildOutputURL(cacheRoot: URL) throws -> URL {
        let outputDirectory = cacheRoot
            .appendingPathComponent("outputs", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        return outputDirectory.appendingPathComponent("\(UUID().uuidString).png")
    }

    private func loadImage(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw DiffusersRuntimeError.imageOutputMissing(url.path)
        }
        return image
    }

    private func imageSize(for format: BookFormat) -> (width: Int, height: Int) {
        switch format {
        case .standard:
            return (1024, 1024)
        case .small:
            return (768, 768)
        case .landscape:
            return (1216, 832)
        case .portrait:
            return (832, 1216)
        }
    }

    private func styledPrompt(prompt: String, style: IllustrationStyle) -> String {
        let noText = " Absolutely no text, words, letters, or numbers in the image."
        switch style {
        case .illustration:
            return "\(prompt) Storybook illustration style, painterly details, soft shading." + noText
        case .animation:
            return "\(prompt) Family-friendly animated style, rounded shapes, cinematic lighting." + noText
        case .sketch:
            return "\(prompt) Hand-drawn sketch style, textured pencil lines, gentle watercolor fill." + noText
        }
    }
}

#endif // os(macOS)


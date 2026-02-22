import CoreGraphics
import Foundation
import ImagePlayground

enum ImagePlaygroundGenerationError: LocalizedError {
    case timedOut(seconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .timedOut(let seconds):
            return "Image Playground timed out after \(Int(seconds)) seconds."
        }
    }
}

struct ImagePlaygroundImageGenerator: StoryImageGenerating {
    let provider: StoryImageProvider = .imagePlayground

    /// Cached creator shared across calls to avoid repeated async init overhead.
    private static let creatorCache = ImageCreatorCache()

    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings,
        referenceImage: CGImage? = nil,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> CGImage {
        try await generateImage(
            prompt: prompt,
            style: style,
            format: format,
            settings: settings,
            referenceImage: referenceImage,
            rankedConcepts: nil,
            onStatus: onStatus
        )
    }

    /// Multi-concept generation entry point. When `rankedConcepts` is provided,
    /// each concept becomes a separate `.text()` input to ImagePlayground, forcing
    /// the diffusion model to address each detail individually.
    func generateImage(
        prompt: String,
        style: IllustrationStyle,
        format: BookFormat,
        settings: ModelSelectionSettings,
        referenceImage: CGImage? = nil,
        rankedConcepts: [RankedImageConcept]?,
        onStatus: @Sendable @escaping (String) -> Void
    ) async throws -> CGImage {
        let isAvailable = await MainActor.run {
            ImagePlaygroundViewController.isAvailable
        }
        guard isAvailable else {
            throw IllustrationError.creatorUnavailable
        }

        // Get or create the ImageCreator outside the timeout so init
        // failures give a clear error rather than a misleading timeout.
        let creator = try await Self.creatorCache.getOrCreate()

        onStatus("Generating with Image Playground...")

        return try await withTimeout(
            seconds: GenerationConfig.imagePlaygroundGenerationTimeoutSeconds
        ) {
            let concepts: [ImagePlaygroundConcept]
            if let ranked = rankedConcepts, !ranked.isEmpty {
                concepts = self.conceptsFromRanked(ranked, referenceImage: referenceImage)
            } else {
                concepts = self.imageConcepts(for: prompt, referenceImage: referenceImage)
            }

            let images = creator.images(
                for: concepts,
                style: style.playgroundStyle,
                limit: 1
            )

            for try await image in images {
                return image.cgImage
            }

            throw IllustrationError.noImageGenerated
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ImagePlaygroundGenerationError.timedOut(seconds: seconds)
            }

            guard let result = try await group.next() else {
                throw IllustrationError.noImageGenerated
            }
            group.cancelAll()
            return result
        }
    }

    /// Convert priority-ranked concept structs into ImagePlayground concepts.
    /// Each ranked concept becomes a separate `.text()` input with its label prefix,
    /// proven to improve adherence to specific details like breed/species.
    private func conceptsFromRanked(
        _ ranked: [RankedImageConcept],
        referenceImage: CGImage? = nil
    ) -> [ImagePlaygroundConcept] {
        var concepts: [ImagePlaygroundConcept] = []

        for rc in ranked {
            let text = "\(rc.label): \(rc.value)"
            concepts.append(.text(text))
        }

        if let ref = referenceImage {
            concepts.append(.image(ref))
        }

        return concepts
    }

    private func imageConcepts(for prompt: String, referenceImage: CGImage? = nil) -> [ImagePlaygroundConcept] {
        var concepts: [ImagePlaygroundConcept] = []

        if prompt.count > 900 {
            concepts.append(
                .extracted(
                    from: prompt,
                    title: "Child-friendly picture-book scene"
                )
            )
        } else {
            concepts.append(.text(prompt))
        }

        if let ref = referenceImage {
            concepts.append(.image(ref))
        }

        return concepts
    }
}

/// Actor-isolated cache for `ImageCreator` to avoid repeated async initialization.
actor ImageCreatorCache {
    private var cached: ImageCreator?

    func getOrCreate() async throws -> ImageCreator {
        if let cached {
            return cached
        }
        let creator = try await ImageCreator()
        cached = creator
        return creator
    }
}

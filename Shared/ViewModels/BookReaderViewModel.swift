import Foundation
import CoreGraphics

@Observable
@MainActor
final class BookReaderViewModel {
    let storyBook: StoryBook
    var images: [Int: CGImage]
    let format: BookFormat
    let illustrationStyle: IllustrationStyle
    private let illustrationGenerator: IllustrationGenerator

    /// Called after a single image is regenerated, passing (imageIndex, newImage).
    var onImageRegenerated: ((Int, CGImage) -> Void)?

    private(set) var currentPage: Int = 0
    var regeneratingPages: Set<Int> = []
    var regenerationErrors: [Int: String] = [:]
    var lastRegenerationError: String?

    /// The UUID of the corresponding StoredStorybook, if persisted.
    var storedBookID: UUID?

    /// Total pages: title page + story pages + "The End" page
    var totalPages: Int {
        storyBook.pages.count + 2
    }

    var isFirstPage: Bool { currentPage == 0 }
    var isLastPage: Bool { currentPage == totalPages - 1 }

    /// Whether the current page is the title page (index 0).
    var isTitlePage: Bool { currentPage == 0 }

    /// Whether the current page is the "The End" page (last index).
    var isEndPage: Bool { currentPage == totalPages - 1 }

    /// The story page for the current position, if it's a content page.
    var currentStoryPage: StoryPage? {
        guard !isTitlePage, !isEndPage else { return nil }
        let pageIndex = currentPage - 1
        guard pageIndex >= 0 && pageIndex < storyBook.pages.count else { return nil }
        return storyBook.pages[pageIndex]
    }

    /// The image for the current page (cover image at index 0, page images at their page number).
    var currentImage: CGImage? {
        if isTitlePage {
            return images[0] // Cover image
        }
        guard let page = currentStoryPage else { return nil }
        return images[page.pageNumber]
    }

    /// All image indices that should have an image (cover + each story page).
    var allImageIndices: [Int] {
        [0] + storyBook.pages.map(\.pageNumber)
    }

    /// Indices that are missing an image and not currently regenerating.
    var missingImageIndices: [Int] {
        allImageIndices.filter { images[$0] == nil && !regeneratingPages.contains($0) }
    }

    init(
        storyBook: StoryBook,
        images: [Int: CGImage],
        format: BookFormat,
        style: IllustrationStyle,
        generator: IllustrationGenerator
    ) {
        self.storyBook = storyBook
        self.images = images
        self.format = format
        self.illustrationStyle = style
        self.illustrationGenerator = generator
    }

    func nextPage() {
        guard !isLastPage else { return }
        currentPage += 1
    }

    func previousPage() {
        guard !isFirstPage else { return }
        currentPage -= 1
    }

    func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        currentPage = page
    }

    // MARK: - Regeneration

    func regeneratePage(index: Int) async {
        guard !regeneratingPages.contains(index) else { return }

        let prompt: String
        if index == 0 {
            prompt = ContentSafetyPolicy.safeCoverPrompt(
                title: storyBook.title,
                concept: storyBook.moral
            )
        } else if let page = storyBook.pages.first(where: { $0.pageNumber == index }) {
            prompt = page.imagePrompt
        } else {
            return
        }

        regeneratingPages.insert(index)
        regenerationErrors[index] = nil
        lastRegenerationError = nil
        do {
            let image = try await illustrationGenerator.generateSingleImage(
                prompt: prompt,
                style: illustrationStyle
            )
            images[index] = image
            onImageRegenerated?(index, image)
        } catch {
            let message = IllustrationGenerator.userFacingErrorMessage(for: error)
            regenerationErrors[index] = message
            lastRegenerationError = message
        }
        regeneratingPages.remove(index)
    }

    func regenerateAllMissing() {
        let missing = missingImageIndices
        for index in missing {
            Task { await regeneratePage(index: index) }
        }
    }
}

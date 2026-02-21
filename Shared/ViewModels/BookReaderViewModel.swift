import Foundation
import CoreGraphics
import FoundationModels

@Observable
@MainActor
final class BookReaderViewModel {
    var storyBook: StoryBook
    var images: [Int: CGImage]
    let format: BookFormat
    let illustrationStyle: IllustrationStyle
    private let illustrationGenerator: IllustrationGenerator

    /// Pre-parsed character entries from Foundation Model (Upgrade 1).
    /// Used by `regenerateImage()` to avoid re-parsing descriptions on each retry.
    var parsedCharacters: [ImagePromptEnricher.CharacterEntry] = []

    /// Called after a single image is regenerated, passing (imageIndex, newImage).
    var onImageRegenerated: ((Int, CGImage) -> Void)?

    /// Called after story text is edited, passing the updated StoryBook.
    var onTextEdited: ((StoryBook) -> Void)?

    /// Called when a page turn is requested. Parameters: (fromPage, toPage, direction).
    /// The view should animate the turn and then call `commitPageChange(to:)`.
    var onPageTurnRequested: ((Int, Int, PageTurnDirection) -> Void)?

    private(set) var currentPage: Int = 0
    /// Tracks whether the last page change was forward or backward, for transition direction.
    private(set) var navigatingForward: Bool = true
    var regeneratingPages: Set<Int> = []
    var regenerationErrors: [Int: String] = [:]
    var lastRegenerationError: String?
    private var pageRetryCount: [Int: Int] = [:]

    // Text regeneration state
    var regeneratingText: Set<Int> = []
    var textRegenerationErrors: [Int: String] = [:]

    /// The original user concept that kicked off story generation.
    var originalConcept: String = ""

    /// Provider and model info for the generation that produced this book.
    var textProviderName: String = ""
    var imageProviderName: String = ""
    var textModelName: String = ""
    var imageModelName: String = ""

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
        let from = currentPage
        let to = from + 1
        navigatingForward = true
        if let handler = onPageTurnRequested {
            handler(from, to, .forward)
        } else {
            currentPage = to
        }
    }

    func previousPage() {
        guard !isFirstPage else { return }
        let from = currentPage
        let to = from - 1
        navigatingForward = false
        if let handler = onPageTurnRequested {
            handler(from, to, .backward)
        } else {
            currentPage = to
        }
    }

    func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        let from = currentPage
        guard page != from else { return }
        let direction: PageTurnDirection = page > from ? .forward : .backward
        navigatingForward = direction == .forward
        if let handler = onPageTurnRequested {
            handler(from, page, direction)
        } else {
            currentPage = page
        }
    }

    /// Commit a page change after the turn animation completes.
    func commitPageChange(to page: Int) {
        currentPage = page
    }

    // MARK: - Parameterized Page Accessors

    /// The story page for a given page index, or nil if it's the title/end page.
    func storyPage(at index: Int) -> StoryPage? {
        guard index > 0, index < totalPages - 1 else { return nil }
        let pageIndex = index - 1
        guard pageIndex >= 0, pageIndex < storyBook.pages.count else { return nil }
        return storyBook.pages[pageIndex]
    }

    /// The image for a given page index.
    func image(at index: Int) -> CGImage? {
        if index == 0 {
            return images[0]
        }
        guard let page = storyPage(at: index) else { return nil }
        return images[page.pageNumber]
    }

    /// Whether the given page index is the title page.
    func isTitlePage(at index: Int) -> Bool { index == 0 }

    /// Whether the given page index is the "The End" page.
    func isEndPage(at index: Int) -> Bool { index == totalPages - 1 }

    // MARK: - Text Editing

    func updateAuthorLine(_ newAuthor: String) {
        storyBook = StoryBook(
            title: storyBook.title,
            authorLine: newAuthor,
            moral: storyBook.moral,
            characterDescriptions: storyBook.characterDescriptions,
            pages: storyBook.pages
        )
        onTextEdited?(storyBook)
    }

    func updateMoral(_ newMoral: String) {
        storyBook = StoryBook(
            title: storyBook.title,
            authorLine: storyBook.authorLine,
            moral: newMoral,
            characterDescriptions: storyBook.characterDescriptions,
            pages: storyBook.pages
        )
        onTextEdited?(storyBook)
    }

    func updatePageText(pageNumber: Int, newText: String) {
        let updatedPages = storyBook.pages.map { page in
            if page.pageNumber == pageNumber {
                return StoryPage(
                    pageNumber: page.pageNumber,
                    text: newText,
                    imagePrompt: page.imagePrompt
                )
            }
            return page
        }
        storyBook = StoryBook(
            title: storyBook.title,
            authorLine: storyBook.authorLine,
            moral: storyBook.moral,
            characterDescriptions: storyBook.characterDescriptions,
            pages: updatedPages
        )
        onTextEdited?(storyBook)
    }

    /// Regenerate an image with an optional custom prompt override.
    func regenerateImage(index: Int, customPrompt: String? = nil) async {
        guard !regeneratingPages.contains(index) else { return }

        let descs = storyBook.characterDescriptions
        let chars = parsedCharacters
        let prompt: String
        if let custom = customPrompt, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt = IllustrationGenerator.enrichPromptWithCharacters(
                ContentSafetyPolicy.safeIllustrationPrompt(custom),
                characterDescriptions: descs,
                parsedCharacters: chars
            )
        } else if index == 0 {
            prompt = IllustrationGenerator.enrichPromptWithCharacters(
                ContentSafetyPolicy.safeCoverPrompt(title: storyBook.title, concept: storyBook.moral),
                characterDescriptions: descs,
                parsedCharacters: chars
            )
        } else if let page = storyBook.pages.first(where: { $0.pageNumber == index }) {
            prompt = IllustrationGenerator.enrichPromptWithCharacters(
                page.imagePrompt,
                characterDescriptions: descs,
                parsedCharacters: chars
            )
        } else {
            return
        }

        // Run single-prompt analysis for species-anchored variants
        let analysis = await PromptAnalysisEngine.analyzeSingle(prompt: prompt)

        let retries = pageRetryCount[index, default: 0]
        let startVariant = min(retries + 1, 5)
        pageRetryCount[index] = retries + 1

        regeneratingPages.insert(index)
        regenerationErrors[index] = nil
        lastRegenerationError = nil
        do {
            let image = try await illustrationGenerator.generateSingleImage(
                prompt: prompt,
                style: illustrationStyle,
                format: format,
                startingVariantIndex: startVariant,
                pageIndex: index,
                analysis: analysis
            )
            images[index] = image
            pageRetryCount[index] = 0
            onImageRegenerated?(index, image)
        } catch {
            let message = IllustrationGenerator.userFacingErrorMessage(for: error)
            regenerationErrors[index] = message
            lastRegenerationError = message
        }
        regeneratingPages.remove(index)
    }

    // MARK: - Text Regeneration

    /// Regenerate a single page's text and imagePrompt using the on-device LLM.
    func regeneratePageText(pageNumber: Int) async {
        guard !regeneratingText.contains(pageNumber) else { return }

        guard let pageIndex = storyBook.pages.firstIndex(where: { $0.pageNumber == pageNumber }) else { return }

        regeneratingText.insert(pageNumber)
        textRegenerationErrors[pageNumber] = nil

        do {
            let session = LanguageModelSession(
                instructions: """
                    You are an award-winning children's storybook author. \
                    You write engaging, age-appropriate stories for children ages 3-8. \
                    Your stories have vivid, simple prose that's fun to read aloud. \
                    You create detailed scene descriptions that would make beautiful illustrations. \
                    Safety requirements: never include violence, weapons, gore, horror, \
                    sexual content, nudity, substance use, hate, abuse, or self-harm.
                    """
            )

            // Build context from surrounding pages
            let prevText = pageIndex > 0 ? storyBook.pages[pageIndex - 1].text : nil
            let nextText = pageIndex < storyBook.pages.count - 1 ? storyBook.pages[pageIndex + 1].text : nil

            var contextParts: [String] = []
            contextParts.append("Story title: \"\(storyBook.title)\"")
            contextParts.append("Story moral: \"\(storyBook.moral)\"")
            if let prev = prevText {
                contextParts.append("Previous page text: \"\(prev)\"")
            }
            if let next = nextText {
                contextParts.append("Next page text: \"\(next)\"")
            }

            let prompt = """
                \(contextParts.joined(separator: "\n"))

                Rewrite page \(pageNumber) of this children's storybook. \
                Generate fresh story text (2-4 sentences) and a new detailed illustration prompt. \
                Keep the page number as \(pageNumber). \
                The new text should flow naturally between the surrounding pages. \
                Keep the tone warm, comforting, and suitable for ages 3-8.
                """

            let response = try await session.respond(
                to: prompt,
                generating: StoryPage.self
            )

            let newPage = StoryPage(
                pageNumber: pageNumber,
                text: response.content.text,
                imagePrompt: response.content.imagePrompt
            )

            let updatedPages = storyBook.pages.map { page in
                page.pageNumber == pageNumber ? newPage : page
            }
            storyBook = StoryBook(
                title: storyBook.title,
                authorLine: storyBook.authorLine,
                moral: storyBook.moral,
                characterDescriptions: storyBook.characterDescriptions,
                pages: updatedPages
            )
            onTextEdited?(storyBook)
        } catch {
            let message: String
            if let genError = error as? LanguageModelSession.GenerationError,
               case .guardrailViolation = genError {
                message = "Safety filter blocked this text. Try regenerating again."
            } else {
                message = "Text regeneration failed: \(error.localizedDescription)"
            }
            textRegenerationErrors[pageNumber] = message
        }
        regeneratingText.remove(pageNumber)
    }

    // MARK: - Regeneration (legacy)

    func regeneratePage(index: Int) async {
        guard !regeneratingPages.contains(index) else { return }

        let descs = storyBook.characterDescriptions
        let chars = parsedCharacters
        let prompt: String
        if index == 0 {
            prompt = IllustrationGenerator.enrichPromptWithCharacters(
                ContentSafetyPolicy.safeCoverPrompt(title: storyBook.title, concept: storyBook.moral),
                characterDescriptions: descs,
                parsedCharacters: chars
            )
        } else if let page = storyBook.pages.first(where: { $0.pageNumber == index }) {
            prompt = IllustrationGenerator.enrichPromptWithCharacters(
                page.imagePrompt,
                characterDescriptions: descs,
                parsedCharacters: chars
            )
        } else {
            return
        }

        // Run single-prompt analysis for species-anchored variants
        let analysis = await PromptAnalysisEngine.analyzeSingle(prompt: prompt)

        // Each retry skips further into the variant list so we don't replay
        // the same prompts that already failed for this page.
        let retries = pageRetryCount[index, default: 0]
        let startVariant = min(retries + 1, 5)
        pageRetryCount[index] = retries + 1

        regeneratingPages.insert(index)
        regenerationErrors[index] = nil
        lastRegenerationError = nil
        do {
            let image = try await illustrationGenerator.generateSingleImage(
                prompt: prompt,
                style: illustrationStyle,
                format: format,
                startingVariantIndex: startVariant,
                pageIndex: index,
                analysis: analysis
            )
            images[index] = image
            pageRetryCount[index] = 0
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

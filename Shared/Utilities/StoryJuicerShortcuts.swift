import Foundation
import AppIntents

enum StoryShortcutFormat: String, CaseIterable, AppEnum {
    case standard
    case landscape
    case small
    case portrait

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Book Format")

    static let caseDisplayRepresentations: [StoryShortcutFormat: DisplayRepresentation] = [
        .standard: DisplayRepresentation(title: "Standard Square"),
        .landscape: DisplayRepresentation(title: "Landscape"),
        .small: DisplayRepresentation(title: "Small Square"),
        .portrait: DisplayRepresentation(title: "Portrait")
    ]

    var bookFormat: BookFormat {
        BookFormat(rawValue: rawValue) ?? .standard
    }
}

enum StoryShortcutStyle: String, CaseIterable, AppEnum {
    case illustration
    case animation
    case sketch

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Illustration Style")

    static let caseDisplayRepresentations: [StoryShortcutStyle: DisplayRepresentation] = [
        .illustration: DisplayRepresentation(title: "Illustration"),
        .animation: DisplayRepresentation(title: "Animation"),
        .sketch: DisplayRepresentation(title: "Sketch")
    ]

    var illustrationStyle: IllustrationStyle {
        IllustrationStyle(rawValue: rawValue) ?? .illustration
    }
}

struct QueueStoryInStoryJuicerIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Story in StoryJuicer"
    static let description = IntentDescription(
        "Queue a story concept in StoryJuicer. This works well after a Use Model action in Shortcuts."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Story Concept")
    var concept: String

    @Parameter(title: "Pages", default: 8)
    var pageCount: Int

    @Parameter(title: "Book Format", default: .standard)
    var format: StoryShortcutFormat

    @Parameter(title: "Illustration Style", default: .illustration)
    var style: StoryShortcutStyle

    @Parameter(title: "Start Generation", default: true)
    var autoStart: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedConcept = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedConcept.isEmpty else {
            return .result(dialog: "Please provide a story concept.")
        }

        let clampedPageCount = min(max(pageCount, GenerationConfig.minPages), GenerationConfig.maxPages)

        let request = ShortcutStoryRequest(
            concept: trimmedConcept,
            pageCount: clampedPageCount,
            format: format.bookFormat,
            style: style.illustrationStyle,
            autoStart: autoStart
        )
        ShortcutStoryRequestStore.save(request)

        if autoStart {
            return .result(dialog: "Story queued. Opening StoryJuicer and starting generation.")
        }
        return .result(dialog: "Story queued. Opening StoryJuicer for review.")
    }
}

struct StoryJuicerAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QueueStoryInStoryJuicerIntent(),
            phrases: [
                "Create a story with \(.applicationName)",
                "Queue a story in \(.applicationName)"
            ],
            shortTitle: "Create Story",
            systemImageName: "book.fill"
        )
    }
}

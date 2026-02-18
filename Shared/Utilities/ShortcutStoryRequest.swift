import Foundation

struct ShortcutStoryRequest: Codable, Sendable {
    let concept: String
    let pageCount: Int
    let formatRawValue: String
    let styleRawValue: String
    let autoStart: Bool
    let queuedAt: Date

    var format: BookFormat {
        BookFormat(rawValue: formatRawValue) ?? .standard
    }

    var style: IllustrationStyle {
        IllustrationStyle(rawValue: styleRawValue) ?? .illustration
    }

    init(
        concept: String,
        pageCount: Int,
        format: BookFormat,
        style: IllustrationStyle,
        autoStart: Bool
    ) {
        self.concept = concept
        self.pageCount = pageCount
        self.formatRawValue = format.rawValue
        self.styleRawValue = style.rawValue
        self.autoStart = autoStart
        self.queuedAt = Date()
    }
}

enum ShortcutStoryRequestStore {
    private static let key = "storyjuicer.shortcut.pendingRequest"

    static func save(_ request: ShortcutStoryRequest, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(request) else { return }
        defaults.set(data, forKey: key)
    }

    static func consume(defaults: UserDefaults = .standard) -> ShortcutStoryRequest? {
        guard let data = defaults.data(forKey: key),
              let request = try? JSONDecoder().decode(ShortcutStoryRequest.self, from: data) else {
            return nil
        }
        defaults.removeObject(forKey: key)
        return request
    }
}

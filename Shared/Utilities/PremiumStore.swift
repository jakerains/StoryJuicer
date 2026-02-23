import Foundation

enum PremiumStore {
    private static let key = "storyfox.premiumState.v1"

    static func load(defaults: UserDefaults = .standard) -> PremiumState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(PremiumState.self, from: data) else {
            return .default
        }
        return state
    }

    static func save(_ state: PremiumState, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}

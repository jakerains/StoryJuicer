import Foundation

/// Describes which premium tier the user has selected.
enum PremiumTier: String, Codable, Sendable, Equatable, CaseIterable, Identifiable {
    case off
    case premium
    case premiumPlus

    var id: String { rawValue }

    /// Whether any premium tier is active (Premium or Premium Plus).
    var isActive: Bool { self != .off }

    /// Whether the full character sheet + edit endpoint pipeline should be used.
    var usesCharacterSheet: Bool { self == .premiumPlus }

    /// Whether photo upload for character references is enabled.
    var supportsPhotoUpload: Bool { self == .premiumPlus }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .premium: return "Premium"
        case .premiumPlus: return "Premium Plus"
        }
    }
}

struct PremiumState: Codable, Sendable, Equatable {
    var tier: PremiumTier = .off

    /// Convenience accessor for backward compatibility.
    var isEnabled: Bool { tier.isActive }

    static let `default` = PremiumState()

    // MARK: - Backward-Compatible Decoding

    /// Handles both old format (`{"isEnabled": true}`) and new format (`{"tier": "premium"}`).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let tier = try? container.decode(PremiumTier.self, forKey: .tier) {
            self.tier = tier
        } else if let isEnabled = try? container.decode(Bool.self, forKey: .isEnabled) {
            // Old format: map `isEnabled: true` → `.premium`
            self.tier = isEnabled ? .premium : .off
        } else {
            self.tier = .off
        }
    }

    init(tier: PremiumTier = .off) {
        self.tier = tier
    }

    private enum CodingKeys: String, CodingKey {
        case tier
        case isEnabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tier, forKey: .tier)
    }
}

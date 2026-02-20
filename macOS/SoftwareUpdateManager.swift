import Foundation
import Sparkle

/// Bridges Sparkle's `SPUUpdater` into Swift `@Observable` so SwiftUI views react to update state.
@Observable
@MainActor
final class SoftwareUpdateManager {

    // MARK: - Public state

    private(set) var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? {
        updaterController.updater.lastUpdateCheckDate
    }

    // MARK: - Private

    private let updaterController: SPUStandardUpdaterController
    private let updaterDelegate = UpdaterDelegate()
    private var kvoObserver: UpdaterKVOObserver?

    // MARK: - Init

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )

        // Bridge KVO → @Observable
        kvoObserver = UpdaterKVOObserver(updater: updaterController.updater) { [weak self] canCheck in
            Task { @MainActor in
                self?.canCheckForUpdates = canCheck
            }
        }

        canCheckForUpdates = updaterController.updater.canCheckForUpdates

        // Default to checking automatically so users don't miss updates
        if !updaterController.updater.automaticallyChecksForUpdates {
            updaterController.updater.automaticallyChecksForUpdates = true
        }

        // Check immediately on launch (after a short delay so the window loads first).
        // Sparkle's automatic schedule only fires every `updateCheckInterval` (default 24h),
        // so without this a freshly-launched app may not discover a new version for hours.
        Task { @MainActor [weak updaterController] in
            try? await Task.sleep(for: .seconds(3))
            updaterController?.updater.checkForUpdatesInBackground()
        }
    }

    // MARK: - Actions

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Silent background check — only shows UI if an update is available.
    func checkInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }
}

// MARK: - Updater Delegate

/// Provides the appcast feed URL to Sparkle since XcodeGen can't inject custom Info.plist keys.
private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        "https://raw.githubusercontent.com/jakerains/StoryFox/main/appcast.xml"
    }
}

// MARK: - KVO Bridge

/// Observes `SPUUpdater.canCheckForUpdates` via KVO and forwards changes to a callback.
private final class UpdaterKVOObserver: NSObject {
    private var observation: NSKeyValueObservation?
    private let onChange: @Sendable (Bool) -> Void

    init(updater: SPUUpdater, onChange: @escaping @Sendable (Bool) -> Void) {
        self.onChange = onChange
        super.init()

        observation = updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { _, change in
            if let newValue = change.newValue {
                onChange(newValue)
            }
        }
    }
}

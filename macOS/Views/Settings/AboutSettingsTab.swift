import SwiftUI

struct AboutSettingsTab: View {
    var updateManager: SoftwareUpdateManager
    @Binding var devModeUnlocked: Bool

    @State private var versionTapCount = 0
    @State private var showDevAuth = false
    @State private var devSecret = ""
    @State private var devAuthError = ""
    @State private var isVerifying = false
    @AppStorage("devBypassSecret") private var storedBypassSecret: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
            softwareUpdateSection
        }
        .sheet(isPresented: $showDevAuth) {
            devAuthSheet
        }
    }

    // MARK: - Software Update

    private var softwareUpdateSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Software Update",
                subtitle: "Keep StoryFox up to date with the latest features and fixes.",
                systemImage: "arrow.triangle.2.circlepath"
            )

            SettingsControlRow(
                title: "Version",
                description: "Currently installed version of StoryFox."
            ) {
                Text(appVersionString)
                    .font(StoryJuicerTypography.settingsBody)
                    .foregroundStyle(Color.sjText)
                    .settingsFieldChrome()
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 7 {
                            versionTapCount = 0
                            if devModeUnlocked {
                                // Already unlocked — toggle it off
                                devModeUnlocked = false
                                storedBypassSecret = ""
                            } else {
                                showDevAuth = true
                            }
                        }
                    }
            }

            SettingsControlRow(
                title: "Automatic Updates",
                description: "Periodically check for new versions in the background."
            ) {
                Toggle("Check automatically", isOn: Binding(
                    get: { updateManager.automaticallyChecksForUpdates },
                    set: { updateManager.automaticallyChecksForUpdates = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.sjCoral)
            }

            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Button("Check for Updates...") {
                        updateManager.checkForUpdates()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!updateManager.canCheckForUpdates)

                    if let lastCheck = updateManager.lastUpdateCheckDate {
                        Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                            .font(StoryJuicerTypography.settingsMeta)
                            .foregroundStyle(Color.sjSecondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Dev Auth Sheet

    private var devAuthSheet: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundStyle(Color.sjCoral)

            Text("Developer Access")
                .font(StoryJuicerTypography.settingsSectionTitle)
                .foregroundStyle(Color.sjGlassInk)

            SecureField("Bypass secret", text: $devSecret)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onSubmit { verifySecret() }

            if !devAuthError.isEmpty {
                Text(devAuthError)
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(.red)
            }

            HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
                Button("Cancel") {
                    devSecret = ""
                    devAuthError = ""
                    showDevAuth = false
                }
                .buttonStyle(.glass)

                Button("Verify") {
                    verifySecret()
                }
                .buttonStyle(.glassProminent)
                .disabled(devSecret.isEmpty || isVerifying)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.xLarge)
        .frame(width: 340)
    }

    private func verifySecret() {
        guard !devSecret.isEmpty, !isVerifying else { return }
        isVerifying = true
        devAuthError = ""

        Task {
            let unlocked = await checkBypass(secret: devSecret)
            await MainActor.run {
                isVerifying = false
                if unlocked {
                    storedBypassSecret = devSecret
                    devModeUnlocked = true
                    devSecret = ""
                    showDevAuth = false
                } else {
                    devAuthError = "Invalid secret"
                }
            }
        }
    }

    private func checkBypass(secret: String) async -> Bool {
        guard let url = URL(string: "https://storyfox.app/api/debug/config") else { return false }
        do {
            var request = URLRequest(url: url)
            request.setValue(secret, forHTTPHeaderField: "X-Dev-Bypass")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let enabled = json["enabled"] as? Bool {
                return enabled
            }
        } catch {}
        return false
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

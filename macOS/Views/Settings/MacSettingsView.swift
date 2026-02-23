import SwiftUI

struct MacSettingsView: View {
    private static let customChoice = "__custom__"

    var updateManager: SoftwareUpdateManager

    @State private var selectedTab: SettingsTab = .general
    @State private var settings: ModelSelectionSettings
    @State private var curatedTextModelChoice: String
    @State private var customTextModelID: String
    @State private var cloudModelCache = CloudModelListCache()
    @State private var premiumState: PremiumState
    @AppStorage("showDebugTab") private var showDebugTabLocal: Bool = false
    @State private var showDebugTabRemote: Bool = false

    init(updateManager: SoftwareUpdateManager) {
        self.updateManager = updateManager

        let loaded = ModelSelectionStore.load()
        let textModelIDs = Set(ModelSelectionSettings.curatedMLXModels.map(\.id))

        _settings = State(initialValue: loaded)
        _curatedTextModelChoice = State(
            initialValue: textModelIDs.contains(loaded.mlxModelID) ? loaded.mlxModelID : Self.customChoice
        )
        _customTextModelID = State(initialValue: loaded.mlxModelID)
        _premiumState = State(initialValue: PremiumStore.load())
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            contentArea
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(backgroundLayer)
        .onChange(of: settings) { _, newValue in
            ModelSelectionStore.save(newValue)
        }
        .onChange(of: curatedTextModelChoice) { _, newChoice in
            guard newChoice != Self.customChoice else { return }
            settings.mlxModelID = newChoice
            customTextModelID = newChoice
        }
        .onChange(of: selectedTab) { _, _ in
            premiumState = PremiumStore.load()
        }
        .task {
            await cloudModelCache.refreshAllAuthenticated()
            await checkDebugEnabled()
        }
    }

    /// Tabs visible in the sidebar. Debug tab shows if either the server flag or local override is enabled.
    private var visibleTabs: [SettingsTab] {
        var tabs = SettingsTab.defaultTabs
        if showDebugTabLocal || showDebugTabRemote {
            tabs.append(.debug)
        }
        return tabs
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Text("Settings")
                .font(StoryJuicerTypography.settingsSectionTitle)
                .foregroundStyle(Color.sjGlassInk)
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                .padding(.top, StoryJuicerGlassTokens.Spacing.large)
                .padding(.bottom, StoryJuicerGlassTokens.Spacing.small)

            ForEach(visibleTabs) { tab in
                Button {
                    withAnimation(StoryJuicerMotion.fast) {
                        selectedTab = tab
                    }
                } label: {
                    SettingsSidebarRow(tab: tab, isSelected: selectedTab == tab)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("Changes are saved automatically.")
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjMuted)
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                .padding(.bottom, StoryJuicerGlassTokens.Spacing.medium)
        }
        .frame(width: 200)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
                tabHeader

                switch selectedTab {
                case .general:
                    premiumGatedContent {
                        GeneralSettingsTab(settings: $settings)
                    }

                case .onDevice:
                    premiumGatedContent {
                        OnDeviceSettingsTab(
                            settings: $settings,
                            curatedTextModelChoice: $curatedTextModelChoice,
                            customTextModelID: $customTextModelID
                        )
                    }

                case .cloud:
                    premiumGatedContent {
                        CloudSettingsTab(
                            settings: $settings,
                            modelCache: cloudModelCache
                        )
                    }

                case .premium:
                    PremiumSettingsTab(settings: $settings)

                case .about:
                    AboutSettingsTab(updateManager: updateManager)

                case .debug:
                    DebugSettingsTab(settings: $settings, modelCache: cloudModelCache)
                }
            }
            .padding(StoryJuicerGlassTokens.Spacing.large)
        }
    }

    // MARK: - Tab Header

    private var tabHeader: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: selectedTab.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.sjCoral)
                .frame(width: 26, height: 26)
                .background(Color.sjCoral.opacity(0.12), in: .circle)
                .overlay {
                    Circle()
                        .strokeBorder(Color.sjCoral.opacity(0.35), lineWidth: 1)
                }

            Text(selectedTab.label)
                .font(StoryJuicerTypography.settingsSectionTitle)
                .foregroundStyle(Color.sjGlassInk)
        }
    }

    // MARK: - Premium Gate

    @ViewBuilder
    private func premiumGatedContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if premiumState.tier.isActive {
            premiumActiveBanner
            content()
                .disabled(true)
                .opacity(0.35)
        } else {
            content()
        }
    }

    private var premiumActiveBanner: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Image(systemName: "crown.fill")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.sjGold, Color.sjCoral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [Color.sjGold.opacity(0.15), Color.sjCoral.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("\(premiumState.tier.displayName) Active")
                    .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.sjCoral, Color.sjGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Premium handles all story and image generation. These settings are not used while Premium is enabled.")
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                withAnimation(StoryJuicerMotion.fast) {
                    selectedTab = .premium
                }
            } label: {
                Text("Manage")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.glass)
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .background(
            LinearGradient(
                colors: [Color.sjGold.opacity(0.06), Color.sjCoral.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
        )
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.sjGold.opacity(0.3), Color.sjCoral.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Debug Config Check

    private func checkDebugEnabled() async {
        guard let url = URL(string: "https://storyfox.app/api/debug/config") else { return }
        do {
            var request = URLRequest(url: url)
            for (key, value) in CloudProvider.openAI.extraHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let enabled = json["enabled"] as? Bool {
                await MainActor.run { showDebugTabRemote = enabled }
            }
        } catch {
            // Silently fail — debug tab stays hidden if unreachable
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sjPaperTop, Color.sjBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            PaperTextureOverlay()

            RadialGradient(
                colors: [Color.sjHighlight.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 460
            )
        }
    }
}

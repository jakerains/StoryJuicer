import SwiftUI

struct MacSettingsView: View {
    private static let customChoice = "__custom__"

    var updateManager: SoftwareUpdateManager

    @State private var selectedTab: SettingsTab = .general
    @State private var settings: ModelSelectionSettings
    @State private var curatedTextModelChoice: String
    @State private var customTextModelID: String
    @State private var cloudModelCache = CloudModelListCache()
    @AppStorage("devModeUnlocked") private var devModeUnlocked: Bool = false

    init(updateManager: SoftwareUpdateManager) {
        self.updateManager = updateManager

        let loaded = ModelSelectionStore.load()
        let textModelIDs = Set(ModelSelectionSettings.curatedMLXModels.map(\.id))

        _settings = State(initialValue: loaded)
        _curatedTextModelChoice = State(
            initialValue: textModelIDs.contains(loaded.mlxModelID) ? loaded.mlxModelID : Self.customChoice
        )
        _customTextModelID = State(initialValue: loaded.mlxModelID)
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
        .task {
            await cloudModelCache.refreshAllAuthenticated()
        }
    }

    private var visibleTabs: [SettingsTab] {
        if devModeUnlocked {
            return SettingsTab.allCases.map { $0 }
        }
        return SettingsTab.defaultTabs
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
                    GeneralSettingsTab(settings: $settings)

                case .onDevice:
                    OnDeviceSettingsTab(
                        settings: $settings,
                        curatedTextModelChoice: $curatedTextModelChoice,
                        customTextModelID: $customTextModelID
                    )

                case .cloud:
                    CloudSettingsTab(
                        settings: $settings,
                        modelCache: cloudModelCache
                    )

                case .premium:
                    PremiumSettingsTab(settings: $settings)

                case .about:
                    AboutSettingsTab(updateManager: updateManager, devModeUnlocked: $devModeUnlocked)

                case .debug:
                    DebugSettingsTab(settings: $settings, modelCache: cloudModelCache) {
                        devModeUnlocked = false
                        UserDefaults.standard.removeObject(forKey: "devBypassSecret")
                        withAnimation(StoryJuicerMotion.fast) {
                            selectedTab = .general
                        }
                    }
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

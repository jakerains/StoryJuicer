import SwiftUI

struct GeneralSettingsTab: View {
    @Binding var settings: ModelSelectionSettings

    private var hasOpenRouterKey: Bool {
        CloudCredentialStore.isAuthenticated(for: .openRouter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
            providerSection
            audienceModeSection
        }
    }

    // MARK: - Provider Pickers

    private var providerSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Generation Providers",
                subtitle: "Choose which engines power story text and illustrations.",
                systemImage: "sparkles.rectangle.stack"
            )

            SettingsControlRow(
                title: "Text Provider",
                description: "Engine used for writing stories."
            ) {
                Picker("Text Provider", selection: $settings.textProvider) {
                    ForEach(StoryTextProvider.allCases.filter { $0 != .togetherAI && $0 != .openAI && $0 != .mlxSwift && ($0 != .openRouter || hasOpenRouterKey) }) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFieldChrome()
                .frame(width: 250)
            }

            SettingsControlRow(
                title: "Image Provider",
                description: "Engine used for generating illustrations."
            ) {
                Picker("Image Provider", selection: $settings.imageProvider) {
                    ForEach(StoryImageProvider.allCases.filter { $0 != .diffusers && $0 != .togetherAI && $0 != .openAI && ($0 != .openRouter || hasOpenRouterKey) }) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFieldChrome()
                .frame(width: 250)
            }

            SettingsControlRow(
                title: "Text Fallback",
                description: "Fall back to Apple Foundation Models when cloud or MLX fails."
            ) {
                Toggle("Enable text fallback", isOn: $settings.enableFoundationFallback)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.sjCoral)
            }
        }
    }

    // MARK: - Audience Mode

    private var audienceModeSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Audience",
                subtitle: "Choose who the story is for — this adjusts language, tone, and complexity.",
                systemImage: "person.2"
            )

            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                ForEach(AudienceMode.allCases) { mode in
                    let isSelected = settings.audienceMode == mode
                    Button {
                        withAnimation(StoryJuicerMotion.standard) {
                            settings.audienceMode = mode
                        }
                    } label: {
                        HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.sjCoral : .sjSecondaryText)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(mode.displayName)
                                    .font(StoryJuicerTypography.settingsControl)
                                    .foregroundStyle(isSelected ? Color.sjGlassInk : .sjSecondaryText)

                                Text(mode.subtitle)
                                    .font(StoryJuicerTypography.settingsMeta)
                                    .foregroundStyle(Color.sjSecondaryText)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
                        .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
                        .sjGlassChip(selected: isSelected, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(mode.displayName) audience mode")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

import SwiftUI

struct PremiumSettingsTab: View {
    @Binding var settings: ModelSelectionSettings
    @State private var premiumState: PremiumState
    @State private var serverEnabled: Bool = true

    init(settings: Binding<ModelSelectionSettings>) {
        _settings = settings
        _premiumState = State(initialValue: PremiumStore.load())
    }

    /// Whether the server has disabled premium at the infrastructure level.
    private var isServerDisabled: Bool {
        !serverEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
            premiumCallout
            tierPickerSection
            if premiumState.tier.isActive {
                tierDescriptionSection
            }
        }
        .onChange(of: premiumState) { _, newValue in
            PremiumStore.save(newValue)
        }
        .task {
            await checkServerEnabled()
        }
    }

    // MARK: - Premium Callout

    private var premiumCallout: some View {
        HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.sjGold, Color.sjCoral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [Color.sjGold.opacity(0.15), Color.sjCoral.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("StoryFox Premium")
                    .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.sjCoral, Color.sjGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Unlock dramatically better stories and illustrations. Choose between fast standard generation or the full character consistency experience.")
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    // MARK: - Tier Picker

    private var tierPickerSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Premium Tier",
                subtitle: "Select the generation quality level. No API key or activation code needed.",
                systemImage: "bolt.fill"
            )

            if isServerDisabled {
                serverDisabledBanner
            }

            Picker("Tier", selection: $premiumState.tier) {
                ForEach(PremiumTier.allCases) { tier in
                    Text(tier.displayName).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isServerDisabled)
        }
    }

    private var serverDisabledBanner: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.sjCoral)

            Text("Premium is currently unavailable. The service is temporarily disabled.")
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StoryJuicerGlassTokens.Spacing.small)
        .background(Color.sjCoral.opacity(0.08), in: .rect(cornerRadius: 8))
    }

    // MARK: - Tier Description

    private var tierDescriptionSection: some View {
        SettingsPanelCard {
            switch premiumState.tier {
            case .off:
                EmptyView()
            case .premium:
                tierRow(
                    icon: "bolt.fill",
                    title: "Premium",
                    features: [
                        "Fast, high-quality illustrations",
                        "Cloud-powered story writing",
                        "Smarter character consistency",
                    ]
                )
            case .premiumPlus:
                tierRow(
                    icon: "bolt.shield.fill",
                    title: "Premium Plus",
                    features: [
                        "Full character reference sheet for visual consistency",
                        "Upload photos of people or pets as characters",
                        "Highest quality illustrations",
                        "Best-in-class image generation",
                    ]
                )
            }
        }
    }

    private func tierRow(icon: String, title: String, features: [String]) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.sjGold)

                Text(title)
                    .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                    .foregroundStyle(Color.sjGlassInk)
            }

            ForEach(features, id: \.self) { feature in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.sjCoral)
                        .padding(.top, 2)

                    Text(feature)
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Server Availability Check

    private func checkServerEnabled() async {
        guard let url = URL(string: "https://storyfox.app/api/premium/config") else { return }
        do {
            var request = URLRequest(url: url)
            for (key, value) in CloudProvider.openAI.extraHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let enabled = json["enabled"] as? Bool {
                await MainActor.run { serverEnabled = enabled }
            }
        } catch {
            // Silently fail — assume enabled if unreachable
        }
    }
}

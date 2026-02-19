import SwiftUI

struct IOSModelSettingsView: View {
    private static let customChoice = "__custom__"

    @Environment(\.dismiss) private var dismiss

    @State private var settings: ModelSelectionSettings
    @State private var curatedTextModelChoice: String
    @State private var customTextModelID: String

    @State private var textModelStatus = "Idle"
    @State private var textModelProgress: Double?
    @State private var isTestingTextModel = false
    @State private var cloudModelCache = CloudModelListCache()

    init() {
        let loaded = ModelSelectionStore.load()

        let textModelIDs = Set(ModelSelectionSettings.curatedMLXModels.map(\.id))

        _settings = State(initialValue: loaded)
        _curatedTextModelChoice = State(
            initialValue: textModelIDs.contains(loaded.mlxModelID) ? loaded.mlxModelID : Self.customChoice
        )
        _customTextModelID = State(initialValue: loaded.mlxModelID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
                    header
                    providerSection

                    sectionLabel("On-Device", systemImage: "cpu")
                    foundationModelSection

                    sectionLabel("Cloud Providers", systemImage: "cloud")
                    huggingFaceCallout
                    CloudProviderSettingsSection(
                        provider: .huggingFace,
                        settings: $settings,
                        modelCache: cloudModelCache
                    )

                    sectionLabel("Local Models", systemImage: "arrow.down.circle")
                    mlxModelSection
                }
                .padding(StoryJuicerGlassTokens.Spacing.large)
            }
            .background(backgroundLayer)
            .navigationTitle("Model Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.sjCoral)
                }
            }
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
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sjPaperTop, Color.sjBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.sjHighlight.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 460
            )
        }
    }

    // MARK: - Section Labels

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.sjCoral.opacity(0.7))

            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.sjSecondaryText.opacity(0.7))
                .tracking(1.2)
        }
        .padding(.top, StoryJuicerGlassTokens.Spacing.small)
    }

    // MARK: - Header

    private var header: some View {
        SettingsPanelCard(tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard)) {
            SettingsSectionHeader(
                title: "Model Settings",
                subtitle: "Configure on-device and cloud models for story writing and illustration.",
                systemImage: "slider.horizontal.3"
            )
            Text("Changes are saved automatically.")
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)
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
                    ForEach(StoryTextProvider.allCases.filter { $0 != .openRouter && $0 != .togetherAI }) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFieldChrome()
            }

            SettingsControlRow(
                title: "Image Provider",
                description: "Engine used for generating illustrations."
            ) {
                Picker("Image Provider", selection: $settings.imageProvider) {
                    ForEach(StoryImageProvider.allCases.filter { $0 != .diffusers && $0 != .openRouter && $0 != .togetherAI }) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFieldChrome()
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

    // MARK: - Foundation Models

    private var foundationModelSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Apple Foundation Models",
                subtitle: "Built-in on-device language model. No setup required.",
                systemImage: "apple.intelligence"
            )

            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.green)
                    .font(.system(size: 14))

                Text("Runs entirely on-device using Apple Intelligence. Requires Apple Silicon.")
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - MLX Model

    private var mlxModelSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "MLX Text Model",
                subtitle: "Run open-source LLMs locally via MLX. Models download on first use.",
                systemImage: "cpu"
            )

            SettingsControlRow(
                title: "Curated Model",
                description: "Tested models for story generation."
            ) {
                Picker("Curated Models", selection: $curatedTextModelChoice) {
                    ForEach(ModelSelectionSettings.curatedMLXModels) { model in
                        Text(model.displayName).tag(model.id)
                    }
                    Text("Custom Hugging Face ID").tag(Self.customChoice)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFieldChrome()
            }

            SettingsControlRow(
                title: "Custom Model ID",
                description: "Any Hugging Face MLX model (owner/model-name)."
            ) {
                VStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    TextField("owner/model-name", text: $customTextModelID)
                        .textFieldStyle(.plain)
                        .settingsFieldChrome()

                    Button("Apply") {
                        applyCustomTextModelID()
                    }
                    .buttonStyle(.glass)
                }
            }

            Text("Current model: \(settings.mlxModelID)")
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)

            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Button(isTestingTextModel ? "Testing..." : "Test Model Load") {
                        Task { await testTextModelLoad() }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isTestingTextModel)

                    Text(textModelStatus)
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                        .lineLimit(2)
                }

                if let textModelProgress {
                    ProgressView(value: textModelProgress)
                        .tint(.sjCoral)
                }
            }
        }
    }

    // MARK: - Hugging Face Callout

    private var huggingFaceCallout: some View {
        HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Image(systemName: "gift.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.sjCoral)
                .frame(width: 36, height: 36)
                .background(Color.sjCoral.opacity(0.12), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("Hugging Face \u{2014} Free Cloud AI")
                    .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                    .foregroundStyle(Color.sjText)

                Text("Create a free Hugging Face account to generate stories and illustrations in the cloud \u{2014} no credit card needed. Sign in below or paste an API token.")
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: URL(string: "https://huggingface.co/join")!) {
                    HStack(spacing: 4) {
                        Text("Create a free account")
                            .font(StoryJuicerTypography.settingsMeta.weight(.medium))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.sjCoral)
                }
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.medium)
        .background(Color.sjCoral.opacity(0.06), in: .rect(cornerRadius: StoryJuicerGlassTokens.Radius.hero))
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
                .strokeBorder(Color.sjCoral.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: - Actions

    private func applyCustomTextModelID() {
        let trimmed = customTextModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.mlxModelID = trimmed

        let curatedIDs = Set(ModelSelectionSettings.curatedMLXModels.map(\.id))
        curatedTextModelChoice = curatedIDs.contains(trimmed) ? trimmed : Self.customChoice
    }

    private func testTextModelLoad() async {
        isTestingTextModel = true
        textModelProgress = nil
        textModelStatus = "Starting MLX model load..."
        applyCustomTextModelID()
        ModelSelectionStore.save(settings)

        let snapshot = settings
        let generator = MLXStoryGenerator(settingsProvider: { snapshot })

        do {
            try await generator.prewarmModel { message in
                Task { @MainActor in
                    textModelStatus = message
                    textModelProgress = parseProgress(from: message)
                }
            }
            textModelStatus = "MLX model is ready."
            textModelProgress = 1.0
        } catch {
            textModelStatus = "MLX model load failed: \(error.localizedDescription)"
            textModelProgress = nil
        }

        isTestingTextModel = false
    }

    private func parseProgress(from message: String) -> Double? {
        guard let percentRange = message.range(of: #"([0-9]{1,3})%"#, options: .regularExpression) else {
            return nil
        }
        let percentText = message[percentRange].dropLast()
        guard let value = Double(percentText) else {
            return nil
        }
        return min(max(value / 100.0, 0.0), 1.0)
    }
}

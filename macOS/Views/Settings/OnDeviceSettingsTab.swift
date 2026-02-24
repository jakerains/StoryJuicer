import SwiftUI

struct OnDeviceSettingsTab: View {
    private static let customChoice = "__custom__"

    @Binding var settings: ModelSelectionSettings
    @Binding var curatedTextModelChoice: String
    @Binding var customTextModelID: String

    @State private var textModelStatus = "Idle"
    @State private var textModelProgress: Double?
    @State private var isTestingTextModel = false

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
            foundationModelSection
            // MLX section hidden — models don't work well yet.
            // Re-enable by uncommenting: mlxModelSection
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

                Text("Runs entirely on-device using Apple Intelligence. Requires Apple Silicon and macOS 26.")
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
                .frame(width: 320)
            }

            SettingsControlRow(
                title: "Custom Model ID",
                description: "Any Hugging Face MLX model (owner/model-name)."
            ) {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    TextField("owner/model-name", text: $customTextModelID)
                        .textFieldStyle(.plain)
                        .settingsFieldChrome()
                        .frame(width: 320)

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
                        .lineLimit(1)
                }

                if let textModelProgress {
                    ProgressView(value: textModelProgress)
                        .tint(.sjCoral)
                }
            }
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

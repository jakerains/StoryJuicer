import SwiftUI

/// Reusable settings card for a single cloud provider.
/// Shows API key input, text/image model pickers, and refresh/test controls.
///
/// Set `bare: true` when embedding inside an external container (e.g. a `DisclosureGroup`)
/// to skip the built-in `SettingsPanelCard` and `SettingsSectionHeader` wrappers.
struct CloudProviderSettingsSection: View {
    let provider: CloudProvider
    @Binding var settings: ModelSelectionSettings
    @Bindable var modelCache: CloudModelListCache
    var bare: Bool = false

    @State private var apiKeyInput: String = ""
    @State private var keyStatus: String = ""
    @State private var hfOAuth = HuggingFaceOAuth()
    @State private var isAPIKeyExpanded = false

    /// Whether the provider has a saved API key (cached in UserDefaults to avoid Keychain reads).
    private var hasStoredKey: Bool {
        UserDefaults.standard.bool(forKey: "com.storyfox.\(provider.rawValue).hasAPIKey")
    }

    private static func setHasStoredKey(_ flag: Bool, for provider: CloudProvider) {
        UserDefaults.standard.set(flag, forKey: "com.storyfox.\(provider.rawValue).hasAPIKey")
    }

    var body: some View {
        if bare {
            content
        } else {
            SettingsPanelCard {
                SettingsSectionHeader(
                    title: provider.displayName,
                    subtitle: provider.supportsOAuth
                        ? "Use an API token or sign in with Hugging Face."
                        : "Enter your API key to enable \(provider.displayName) models.",
                    systemImage: cloudProviderSystemIcon,
                    customImage: cloudProviderCustomImage
                )

                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if provider.supportsOAuth {
            oauthRow

            Button {
                withAnimation(StoryJuicerMotion.fast) {
                    isAPIKeyExpanded.toggle()
                }
            } label: {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.sjMuted)
                        .rotationEffect(.degrees(isAPIKeyExpanded ? 90 : 0))

                    Text("Use an API token instead")
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(Color.sjSecondaryText)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isAPIKeyExpanded {
                apiKeyRow
                    .padding(.top, StoryJuicerGlassTokens.Spacing.small)
            }
        } else {
            apiKeyRow
        }

        textModelPicker
        imageModelPicker
        actionButtons
    }

    private var cloudProviderSystemIcon: String? {
        switch provider {
        case .togetherAI:  return "server.rack"
        case .openRouter, .huggingFace, .openAI: return nil
        }
    }

    private var cloudProviderCustomImage: String? {
        switch provider {
        case .huggingFace: return "HuggingFaceLogo"
        case .openRouter:  return "OpenRouterLogo"
        case .togetherAI, .openAI:  return nil
        }
    }

    // MARK: - API Key

    private var apiKeyRow: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            SettingsControlRow(
                title: "API Key",
                description: hasStoredKey
                    ? "A key is saved in Keychain. Paste a new one to replace it."
                    : "Stored securely in Keychain."
            ) {
                SecureField(hasStoredKey ? "Paste new key to replace" : "sk-...", text: $apiKeyInput)
                    .textFieldStyle(.plain)
                    .settingsFieldChrome()
                    .frame(width: 320)
            }

            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button("Save Key") {
                    saveAPIKey()
                }
                .buttonStyle(.glassProminent)

                Button("Clear Key", role: .destructive) {
                    clearAPIKey()
                }
                .buttonStyle(.glass)

                if !keyStatus.isEmpty {
                    Text(keyStatus)
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                }
            }

            CloudProviderTokenHelper(provider: provider)
        }
    }

    // MARK: - OAuth Login

    private var oauthRow: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Text("Sign in with Hugging Face")
                .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                .foregroundStyle(Color.sjText)

            if hfOAuth.isLoggedIn {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("Signed in\(hfOAuth.username.map { " as \($0)" } ?? "")")
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(Color.sjSecondaryText)

                    Button("Sign Out", role: .destructive) {
                        Task { await hfOAuth.logout() }
                    }
                    .buttonStyle(.glass)
                }
            } else {
                Button {
                    Task { await hfOAuth.login() }
                } label: {
                    HStack(spacing: 8) {
                        Text("🤗")
                            .font(.system(size: 18))
                        Text(hfOAuth.isLoggingIn ? "Signing in…" : "Sign in with Hugging Face")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.sRGB, red: 1.0, green: 0.82, blue: 0.12, opacity: 1.0))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(hfOAuth.isLoggingIn)
                .opacity(hfOAuth.isLoggingIn ? 0.6 : 1.0)
            }

            if let error = hfOAuth.error {
                Text(error)
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjCoral)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Text Model Picker

    private var textModelPicker: some View {
        SettingsControlRow(
            title: "Text Model",
            description: "Model for story generation."
        ) {
            Picker("Text Model", selection: textModelBinding) {
                let models = modelCache.textModels[provider] ?? []
                let recommended = models.filter(\.isRecommended)
                let others = models.filter { !$0.isRecommended }

                if !recommended.isEmpty {
                    Section("Recommended") {
                        ForEach(recommended) { model in
                            Text(model.displayName)
                                .bold()
                                .tag(model.id)
                        }
                    }
                }

                if !others.isEmpty {
                    Section("All Models") {
                        ForEach(others) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                }

                if !models.contains(where: { $0.id == textModelBinding.wrappedValue }) {
                    Text(textModelBinding.wrappedValue).tag(textModelBinding.wrappedValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .settingsFieldChrome()
            .frame(width: 320)
        }
    }

    // MARK: - Image Model Picker

    private var imageModelPicker: some View {
        SettingsControlRow(
            title: "Image Model",
            description: "Model for illustration generation."
        ) {
            Picker("Image Model", selection: imageModelBinding) {
                let models = modelCache.imageModels[provider] ?? []
                ForEach(models) { model in
                    Text(model.displayName).tag(model.id)
                }
                if !models.contains(where: { $0.id == imageModelBinding.wrappedValue }) {
                    Text(imageModelBinding.wrappedValue).tag(imageModelBinding.wrappedValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .settingsFieldChrome()
            .frame(width: 320)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await modelCache.refreshModels(for: provider, force: true) }
                } label: {
                    if modelCache.isLoading[provider] == true {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh Models", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.glass)
                .disabled(modelCache.isLoading[provider] == true)
            }

            if let error = modelCache.lastError[provider] {
                Text(error)
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjCoral)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Bindings

    private var textModelBinding: Binding<String> {
        switch provider {
        case .openRouter:  return $settings.openRouterTextModelID
        case .togetherAI:  return $settings.togetherTextModelID
        case .huggingFace: return $settings.huggingFaceTextModelID
        case .openAI:      return .constant(provider.defaultTextModelID)  // Server-controlled
        }
    }

    private var imageModelBinding: Binding<String> {
        switch provider {
        case .openRouter:  return $settings.openRouterImageModelID
        case .togetherAI:  return $settings.togetherImageModelID
        case .huggingFace: return $settings.huggingFaceImageModelID
        case .openAI:      return .constant(provider.defaultImageModelID)  // Server-controlled
        }
    }

    // MARK: - Key Management

    private func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        if CloudCredentialStore.saveAPIKey(key, for: provider) {
            Self.setHasStoredKey(true, for: provider)
            keyStatus = "Saved \(provider.displayName) API key."
            apiKeyInput = ""
        } else {
            keyStatus = "Failed to save API key."
        }
    }

    private func clearAPIKey() {
        CloudCredentialStore.deleteAPIKey(for: provider)
        Self.setHasStoredKey(false, for: provider)
        apiKeyInput = ""
        keyStatus = "Cleared \(provider.displayName) API key."
    }
}

import CoreGraphics
import HuggingFace
import ImageIO
import SwiftUI

/// Reusable settings card for a single cloud provider.
/// Shows API key input, text/image model pickers, and refresh/test controls.
struct CloudProviderSettingsSection: View {
    let provider: CloudProvider
    @Binding var settings: ModelSelectionSettings
    @Bindable var modelCache: CloudModelListCache

    @State private var apiKeyInput: String = ""
    @State private var keyStatus: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: String = ""
    @State private var isTestingText: Bool = false
    @State private var textTestResult: String = ""
    @State private var isTestingImage: Bool = false
    @State private var imageTestResult: String = ""
    @State private var hfOAuth = HuggingFaceOAuth()

    /// Whether the provider has a saved API key (cached in UserDefaults to avoid Keychain reads).
    private var hasStoredKey: Bool {
        UserDefaults.standard.bool(forKey: "com.storyjuicer.\(provider.rawValue).hasAPIKey")
    }

    private static func setHasStoredKey(_ flag: Bool, for provider: CloudProvider) {
        UserDefaults.standard.set(flag, forKey: "com.storyjuicer.\(provider.rawValue).hasAPIKey")
    }

    var body: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: provider.displayName,
                subtitle: provider.supportsOAuth
                    ? "Use an API token or sign in with Hugging Face."
                    : "Enter your API key to enable \(provider.displayName) models.",
                systemImage: cloudProviderIcon
            )

            apiKeyRow

            if provider.supportsOAuth {
                oauthRow
            }

            textModelPicker
            imageModelPicker
            actionButtons
        }
    }

    private var cloudProviderIcon: String {
        switch provider {
        case .openRouter:  return "cloud"
        case .togetherAI:  return "server.rack"
        case .huggingFace: return "face.smiling"
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
            Divider()
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)

            Text("Or sign in with Hugging Face")
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)

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
                ForEach(models) { model in
                    Text(model.displayName).tag(model.id)
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
            // Row 1: Refresh + Test Connection
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

                Button(isTesting ? "Testing..." : "Test Connection") {
                    Task { await testConnection() }
                }
                .buttonStyle(.glass)
                .disabled(isTesting)

                if !testResult.isEmpty {
                    Text(testResult)
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                        .lineLimit(1)
                }
            }

            // Row 2: Test Text Model
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await testTextModel() }
                } label: {
                    if isTestingText {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Text Model", systemImage: "text.bubble")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isTestingText)

                if !textTestResult.isEmpty {
                    Text(textTestResult)
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(textTestResult.hasPrefix("Text OK")
                            ? Color.sjSecondaryText
                            : Color.sjCoral)
                        .lineLimit(4)
                }
            }

            // Row 3: Test Image Model
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await testImageModel() }
                } label: {
                    if isTestingImage {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Image Model", systemImage: "photo")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isTestingImage)

                if !imageTestResult.isEmpty {
                    Text(imageTestResult)
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(imageTestResult.hasPrefix("Image OK")
                            ? Color.sjSecondaryText
                            : Color.sjCoral)
                        .lineLimit(4)
                }
            }

            // Model list error
            if let error = modelCache.lastError[provider] {
                Text(error)
                    .font(StoryJuicerTypography.settingsMeta)
                    .foregroundStyle(Color.sjCoral)
                    .lineLimit(4)
            }
        }
        .textSelection(.enabled)
    }

    // MARK: - Bindings

    private var textModelBinding: Binding<String> {
        switch provider {
        case .openRouter:  return $settings.openRouterTextModelID
        case .togetherAI:  return $settings.togetherTextModelID
        case .huggingFace: return $settings.huggingFaceTextModelID
        }
    }

    private var imageModelBinding: Binding<String> {
        switch provider {
        case .openRouter:  return $settings.openRouterImageModelID
        case .togetherAI:  return $settings.togetherImageModelID
        case .huggingFace: return $settings.huggingFaceImageModelID
        }
    }

    // MARK: - Actions

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

    private func testConnection() async {
        isTesting = true
        testResult = ""

        guard let apiKey = CloudCredentialStore.bearerToken(for: provider) else {
            testResult = "No API key configured."
            isTesting = false
            return
        }

        do {
            let client = OpenAICompatibleClient()
            _ = try await client.fetchModels(
                url: provider.modelListURL,
                apiKey: apiKey,
                extraHeaders: provider.extraHeaders
            )
            testResult = "Connected successfully."
        } catch {
            testResult = "Connection failed: \(verboseError(error))"
        }

        isTesting = false
    }

    // MARK: - Model ID Resolution

    private func resolvedTextModelID() -> String {
        let modelID: String
        switch provider {
        case .openRouter:  modelID = settings.openRouterTextModelID
        case .togetherAI:  modelID = settings.togetherTextModelID
        case .huggingFace: modelID = settings.huggingFaceTextModelID
        }
        return modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultTextModelID
            : modelID
    }

    private func resolvedImageModelID() -> String {
        let modelID: String
        switch provider {
        case .openRouter:  modelID = settings.openRouterImageModelID
        case .togetherAI:  modelID = settings.togetherImageModelID
        case .huggingFace: modelID = settings.huggingFaceImageModelID
        }
        return modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultImageModelID
            : modelID
    }

    // MARK: - Test Text Model

    private func testTextModel() async {
        isTestingText = true
        textTestResult = ""

        guard let apiKey = CloudCredentialStore.bearerToken(for: provider) else {
            textTestResult = "No API key configured."
            isTestingText = false
            return
        }

        let modelID = resolvedTextModelID()

        do {
            let responseText: String

            if provider == .huggingFace {
                // HuggingFace SDK path
                let hfClient = InferenceClient(host: InferenceClient.defaultHost, bearerToken: apiKey)
                let messages: [ChatCompletion.Message] = [
                    .init(role: .system, content: .text("You are a helpful assistant.")),
                    .init(role: .user, content: .text("Say hello in one sentence."))
                ]
                let response = try await hfClient.chatCompletion(
                    model: modelID,
                    messages: messages,
                    maxTokens: 60
                )
                guard let choice = response.choices.first else {
                    throw CloudProviderError.unparsableResponse
                }
                switch choice.message.content {
                case .text(let text):
                    responseText = text
                case .mixed(let items):
                    let parts = items.compactMap { item -> String? in
                        if case .text(let text) = item { return text }
                        return nil
                    }
                    responseText = parts.joined(separator: " ")
                case .none:
                    throw CloudProviderError.unparsableResponse
                }
            } else {
                // OpenAI-compatible path (OpenRouter / Together AI)
                let client = OpenAICompatibleClient()
                let data = try await client.chatCompletion(
                    url: provider.chatCompletionURL,
                    apiKey: apiKey,
                    model: modelID,
                    systemPrompt: "You are a helpful assistant.",
                    userPrompt: "Say hello in one sentence.",
                    maxTokens: 60,
                    extraHeaders: provider.extraHeaders
                )
                if let text = StoryDecoding.extractTextContent(from: data) {
                    responseText = text
                } else if let raw = String(data: data, encoding: .utf8) {
                    responseText = raw
                } else {
                    throw CloudProviderError.unparsableResponse
                }
            }

            let snippet = String(responseText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            textTestResult = "Text OK (\(modelID)): \(snippet)"
        } catch {
            textTestResult = "Text failed: \(verboseError(error))"
        }

        isTestingText = false
    }

    /// Returns a detailed error description. Many SDK errors (e.g. HuggingFace
    /// `HTTPClientError`) have unhelpful `localizedDescription`; falling back to
    /// `String(describing:)` surfaces the actual enum case and associated values.
    private func verboseError(_ error: Error) -> String {
        let localized = error.localizedDescription
        let described = String(describing: error)
        // If localizedDescription is generic/unhelpful, prefer the full description
        if localized.contains("error 1") || localized.contains("error 0")
            || localized == described || localized.count < 10 {
            return described
        }
        return localized
    }

    // MARK: - Test Image Model

    private func testImageModel() async {
        isTestingImage = true
        imageTestResult = ""

        guard let apiKey = CloudCredentialStore.bearerToken(for: provider) else {
            imageTestResult = "No API key configured."
            isTestingImage = false
            return
        }

        let modelID = resolvedImageModelID()
        let prompt = "A friendly cartoon cat in a sunny garden, children's book illustration"

        do {
            let image: CGImage

            if provider == .huggingFace {
                // Direct HF Inference API — the SDK's /v1/images/generations is a confirmed 404.
                // The working endpoint is /hf-inference/models/{model}, returning raw image bytes.
                let url = URL(string: "https://router.huggingface.co/hf-inference/models/\(modelID)")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 120

                let body: [String: Any] = ["inputs": prompt]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, urlResponse) = try await URLSession.shared.data(for: request)
                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    throw CloudProviderError.unparsableResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw CloudProviderError.httpError(
                        statusCode: httpResponse.statusCode,
                        message: String(detail.prefix(500))
                    )
                }
                // Response is raw image bytes (JPEG)
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    throw CloudProviderError.imageDecodingFailed
                }
                image = cgImage
            } else {
                // OpenAI-compatible path (OpenRouter / Together AI)
                let client = OpenAICompatibleClient()
                image = try await client.imageGeneration(
                    url: provider.imageGenerationURL,
                    apiKey: apiKey,
                    model: modelID,
                    prompt: prompt,
                    size: "512x512",
                    extraHeaders: provider.extraHeaders
                )
            }

            imageTestResult = "Image OK (\(modelID)): \(image.width)x\(image.height)"
        } catch {
            imageTestResult = "Image failed: \(verboseError(error))"
        }

        isTestingImage = false
    }
}

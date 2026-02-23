import CoreGraphics
import HuggingFace
import ImageIO
import SwiftUI

/// Consolidated debug and diagnostics panel.
/// Shows test buttons for all providers (premium proxy + cloud) and current config info.
struct DebugSettingsTab: View {
    @Binding var settings: ModelSelectionSettings
    @Bindable var modelCache: CloudModelListCache

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
            devBypassSection
            premiumProxySection
            cloudProviderTestsSection
            diagnosticsSection
        }
    }

    // MARK: - Dev Bypass Secret

    private var devBypassSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Dev Bypass",
                subtitle: "Secret token to unlock premium and debug features when they are disabled in production.",
                systemImage: "key.fill"
            )

            DevBypassSecretField()
        }
    }

    // MARK: - Premium Proxy Tests

    private var premiumProxySection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Premium Proxy",
                subtitle: "Test the Vercel proxy endpoints that route to OpenAI.",
                systemImage: "crown.fill"
            )

            PremiumTextTestRow()
            PremiumImageTestRow()
            PremiumConfigRow()
        }
    }

    // MARK: - Cloud Provider Tests

    private var cloudProviderTestsSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Cloud Providers",
                subtitle: "Test connection, text, and image generation for each cloud provider.",
                systemImage: "cloud"
            )

            ForEach(activeCloudProviders, id: \.self) { provider in
                CloudProviderTestGroup(
                    provider: provider,
                    settings: $settings,
                    modelCache: modelCache
                )

                if provider != activeCloudProviders.last {
                    Divider()
                        .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)
                }
            }
        }
    }

    /// Providers that have a saved API key or use the proxy.
    private var activeCloudProviders: [CloudProvider] {
        CloudProvider.allCases.filter { provider in
            if provider.usesProxy { return false }  // Premium proxy is tested above
            return CloudCredentialStore.bearerToken(for: provider) != nil
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Diagnostics",
                subtitle: "Current configuration and app info.",
                systemImage: "info.circle"
            )

            let premiumState = PremiumStore.load()

            diagnosticRow("Premium Tier", value: premiumState.tier.displayName)
            diagnosticRow("Text Provider", value: settings.textProvider.displayName)
            diagnosticRow("Image Provider", value: settings.imageProvider.displayName)
            diagnosticRow("Text Model", value: settings.resolvedTextModelLabel)
            diagnosticRow("Image Model", value: settings.resolvedImageModelLabel)
            diagnosticRow("App Version", value: appVersion)
            diagnosticRow("Build", value: appBuild)
        }
    }

    private func diagnosticRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)
            Spacer()
            Text(value)
                .font(StoryJuicerTypography.settingsMeta.monospaced())
                .foregroundStyle(Color.sjText)
                .textSelection(.enabled)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}

// MARK: - Dev Bypass Secret Field

private struct DevBypassSecretField: View {
    @AppStorage("devBypassSecret") private var secret: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack {
                SecureField("Bypass secret", text: $secret)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                if !secret.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                        .font(.system(size: 14))
                }
            }

            Text("Stored locally. Sent as X-Dev-Bypass header with all premium and debug requests.")
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjMuted)
        }
    }
}

// MARK: - Test Result Display

/// Shows test result text with a "Copy" button when the result is an error.
private struct TestResultView: View {
    let result: String
    let successPrefix: String
    @State private var copied = false

    private var isSuccess: Bool { result.hasPrefix(successPrefix) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result)
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(isSuccess ? Color.sjSecondaryText : Color.sjCoral)
                .lineLimit(6)
                .textSelection(.enabled)

            if !isSuccess {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy Error", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Premium Text Test

private struct PremiumTextTestRow: View {
    @State private var isTesting = false
    @State private var result = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await runTest() }
                } label: {
                    if isTesting {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Premium Text", systemImage: "text.bubble")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isTesting)
            }

            if !result.isEmpty {
                TestResultView(result: result, successPrefix: "Text OK")
            }
        }
    }

    private func runTest() async {
        isTesting = true
        result = ""

        do {
            let client = OpenAICompatibleClient()
            let data = try await client.chatCompletion(
                url: CloudProvider.openAI.chatCompletionURL,
                apiKey: "",
                model: CloudProvider.openAI.defaultTextModelID,
                systemPrompt: "You are a helpful assistant.",
                userPrompt: "Say hello in one sentence.",
                maxTokens: 60,
                extraHeaders: CloudProvider.openAI.extraHeaders,
                skipAuth: true
            )
            if let text = StoryDecoding.extractTextContent(from: data) {
                let snippet = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
                result = "Text OK: \(snippet)"
            } else if let raw = String(data: data, encoding: .utf8) {
                result = "Text OK (raw): \(String(raw.prefix(120)))"
            } else {
                result = "Response received but could not parse text."
            }
        } catch {
            result = "Text failed: \(verboseError(error))"
        }

        isTesting = false
    }
}

// MARK: - Premium Image Test

private struct PremiumImageTestRow: View {
    @State private var isTesting = false
    @State private var result = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await runTest() }
                } label: {
                    if isTesting {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Premium Image", systemImage: "photo")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isTesting)
            }

            if !result.isEmpty {
                TestResultView(result: result, successPrefix: "Image OK")
            }
        }
    }

    private func runTest() async {
        isTesting = true
        result = ""

        do {
            let client = OpenAICompatibleClient()
            let image = try await client.imageGeneration(
                url: CloudProvider.openAI.imageGenerationURL,
                apiKey: "",
                model: CloudProvider.openAI.defaultImageModelID,
                prompt: "A friendly fox reading a book, children's illustration",
                size: "1024x1024",
                extraHeaders: CloudProvider.openAI.extraHeaders,
                skipAuth: true,
                tier: "standard"
            )
            result = "Image OK: \(image.width)x\(image.height)"
        } catch {
            result = "Image failed: \(verboseError(error))"
        }

        isTesting = false
    }
}

// MARK: - Premium Config Display

private struct PremiumConfigRow: View {
    @State private var isFetching = false
    @State private var configText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Button {
                Task { await fetchConfig() }
            } label: {
                if isFetching {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("Fetching...")
                    }
                } else {
                    Label("Fetch Premium Config", systemImage: "gear")
                }
            }
            .buttonStyle(.glass)
            .disabled(isFetching)

            if !configText.isEmpty {
                // Config display: errors get copy button, success shows monospaced text
                if configText.hasPrefix("Error") {
                    TestResultView(result: configText, successPrefix: "___never_match___")
                } else {
                    Text(configText)
                        .font(StoryJuicerTypography.settingsMeta.monospaced())
                        .foregroundStyle(Color.sjSecondaryText)
                        .lineLimit(10)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func fetchConfig() async {
        isFetching = true
        configText = ""

        guard let url = URL(string: "https://storyfox.app/api/premium/config") else {
            configText = "Error: Invalid URL"
            isFetching = false
            return
        }

        do {
            var request = URLRequest(url: url)
            for (key, value) in CloudProvider.openAI.extraHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let lines = json.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }
                configText = lines.joined(separator: "\n")
            } else {
                configText = String(data: data, encoding: .utf8) ?? "Unparsable response"
            }
        } catch {
            configText = "Error: \(error.localizedDescription)"
        }

        isFetching = false
    }
}

// MARK: - Cloud Provider Test Group

private struct CloudProviderTestGroup: View {
    let provider: CloudProvider
    @Binding var settings: ModelSelectionSettings
    @Bindable var modelCache: CloudModelListCache

    @State private var isTesting = false
    @State private var testResult = ""
    @State private var isTestingText = false
    @State private var textTestResult = ""
    @State private var isTestingImage = false
    @State private var imageTestResult = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Text(provider.displayName)
                .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                .foregroundStyle(Color.sjText)

            // Test Connection
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button(isTesting ? "Testing..." : "Test Connection") {
                    Task { await testConnection() }
                }
                .buttonStyle(.glass)
                .disabled(isTesting)

                if !testResult.isEmpty {
                    TestResultView(result: testResult, successPrefix: "Connected")
                }
            }

            // Test Text Model
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await testTextModel() }
                } label: {
                    if isTestingText {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Text", systemImage: "text.bubble")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isTestingText)

                if !textTestResult.isEmpty {
                    TestResultView(result: textTestResult, successPrefix: "Text OK")
                }
            }

            // Test Image Model
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await testImageModel() }
                } label: {
                    if isTestingImage {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Image", systemImage: "photo")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isTestingImage)

                if !imageTestResult.isEmpty {
                    TestResultView(result: imageTestResult, successPrefix: "Image OK")
                }
            }
        }
    }

    // MARK: - Test Connection

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
        case .openAI:      return provider.defaultTextModelID
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
        case .openAI:      return provider.defaultImageModelID
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
                let url = await HFInferenceRouter.shared.inferenceURL(for: modelID, apiKey: apiKey)
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
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    throw CloudProviderError.imageDecodingFailed
                }
                image = cgImage
            } else {
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

// MARK: - Shared Helpers

/// Returns a detailed error description. Many SDK errors (e.g. HuggingFace
/// `HTTPClientError`) have unhelpful `localizedDescription`; falling back to
/// `String(describing:)` surfaces the actual enum case and associated values.
private func verboseError(_ error: Error) -> String {
    let localized = error.localizedDescription
    let described = String(describing: error)
    if localized.contains("error 1") || localized.contains("error 0")
        || localized == described || localized.count < 10 {
        return described
    }
    return localized
}

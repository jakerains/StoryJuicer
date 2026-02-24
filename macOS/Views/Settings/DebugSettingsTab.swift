import CoreGraphics
import FoundationModels
import HuggingFace
import ImageIO
import ImagePlayground
import SwiftUI

/// Consolidated debug and diagnostics panel.
/// Shows test buttons for all providers (premium proxy + cloud) and current config info.
struct DebugSettingsTab: View {
    @Binding var settings: ModelSelectionSettings
    @Bindable var modelCache: CloudModelListCache
    var onLock: () -> Void

    @State private var showLockConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
            verboseLoggingSection
            providerAvailabilitySection
            premiumProxySection
            cloudProviderTestsSection
            contentSafetyTesterSection
            cacheManagementSection
            diagnosticsSection
            devAccessSection
        }
    }

    // MARK: - Verbose Generation Logging

    private var verboseLoggingSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Generation Logging",
                subtitle: "Write a detailed Markdown log for every generation session — captures all prompts, responses, and timing.",
                systemImage: "doc.text.magnifyingglass"
            )

            VerboseLoggingControls()
        }
    }

    // MARK: - Provider Availability

    private var providerAvailabilitySection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Provider Availability",
                subtitle: "At-a-glance status of every text and image generation provider.",
                systemImage: "antenna.radiowaves.left.and.right"
            )

            ProviderAvailabilityPanel()
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

    /// All non-proxy providers — always shown so test buttons are accessible.
    /// Each test row handles missing credentials with its own "No API key" message.
    private var activeCloudProviders: [CloudProvider] {
        CloudProvider.allCases.filter { !$0.usesProxy }
    }

    // MARK: - Content Safety Tester

    private var contentSafetyTesterSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Content Safety Tester",
                subtitle: "Test how the safety pipeline processes any concept or image prompt.",
                systemImage: "shield.checkmark"
            )

            ContentSafetyTester()
        }
    }

    // MARK: - Cache Management

    private var cacheManagementSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Cache Management",
                subtitle: "Clear stale caches that cause confusion during development.",
                systemImage: "trash.circle"
            )

            CacheManagementPanel(modelCache: modelCache, settings: $settings)
        }
    }

    // MARK: - Lock Developer Mode

    private var devAccessSection: some View {
        SettingsPanelCard {
            SettingsSectionHeader(
                title: "Developer Access",
                subtitle: "Lock developer mode to hide Premium and Debug tabs.",
                systemImage: "lock.shield"
            )

            Button(role: .destructive) {
                showLockConfirm = true
            } label: {
                Label("Lock Developer Mode", systemImage: "lock.fill")
            }
            .buttonStyle(.glassProminent)
            .alert("Lock Developer Mode?", isPresented: $showLockConfirm) {
                Button("Lock", role: .destructive) {
                    onLock()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your bypass secret and hide Premium and Debug tabs. You can re-enable by tapping the version number 7 times in About.")
            }
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
            let effective = effectiveSettings(premium: premiumState)

            diagnosticRow("Premium Tier", value: premiumState.tier.displayName)
            diagnosticRow("Text Provider", value: effective.textProvider)
            diagnosticRow("Image Provider", value: effective.imageProvider)
            diagnosticRow("Text Model", value: effective.textModel)
            diagnosticRow("Image Model", value: effective.imageModel)
            diagnosticRow("App Version", value: appVersion)
            diagnosticRow("Build", value: appBuild)

            Divider()
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.small)

            CopyDebugInfoButton(
                premiumTier: premiumState.tier.displayName,
                textProvider: effective.textProvider,
                imageProvider: effective.imageProvider,
                textModel: effective.textModel,
                imageModel: effective.imageModel,
                appVersion: appVersion,
                appBuild: appBuild
            )
        }
    }

    /// Computes the effective (runtime) providers and models, applying the
    /// same premium override that `CreationViewModel.squeezeStory()` uses.
    private func effectiveSettings(premium: PremiumState) -> (textProvider: String, imageProvider: String, textModel: String, imageModel: String) {
        if premium.tier == .premiumPlus {
            return (
                textProvider: "OpenAI (Premium Plus)",
                imageProvider: "OpenAI (Premium Plus)",
                textModel: "gpt-5.2",
                imageModel: "gpt-image-1.5"
            )
        }
        if premium.tier == .premium {
            return (
                textProvider: "OpenAI (Premium)",
                imageProvider: "OpenAI (Premium)",
                textModel: CloudProvider.openAI.defaultTextModelID,
                imageModel: CloudProvider.openAI.defaultImageModelID
            )
        }
        return (
            textProvider: settings.textProvider.displayName,
            imageProvider: settings.imageProvider.displayName,
            textModel: settings.resolvedTextModelLabel,
            imageModel: settings.resolvedImageModelLabel
        )
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

// MARK: - Provider Availability Panel

private struct ProviderAvailabilityPanel: View {
    @State private var textStatus: [StoryTextProvider: ProviderStatus] = [:]
    @State private var imageStatus: [StoryImageProvider: ProviderStatus] = [:]
    @State private var isRefreshing = false

    private enum ProviderStatus {
        case available
        case unavailable(String)
        case hidden

        var color: Color {
            switch self {
            case .available: .green
            case .unavailable: .red
            case .hidden: .secondary
            }
        }

        var label: String {
            switch self {
            case .available: "Available"
            case .unavailable(let reason): reason
            case .hidden: "Hidden"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Text("Text Providers")
                .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                .foregroundStyle(Color.sjText)

            ForEach(StoryTextProvider.allCases, id: \.self) { provider in
                statusRow(
                    name: provider.displayName,
                    status: textStatus[provider] ?? .unavailable("Checking…")
                )
            }

            Divider()

            Text("Image Providers")
                .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                .foregroundStyle(Color.sjText)

            ForEach(StoryImageProvider.allCases, id: \.self) { provider in
                statusRow(
                    name: provider.displayName,
                    status: imageStatus[provider] ?? .unavailable("Checking…")
                )
            }

            Button {
                Task { await refreshAll() }
            } label: {
                if isRefreshing {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("Refreshing…")
                    }
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.glass)
            .disabled(isRefreshing)
        }
        .task { await refreshAll() }
    }

    private func statusRow(name: String, status: ProviderStatus) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(StoryJuicerTypography.settingsBody)
                .foregroundStyle(Color.sjText)
            Spacer()
            Text(status.label)
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(status.color == .secondary ? Color.sjMuted : Color.sjSecondaryText)
                .lineLimit(1)
        }
    }

    private func refreshAll() async {
        isRefreshing = true

        // Text providers
        for provider in StoryTextProvider.allCases {
            textStatus[provider] = await checkTextProvider(provider)
        }

        // Image providers
        for provider in StoryImageProvider.allCases {
            imageStatus[provider] = await checkImageProvider(provider)
        }

        isRefreshing = false
    }

    private func checkTextProvider(_ provider: StoryTextProvider) async -> ProviderStatus {
        switch provider {
        case .appleFoundation:
            return SystemLanguageModel.default.availability == .available
                ? .available : .unavailable("Not available")
        case .mlxSwift:
            return .available
        case .huggingFace:
            return CloudCredentialStore.isAuthenticated(for: .huggingFace)
                ? .available : .unavailable("No credentials")
        case .openAI:
            let hasAuth = CloudCredentialStore.isAuthenticated(for: .openAI)
            let premium = PremiumStore.load()
            if premium.tier == .premium || premium.tier == .premiumPlus { return .available }
            return hasAuth ? .available : .unavailable("No credentials")
        case .openRouter:
            return CloudCredentialStore.isAuthenticated(for: .openRouter)
                ? .available : .unavailable("No credentials")
        case .togetherAI:
            return CloudCredentialStore.isAuthenticated(for: .togetherAI)
                ? .available : .unavailable("No credentials")
        }
    }

    private func checkImageProvider(_ provider: StoryImageProvider) async -> ProviderStatus {
        switch provider {
        case .imagePlayground:
            let isAvailable = await MainActor.run {
                ImagePlaygroundViewController.isAvailable
            }
            return isAvailable ? .available : .unavailable("Not available")
        case .diffusers:
            return .hidden
        case .huggingFace:
            return CloudCredentialStore.isAuthenticated(for: .huggingFace)
                ? .available : .unavailable("No credentials")
        case .openAI:
            let hasAuth = CloudCredentialStore.isAuthenticated(for: .openAI)
            let premium = PremiumStore.load()
            if premium.tier == .premium || premium.tier == .premiumPlus { return .available }
            return hasAuth ? .available : .unavailable("No credentials")
        case .openRouter:
            return CloudCredentialStore.isAuthenticated(for: .openRouter)
                ? .available : .unavailable("No credentials")
        case .togetherAI:
            return CloudCredentialStore.isAuthenticated(for: .togetherAI)
                ? .available : .unavailable("No credentials")
        }
    }
}

// MARK: - Content Safety Tester

private struct ContentSafetyTester: View {
    @State private var input = ""
    @State private var isTestingConcept = false
    @State private var isTestingPrompt = false
    @State private var conceptResult: SafetyTestResult?
    @State private var promptResult: SafetyTestResult?

    private struct SafetyTestResult {
        var isAllowed: Bool
        var reason: String?
        var sanitized: String?
        var hasUnsafe: Bool?
        var syncPrompt: String?
        var syncCharCount: Int?
        var asyncPrompt: String?
        var asyncCharCount: Int?
        var isLoadingAsync: Bool = false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            TextField("Enter a concept or image prompt…", text: $input)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Button {
                    Task { await testConcept() }
                } label: {
                    if isTestingConcept {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Testing…")
                        }
                    } else {
                        Label("Test Concept", systemImage: "text.magnifyingglass")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(input.isEmpty || isTestingConcept)

                Button {
                    Task { await testImagePrompt() }
                } label: {
                    if isTestingPrompt {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Testing…")
                        }
                    } else {
                        Label("Test Image Prompt", systemImage: "photo.badge.checkmark")
                    }
                }
                .buttonStyle(.glass)
                .disabled(input.isEmpty || isTestingPrompt)
            }

            if let result = conceptResult {
                safetyResultView(title: "Concept Validation", result: result)
            }

            if let result = promptResult {
                safetyResultView(title: "Image Prompt Pipeline", result: result)
            }
        }
    }

    private func safetyResultView(title: String, result: SafetyTestResult) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            HStack(spacing: 6) {
                Image(systemName: result.isAllowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.isAllowed ? .green : .red)
                Text(title)
                    .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                    .foregroundStyle(Color.sjText)
                Text(result.isAllowed ? "ALLOWED" : "BLOCKED")
                    .font(.system(size: 10, weight: .bold).monospaced())
                    .foregroundStyle(result.isAllowed ? .green : .red)
            }

            if let reason = result.reason {
                safetyRow("Reason", value: reason, isError: true)
            }
            if let sanitized = result.sanitized {
                safetyRow("Sanitized", value: sanitized)
            }
            if let hasUnsafe = result.hasUnsafe {
                safetyRow("Has unsafe content", value: hasUnsafe ? "Yes" : "No", isError: hasUnsafe)
            }
            if let sync = result.syncPrompt {
                safetyRow("Safe prompt (sync)", value: "\(sync) [\(result.syncCharCount ?? 0) chars]")
            }
            if result.isLoadingAsync {
                HStack(spacing: 4) {
                    Text("Safe prompt (FM)")
                        .font(StoryJuicerTypography.settingsMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                    ProgressView().controlSize(.mini)
                }
            } else if let asyncP = result.asyncPrompt {
                safetyRow("Safe prompt (FM)", value: "\(asyncP) [\(result.asyncCharCount ?? 0) chars]")
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.small)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func safetyRow(_ label: String, value: String, isError: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)
            Text(value)
                .font(StoryJuicerTypography.settingsMeta.monospaced())
                .foregroundStyle(isError ? Color.sjCoral : Color.sjText)
                .textSelection(.enabled)
                .lineLimit(4)
        }
    }

    private func testConcept() async {
        isTestingConcept = true
        let checkResult = ContentSafetyPolicy.validateConcept(input)
        let hasUnsafe = ContentSafetyPolicy.hasUnsafeContent(input)
        let sanitized = ContentSafetyPolicy.sanitizeConcept(input)

        switch checkResult {
        case .allowed(let clean):
            conceptResult = SafetyTestResult(
                isAllowed: true,
                sanitized: clean,
                hasUnsafe: hasUnsafe
            )
        case .blocked(let reason):
            conceptResult = SafetyTestResult(
                isAllowed: false,
                reason: reason,
                sanitized: sanitized,
                hasUnsafe: hasUnsafe
            )
        }
        isTestingConcept = false
    }

    private func testImagePrompt() async {
        isTestingPrompt = true
        let hasUnsafe = ContentSafetyPolicy.hasUnsafeContent(input)
        let syncPrompt = ContentSafetyPolicy.safeIllustrationPrompt(input)

        promptResult = SafetyTestResult(
            isAllowed: !hasUnsafe,
            hasUnsafe: hasUnsafe,
            syncPrompt: syncPrompt,
            syncCharCount: syncPrompt.count,
            isLoadingAsync: true
        )

        let asyncPrompt = await ContentSafetyPolicy.safeIllustrationPromptAsync(input)
        promptResult?.asyncPrompt = asyncPrompt
        promptResult?.asyncCharCount = asyncPrompt.count
        promptResult?.isLoadingAsync = false

        isTestingPrompt = false
    }
}

// MARK: - Cache Management Panel

private struct CacheManagementPanel: View {
    @Bindable var modelCache: CloudModelListCache
    @Binding var settings: ModelSelectionSettings
    @State private var isClearing = false
    @State private var showResetConfirm = false
    @State private var showDeleteDiagnosticsConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            // Cloud Model Lists
            cacheRow(
                title: "Cloud Model Lists",
                description: "In-memory + UserDefaults cache of provider model lists (10min TTL)"
            ) {
                Button {
                    Task {
                        isClearing = true
                        modelCache.clearAllCaches()
                        await modelCache.refreshAllAuthenticated()
                        isClearing = false
                    }
                } label: {
                    if isClearing {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Clearing…")
                        }
                    } else {
                        Label("Clear & Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(isClearing)
            }

            Divider()

            // HF Inference Router
            cacheRow(
                title: "HF Inference Router",
                description: "Cached provider-to-URL mappings for HuggingFace models"
            ) {
                Button {
                    Task { await HFInferenceRouter.shared.clearCache() }
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            Divider()

            // Diagnostics Logs
            cacheRow(
                title: "Diagnostics Logs",
                description: "JSONL logs for image generation sessions"
            ) {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Button {
                        let path = GenerationDiagnosticsLogger.logFilePathString()
                        let folderURL = URL(fileURLWithPath: path).deletingLastPathComponent()
                        NSWorkspace.shared.open(folderURL)
                    } label: {
                        Label("Open", systemImage: "folder")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        showDeleteDiagnosticsConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .alert("Delete Diagnostics Logs?", isPresented: $showDeleteDiagnosticsConfirm) {
                        Button("Delete", role: .destructive) {
                            let path = GenerationDiagnosticsLogger.logFilePathString()
                            try? FileManager.default.removeItem(atPath: path)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all image generation diagnostic logs.")
                    }
                }
            }

            Divider()

            // Model Settings Reset
            cacheRow(
                title: "Model Settings",
                description: "Reset all provider and model selections to factory defaults"
            ) {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .alert("Reset Model Settings?", isPresented: $showResetConfirm) {
                    Button("Reset", role: .destructive) {
                        settings = .default
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will revert all provider and model selections to their default values.")
                }
            }
        }
    }

    private func cacheRow<Action: View>(
        title: String,
        description: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Text(title)
                .font(StoryJuicerTypography.settingsBody.weight(.semibold))
                .foregroundStyle(Color.sjText)
            Text(description)
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjMuted)
            action()
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
            let text = try await client.responsesAPI(
                url: CloudProvider.openAI.chatCompletionURL,
                instructions: "You are a helpful assistant.",
                userPrompt: "Say hello in one sentence.",
                maxOutputTokens: 60,
                tier: "standard",
                extraHeaders: CloudProvider.openAI.extraHeaders
            )
            let snippet = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
            result = "Text OK: \(snippet)"
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

    /// Resolves a bearer token from CloudCredentialStore or HFTokenStore.
    private func resolvedBearerToken() -> String? {
        if let token = CloudCredentialStore.bearerToken(for: provider) {
            return token
        }
        if provider == .huggingFace {
            let alias = settings.resolvedHFTokenAlias
            if let token = HFTokenStore.loadToken(alias: alias), !token.isEmpty {
                return token
            }
        }
        return nil
    }

    // MARK: - Test Connection

    private func testConnection() async {
        isTesting = true
        testResult = ""

        guard let apiKey = resolvedBearerToken() else {
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

        guard let apiKey = resolvedBearerToken() else {
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

        guard let apiKey = resolvedBearerToken() else {
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

// MARK: - Verbose Logging Controls

private struct VerboseLoggingControls: View {
    @AppStorage("verboseLoggingEnabled") private var verboseLoggingEnabled: Bool = false
    @AppStorage("verboseLoggingFolderPath") private var verboseLoggingFolderPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Toggle("Enable verbose generation logging", isOn: $verboseLoggingEnabled)
                .font(StoryJuicerTypography.settingsBody)

            if verboseLoggingEnabled {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Text(abbreviatedPath)
                        .font(StoryJuicerTypography.settingsMeta.monospaced())
                        .foregroundStyle(Color.sjSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Choose\u{2026}") {
                        chooseFolder()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                if !verboseLoggingFolderPath.isEmpty {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: verboseLoggingFolderPath))
                    } label: {
                        Label("Open Logs Folder", systemImage: "folder")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }

    private var abbreviatedPath: String {
        guard !verboseLoggingFolderPath.isEmpty else { return "No folder selected" }
        return (verboseLoggingFolderPath as NSString).abbreviatingWithTildeInPath
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder for verbose generation logs"

        if panel.runModal() == .OK, let url = panel.url {
            verboseLoggingFolderPath = url.path
        }
    }
}

// MARK: - Copy Debug Info Button

private struct CopyDebugInfoButton: View {
    let premiumTier: String
    let textProvider: String
    let imageProvider: String
    let textModel: String
    let imageModel: String
    let appVersion: String
    let appBuild: String

    @State private var copied = false

    var body: some View {
        Button {
            let info = [
                "Premium Tier: \(premiumTier)",
                "Text Provider: \(textProvider)",
                "Image Provider: \(imageProvider)",
                "Text Model: \(textModel)",
                "Image Model: \(imageModel)",
                "App Version: \(appVersion)",
                "Build: \(appBuild)",
                "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)"
            ].joined(separator: "\n")

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(info, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
        } label: {
            Label(copied ? "Copied!" : "Copy Debug Info", systemImage: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.glass)
        .controlSize(.small)
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

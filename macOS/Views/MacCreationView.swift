import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Simplified generation source: on-device Apple Intelligence or cloud via HuggingFace.
private enum GenerationMode: String, CaseIterable, Identifiable {
    case local
    case cloud

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local: "Local"
        case .cloud: "Cloud"
        }
    }

    var systemImage: String {
        switch self {
        case .local: "desktopcomputer"
        case .cloud: "cloud"
        }
    }
}

struct MacCreationView: View {
    @Bindable var viewModel: CreationViewModel
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground

    @State private var animateTitle = false
    @State private var creationMode: CreationMode = .quick
    @State private var qaViewModel = StoryQAViewModel()
    @State private var showBookSetupPopover = false
    @State private var generationMode: GenerationMode = {
        let settings = ModelSelectionStore.load()
        return settings.textProvider.isCloud ? .cloud : .local
    }()
    @FocusState private var editorFocused: Bool
    @AppStorage("devModeUnlocked") private var devModeUnlocked: Bool = false
    @State private var premiumState: PremiumState = PremiumStore.load()

    /// Premium is only active when dev mode is unlocked AND the user has enabled a premium tier.
    private var isPremiumActive: Bool {
        devModeUnlocked && premiumState.tier.isActive
    }

    private var isPremiumPlus: Bool {
        devModeUnlocked && premiumState.tier == .premiumPlus
    }

    private var hasCloudCredential: Bool {
        CloudCredentialStore.isAuthenticated(for: .huggingFace)
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection

                    titleLine

                    // Controls row — always visible, right under the title
                    controlsRow
                        .padding(.top, StoryJuicerGlassTokens.Spacing.large)

                    if case .failed(let message) = viewModel.phase {
                        ErrorBanner(
                            message: message,
                            onRetry: {
                                if creationMode == .author {
                                    viewModel.illustrateAuthorStory()
                                } else {
                                    viewModel.squeezeStory()
                                }
                            },
                            onDismiss: { viewModel.reset() }
                        )
                        .padding(.top, StoryJuicerGlassTokens.Spacing.large)
                    }

                    if creationMode == .author {
                        // Author Mode: page-by-page story editor
                        AuthorStoryEditor(viewModel: viewModel)
                            .padding(.top, StoryJuicerGlassTokens.Spacing.medium)
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))

                        SqueezeButton(
                            title: "Illustrate My Story",
                            subtitle: "Generate illustrations for your pages",
                            icon: "paintbrush.pointed.fill",
                            isEnabled: viewModel.canIllustrateAuthorStory
                        ) {
                            viewModel.illustrateAuthorStory()
                        }
                        .padding(.top, StoryJuicerGlassTokens.Spacing.large)
                    } else {
                        conceptSection
                            .padding(.top, StoryJuicerGlassTokens.Spacing.medium)

                        // Q&A flow when guided mode is active and running
                        if creationMode == .guided && qaViewModel.phase != .idle {
                            StoryQAFlowView(
                                viewModel: qaViewModel,
                                onComplete: { enrichedConcept in
                                    viewModel.storyConcept = enrichedConcept
                                    viewModel.isEnrichedConcept = true
                                    viewModel.squeezeStory()
                                },
                                onCancel: {
                                    qaViewModel.cancel()
                                    withAnimation(StoryJuicerMotion.standard) {
                                        creationMode = .quick
                                    }
                                }
                            )
                            .padding(.top, StoryJuicerGlassTokens.Spacing.large)
                        }

                        // Premium Plus photo upload section
                        if isPremiumPlus {
                            CharacterPhotosSection(characterPhotos: $viewModel.characterPhotos)
                                .padding(.top, StoryJuicerGlassTokens.Spacing.medium)
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        }

                        if creationMode == .quick {
                            SqueezeButton(
                                title: isPremiumActive ? "Create Story" : "Squeeze a Story",
                                subtitle: isPremiumPlus
                                    ? "Creating with Premium Plus models"
                                    : isPremiumActive
                                        ? "Creating with Premium models"
                                        : "AI writes & illustrates your idea",
                                isEnabled: viewModel.canGenerate
                            ) {
                                viewModel.squeezeStory()
                            }
                            .padding(.top, StoryJuicerGlassTokens.Spacing.large)
                        } else if creationMode == .guided && qaViewModel.phase == .idle {
                            SqueezeButton(
                                title: "Explore Your Story",
                                subtitle: "AI will ask questions to enrich your concept",
                                icon: "sparkle.magnifyingglass",
                                isEnabled: viewModel.canGenerate
                            ) {
                                qaViewModel.startQA(concept: viewModel.storyConcept)
                            }
                            .padding(.top, StoryJuicerGlassTokens.Spacing.large)
                        }
                    }
                }
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.xLarge + 8)
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.xLarge)
                .animation(StoryJuicerMotion.emphasis, value: creationMode)
            }

            if let reason = viewModel.unavailabilityReason {
                UnavailableOverlay(reason: reason)
            }
        }
        .task {
            viewModel.generateSuggestions()
        }
        .onAppear {
            withAnimation(StoryJuicerMotion.emphasis) {
                animateTitle = true
            }
        }
        .onChange(of: viewModel.storyConcept) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.restartSuggestionCycleAfterDelay()
            } else {
                viewModel.stopSuggestionCycle()
            }
        }
        .onChange(of: creationMode) { _, newMode in
            if newMode != .quick {
                viewModel.stopSuggestionCycle()
            }
            if newMode == .author && viewModel.authorPages.allSatisfy(\.isEmpty) {
                viewModel.authorPages = ["", "", "", ""]
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

            PaperTextureOverlay()

            DriftingCloudsOverlay()
                .opacity(generationMode == .cloud ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: generationMode)

            RadialGradient(
                colors: [Color.sjHighlight.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 560
            )

            LinearGradient(
                colors: [.clear, Color.sjPeach.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Hero Section (image + sparkles)

    private var heroSection: some View {
        // The hero illustration — sparkles are positioned relative to its center
        Image("StoryFoxHero")
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 340)
            .opacity(animateTitle ? 0.85 : 0)
            .scaleEffect(animateTitle ? 1 : 0.96)
            .frame(maxWidth: .infinity, alignment: .center)
            .overlay {
                // Sparkle stars scattered around the image
                ForEach(Array(allSparkles.enumerated()), id: \.offset) { _, s in
                    SparkleStarShape()
                        .fill(s.color)
                        .frame(width: s.size, height: s.size)
                        .offset(x: s.offsetX, y: s.offsetY)
                        .opacity(animateTitle ? s.opacity : 0)
                        .scaleEffect(animateTitle ? 1.0 : 0.5)
                        .rotationEffect(.degrees(s.rotates ? (animateTitle ? 180 : 0) : 0))
                        .animation(
                            .easeInOut(duration: s.duration)
                                .repeatForever(autoreverses: true)
                                .delay(s.delay),
                            value: animateTitle
                        )
                }
            }
            .padding(.bottom, StoryJuicerGlassTokens.Spacing.xSmall)
    }

    // All sparkles — floating accents around the image + twinkling background dots
    // Offsets scaled for 340pt hero image
    private var allSparkles: [SparkleData] {
        [
            // Close sparkles around the image edges (larger, brighter)
            SparkleData(size: 16, color: .sjGold, offsetX: -200, offsetY: -50, delay: 0, duration: 5, rotates: true, opacity: 0.8),
            SparkleData(size: 13, color: .sjCoral, offsetX: 195, offsetY: -80, delay: 1.5, duration: 4.5, opacity: 0.75),
            SparkleData(size: 12, color: .sjHighlight, offsetX: 210, offsetY: 60, delay: 0.8, duration: 5.5, rotates: true, opacity: 0.8),
            SparkleData(size: 11, color: .sjGold, offsetX: -215, offsetY: 75, delay: 2, duration: 6, opacity: 0.7),
            SparkleData(size: 14, color: .sjCoral, offsetX: -95, offsetY: -135, delay: 0.5, duration: 5, rotates: true, opacity: 0.75),
            SparkleData(size: 15, color: .sjGold, offsetX: 120, offsetY: -120, delay: 3, duration: 4, opacity: 0.8),
            SparkleData(size: 10, color: .sjHighlight, offsetX: -165, offsetY: 15, delay: 1, duration: 7, rotates: true, opacity: 0.7),
            SparkleData(size: 12, color: .sjGold, offsetX: 75, offsetY: 110, delay: 2.5, duration: 5.2, opacity: 0.75),

            // Wider scattered sparkles (smaller, subtler — beyond the image)
            SparkleData(size: 8, color: .sjGold, offsetX: -300, offsetY: -90, delay: 0, duration: 3, opacity: 0.4),
            SparkleData(size: 6, color: .sjCoral, offsetX: 290, offsetY: -120, delay: 1.2, duration: 2.5, opacity: 0.35),
            SparkleData(size: 9, color: .sjHighlight, offsetX: -275, offsetY: 60, delay: 0.6, duration: 3.5, opacity: 0.4),
            SparkleData(size: 6, color: .sjGold, offsetX: 270, offsetY: 105, delay: 2, duration: 2.8, opacity: 0.3),
            SparkleData(size: 7, color: .sjCoral, offsetX: -140, offsetY: -155, delay: 1.8, duration: 3.2, rotates: true, opacity: 0.35),
            SparkleData(size: 6, color: .sjGold, offsetX: 170, offsetY: -155, delay: 0.3, duration: 2.6, opacity: 0.3),
            SparkleData(size: 7, color: .sjHighlight, offsetX: -340, offsetY: -30, delay: 2.5, duration: 3, rotates: true, opacity: 0.35),
            SparkleData(size: 8, color: .sjGold, offsetX: 325, offsetY: 15, delay: 0.9, duration: 2.4, opacity: 0.4),
            SparkleData(size: 5, color: .sjCoral, offsetX: -60, offsetY: 170, delay: 1.5, duration: 3.8, opacity: 0.3),
            SparkleData(size: 5, color: .sjGold, offsetX: 60, offsetY: 170, delay: 0.4, duration: 3.3, opacity: 0.3),
            SparkleData(size: 6, color: .sjHighlight, offsetX: -245, offsetY: 140, delay: 2.2, duration: 2.7, rotates: true, opacity: 0.3),
            SparkleData(size: 7, color: .sjGold, offsetX: 240, offsetY: -25, delay: 1, duration: 3.6, opacity: 0.35),
        ]
    }

    // MARK: - Title

    private var titleLine: some View {
        Text("What story shall we create?")
            .font(.system(size: 40, weight: .bold, design: .serif))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.sjCoral, Color.sjGold, Color.sjHighlight, Color.sjCoral],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.sjGold.opacity(0.8))
                    .symbolEffect(.breathe.pulse, options: .repeating.speed(0.5))
                    .offset(x: 10, y: -8)
            }
            .overlay(alignment: .bottomLeading) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.sjGold.opacity(0.6))
                    .symbolEffect(.breathe.pulse, options: .repeating.speed(0.4))
                    .offset(x: -8, y: 5)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .offset(y: -14)
            .opacity(animateTitle ? 1 : 0)
    }

    // MARK: - Concept Input

    /// Whether the Q&A flow is actively running (not idle)
    private var isQAActive: Bool {
        creationMode == .guided && qaViewModel.phase != .idle
    }

    // MARK: - Controls Row (mode toggle + book setup)

    private var controlsRow: some View {
        HStack {
            CreationModeToggle(selection: $creationMode)

            Spacer(minLength: StoryJuicerGlassTokens.Spacing.medium)

            if isPremiumActive {
                premiumIndicatorPill
            } else {
                generationModePicker
                    .fixedSize()
            }

            bookSetupRow
                .fixedSize()
        }
    }

    private var generationModePicker: some View {
        Picker("Mode", selection: $generationMode) {
            ForEach(availableGenerationModes) { mode in
                Label(mode.displayName, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.small + 2)
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.xSmall + 2)
        .sjGlassChip(selected: false, interactive: true)
        .onChange(of: generationMode) { _, newMode in
            applyGenerationMode(newMode)
        }
    }

    private var availableGenerationModes: [GenerationMode] {
        var modes: [GenerationMode] = [.local]
        if hasCloudCredential {
            modes.append(.cloud)
        }
        return modes
    }

    private func applyGenerationMode(_ mode: GenerationMode) {
        var settings = ModelSelectionStore.load()
        switch mode {
        case .local:
            settings.textProvider = .appleFoundation
            settings.imageProvider = .imagePlayground
        case .cloud:
            settings.textProvider = .huggingFace
            settings.imageProvider = .huggingFace
        }
        ModelSelectionStore.save(settings)
    }

    private var premiumIndicatorPill: some View {
        HStack(spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
            Image(systemName: isPremiumPlus ? "bolt.shield.fill" : "crown.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.sjGold)

            Text(premiumState.tier.displayName)
                .font(StoryJuicerTypography.uiMetaStrong)
                .foregroundStyle(Color.sjGold)
        }
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.small + 2)
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.xSmall + 2)
        .background(Color.sjGold.opacity(0.12))
        .clipShape(.capsule)
        .overlay {
            Capsule()
                .strokeBorder(Color.sjGold.opacity(0.35), lineWidth: 1)
        }
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            // When guided Q&A is active, collapse the editor into a compact read-only line
            if isQAActive {
                conceptReadOnlyLine
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            } else {
                conceptEditor
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .animation(StoryJuicerMotion.emphasis, value: isQAActive)
    }

    /// Whether the suggestion typewriter should replace the TextEditor entirely.
    private var showSuggestionFacade: Bool {
        viewModel.storyConcept.isEmpty && viewModel.isSuggestionCycleActive
    }

    /// Full TextEditor for typing or editing the story concept.
    @ViewBuilder
    private var conceptEditor: some View {
        Group {
            if showSuggestionFacade {
                // Cursor-free facade — just a Text view, no NSTextView underneath.
                Text(viewModel.suggestionDisplayText)
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjCoral.opacity(0.65))
                    .opacity(viewModel.suggestionOpacity)
                    .animation(.easeOut(duration: 0.5), value: viewModel.suggestionOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 7)
                    .padding(.leading, 5)
                    .frame(minHeight: 120, maxHeight: 190)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.stopSuggestionCycle()
                        editorFocused = true
                    }
            } else {
                // Real TextEditor — only rendered once suggestions stop.
                TextEditor(text: $viewModel.storyConcept)
                    .focused($editorFocused)
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjText)
                    .frame(minHeight: 120, maxHeight: 190)
                    .overlay(alignment: .topLeading) {
                        if viewModel.storyConcept.isEmpty {
                            Text("Describe your story idea...")
                                .font(StoryJuicerTypography.uiBody)
                                .foregroundStyle(Color.sjSecondaryText)
                                .padding(.top, 7)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(StoryJuicerGlassTokens.Spacing.small)
        .background(Color.sjReadableCard.opacity(0.9))
        .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                .strokeBorder(Color.sjBorder.opacity(0.75), lineWidth: 1)
        }
    }

    /// Compact read-only line showing the concept while Q&A is active.
    private var conceptReadOnlyLine: some View {
        HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: "text.quote")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.sjCoral.opacity(0.7))
                .padding(.top, 2)

            Text(viewModel.storyConcept)
                .font(StoryJuicerTypography.uiBody.italic())
                .foregroundStyle(Color.sjSecondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.small + 2)
        .background(Color.sjReadableCard.opacity(0.5))
        .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                .strokeBorder(Color.sjBorder.opacity(0.4), lineWidth: 1)
        }
    }

    // MARK: - Book Setup Chip + Popover

    private var bookSetupRow: some View {
        Button {
            showBookSetupPopover.toggle()
        } label: {
            HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.sjCoral)

                Text("\(viewModel.pageCount) pages · \(viewModel.selectedStyle.displayName)")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjGlassInk)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.sjSecondaryText)
                    .rotationEffect(.degrees(showBookSetupPopover ? 180 : 0))
                    .animation(StoryJuicerMotion.fast, value: showBookSetupPopover)
            }
            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.medium)
            .padding(.vertical, StoryJuicerGlassTokens.Spacing.small + 2)
            .contentShape(Rectangle())
            .sjGlassChip(selected: false, interactive: true)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showBookSetupPopover, arrowEdge: .bottom) {
            bookSetupPopoverContent
        }
    }

    private var bookSetupPopoverContent: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            SettingsSectionHeader(
                title: "Book Setup",
                subtitle: "Configure pages and illustration style.",
                systemImage: "wand.and.stars"
            )

            panelDivider

            pageCountRow

            panelDivider

            stylePickerSection
        }
        .padding(StoryJuicerGlassTokens.Spacing.large)
        .frame(width: 420)
    }

    // MARK: - Settings Content (reused in popover)

    private var panelDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.sjBorder.opacity(0.2), Color.sjBorder.opacity(0.85), Color.sjBorder.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    /// Even page counts from min to max (4, 6, 8, 10, 12, 14, 16).
    private var pageCountOptions: [Int] {
        stride(from: GenerationConfig.minPages, through: GenerationConfig.maxPages, by: 2).map { $0 }
    }

    private var pageCountRow: some View {
        SettingsControlRow(
            title: "Page Count",
            description: "Choose how many pages your storybook will have."
        ) {
            Picker("Page Count", selection: $viewModel.pageCount) {
                ForEach(pageCountOptions, id: \.self) { count in
                    Text("\(count) pages").tag(count)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .settingsFieldChrome()
            .frame(width: 160)
        }
    }

    private var stylePickerSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            SettingsSectionHeader(
                title: "Illustration Style",
                subtitle: "Choose the visual treatment for every generated page.",
                systemImage: "paintbrush.fill"
            )

            if !supportsImagePlayground && ModelSelectionStore.load().imageProvider == .imagePlayground {
                warningCallout(
                    "Image Playground is not available on this device.",
                    systemImage: "exclamationmark.triangle"
                )
            }

            GlassEffectContainer(spacing: StoryJuicerGlassTokens.Spacing.medium) {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
                    ForEach(IllustrationStyle.allCases) { style in
                        Button {
                            withAnimation(StoryJuicerMotion.standard) {
                                viewModel.selectedStyle = style
                            }
                        } label: {
                            StylePickerItem(
                                style: style,
                                isSelected: viewModel.selectedStyle == style
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Illustration style \(style.displayName)")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func warningCallout(_ message: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.sjCoral)

            Text(message)
                .font(StoryJuicerTypography.settingsMeta)
                .foregroundStyle(Color.sjSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StoryJuicerGlassTokens.Spacing.small)
        .background(Color.sjCoral.opacity(0.12), in: .rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                .strokeBorder(Color.sjCoral.opacity(0.38), lineWidth: 1)
        }
    }
}

// MARK: - Sparkle Star Shape (4-point star matching landing page SVG)

/// Draws the same 4-point sparkle star used on the landing page:
/// SVG path: M12 0C12.5 7 17 11.5 24 12C17 12.5 12.5 17 12 24C11.5 17 7 12.5 0 12C7 11.5 11.5 7 12 0Z
struct SparkleStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        // Top point → right point
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.5),
            control1: CGPoint(x: w * 0.521, y: h * 0.292),
            control2: CGPoint(x: w * 0.708, y: h * 0.479)
        )
        // Right point → bottom point
        p.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.708, y: h * 0.521),
            control2: CGPoint(x: w * 0.521, y: h * 0.708)
        )
        // Bottom point → left point
        p.addCurve(
            to: CGPoint(x: 0, y: h * 0.5),
            control1: CGPoint(x: w * 0.479, y: h * 0.708),
            control2: CGPoint(x: w * 0.292, y: h * 0.521)
        )
        // Left point → top point
        p.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: w * 0.292, y: h * 0.479),
            control2: CGPoint(x: w * 0.479, y: h * 0.292)
        )
        p.closeSubpath()
        return p
    }
}

struct SparkleData {
    let size: CGFloat
    let color: Color
    let offsetX: CGFloat
    let offsetY: CGFloat
    let delay: Double
    let duration: Double
    var rotates: Bool = false
    var opacity: Double = 0.8
}

// MARK: - Drifting Clouds Background

/// Layered parallax clouds that drift when Cloud mode is active.
/// Three depth lanes — far (small, slow, faint), mid, near (large, faster, brighter).
private struct DriftingCloudsOverlay: View {
    @State private var drift = false

    // Each cloud: depth lane, shape variant, vertical position, scale, opacity, speed (seconds), start fraction (0 = off-screen left, 0.5 = mid-screen)
    private struct CloudSpec: Identifiable {
        let id: Int
        let lane: DepthLane
        let shape: Int          // 0, 1, or 2 — picks shape variant
        let yFraction: CGFloat
        let scale: CGFloat
        let speed: Double
        let startFraction: CGFloat // where the cloud begins (0 = left edge, negative = off-screen)
    }

    private enum DepthLane {
        case far, mid, near

        var opacity: Double {
            switch self {
            case .far:  0.06
            case .mid:  0.09
            case .near: 0.13
            }
        }

        var blur: CGFloat {
            switch self {
            case .far:  3.0
            case .mid:  1.5
            case .near: 0.5
            }
        }
    }

    private static let clouds: [CloudSpec] = [
        // Far lane — small, slow, hazy
        CloudSpec(id: 0,  lane: .far, shape: 0, yFraction: 0.08, scale: 0.5,  speed: 90, startFraction: 0.2),
        CloudSpec(id: 1,  lane: .far, shape: 1, yFraction: 0.28, scale: 0.45, speed: 100, startFraction: 0.65),
        CloudSpec(id: 2,  lane: .far, shape: 2, yFraction: 0.62, scale: 0.4,  speed: 95, startFraction: -0.1),
        CloudSpec(id: 3,  lane: .far, shape: 0, yFraction: 0.85, scale: 0.35, speed: 105, startFraction: 0.45),
        // Mid lane — medium
        CloudSpec(id: 4,  lane: .mid, shape: 1, yFraction: 0.15, scale: 0.75, speed: 65, startFraction: 0.4),
        CloudSpec(id: 5,  lane: .mid, shape: 2, yFraction: 0.40, scale: 0.65, speed: 70, startFraction: -0.15),
        CloudSpec(id: 6,  lane: .mid, shape: 0, yFraction: 0.70, scale: 0.7,  speed: 60, startFraction: 0.55),
        CloudSpec(id: 7,  lane: .mid, shape: 1, yFraction: 0.52, scale: 0.6,  speed: 75, startFraction: 0.1),
        // Near lane — large, brighter, faster
        CloudSpec(id: 8,  lane: .near, shape: 2, yFraction: 0.05, scale: 1.1,  speed: 42, startFraction: 0.3),
        CloudSpec(id: 9,  lane: .near, shape: 0, yFraction: 0.35, scale: 0.95, speed: 48, startFraction: -0.2),
        CloudSpec(id: 10, lane: .near, shape: 1, yFraction: 0.68, scale: 1.0,  speed: 45, startFraction: 0.6),
        CloudSpec(id: 11, lane: .near, shape: 2, yFraction: 0.88, scale: 0.85, speed: 50, startFraction: 0.05),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Self.clouds) { cloud in
                singleCloud(cloud: cloud, geoSize: geo.size)
            }
        }
        .clipped()
        .drawingGroup()
        .onAppear { drift = true }
    }

    private func singleCloud(cloud: CloudSpec, geoSize: CGSize) -> some View {
        let cloudWidth: CGFloat = 180 * cloud.scale
        let cloudHeight: CGFloat = 70 * cloud.scale
        let startX: CGFloat = geoSize.width * cloud.startFraction - 200
        let endX: CGFloat = geoSize.width + 200
        let yPos: CGFloat = geoSize.height * cloud.yFraction
        let fillColor = Color.white.opacity(cloud.lane.opacity)

        return cloudFilled(variant: cloud.shape, color: fillColor)
            .frame(width: cloudWidth, height: cloudHeight)
            .blur(radius: cloud.lane.blur)
            .offset(x: drift ? endX : startX, y: yPos)
            .animation(
                .linear(duration: cloud.speed)
                    .repeatForever(autoreverses: false),
                value: drift
            )
    }

    @ViewBuilder
    private func cloudFilled(variant: Int, color: Color) -> some View {
        switch variant {
        case 1:  FluffyCloudShape2().fill(color)
        case 2:  FluffyCloudShape3().fill(color)
        default: FluffyCloudShape1().fill(color)
        }
    }
}

// MARK: - Cloud Shape Variants (smooth continuous bezier outlines)

/// Cumulus cloud — 3 rounded bumps, tallest in the center, flat base.
private struct FluffyCloudShape1: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Start bottom-left, trace clockwise
        p.move(to: pt(0.06, 0.82, w, h))
        // Left edge curves up
        p.addQuadCurve(to: pt(0.10, 0.55, w, h), control: pt(0.02, 0.68, w, h))
        // Left bump
        p.addCurve(to: pt(0.30, 0.32, w, h),
                    control1: pt(0.10, 0.38, w, h), control2: pt(0.18, 0.28, w, h))
        // Valley between left and center
        p.addQuadCurve(to: pt(0.38, 0.35, w, h), control: pt(0.34, 0.34, w, h))
        // Center dome (tallest)
        p.addCurve(to: pt(0.62, 0.12, w, h),
                    control1: pt(0.38, 0.18, w, h), control2: pt(0.48, 0.08, w, h))
        // Valley between center and right
        p.addCurve(to: pt(0.72, 0.30, w, h),
                    control1: pt(0.70, 0.12, w, h), control2: pt(0.72, 0.22, w, h))
        // Right bump
        p.addCurve(to: pt(0.90, 0.50, w, h),
                    control1: pt(0.72, 0.38, w, h), control2: pt(0.82, 0.34, w, h))
        // Right edge curves down
        p.addQuadCurve(to: pt(0.94, 0.82, w, h), control: pt(0.98, 0.62, w, h))
        // Flat base
        p.addLine(to: pt(0.06, 0.82, w, h))
        p.closeSubpath()
        return p
    }
}

/// Wide stratus cloud — 4 gentle undulations, low and broad.
private struct FluffyCloudShape2: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: pt(0.04, 0.85, w, h))
        // Left rise
        p.addQuadCurve(to: pt(0.10, 0.52, w, h), control: pt(0.01, 0.65, w, h))
        // Bump 1 (small left)
        p.addCurve(to: pt(0.24, 0.38, w, h),
                    control1: pt(0.10, 0.40, w, h), control2: pt(0.16, 0.34, w, h))
        // Bump 2 (left-center)
        p.addCurve(to: pt(0.42, 0.22, w, h),
                    control1: pt(0.30, 0.40, w, h), control2: pt(0.34, 0.22, w, h))
        // Bump 3 (right-center, tallest)
        p.addCurve(to: pt(0.65, 0.18, w, h),
                    control1: pt(0.48, 0.22, w, h), control2: pt(0.56, 0.12, w, h))
        // Bump 4 (small right)
        p.addCurve(to: pt(0.82, 0.38, w, h),
                    control1: pt(0.72, 0.22, w, h), control2: pt(0.78, 0.30, w, h))
        // Right descent
        p.addQuadCurve(to: pt(0.96, 0.85, w, h), control: pt(0.96, 0.55, w, h))
        // Flat base
        p.addLine(to: pt(0.04, 0.85, w, h))
        p.closeSubpath()
        return p
    }
}

/// Puffy asymmetric cloud — big dome on the right, smaller bumps on the left.
private struct FluffyCloudShape3: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: pt(0.05, 0.80, w, h))
        // Left edge
        p.addQuadCurve(to: pt(0.12, 0.50, w, h), control: pt(0.02, 0.62, w, h))
        // Small left bump
        p.addCurve(to: pt(0.26, 0.36, w, h),
                    control1: pt(0.12, 0.38, w, h), control2: pt(0.18, 0.32, w, h))
        // Dip
        p.addQuadCurve(to: pt(0.34, 0.40, w, h), control: pt(0.30, 0.38, w, h))
        // Medium bump
        p.addCurve(to: pt(0.50, 0.22, w, h),
                    control1: pt(0.36, 0.28, w, h), control2: pt(0.42, 0.18, w, h))
        // Big right dome
        p.addCurve(to: pt(0.78, 0.10, w, h),
                    control1: pt(0.56, 0.22, w, h), control2: pt(0.65, 0.06, w, h))
        // Right descent
        p.addCurve(to: pt(0.95, 0.55, w, h),
                    control1: pt(0.90, 0.10, w, h), control2: pt(0.95, 0.35, w, h))
        p.addQuadCurve(to: pt(0.95, 0.80, w, h), control: pt(0.98, 0.70, w, h))
        // Flat base
        p.addLine(to: pt(0.05, 0.80, w, h))
        p.closeSubpath()
        return p
    }
}

/// Helper to convert fractional coordinates to a CGPoint.
private func pt(_ xf: CGFloat, _ yf: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
    CGPoint(x: w * xf, y: h * yf)
}

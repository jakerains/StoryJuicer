import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MacCreationView: View {
    @Bindable var viewModel: CreationViewModel
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground

    @State private var animateTitle = false
    @State private var creationMode: CreationMode = .quick
    @State private var qaViewModel = StoryQAViewModel()
    @State private var showBookSetupPopover = false

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

                        if creationMode == .quick {
                            SqueezeButton(isEnabled: viewModel.canGenerate) {
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
        .onAppear {
            withAnimation(StoryJuicerMotion.emphasis) {
                animateTitle = true
            }
        }
        .onChange(of: creationMode) { _, newMode in
            if newMode == .author && viewModel.authorPages.allSatisfy(\.isEmpty) {
                // Seed 4 empty pages when first entering author mode
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

            bookSetupRow
                .fixedSize()
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

    /// Full TextEditor for typing or editing the story concept.
    private var conceptEditor: some View {
        TextEditor(text: $viewModel.storyConcept)
            .font(StoryJuicerTypography.uiBody)
            .foregroundStyle(Color.sjText)
            .frame(minHeight: 120, maxHeight: 190)
            .padding(StoryJuicerGlassTokens.Spacing.small)
            .scrollContentBackground(.hidden)
            .background(Color.sjReadableCard.opacity(0.9))
            .clipShape(.rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
            .overlay {
                RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                    .strokeBorder(Color.sjBorder.opacity(0.75), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                if viewModel.storyConcept.isEmpty {
                    Text("Describe your story idea... e.g. a curious fox building a moonlight library in the forest")
                        .font(StoryJuicerTypography.uiBody)
                        .foregroundStyle(Color.sjSecondaryText)
                        .padding(StoryJuicerGlassTokens.Spacing.medium)
                        .allowsHitTesting(false)
                }
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

                Text("\(viewModel.pageCount) pages · \(viewModel.selectedFormat.displayName) · \(viewModel.selectedStyle.displayName)")
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
                subtitle: "Configure pages, format, and illustration style.",
                systemImage: "wand.and.stars"
            )

            panelDivider

            pageCountRow

            panelDivider

            formatPickerSection

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

    private var pageCountRow: some View {
        SettingsControlRow(
            title: "Page Count",
            description: "Choose an even value from \(GenerationConfig.minPages) to \(GenerationConfig.maxPages)."
        ) {
            Stepper(
                value: $viewModel.pageCount,
                in: GenerationConfig.minPages...GenerationConfig.maxPages,
                step: 2
            ) {
                Text("\(viewModel.pageCount) pages")
                    .font(StoryJuicerTypography.settingsControl)
                    .foregroundStyle(Color.sjText)
            }
            .frame(width: 210)
            .padding(.horizontal, StoryJuicerGlassTokens.Spacing.small)
            .padding(.vertical, StoryJuicerGlassTokens.Spacing.xSmall + 2)
            .background(Color.sjReadableCard.opacity(0.85), in: .rect(cornerRadius: StoryJuicerGlassTokens.Radius.input))
            .overlay {
                RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                    .strokeBorder(Color.sjBorder.opacity(0.8), lineWidth: 1)
            }
            .tint(.sjCoral)
        }
    }

    private var formatPickerSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            SettingsSectionHeader(
                title: "Book Format",
                subtitle: "Pick page proportions for reading and PDF export.",
                systemImage: "rectangle.portrait.on.rectangle.portrait"
            )

            GlassEffectContainer(spacing: StoryJuicerGlassTokens.Spacing.small) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 145, maximum: 220), spacing: StoryJuicerGlassTokens.Spacing.small)],
                    spacing: StoryJuicerGlassTokens.Spacing.small
                ) {
                    ForEach(BookFormat.allCases) { format in
                        Button {
                            withAnimation(StoryJuicerMotion.standard) {
                                viewModel.selectedFormat = format
                            }
                        } label: {
                            FormatPreviewCard(
                                format: format,
                                isSelected: viewModel.selectedFormat == format
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Book format \(format.displayName)")
                    }
                }
            }
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

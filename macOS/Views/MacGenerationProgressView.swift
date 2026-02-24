import SwiftUI

struct MacGenerationProgressView: View {
    @Bindable var viewModel: CreationViewModel
    let onCancel: () -> Void

    @State private var sparklesAppeared = false
    @State private var heroRingSparklesActive = false
    @State private var progressImageBreathing = false
    @State private var marqueeGlowActive = false
    @State private var marqueeEdgeSparklesActive = false
    @State private var marqueeLineIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            // Floating sparkle particles across the entire view
            floatingSparkles

            ScrollView {
                VStack(spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
                    heroPhaseSection
                    contentAreaCard
                    cancelButton
                }
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.xLarge + 8)
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.xLarge)
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

            // Warm radial glow behind the center — gives a magical lantern feel
            RadialGradient(
                colors: [Color.sjGold.opacity(0.08), Color.sjCoral.opacity(0.1), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 500
            )

            RadialGradient(
                colors: [Color.sjCoral.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
        }
    }

    // MARK: - Floating Sparkles

    private var floatingSparkles: some View {
        let sparkles: [ProgressSparkle] = [
            .init(size: 14, color: .sjGold, x: 0.08, y: 0.12, delay: 0, duration: 5, rotates: true),
            .init(size: 10, color: .sjCoral, x: 0.92, y: 0.08, delay: 1.2, duration: 4.5),
            .init(size: 12, color: .sjHighlight, x: 0.05, y: 0.55, delay: 0.6, duration: 5.5, rotates: true),
            .init(size: 9, color: .sjGold, x: 0.95, y: 0.45, delay: 2, duration: 6),
            .init(size: 16, color: .sjGold, x: 0.15, y: 0.85, delay: 0.3, duration: 4),
            .init(size: 8, color: .sjCoral, x: 0.88, y: 0.78, delay: 1.8, duration: 5.2, rotates: true),
            .init(size: 11, color: .sjHighlight, x: 0.50, y: 0.03, delay: 0.9, duration: 5.8),
            .init(size: 7, color: .sjGold, x: 0.35, y: 0.92, delay: 2.5, duration: 4.8, rotates: true),
            .init(size: 6, color: .sjCoral, x: 0.72, y: 0.15, delay: 1.5, duration: 3.5),
            .init(size: 8, color: .sjGold, x: 0.22, y: 0.38, delay: 0.4, duration: 6.2),
            .init(size: 5, color: .sjHighlight, x: 0.78, y: 0.62, delay: 2.2, duration: 3.8, rotates: true),
            .init(size: 7, color: .sjGold, x: 0.42, y: 0.70, delay: 1, duration: 5),
        ]

        return GeometryReader { geo in
            ForEach(Array(sparkles.enumerated()), id: \.offset) { _, s in
                SparkleStarShape()
                    .fill(s.color)
                    .frame(width: s.size, height: s.size)
                    .opacity(sparklesAppeared ? (s.size > 10 ? 0.45 : 0.25) : 0)
                    .scaleEffect(reduceMotion ? 1.0 : (sparklesAppeared ? 1.0 : 0.3))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (sparklesAppeared && s.rotates ? 360 : 0)))
                    .position(
                        x: geo.size.width * s.x,
                        y: geo.size.height * s.y + (reduceMotion ? 0 : (sparklesAppeared ? -8 : 8))
                    )
                    .animation(
                        .easeInOut(duration: s.duration)
                            .repeatForever(autoreverses: true)
                            .delay(s.delay),
                        value: sparklesAppeared
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { sparklesAppeared = true }
    }

    // MARK: - Hero Phase Section (centered, magical)

    private var heroPhaseSection: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            // Progress image with sparkle glow
            if let imageName = progressImageName {
                progressImageHero(named: imageName)
            }

            // Phase title with gradient
            phaseTitle

            // Provider badge
            providerBadge(phaseProviderLabel)

            // Subtitle description
            Text(phaseDescription)
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjSecondaryText)
                .multilineTextAlignment(.center)

            // Phase-specific progress indicator
            phaseProgressIndicator

            // Character photo reference (character sheet phase only)
            if case .generatingCharacterSheet = viewModel.phase,
               let firstPhoto = viewModel.characterPhotos.first {
                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Image(firstPhoto.photo, scale: 1.0, label: Text("Reference photo"))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.sjCoral.opacity(0.4), lineWidth: 1)
                        }

                    Text("Using uploaded photo as reference")
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StoryJuicerGlassTokens.Spacing.xLarge)
        .padding(.horizontal, StoryJuicerGlassTokens.Spacing.large)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.sjGold.opacity(0.3), Color.sjCoral.opacity(0.25), Color.sjBorder.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var phaseTitle: some View {
        Text(phaseTitleText)
            .font(StoryJuicerTypography.sectionHero)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.sjCoral, Color.sjGold],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .multilineTextAlignment(.center)
    }

    private var phaseTitleText: String {
        switch viewModel.phase {
        case .generatingText:            return "Writing your story"
        case .generatingCharacterSheet:  return "Creating characters"
        case .generatingImages:          return "Painting illustrations"
        default:                         return "Preparing"
        }
    }

    private var phaseProviderLabel: String {
        switch viewModel.phase {
        case .generatingText:            return currentSettings.resolvedTextModelLabel
        case .generatingCharacterSheet:  return "Premium"
        case .generatingImages:          return activeImageModelLabel
        default:                         return ""
        }
    }

    private var phaseDescription: String {
        switch viewModel.phase {
        case .generatingText:
            return textProviderDescription
        case .generatingCharacterSheet:
            return "Sketching your character from every angle so they look just right on every page."
        case .generatingImages(let completed, let total):
            return "Painting page \(completed) of \(total) with enchanted brushes"
        default:
            return ""
        }
    }

    @ViewBuilder
    private var phaseProgressIndicator: some View {
        switch viewModel.phase {
        case .generatingText:
            ProgressView()
                .scaleEffect(1.15)
                .tint(Color.sjCoral)

        case .generatingCharacterSheet:
            ProgressView()
                .scaleEffect(1.15)
                .tint(Color.sjCoral)

        case .generatingImages(let completed, let total):
            ProgressView(value: Double(completed), total: Double(total))
                .tint(Color.sjCoral)
                .frame(maxWidth: 300)

        default:
            EmptyView()
        }
    }

    // MARK: - Settings & Helpers

    private var currentSettings: ModelSelectionSettings {
        var settings = ModelSelectionStore.load()
        if PremiumStore.load().tier.isActive {
            settings.textProvider = .openAI
            settings.imageProvider = .openAI
        }
        return settings
    }

    private var progressImageName: String? {
        switch viewModel.phase {
        case .generatingText:            return "PremiumProgressWriting"
        case .generatingCharacterSheet:  return "PremiumProgressCharacter"
        case .generatingImages:          return "PremiumProgressPainting"
        default:                         return nil
        }
    }

    private var activeImageModelLabel: String {
        if let actual = viewModel.illustrationGenerator.activeImageProvider,
           actual != currentSettings.imageProvider {
            return actual.displayName
        }
        return currentSettings.resolvedImageModelLabel
    }

    private func providerBadge(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.sjCoral)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.sjCoral.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.sjCoral.opacity(0.3), lineWidth: 1)
            }
    }

    private var textProviderDescription: String {
        "Our storytelling fox is weaving your tale, one page at a time."
    }

    // MARK: - Progress Image

    private var heroRingSparkles: [ProgressHeroRingSparkle] {
        [
            // Near ring (larger/brighter)
            .init(size: 14, color: .sjGold, offsetX: -134, offsetY: -68, drift: 6, delay: 0.0, duration: 5.0, rotates: true, opacity: 0.72),
            .init(size: 12, color: .sjCoral, offsetX: 126, offsetY: -76, drift: 5, delay: 1.2, duration: 4.6, opacity: 0.68),
            .init(size: 13, color: .sjHighlight, offsetX: 138, offsetY: 52, drift: 6, delay: 0.8, duration: 5.4, rotates: true, opacity: 0.7),
            .init(size: 11, color: .sjGold, offsetX: -146, offsetY: 60, drift: 5, delay: 1.8, duration: 6.0, opacity: 0.64),
            .init(size: 12, color: .sjCoral, offsetX: -82, offsetY: -112, drift: 5, delay: 0.5, duration: 5.2, rotates: true, opacity: 0.66),
            .init(size: 13, color: .sjGold, offsetX: 86, offsetY: -114, drift: 6, delay: 2.4, duration: 4.8, opacity: 0.72),
            .init(size: 10, color: .sjHighlight, offsetX: -92, offsetY: 102, drift: 4, delay: 1.1, duration: 6.2, opacity: 0.58),
            .init(size: 11, color: .sjGold, offsetX: 94, offsetY: 104, drift: 5, delay: 2.0, duration: 5.6, opacity: 0.62),
            // Outer ring (smaller/subtler)
            .init(size: 8, color: .sjGold, offsetX: -174, offsetY: -92, drift: 4, delay: 0.4, duration: 3.6, opacity: 0.42),
            .init(size: 7, color: .sjCoral, offsetX: 176, offsetY: -84, drift: 3, delay: 1.6, duration: 3.3, opacity: 0.38),
            .init(size: 7, color: .sjHighlight, offsetX: -182, offsetY: 34, drift: 3, delay: 2.3, duration: 3.8, rotates: true, opacity: 0.36),
            .init(size: 8, color: .sjGold, offsetX: 184, offsetY: 24, drift: 4, delay: 0.9, duration: 3.4, opacity: 0.4),
            .init(size: 6, color: .sjCoral, offsetX: -136, offsetY: 140, drift: 3, delay: 1.4, duration: 3.7, opacity: 0.34),
            .init(size: 7, color: .sjGold, offsetX: 132, offsetY: 146, drift: 3, delay: 0.2, duration: 3.5, opacity: 0.36),
        ]
    }

    private func progressImageHero(named assetName: String) -> some View {
        ZStack {
            ForEach(Array(heroRingSparkles.enumerated()), id: \.offset) { _, sparkle in
                SparkleStarShape()
                    .fill(sparkle.color)
                    .frame(width: sparkle.size, height: sparkle.size)
                    .offset(
                        x: sparkle.offsetX,
                        y: sparkle.offsetY + (reduceMotion ? 0 : (heroRingSparklesActive ? -sparkle.drift : sparkle.drift))
                    )
                    .scaleEffect(heroRingSparklesActive ? 1.0 : 0.9)
                    .opacity(heroRingSparklesActive ? sparkle.opacity : sparkle.opacity * 0.5)
                    .rotationEffect(
                        .degrees(reduceMotion ? 0 : (sparkle.rotates ? (heroRingSparklesActive ? 170 : 0) : 0))
                    )
                    .shadow(color: sparkle.color.opacity(0.3), radius: sparkle.size >= 10 ? 6 : 3, y: 0)
                    .animation(
                        .easeInOut(duration: sparkle.duration)
                            .repeatForever(autoreverses: true)
                            .delay(sparkle.delay),
                        value: heroRingSparklesActive
                    )
            }

            progressImageView(named: assetName)
        }
        .frame(width: 380, height: 280)
        .onAppear { heroRingSparklesActive = true }
    }

    private func progressImageView(named assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 220, maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .opacity(progressImageBreathing ? 1.0 : 0.82)
            .scaleEffect(progressImageBreathing ? 1.0 : 0.97)
            .animation(
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                value: progressImageBreathing
            )
            .shadow(color: Color.sjGold.opacity(0.25), radius: 20, y: 6)
            .shadow(color: Color.sjCoral.opacity(0.15), radius: 8, y: 2)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .onAppear { progressImageBreathing = true }
    }

    // MARK: - Content Area Card

    private var contentAreaCard: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            switch viewModel.phase {
            case .generatingText(let partialText):
                textStreamingView(partialText)
            case .generatingCharacterSheet:
                characterSheetProgressView
            case .generatingImages:
                imageProgressGrid
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(StoryJuicerGlassTokens.Spacing.large)
        .sjGlassCard(
            tint: .sjGlassWeak.opacity(0.6),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
    }

    // MARK: - Text Streaming

    private func textStreamingView(_ text: String) -> some View {
        let mode = textStreamingMode(from: text)

        return VStack(spacing: StoryJuicerGlassTokens.Spacing.medium) {
            if let book = viewModel.storyBook {
                Text(book.title)
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.sjGlassInk, Color.sjCoral.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
            }

            switch mode {
            case .story(let storyText):
                Text(storyText)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.sjText)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .animation(StoryJuicerMotion.standard, value: storyText)
                    .textSelection(.enabled)
            case .marquee(let liveText):
                magicalStatusMarquee(liveText: liveText)
            }
        }
    }

    private var rotatingWhimsicalLines: [String] {
        [
            "Spinning starlight into story pages...",
            "Waking the fox's golden quill...",
            "Threading wonder through every line...",
            "Gathering little sparks for your tale...",
        ]
    }

    private func magicalStatusMarquee(liveText: String?) -> some View {
        let marqueeText = liveText ?? rotatingWhimsicalLines[marqueeLineIndex % rotatingWhimsicalLines.count]

        return ZStack {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                .fill(Color.sjGlassWeak.opacity(0.34))

            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.sjCoral.opacity(0.35), Color.sjGold.opacity(0.45), Color.sjBorder.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )

            Text(marqueeText)
                .id(marqueeText)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.sjCoral, Color.sjGold, Color.sjHighlight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.sjGold.opacity(marqueeGlowActive ? 0.34 : 0.14), radius: marqueeGlowActive ? 10 : 4, y: 0)
                .shadow(color: Color.sjCoral.opacity(0.18), radius: 2, y: 0)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(StoryJuicerMotion.standard, value: marqueeText)
                .animation(
                    .easeInOut(duration: reduceMotion ? 2.8 : 2.0).repeatForever(autoreverses: true),
                    value: marqueeGlowActive
                )

            HStack {
                ZStack {
                    SparkleStarShape()
                        .fill(Color.sjGold.opacity(marqueeEdgeSparklesActive ? 0.7 : 0.35))
                        .frame(width: 10, height: 10)
                        .scaleEffect(marqueeEdgeSparklesActive ? 1.0 : 0.75)
                    SparkleStarShape()
                        .fill(Color.sjCoral.opacity(marqueeEdgeSparklesActive ? 0.6 : 0.3))
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: 6)
                        .scaleEffect(marqueeEdgeSparklesActive ? 0.95 : 0.65)
                }
                .offset(x: 12)
                .animation(
                    .easeInOut(duration: reduceMotion ? 2.6 : 1.8).repeatForever(autoreverses: true),
                    value: marqueeEdgeSparklesActive
                )

                Spacer(minLength: 0)

                ZStack {
                    SparkleStarShape()
                        .fill(Color.sjGold.opacity(marqueeEdgeSparklesActive ? 0.7 : 0.35))
                        .frame(width: 10, height: 10)
                        .scaleEffect(marqueeEdgeSparklesActive ? 1.0 : 0.75)
                    SparkleStarShape()
                        .fill(Color.sjCoral.opacity(marqueeEdgeSparklesActive ? 0.6 : 0.3))
                        .frame(width: 6, height: 6)
                        .offset(x: -8, y: 6)
                        .scaleEffect(marqueeEdgeSparklesActive ? 0.95 : 0.65)
                }
                .offset(x: -12)
                .animation(
                    .easeInOut(duration: reduceMotion ? 2.6 : 1.8)
                        .repeatForever(autoreverses: true)
                        .delay(0.3),
                    value: marqueeEdgeSparklesActive
                )
            }
            .padding(.horizontal, 8)

        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.input))
        .onAppear {
            marqueeGlowActive = true
            marqueeEdgeSparklesActive = true
        }
        .task(id: liveText == nil) {
            guard liveText == nil else { return }
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.6))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    marqueeLineIndex = (marqueeLineIndex + 1) % rotatingWhimsicalLines.count
                }
            }
        }
    }

    private enum TextStreamingMode {
        case story(String)
        case marquee(liveText: String?)
    }

    private func textStreamingMode(from text: String) -> TextStreamingMode {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .marquee(liveText: nil)
        }
        guard !looksLikeRawModelJSON(trimmed) else {
            return .marquee(liveText: nil)
        }
        if shouldShowLiveProviderStatus(trimmed) {
            return .marquee(liveText: trimmed)
        }
        if isKnownProviderStatus(trimmed) {
            return .marquee(liveText: nil)
        }
        return .story(text)
    }

    private func shouldShowLiveProviderStatus(_ text: String) -> Bool {
        let normalized = normalizedStatusText(text)
        if normalized.contains("%") && normalized.contains(where: { $0.isNumber }) {
            return true
        }
        if normalized.contains("try that again") || normalized.contains("sketch those illustrations again") {
            return true
        }
        return false
    }

    private func isKnownProviderStatus(_ text: String) -> Bool {
        let normalized = normalizedStatusText(text)
        let knownStatuses: [String] = [
            "spinning starlight into story pages...",
            "weaving words and wonder...",
            "dreaming up illustrations for each page...",
            "tidying up the pages...",
            "fetching the fox's quill...",
            "quill ready! writing your story...",
            "scribbling away...",
            "preparing your story...",
            "planning the illustrations...",
            "turning the page...",
            "generating draft pages...",
        ]
        return knownStatuses.contains { normalized == $0 }
    }

    private func normalizedStatusText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "…", with: "...")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func looksLikeRawModelJSON(_ text: String) -> Bool {
        if text.first == "{" || text.first == "[" {
            return true
        }
        let jsonMarkers = ["\"title\"", "\"authorLine\"", "\"moral\"", "\"pages\"", "\"imagePrompt\""]
        return jsonMarkers.contains(where: { text.contains($0) })
    }

    // MARK: - Character Sheet Progress

    private var characterSheetProgressView: some View {
        VStack(alignment: .center, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            if let book = viewModel.storyBook {
                Text(book.title)
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(Color.sjGlassInk)
                    .multilineTextAlignment(.center)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.sjGlassWeak.opacity(0.3))
                    .frame(width: 200, height: 200)

                if let firstPhoto = viewModel.characterPhotos.first {
                    Image(firstPhoto.photo, scale: 1.0, label: Text("Character photo"))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .opacity(0.6)
                } else {
                    Image(systemName: "person.crop.artframe")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.sjCoral.opacity(0.5))
                }

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color.sjCoral)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.sjCoral.opacity(0.3), lineWidth: 1.5)
            }

            Text("Transforming into \(viewModel.selectedStyle.displayName.lowercased()) style...")
                .font(StoryJuicerTypography.uiBody)
                .foregroundStyle(Color.sjSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Image Progress Grid

    private var imageProgressGrid: some View {
        GlassEffectContainer(spacing: StoryJuicerGlassTokens.Spacing.small) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: StoryJuicerGlassTokens.Spacing.small)],
                spacing: StoryJuicerGlassTokens.Spacing.small
            ) {
                if let book = viewModel.storyBook {
                    let ratio = viewModel.selectedFormat.aspectRatio

                    if let sheet = viewModel.characterSheetImage {
                        characterSheetThumbnail(sheet, aspectRatio: ratio)
                    }

                    PageThumbnail(
                        pageNumber: 0,
                        image: viewModel.generatedImages[0],
                        isGenerating: viewModel.generatedImages[0] == nil,
                        aspectRatio: ratio
                    )

                    ForEach(book.pages, id: \.pageNumber) { page in
                        PageThumbnail(
                            pageNumber: page.pageNumber,
                            image: viewModel.generatedImages[page.pageNumber],
                            isGenerating: viewModel.generatedImages[page.pageNumber] == nil,
                            aspectRatio: ratio
                        )
                    }
                }
            }
        }
    }

    private func characterSheetThumbnail(_ image: CGImage, aspectRatio: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(image, scale: 1.0, label: Text("Character sheet"))
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Ref")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.sjCoral)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.sjCoral.opacity(0.12), in: Capsule())
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.sjCoral.opacity(0.4), lineWidth: 1.5)
        }
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button("Cancel Generation") {
            onCancel()
        }
        .sjGlassToolbarItem(prominent: false)
        .tint(Color.sjCoral)
    }
}

// MARK: - Progress Sparkle Data

private struct ProgressSparkle {
    let size: CGFloat
    let color: Color
    let x: CGFloat      // 0...1 fraction of view width
    let y: CGFloat      // 0...1 fraction of view height
    let delay: Double
    let duration: Double
    var rotates: Bool = false
}

private struct ProgressHeroRingSparkle {
    let size: CGFloat
    let color: Color
    let offsetX: CGFloat
    let offsetY: CGFloat
    let drift: CGFloat
    let delay: Double
    let duration: Double
    var rotates: Bool = false
    var opacity: Double = 0.7
}

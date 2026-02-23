import SwiftUI

struct MacGenerationProgressView: View {
    @Bindable var viewModel: CreationViewModel
    let onCancel: () -> Void

    @State private var sparklesAppeared = false
    @State private var premiumImageBreathing = false

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
                    .opacity(sparklesAppeared ? s.size > 10 ? 0.6 : 0.35 : 0)
                    .scaleEffect(sparklesAppeared ? 1.0 : 0.3)
                    .rotationEffect(.degrees(sparklesAppeared && s.rotates ? 360 : 0))
                    .position(
                        x: geo.size.width * s.x,
                        y: geo.size.height * s.y + (sparklesAppeared ? -8 : 8)
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
            // Premium progress image with sparkle glow
            if isPremium, let imageName = premiumProgressImageName {
                premiumProgressImageView(named: imageName)
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

    private var isPremium: Bool {
        PremiumStore.load().tier.isActive
    }

    private var premiumProgressImageName: String? {
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

    // MARK: - Premium Progress Image

    private func premiumProgressImageView(named assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 220, maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .opacity(premiumImageBreathing ? 1.0 : 0.82)
            .scaleEffect(premiumImageBreathing ? 1.0 : 0.97)
            .animation(
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                value: premiumImageBreathing
            )
            .shadow(color: Color.sjGold.opacity(0.25), radius: 20, y: 6)
            .shadow(color: Color.sjCoral.opacity(0.15), radius: 8, y: 2)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .onAppear { premiumImageBreathing = true }
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
        let displayText = userFacingStreamingText(from: text)

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

            Text(displayText)
                .font(.system(.body, design: .serif))
                .foregroundStyle(displayText == "Generating draft pages..." ? Color.sjSecondaryText : Color.sjText)
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .animation(StoryJuicerMotion.standard, value: displayText)
                .textSelection(.enabled)
        }
    }

    private func userFacingStreamingText(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Turning the page..."
        }
        guard !looksLikeRawModelJSON(trimmed) else {
            return "Turning the page..."
        }
        return text
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

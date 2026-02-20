import SwiftUI

struct MacGenerationProgressView: View {
    @Bindable var viewModel: CreationViewModel
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
                    phaseHeaderCard
                    contentAreaCard
                    cancelButton
                }
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.xLarge + 8)
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.xLarge)
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sjPaperTop, Color.sjBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.sjCoral.opacity(0.14), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
        }
    }

    private var phaseHeaderCard: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            Text("Generation in progress")
                .font(StoryJuicerTypography.sectionHero)
                .foregroundStyle(Color.sjGlassInk)

            phaseIndicator
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StoryJuicerGlassTokens.Spacing.large)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
                .strokeBorder(Color.sjBorder.opacity(0.7), lineWidth: 1)
        }
    }

    private var currentSettings: ModelSelectionSettings {
        ModelSelectionStore.load()
    }

    /// Reflects the actual image provider in use, including fallbacks.
    private var activeImageModelLabel: String {
        if let actual = viewModel.illustrationGenerator.activeImageProvider,
           actual != currentSettings.imageProvider {
            // Fallback occurred — show what's actually running
            return actual.displayName
        }
        return currentSettings.resolvedImageModelLabel
    }

    @ViewBuilder
    private var phaseIndicator: some View {
        switch viewModel.phase {
        case .generatingText:
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(Color.sjCoral)

                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Text("Writing your story")
                        .font(StoryJuicerTypography.uiTitle)
                        .foregroundStyle(Color.sjGlassInk)

                    providerBadge(currentSettings.resolvedTextModelLabel)
                }

                Text(textProviderDescription)
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjSecondaryText)
            }

        case .generatingImages(let completed, let total):
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                ProgressView(value: Double(completed), total: Double(total))
                    .tint(Color.sjCoral)
                    .frame(maxWidth: 360)

                HStack(spacing: StoryJuicerGlassTokens.Spacing.small) {
                    Text("Painting illustrations")
                        .font(StoryJuicerTypography.uiTitle)
                        .foregroundStyle(Color.sjGlassInk)

                    providerBadge(activeImageModelLabel)
                }

                Text("Illustrating page \(completed) of \(total)")
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjSecondaryText)

                if let status = viewModel.illustrationGenerator.lastStatusMessage,
                   !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(status)
                        .font(StoryJuicerTypography.uiMeta)
                        .foregroundStyle(Color.sjSecondaryText)
                }
            }

        default:
            EmptyView()
        }
    }

    private func providerBadge(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.sjCoral)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.sjCoral.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.sjCoral.opacity(0.3), lineWidth: 1)
            }
    }

    private var textProviderDescription: String {
        switch currentSettings.textProvider {
        case .appleFoundation:
            return "On-device Apple Foundation model is composing each page."
        case .mlxSwift:
            return "Local MLX model is composing each page."
        case .openRouter:
            return "OpenRouter cloud model is composing each page."
        case .togetherAI:
            return "Together AI cloud model is composing each page."
        case .huggingFace:
            return "Hugging Face cloud model is composing each page."
        }
    }

    private var contentAreaCard: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.medium) {
            switch viewModel.phase {
            case .generatingText(let partialText):
                textStreamingView(partialText)
            case .generatingImages:
                imageProgressGrid
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StoryJuicerGlassTokens.Spacing.large)
        .sjGlassCard(
            tint: .sjGlassWeak.opacity(0.6),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
    }

    private func textStreamingView(_ text: String) -> some View {
        let displayText = userFacingStreamingText(from: text)

        return VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            if let book = viewModel.storyBook {
                Text(book.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.sjGlassInk)
            }

            Text(displayText)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(displayText == "Generating draft pages..." ? Color.sjSecondaryText : Color.sjText)
                .lineSpacing(7)
                .animation(StoryJuicerMotion.standard, value: displayText)
                .textSelection(.enabled)
        }
    }

    private func userFacingStreamingText(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Generating draft pages..."
        }
        guard !looksLikeRawModelJSON(trimmed) else {
            return "Generating draft pages..."
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

    private var imageProgressGrid: some View {
        GlassEffectContainer(spacing: StoryJuicerGlassTokens.Spacing.small) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: StoryJuicerGlassTokens.Spacing.small)],
                spacing: StoryJuicerGlassTokens.Spacing.small
            ) {
                if let book = viewModel.storyBook {
                    let ratio = viewModel.selectedFormat.aspectRatio

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

    private var cancelButton: some View {
        Button("Cancel Generation") {
            onCancel()
        }
        .sjGlassToolbarItem(prominent: false)
        .tint(Color.sjCoral)
    }
}

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

    @ViewBuilder
    private var phaseIndicator: some View {
        switch viewModel.phase {
        case .generatingText:
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(Color.sjCoral)

                Text("Writing your story")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Text("The on-device model is composing each page and scene prompt.")
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjSecondaryText)
            }

        case .generatingImages(let completed, let total):
            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
                ProgressView(value: Double(completed), total: Double(total))
                    .tint(Color.sjCoral)
                    .frame(maxWidth: 360)

                Text("Painting illustrations")
                    .font(StoryJuicerTypography.uiTitle)
                    .foregroundStyle(Color.sjGlassInk)

                Text("Illustrating page \(completed) of \(total)")
                    .font(StoryJuicerTypography.uiBody)
                    .foregroundStyle(Color.sjSecondaryText)
            }

        default:
            EmptyView()
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
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            if let book = viewModel.storyBook {
                Text(book.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.sjGlassInk)
            }

            Text(text.isEmpty ? "Generating draft pages..." : text)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(text.isEmpty ? Color.sjSecondaryText : Color.sjText)
                .lineSpacing(7)
                .animation(StoryJuicerMotion.standard, value: text)
                .textSelection(.enabled)
        }
    }

    private var imageProgressGrid: some View {
        GlassEffectContainer(spacing: StoryJuicerGlassTokens.Spacing.small) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: StoryJuicerGlassTokens.Spacing.small)],
                spacing: StoryJuicerGlassTokens.Spacing.small
            ) {
                if let book = viewModel.storyBook {
                    PageThumbnail(
                        pageNumber: 0,
                        image: viewModel.generatedImages[0],
                        isGenerating: viewModel.generatedImages[0] == nil
                    )

                    ForEach(book.pages, id: \.pageNumber) { page in
                        PageThumbnail(
                            pageNumber: page.pageNumber,
                            image: viewModel.generatedImages[page.pageNumber],
                            isGenerating: viewModel.generatedImages[page.pageNumber] == nil
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

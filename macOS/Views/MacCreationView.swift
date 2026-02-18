import SwiftUI

struct MacCreationView: View {
    @Bindable var viewModel: CreationViewModel
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground

    @State private var animateHero = false

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: StoryJuicerGlassTokens.Spacing.xLarge) {
                    headerSection

                    if case .failed(let message) = viewModel.phase {
                        ErrorBanner(
                            message: message,
                            onRetry: { viewModel.squeezeStory() },
                            onDismiss: { viewModel.reset() }
                        )
                    }

                    conceptSection
                    settingsSection

                    SqueezeButton(isEnabled: viewModel.canGenerate) {
                        viewModel.squeezeStory()
                    }
                    .padding(.top, StoryJuicerGlassTokens.Spacing.small)
                }
                .padding(.horizontal, StoryJuicerGlassTokens.Spacing.xLarge + 8)
                .padding(.vertical, StoryJuicerGlassTokens.Spacing.xLarge)
            }

            if let reason = viewModel.unavailabilityReason {
                UnavailableOverlay(reason: reason)
            }
        }
        .onAppear {
            withAnimation(StoryJuicerMotion.emphasis) {
                animateHero = true
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

    private var headerSection: some View {
        HStack(alignment: .top, spacing: StoryJuicerGlassTokens.Spacing.large) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.sjCoral.opacity(0.9), Color.sjGold.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "book.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 66, height: 66)
            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
            .scaleEffect(animateHero ? 1 : 0.94)

            VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.xSmall) {
                Text("StoryJuicer")
                    .font(StoryJuicerTypography.brandHero)
                    .foregroundStyle(Color.sjGlassInk)

                Text("Create editorial-quality illustrated books with on-device Apple intelligence.")
                    .font(StoryJuicerTypography.uiBodyStrong)
                    .foregroundStyle(Color.sjSecondaryText)

                Text("No cloud calls. No API keys. Just your idea and your Mac.")
                    .font(StoryJuicerTypography.uiMeta)
                    .foregroundStyle(Color.sjSecondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(StoryJuicerGlassTokens.Spacing.large)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.standard),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
                .strokeBorder(Color.sjBorder.opacity(0.65), lineWidth: 1)
        }
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Label("Story Concept", systemImage: "sparkles")
                .font(StoryJuicerTypography.uiTitle)
                .foregroundStyle(Color.sjGlassInk)

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
        .padding(StoryJuicerGlassTokens.Spacing.large)
        .sjGlassCard(
            tint: .sjGlassSoft.opacity(StoryJuicerGlassTokens.Tint.subtle),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
    }

    private var settingsSection: some View {
        VStack(spacing: StoryJuicerGlassTokens.Spacing.large) {
            pageCountRow

            Divider()
                .overlay(Color.sjBorder.opacity(0.65))

            formatPickerSection

            Divider()
                .overlay(Color.sjBorder.opacity(0.65))

            stylePickerSection
        }
        .padding(StoryJuicerGlassTokens.Spacing.large)
        .sjGlassCard(
            tint: .sjGlassWeak.opacity(0.65),
            cornerRadius: StoryJuicerGlassTokens.Radius.hero
        )
        .overlay {
            RoundedRectangle(cornerRadius: StoryJuicerGlassTokens.Radius.hero)
                .strokeBorder(Color.sjBorder.opacity(0.65), lineWidth: 1)
        }
    }

    private var pageCountRow: some View {
        HStack {
            Label("Pages", systemImage: "doc.on.doc")
                .font(StoryJuicerTypography.uiTitle)
                .foregroundStyle(Color.sjGlassInk)

            Spacer()

            Stepper(
                "\(viewModel.pageCount) pages",
                value: $viewModel.pageCount,
                in: GenerationConfig.minPages...GenerationConfig.maxPages,
                step: 2
            )
            .frame(width: 190)
        }
    }

    private var formatPickerSection: some View {
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Label("Book Format", systemImage: "rectangle.portrait.on.rectangle.portrait")
                .font(StoryJuicerTypography.uiTitle)
                .foregroundStyle(Color.sjGlassInk)

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
        VStack(alignment: .leading, spacing: StoryJuicerGlassTokens.Spacing.small) {
            Label("Illustration Style", systemImage: "paintbrush.fill")
                .font(StoryJuicerTypography.uiTitle)
                .foregroundStyle(Color.sjGlassInk)

            if !supportsImagePlayground {
                Label("Image Playground is not available on this device.", systemImage: "exclamationmark.triangle")
                    .font(StoryJuicerTypography.uiMetaStrong)
                    .foregroundStyle(Color.sjCoral)
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
}
